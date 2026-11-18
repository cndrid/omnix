import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track_model.dart';
import 'skip_service.dart';
import 'stream_extractor.dart';

/// Handler audio OmniX: just_audio + audio_service.
///
/// Ketahanan jaringan (17 Nov 2026):
/// - Setiap stream diputar lewat [LockCachingAudioSource]: audio yang
///   sudah terunduh tersimpan di cache lokal, jadi kalau internet putus
///   sesaat, bagian yang sudah ter-buffer tetap jalan, dan lagu yang
///   diputar ulang langsung diambil dari cache tanpa unduh ulang.
/// - Segmen sponsor/intro/outro (SponsorBlock) dilewati otomatis.
/// - Kalau satu URL gagal dimuat, pemanggil mencoba kandidat berikutnya
///   (lihat PlayerController.selectTrack) — layar tidak langsung merah.
///
/// Perbaikan 18 Nov 2026 (buffering + fast start + bug klik play 2x):
/// - Fast start: [AudioLoadConfiguration] mulai putar tanpa menunggu
///   buffer penuh (bufferForPlayback 0) tapi tetap buffer jauh ke depan
///   (min 60 dtk / maks 200 dtk, ala SimpMusic).
/// - Cache audio permanen di dokumen aplikasi (bukan direktori sementara
///   yang bisa dibersihkan OS), tetap maks. 50 file terbaru.
/// - Auto-recovery: kalau lagu macet di tengah jalan (buffering > ~10
///   detik atau error dari player), link baru di-extract ulang
///   (langsung -> Piped) dan pemutaran lanjut dari posisi terakhir,
///   maks. 3x coba. Selama recovery UI menampilkan spinner, bukan kartu
///   error; kartu error netral + tombol Coba Lagi baru muncul kalau 3x
///   gagal (lewat [onRecoveryFailed]).
/// - Bug klik play 2x: [loadAndPlay] membersihkan flag playing yang basi
///   dulu (`pause()` sebelum `setAudioSource`), dan `play()` diberi batas
///   waktu ±5 detik + satu kali coba ulang supaya tidak menggantung
///   kalau audio focus Android ditolak.
class OmniXAudioHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  /// Fast start (18 Nov 2026): mulai putar instan, buffer jauh ke depan.
  final AudioPlayer _player = AudioPlayer(
    audioLoadConfiguration: const AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        minBufferDuration: Duration(seconds: 60),
        maxBufferDuration: Duration(seconds: 200),
        bufferForPlaybackDuration: Duration.zero,
        bufferForPlaybackAfterRebufferDuration: Duration.zero,
      ),
      darwinLoadControl: DarwinLoadControl(
        automaticallyWaitsToMinimizeStalling: false,
      ),
    ),
  );
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<ProcessingState>? _processingStateSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<PlaybackEvent>? _playbackEventSub;
  List<SkipSegment> _skipSegments = const [];

  // --- Auto-recovery (18 Nov 2026) ---
  static const _stallThreshold = Duration(seconds: 10);
  static const _maxRecoveryAttempts = 3;
  Timer? _stallTimer;
  bool _hasStartedPlaying = false;
  bool _recovering = false;
  int _loadGeneration = 0;
  TrackModel? _currentTrack;
  String? _currentStreamUrl;

  /// Dipanggil saat auto-recovery mulai (true) / selesai (false): selama
  /// recovery, provider menampilkan spinner (isLoadingTrack = true),
  /// BUKAN kartu error. Hanya dipanggil kalau recovery ini masih berlaku
  /// (pengguna belum pindah lagu lain).
  void Function(bool recovering)? onRecoveryStateChanged;

  /// Dipanggil kalau 3x percobaan recovery gagal: baru saat itu provider
  /// menampilkan kartu error netral + tombol Coba Lagi.
  void Function(String message)? onRecoveryFailed;

  AudioPlayer get player => _player;

  OmniXAudioHandler() {
    _initAudioSession();
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _processingStateSub =
        _player.processingStateStream.listen(_onProcessingState);
    _playingSub = _player.playingStream.listen((playing) {
      if (playing) _hasStartedPlaying = true;
    });
    // Error dari platform saat pemutaran berjalan (mis. stream putus di
    // tengah lagu) tidak dilempar ke pemanggil — just_audio melaporkannya
    // lewat playbackEventStream. Tangkap di sini untuk memicu recovery.
    _playbackEventSub = _player.playbackEventStream.listen(
      (_) {},
      onError: (_) => _onPlaybackError(),
    );
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  static const _chromeUa =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  /// Direktori cache audio permanen (maks. 50 file terbaru, dibersihkan
  /// berkala). Sejak 18 Nov 2026 memakai dokumen aplikasi, bukan direktori
  /// sementara — cache lama bisa dibersihkan OS sewaktu-waktu sehingga lagu
  /// yang sudah terunduh hilang dan harus unduh ulang.
  Future<Directory> _cacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/audio_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<void> _pruneCache(Directory dir) async {
    try {
      final files = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      if (files.length <= 50) return;
      files.sort((a, b) => b
          .lastModifiedSync()
          .compareTo(a.lastModifiedSync()));
      for (final f in files.skip(50)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Kunci cache dari URL stream (videoId + itag, kalau ada).
  String? _cacheKeyFor(String videoId, String streamUrl) {
    final m = RegExp(r'[?&]itag=(\d+)').firstMatch(streamUrl);
    if (m == null) return null;
    return '$videoId-${m.group(1)}';
  }

  /// Buang file cache setengah jalan dari URL yang sedang dipakai — dipakai
  /// tiap percobaan auto-recovery supaya percobaan berikut memakai file
  /// cache baru, bukan melanjutkan unduhan yang sudah rusak/terpotong.
  Future<void> _discardPartialCache() async {
    final track = _currentTrack;
    final url = _currentStreamUrl;
    if (track == null || url == null) return;
    final key = _cacheKeyFor(track.videoId, url);
    if (key == null) return;
    try {
      final dir = await _cacheDir();
      final file = File('${dir.path}/$key.cache');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Deteksi macet lewat processingState: buffering yang bertahan lebih
  /// dari ~10 detik padahal lagu sudah mulai bunyi. Buffering di awal
  /// pemuatan sengaja TIDAK memicu recovery (lagu belum mulai bunyi —
  /// kegagalan di sana sudah ditangani loop kandidat di selectTrack).
  void _onProcessingState(ProcessingState state) {
    _stallTimer?.cancel();
    _stallTimer = null;
    if (state == ProcessingState.buffering &&
        _hasStartedPlaying &&
        !_recovering &&
        _currentTrack != null) {
      _stallTimer = Timer(_stallThreshold, () {
        unawaited(_recoverStall());
      });
    }
  }

  /// Deteksi macet lewat error player (stream putus di tengah lagu).
  /// Kalau pengguna sudah menekan pause, jangan pulihkan — biarkan diam.
  void _onPlaybackError() {
    if (_recovering || !_hasStartedPlaying || _currentTrack == null) return;
    if (!_player.playing) return;
    unawaited(_recoverStall());
  }

  /// Pulihkan stream yang macet: extract ulang link baru (langsung dulu,
  /// lalu Piped — lihat StreamExtractor) dan lanjut dari posisi terakhir
  /// berhenti, bukan dari awal. Maks. 3x coba; tiap percobaan gagal
  /// membuang cache setengah jalannya dan memakai file cache baru.
  /// Selama proses, provider menampilkan spinner (lewat
  /// [onRecoveryStateChanged]); kalau 3x gagal, provider menampilkan
  /// kartu error netral + tombol Coba Lagi (lewat [onRecoveryFailed]).
  Future<void> _recoverStall() async {
    final track = _currentTrack;
    if (track == null || _recovering) return;
    // Kalau pengguna sudah menekan pause, jangan memutar lagi sendiri.
    if (!_player.playing) return;
    final generation = _loadGeneration;
    _recovering = true;
    onRecoveryStateChanged?.call(true);
    try {
      var recovered = false;
      for (var attempt = 1;
          attempt <= _maxRecoveryAttempts;
          attempt++) {
        // Pengguna sudah pindah lagu lain: batalkan diam-diam, state
        // dimiliki selectTrack yang baru.
        if (generation != _loadGeneration) return;
        // Posisi terakhir berhenti — lanjut dari sana, bukan dari awal.
        final resumePosition = _player.position;
        await _discardPartialCache();
        final candidates = await StreamExtractor.extractAudioCandidates(
          track.videoId,
          forceRefresh: true,
        );
        if (generation != _loadGeneration) return;
        for (final candidate in candidates) {
          if (generation != _loadGeneration) return;
          try {
            await loadAndPlay(
              track: track,
              streamUrl: candidate.url,
              startPosition: resumePosition,
              skipSegments: _skipSegments,
              isRecoveryAttempt: true,
            );
            recovered = true;
            break;
          } catch (_) {
            // Kandidat ini gagal — coba URL berikutnya.
            continue;
          }
        }
        if (recovered) break;
      }
      if (!recovered && generation == _loadGeneration) {
        onRecoveryFailed?.call(
          'Koneksi putus dan stream tidak bisa dipulihkan. Coba lagi.',
        );
      }
    } finally {
      _recovering = false;
      // Beri tahu provider hanya kalau recovery ini masih yang berlaku.
      if (generation == _loadGeneration) {
        onRecoveryStateChanged?.call(false);
      }
    }
  }

  Future<void> loadAndPlay({
    required TrackModel track,
    required String streamUrl,
    Duration? startPosition,
    List<SkipSegment>? skipSegments,
    bool isRecoveryAttempt = false,
  }) async {
    final item = MediaItem(
      id: track.videoId,
      title: track.title,
      artist: track.artistLine,
      album: track.album?.name,
      duration: track.durationSeconds != null
          ? Duration(seconds: track.durationSeconds!)
          : null,
      artUri: track.bestThumbnailUrl.isNotEmpty
          ? Uri.tryParse(track.bestThumbnailUrl)
          : null,
    );
    mediaItem.add(item);

    _skipSegments = skipSegments ?? const [];
    await _positionSub?.cancel();
    _positionSub = null;

    // Lagu (baru) dimuat: reset penanda supaya deteksi macet hanya aktif
    // setelah lagu ini benar-benar mulai bunyi. Timer macet lama dibatalkan.
    _hasStartedPlaying = false;
    _stallTimer?.cancel();
    _stallTimer = null;
    // Generasi naik tiap pemuatan baru (bukan recovery): recovery yang
    // sedang jalan untuk lagu lama akan batal diam-diam. Generasi
    // ditangkap SEBELUM await pertama supaya pemuatan yang kedaluwarsa
    // selama menunggu (mis. pengguna memilih lagu lain) terdeteksi.
    if (!isRecoveryAttempt) _loadGeneration++;
    final myGeneration = _loadGeneration;
    _currentTrack = track;
    _currentStreamUrl = streamUrl;

    // Sumber audio: cache lokal kalau URL-nya bisa di-cache.
    AudioSource source;
    final cacheKey = _cacheKeyFor(track.videoId, streamUrl);
    if (cacheKey != null) {
      try {
        final dir = await _cacheDir();
        unawaited(_pruneCache(dir));
        final file = File('${dir.path}/$cacheKey.cache');
        // ignore: experimental_member_use
        source = LockCachingAudioSource(
          Uri.parse(streamUrl),
          cacheFile: file,
          headers: const {'User-Agent': _chromeUa},
        );
      } catch (_) {
        source = AudioSource.uri(
          Uri.parse(streamUrl),
          headers: const {'User-Agent': _chromeUa},
        );
      }
    } else {
      source = AudioSource.uri(
        Uri.parse(streamUrl),
        headers: const {'User-Agent': _chromeUa},
      );
    }

    // Perbaikan bug klik play 2x (18 Nov 2026, item B): bersihkan dulu
    // flag playing yang basi — mis. ketukan play dini saat belum ada sumber
    // audio membuat flag Dart true tanpa perintah play ke Android, lalu
    // play() berikut mengira sudah memutar dan langsung kembali. pause()
    // di sini no-op kalau flag false. Best-effort: jangan sampai gagalnya
    // pause menghalangi pemuatan sumber.
    try {
      await _player.pause().timeout(const Duration(seconds: 2));
    } catch (_) {}

    // Lagu lain sudah dipilih selama menunggu: jangan lanjut memuat lagu
    // lama ini — batalkan supaya loop kandidat pemanggil (yang juga sudah
    // kedaluwarsa) tidak mengira pemutaran berhasil.
    if (!isRecoveryAttempt && myGeneration != _loadGeneration) {
      throw StateError('Pemuatan dibatalkan: lagu lain sudah dipilih.');
    }
    await _player.setAudioSource(source, initialPosition: startPosition);
    // Periksa lagi setelah sumber dimuat: lagu lain bisa saja dipilih
    // selama setAudioSource berjalan.
    if (!isRecoveryAttempt && myGeneration != _loadGeneration) {
      throw StateError('Pemuatan dibatalkan: lagu lain sudah dipilih.');
    }
    // Perbaikan bug klik play 2x (item C): play() just_audio bisa
    // menggantung selamanya kalau audio focus Android ditolak — beri batas
    // waktu ±5 detik lalu coba lagi sekali. Kalau tetap gagal, lempar
    // supaya pemanggil (loop kandidat di selectTrack) bisa lanjut ke
    // kandidat berikut, bukan menggantung diam-diam.
    final started = await _playWithTimeout();
    if (!started) {
      throw Exception(
        'Pemutaran tidak dimulai (audio focus ditolak atau pemutar tidak merespons).',
      );
    }
    _watchSkipSegments();
  }

  /// `play()` dengan batas waktu (bug klik play 2x, item C): just_audio
  /// 0.9.46 bisa menggantung selamanya di `play()` kalau audio focus
  /// Android ditolak — completer-nya tidak pernah selesai di cabang itu.
  /// Batas ±5 detik, coba lagi sekali (reset flag dulu bila perlu).
  /// Mengembalikan false kalau tetap gagal — pemanggil yang memutuskan
  /// (lanjut kandidat berikut / tampilkan pause), bukan menggantung.
  Future<bool> _playWithTimeout() async {
    try {
      await _player.play().timeout(const Duration(seconds: 5));
      return true;
    } on TimeoutException {
      try {
        await _player.pause().timeout(const Duration(seconds: 2));
      } catch (_) {}
      try {
        await _player.play().timeout(const Duration(seconds: 5));
        return true;
      } catch (_) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  /// Lewati segmen sponsor/intro/outro secara otomatis saat posisi
  /// pemutaran memasukinya.
  void _watchSkipSegments() {
    if (_skipSegments.isEmpty) return;
    _positionSub = _player.positionStream.listen((pos) {
      for (final seg in _skipSegments) {
        final start = Duration(
          milliseconds: (seg.startSeconds * 1000).round(),
        );
        final end = Duration(
          milliseconds: (seg.endSeconds * 1000).round(),
        );
        if (pos >= start && pos < end - const Duration(milliseconds: 300)) {
          unawaited(_player.seek(end));
          break;
        }
      }
    });
  }

  @override
  Future<void> play() async {
    // Batas waktu yang sama seperti di loadAndPlay supaya ketukan play dari
    // UI / notifikasi / media session juga tidak menggantung kalau audio
    // focus ditolak; kalau gagal, lagu tampil pause (tombol ▶) dan pengguna
    // bisa mengetuk lagi saat sudah siap.
    await _playWithTimeout();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() async {
    _stallTimer?.cancel();
    _stallTimer = null;
    _currentTrack = null;
    // Batalkan recovery / pemuatan yang mungkin sedang jalan.
    _loadGeneration++;
    await _positionSub?.cancel();
    await _player.stop();
    return super.stop();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setSpeed,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  Future<void> dispose() async {
    _stallTimer?.cancel();
    await _processingStateSub?.cancel();
    await _playingSub?.cancel();
    await _playbackEventSub?.cancel();
    await _positionSub?.cancel();
    onRecoveryStateChanged = null;
    onRecoveryFailed = null;
    await _player.dispose();
  }
}
