import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/track_model.dart';
import 'skip_service.dart';

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
class OmniXAudioHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  List<SkipSegment> _skipSegments = const [];

  AudioPlayer get player => _player;

  OmniXAudioHandler() {
    _initAudioSession();
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  static const _chromeUa =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

  /// Direktori cache audio (maks. 50 file terbaru, dibersihkan berkala).
  Future<Directory> _cacheDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/audio_cache');
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

  Future<void> loadAndPlay({
    required TrackModel track,
    required String streamUrl,
    Duration? startPosition,
    List<SkipSegment>? skipSegments,
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

    await _player.setAudioSource(source, initialPosition: startPosition);
    await _player.play();
    _watchSkipSegments();
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
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> stop() async {
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
    await _positionSub?.cancel();
    await _player.dispose();
  }
}
