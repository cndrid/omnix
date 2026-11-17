import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Ekstraksi direct stream URL langsung di HP pengguna.
///
/// Alasan: IP server Fly.io diblokir YouTube untuk pengambilan stream,
/// sedangkan request dari IP HP (Wi-Fi rumah / seluler) tidak diblokir.
/// Backend Fly tetap dipakai untuk pencarian + metadata lagu; yang
/// dipindah ke sini hanya pengambilan URL stream-nya.
///
/// Kalau ekstraksi gagal (mis. YouTube mengubah format player), fungsi
/// mengembalikan null dan pemanggil memakai URL dari backend sebagai
/// fallback — jadi pemutaran tidak langsung mati.
class StreamExtractor {
  static const _timeout = Duration(seconds: 15);

  /// URL audio-only terbaik untuk [videoId], atau null kalau gagal.
  /// Utamakan m4a (container mp4, itag 140) karena bisa diputar di semua
  /// platform (Android, iOS, Windows); kalau tidak ada, bitrate tertinggi.
  static Future<String?> extractAudioUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(_timeout);
      final audioOnly = manifest.audioOnly.toList();
      if (audioOnly.isEmpty) return null;
      audioOnly.sort((a, b) {
        final aMp4 = a.container.name == 'mp4' ? 0 : 1;
        final bMp4 = b.container.name == 'mp4' ? 0 : 1;
        if (aMp4 != bMp4) return aMp4 - bMp4;
        return b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
      });
      return audioOnly.first.url.toString();
    } catch (_) {
      return null;
    } finally {
      yt.close();
    }
  }

  /// URL video muxed (audio + video dalam satu file, itag 18/22) terbaik
  /// untuk [videoId], atau null kalau gagal / tidak ada stream muxed.
  static Future<String?> extractVideoUrl(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(_timeout);
      final muxed = manifest.muxed.toList();
      if (muxed.isEmpty) return null;
      muxed.sort(
        (a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
      );
      return muxed.first.url.toString();
    } catch (_) {
      return null;
    } finally {
      yt.close();
    }
  }
}
