import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';

import 'audio_handler_service.dart';

/// Jembatan Dart → Media3 (pengganti audio_service, 24 Nov 2026).
///
/// Audio di OmniX tetap diputar oleh just_audio lewat [OmniXAudioHandler];
/// yang diganti hanya sisi "media session + notifikasi media" Android:
/// dulu audio_service (terbukti tidak pernah memposting notifikasi di
/// Poco F7 Pak), sekarang Media3 (MediaSessionService + MediaSession)
/// yang memposting notifikasi media sistem secara native.
///
/// Arah Dart → native: setiap perubahan [OmniXAudioHandler.playbackState],
/// [OmniXAudioHandler.mediaItem], dan [OmniXAudioHandler.queue] dikirim
/// lewat MethodChannel `com.example.omnix_app/media3` sebagai
/// `updateState` / `updateMediaItem` / `updateQueue`. Sisi native
/// mencerminkan state itu di player-nya (SimpleBasePlayer) — tidak ada
/// audio yang diputar di sisi native.
///
/// Arah native → Dart: tombol media (notifikasi / pusat kontrol /
/// headset / Android Auto) diteruskan sebagai `play`, `pause`, `seekTo`,
/// `skipToNext`, `skipToPrevious`.
///
/// Semua pemanggilan channel dibungkus try/catch: kalau sisi native belum
/// siap (mis. service belum jalan), aplikasi tidak boleh crash — update
/// state berikutnya akan menyusul.
class Media3Bridge {
  static const _channel = MethodChannel('com.example.omnix_app/media3');

  static bool _initialized = false;
  static final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Pasang handler perintah native → Dart dan mulai meneruskan state
  /// handler ke native. Dipanggil sekali dari main().
  static Future<void> init(OmniXAudioHandler handler) async {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      try {
        switch (call.method) {
          case 'play':
            await handler.play();
          case 'pause':
            await handler.pause();
          case 'seekTo':
            final positionMs =
                (call.arguments as Map?)?['positionMs'] as num?;
            if (positionMs != null) {
              await handler.seek(Duration(milliseconds: positionMs.toInt()));
            }
          case 'skipToNext':
            await handler.skipToNext();
          case 'skipToPrevious':
            await handler.skipToPrevious();
        }
      } catch (_) {
        // Perintah dari notifikasi tidak boleh melempar kembali ke native.
      }
    });

    // Ketiga stream ini BehaviorSubject: nilai terakhir langsung
    // diputar ulang saat subscribe, jadi native langsung mendapat state
    // awal tanpa menunggu perubahan berikutnya.
    _subscriptions.addAll([
      handler.playbackState.listen(
        (state) {
          unawaited(_send('updateState', _stateMap(state)));
        },
        onError: (_) {},
      ),
      handler.mediaItem.listen(
        (item) {
          unawaited(_send('updateMediaItem', _mediaItemMap(item)));
        },
        onError: (_) {},
      ),
      handler.queue.listen(
        (queue) {
          unawaited(_send('updateQueue', {
            'items': queue.map(_mediaItemMap).toList(),
          }));
        },
        onError: (_) {},
      ),
    ]);
  }

  static Future<void> _send(String method, Object? arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (_) {
      // Sisi native belum siap (mis. service belum jalan) — bukan fatal;
      // update state berikutnya akan menyusul.
    }
  }

  static Map<String, Object?> _stateMap(PlaybackState state) {
    return {
      'playing': state.playing,
      'processingState': _processingStateName(state.processingState),
      'positionMs': state.updatePosition.inMilliseconds,
      'bufferedPositionMs': state.bufferedPosition.inMilliseconds,
    };
  }

  static String _processingStateName(AudioProcessingState state) {
    switch (state) {
      case AudioProcessingState.idle:
        return 'idle';
      case AudioProcessingState.loading:
        return 'loading';
      case AudioProcessingState.buffering:
        return 'buffering';
      case AudioProcessingState.ready:
        return 'ready';
      case AudioProcessingState.completed:
        return 'completed';
      case AudioProcessingState.error:
        return 'error';
    }
  }

  static Map<String, Object?>? _mediaItemMap(MediaItem? item) {
    if (item == null) return null;
    return {
      'id': item.id,
      'title': item.title,
      'artist': item.artist,
      'album': item.album,
      'durationMs': item.duration?.inMilliseconds,
      'artUri': item.artUri?.toString(),
    };
  }
}
