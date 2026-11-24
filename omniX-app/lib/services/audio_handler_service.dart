import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track_model.dart';
import 'skip_service.dart';
import 'stream_extractor.dart';

/// Gagal memulai pemutaran karena `play()` tidak kembali (biasanya audio
/// focus Android ditolak / platform tidak merespons) — BUKAN karena URL-nya
/// jelek. Pemanggil membedakannya dari gagal muat sumber: gagal focus itu
/// kondisi global pemutar, jadi mencoba kandidat URL lain dengan `play()`
/// yang sama hanya mengulang jeda timeout yang sama (±12 detik per
/// kandidat). Lihat [OmniXAudioHandler.loadAndPlay].
class PlayStartException implements Exception {
  final String message;
  const PlayStartException(this.message);

  @override
  String toString() => message;
}

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
/// - Cache audio di direktori sementara aplikasi (24 Nov 2026: pindah dari
///   dokumen aplikasi — cache lama di dokumen dihapus sekali saat migrasi),
///   maks. 20 file terbaru DAN maks. ~200 MB total (file terlama dihapus
///   dulu). Prune jalan saat handler mulai + setelah lagu selesai diputar.
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

  /// Callback ke PlayerController.skipNext/skipPrevious (24 Nov 2026).
  /// Didaftarkan di konstruktor PlayerController — handler TIDAK BOLEH
  /// import app_providers.dart (arah importnya berlawanan: app_providers
  /// import handler). Dipanggil [skipToNext]/[skipToPrevious] saat tombol
  /// next/prev notifikasi / media session ditekan.
  void Function()? onSkipNext;
  void Function()? onSkipPrevious;

  /// Indeks lagu aktif di antrean yang didorong controller lewat
  /// [setQueueItems] — dipakai [PlaybackState.queueIndex]. Indeks dari
  /// event just_audio selalu 0 (sumbernya satu lagu), jadi tidak dipakai.
  int _queueIndex = 0;

  // --- Pelepas idle hemat baterai (24 Nov 2026) ---
  // Saat lagu dijeda, player + audio session tetap menahan audio focus
  // dan ExoPlayer bisa terus mengunduh sampai batas buffer (200 dtk).
  // Kalau jeda bertahan 10 menit, sumber dilepas (_player.stop() +
  // setActive(false)); ketukan play berikutnya memuat ulang lagu yang
  // sama dari posisi terakhir (lihat [play]).
  static const _idleReleaseAfter = Duration(minutes: 10);
  Timer? _idleReleaseTimer;
  bool _idleReleased = false;
  Duration _idlePosition = Duration.zero;

  AudioPlayer get player => _player;

  OmniXAudioHandler() {
    _initAudioSession();
    // Migrasi cache (24 Nov 2026): hapus folder cache lama di dokumen
    // aplikasi + prune cache baru. Fire-and-forget: tidak menghalangi
    // konstruktor, dan tidak bentrok dengan loadAndPlay (folder beda).
    unawaited(_migrateCacheLocation());
    // JANGAN pakai .pipe() di sini: pipe meneruskan error source ke
    // playbackState, dan loop `await for` audio_service (tanpa try/catch)
    // mati selamanya saat satu error masuk — media session tidak pernah
    // aktif (kartu media HyperOS hilang) walau lagu tetap bunyi. Error
    // sudah ditangani _playbackEventSub di bawah (auto-recovery).
    _player.playbackEventStream.listen(
      (_) => playbackState.add(_transformEvent()),
      onError: (_) {},
    );
    _processingStateSub =
        _player.processingStateStream.listen(_onProcessingState);
    _playingSub = _player.playingStream.listen((playing) {
      if (playing) {
        _hasStartedPlaying = true;
        // Kembali bunyi: batalkan pelepas idle (kalau sempat dijadwalkan).
        _cancelIdleReleaseTimer();
      } else if (_currentTrack != null && !_idleReleased) {
        // Dijeda dengan lagu termuat: jadwalkan pelepas idle. Tidak
        // dijadwalkan kalau belum ada lagu (tidak ada yang dilepas).
        _startIdleReleaseTimer();
      }
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

  /// Batas cache audio (24 Nov 2026): maks. 20 file DAN maks. ~200 MB
  /// total. File terlama dihapus dulu; file terbaru selalu dipertahankan
  /// walau sendirian melewati batas byte (satu lagu tidak pernah sebesar
  /// itu, tapi prune tidak boleh menghapus lagu yang sedang diputar).
  static const maxCacheFiles = 20;
  static const maxCacheBytes = 200 * 1024 * 1024;

  /// Direktori cache audio (24 Nov 2026): direktori sementara aplikasi
  /// (getTemporaryDirectory — boleh dibersihkan OS). Sebelumnya memakai
  /// dokumen aplikasi yang PERMANEN (OS tidak membersihkan): 50 lagu
  /// × ~5-10 MB bisa sampai ~500 MB dan tidak pernah hilang sendiri.
  Future<Directory> _cacheDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/audio_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Lokasi cache lama (dokumen aplikasi, dipakai sampai 23 Nov 2026).
  /// Hanya dipakai migrasi sekali jalan + hitung/hapus cache: JANGAN
  /// hapus folder lain di dokumen aplikasi.
  Future<Directory> _legacyCacheDir() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/audio_cache');
  }

  /// Migrasi sekali jalan saat handler pertama dibuat: hapus folder cache
  /// lama (documents/audio_cache) PERSIS — supaya ~500 MB lama tidak
  /// tertinggal selamanya — lalu prune cache baru. Semua best-effort:
  /// gagal migrasi tidak boleh menghalangi pemutaran.
  Future<void> _migrateCacheLocation() async {
    try {
      final legacy = await _legacyCacheDir();
      if (await legacy.exists()) {
        await legacy.delete(recursive: true);
      }
    } catch (_) {}
    await _pruneCache();
  }

  /// Pilih file cache yang harus dihapus supaya sisa file memenuhi DUA
  /// batas: maks. [maxCacheFiles] file terbaru DAN total maks.
  /// [maxCacheBytes]. File terlama dihapus dulu. Murni (hanya baca
  /// daftar file yang diberikan) supaya bisa diuji tanpa platform
  /// channel — lihat test/cache_prune_test.dart.
  static List<File> selectCacheFilesToDelete(List<File> files) {
    int fileSize(File f) {
      try {
        return f.lengthSync();
      } catch (_) {
        return 0;
      }
    }

    DateTime fileTime(File f) {
      try {
        return f.lastModifiedSync();
      } catch (_) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
    }

    // Terbaru dulu.
    final sorted = List<File>.from(files)
      ..sort((a, b) => fileTime(b).compareTo(fileTime(a)));
    final toDelete = <File>[];
    var keptCount = 0;
    var keptBytes = 0;
    for (final f in sorted) {
      final size = fileSize(f);
      final fitsCount = keptCount < maxCacheFiles;
      final fitsBytes = keptBytes + size <= maxCacheBytes;
      if (keptCount == 0 || (fitsCount && fitsBytes)) {
        keptCount++;
        keptBytes += size;
      } else {
        toDelete.add(f);
      }
    }
    return toDelete;
  }

  Future<void> _pruneCache() async {
    try {
      final dir = await _cacheDir();
      final files = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      for (final f in selectCacheFilesToDelete(files)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// File cache milik lagu yang sedang diputar (kalau ada) — tidak boleh
  /// dihapus saat [clearAudioCache], LockCachingAudioSource masih
  /// membacanya.
  File? _currentCacheFile(Directory dir) {
    final track = _currentTrack;
    final url = _currentStreamUrl;
    if (track == null || url == null) return null;
    final key = _cacheKeyFor(track.videoId, url);
    if (key == null) return null;
    return File('${dir.path}/$key.cache');
  }

  /// Hapus semua file cache audio (lokasi baru + sisa lokasi lama kalau
  /// masih ada), kecuali file lagu yang sedang diputar. Dipakai tombol
  /// "Hapus cache" di Profil.
  Future<void> clearAudioCache() async {
    for (final getDir in [_cacheDir(), _legacyCacheDir()]) {
      try {
        final dir = await getDir;
        if (!await dir.exists()) continue;
        final keep = _currentCacheFile(dir);
        await for (final e in dir.list()) {
          if (e is File && e.path != keep?.path) {
            try {
              await e.delete();
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
  }

  /// Total ukuran cache audio saat ini (byte; lokasi baru + sisa lokasi
  /// lama kalau masih ada). Dipakai tampilan ukuran di Profil.
  Future<int> audioCacheSizeBytes() async {
    var total = 0;
    for (final getDir in [_cacheDir(), _legacyCacheDir()]) {
      try {
        final dir = await getDir;
        if (!await dir.exists()) continue;
        await for (final e in dir.list()) {
          if (e is File) {
            try {
              total += await e.length();
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
    return total;
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
    // Lagu selesai diputar: prune cache (batas 20 file / 200 MB).
    if (state == ProcessingState.completed) {
      unawaited(_pruneCache());
    }
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
    final item = mediaItemForTrack(track);
    mediaItem.add(item);

    _skipSegments = skipSegments ?? const [];
    await _positionSub?.cancel();
    _positionSub = null;
    // Lagu (baru) dimuat: pelepas idle tidak berlaku lagi — lagu ini
    // sedang dimuat/diputar, dan penanda idle-release lama direset supaya
    // play() berikut tidak mengira player masih dilepas.
    _idleReleased = false;
    _cancelIdleReleaseTimer();

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
        unawaited(_pruneCache());
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
    // Batas waktu pemuatan sumber (bug start lambat): tanpa ini, prepare
    // ExoPlayer yang macet (mis. host stream lambat) menggantung satu
    // kandidat selamanya dan pemutar tidak pernah lanjut ke kandidat
    // berikut. Timeout -> lempar -> pemanggil coba kandidat berikutnya.
    await _player
        .setAudioSource(source, initialPosition: startPosition)
        .timeout(const Duration(seconds: 10));
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
      // Sengaja tipe sendiri (bukan Exception umum): pemanggil harus bisa
      // membedakan "play() menggantung" (masalah global pemutar/focus)
      // dari "sumber gagal dimuat" (masalah URL itu) — lihat loop kandidat
      // di PlayerController.selectTrack.
      throw const PlayStartException(
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

  /// MediaItem untuk satu lagu — dipakai [loadAndPlay] dan controller
  /// saat mendorong antrean (lihat [setQueueItems]).
  static MediaItem mediaItemForTrack(TrackModel track) {
    return MediaItem(
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
  }

  /// Dorong antrean pemutar (milik PlayerController) ke media session
  /// (24 Nov 2026). Dipanggil controller setiap kali antrean berubah.
  /// Sebelumnya queue TIDAK PERNAH diisi, jadi skipToNext/skipToPrevious
  /// bawaan audio_service (yang jalan di atas queue) tidak bisa bekerja
  /// dan tombol next/prev notifikasi diam. [currentIndex] ikut disimpan
  /// supaya [PlaybackState.queueIndex] benar (lihat [_transformEvent]).
  Future<void> setQueueItems(
    List<MediaItem> items, {
    int currentIndex = 0,
  }) async {
    _queueIndex =
        items.isEmpty ? 0 : currentIndex.clamp(0, items.length - 1);
    await updateQueue(items);
  }

  /// Segmen sponsor yang datang MENYUSUL setelah lagu mulai bunyi (jalur
  /// start tidak lagi menunggu SponsorBlock — lihat PlayerController).
  /// Pasang + aktifkan watcher-nya; kalau posisi sudah masuk segmen,
  /// position event berikutnya langsung melompatinya.
  void updateSkipSegments(List<SkipSegment> segments) {
    _skipSegments = segments;
    if (_currentTrack != null) {
      _watchSkipSegments();
    }
  }

  /// Lewati segmen sponsor/intro/outro secara otomatis saat posisi
  /// pemutaran memasukinya.
  void _watchSkipSegments() {
    if (_skipSegments.isEmpty) return;
    // Batalkan subscription lama dulu: metode ini bisa dipanggil dua kali
    // (sekali dari loadAndPlay, sekali saat segmen datang menyusul) —
    // tanpa ini ada dua listener yang sama-sama memanggil seek.
    unawaited(_positionSub?.cancel());
    _positionSub = null;
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
    // Player dilepas setelah idle lama (lihat [_releaseIdleResources]):
    // play() biasa tidak bisa membunyikan player yang sudah di-stop —
    // muat ulang lagu yang sama dari posisi terakhir. Kalau muat ulang
    // gagal (mis. URL kedaluwarsa), _idleReleased dikembalikan true
    // supaya ketukan play berikut mencoba muat ulang lagi.
    if (_idleReleased && _currentTrack != null && _currentStreamUrl != null) {
      try {
        await loadAndPlay(
          track: _currentTrack!,
          streamUrl: _currentStreamUrl!,
          startPosition: _idlePosition,
          skipSegments: _skipSegments,
        );
      } catch (_) {
        _idleReleased = true;
      }
      return;
    }
    // Batas waktu yang sama seperti di loadAndPlay supaya ketukan play dari
    // UI / notifikasi / media session juga tidak menggantung kalau audio
    // focus ditolak; kalau gagal, lagu tampil pause (tombol ▶) dan pengguna
    // bisa mengetuk lagi saat sudah siap.
    await _playWithTimeout();
  }

  @override
  Future<void> pause() => _player.pause();

  /// Tombol next notifikasi / media session (24 Nov 2026): teruskan ke
  /// PlayerController.skipNext lewat callback (lihat [onSkipNext]).
  /// Sebelumnya tidak ada override — QueueHandler bawaan audio_service
  /// bekerja di atas queue yang tidak pernah diisi, jadi tombol diam.
  @override
  Future<void> skipToNext() async {
    onSkipNext?.call();
  }

  /// Tombol prev notifikasi / media session (24 Nov 2026): teruskan ke
  /// PlayerController.skipPrevious lewat callback (lihat [onSkipPrevious]).
  @override
  Future<void> skipToPrevious() async {
    onSkipPrevious?.call();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() async {
    _stallTimer?.cancel();
    _stallTimer = null;
    _cancelIdleReleaseTimer();
    _idleReleased = false;
    _currentTrack = null;
    // Batalkan recovery / pemuatan yang mungkin sedang jalan.
    _loadGeneration++;
    await _positionSub?.cancel();
    await _player.stop();
    // Lepas audio session (best-effort; di Android umumnya no-op dan
    // just_audio mengaktifkannya lagi saat play berikutnya).
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
    return super.stop();
  }

  /// Jadwalkan pelepas idle: kalau lagu tetap dijeda selama
  /// [_idleReleaseAfter], player + audio session dilepas.
  void _startIdleReleaseTimer() {
    _cancelIdleReleaseTimer();
    _idleReleaseTimer = Timer(_idleReleaseAfter, () {
      unawaited(_releaseIdleResources());
    });
  }

  void _cancelIdleReleaseTimer() {
    _idleReleaseTimer?.cancel();
    _idleReleaseTimer = null;
  }

  /// Lepas player + audio session setelah jeda lama (hemat baterai):
  /// stop() just_audio melepas audio focus dan menghentikan unduhan
  /// buffer ExoPlayer; setActive(false) menonaktifkan audio session.
  /// Posisi terakhir disimpan supaya [play] bisa lanjut dari sana.
  /// Hanya jalan kalau benar-benar masih jeda — kalau pengguna sudah
  /// menekan play lagi, timer sudah dibatalkan lewat playingStream.
  Future<void> _releaseIdleResources() async {
    if (_player.playing || _currentTrack == null || _idleReleased) return;
    _idlePosition = _player.position;
    _idleReleased = true;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }

  PlaybackState _transformEvent() {
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
      // Indeks dari antrean controller (lihat setQueueItems), bukan
      // event.currentIndex just_audio yang selalu 0 (sumber satu lagu).
      queueIndex: _queueIndex,
    );
  }

  Future<void> dispose() async {
    _stallTimer?.cancel();
    _cancelIdleReleaseTimer();
    await _processingStateSub?.cancel();
    await _playingSub?.cancel();
    await _playbackEventSub?.cancel();
    await _positionSub?.cancel();
    onRecoveryStateChanged = null;
    onRecoveryFailed = null;
    onSkipNext = null;
    onSkipPrevious = null;
    await _player.dispose();
  }
}
