import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Kandidat audio beserta info formatnya (untuk label format asli).
class AudioCandidate {
  final String url;
  final String mimeType;
  final int bitrateKbps;

  const AudioCandidate({
    required this.url,
    required this.mimeType,
    required this.bitrateKbps,
  });
}

/// Ekstraksi direct stream URL langsung di HP pengguna.
///
/// Alasan: IP server Fly.io diblokir YouTube untuk pengambilan stream,
/// sedangkan request dari IP HP (Wi-Fi rumah / seluler) tidak diblokir.
/// Sejak arsitektur client-side, SEMUA logika (pencarian, metadata,
/// ekstraksi) jalan di HP — tidak ada lagi backend di tengah jalan.
class StreamExtractor {
  static const _timeout = Duration(seconds: 15);

  /// URL audio-only terbaik untuk [videoId], atau null kalau gagal.
  /// Utamakan m4a (container mp4, itag 140) karena bisa diputar di semua
  /// platform (Android, iOS, Windows); kalau tidak ada, bitrate tertinggi.
  static Future<String?> extractAudioUrl(String videoId) async {
    final urls = await extractAudioUrls(videoId);
    return urls.isEmpty ? null : urls.first;
  }

  /// Info format audio terbaik (URL + mime + bitrate asli), atau null.
  /// Dipakai untuk menampilkan label format yang jujur di pemutar.
  static Future<AudioCandidate?> extractBestAudioInfo(
    String videoId,
  ) async {
    final candidates = await _audioCandidates(videoId);
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Daftar kandidat URL audio untuk [videoId], terurut dari yang terbaik:
  /// audio-only (m4a dulu, lalu bitrate tertinggi), lalu muxed.
  /// Dipakai pemutar untuk mencoba satu per satu kalau URL pertama gagal
  /// dimuat (mis. format ditolak player). List kosong kalau ekstraksi
  /// gagal total.
  static Future<List<String>> extractAudioUrls(String videoId) async {
    final candidates = await _audioCandidates(videoId);
    return candidates.map((c) => c.url).toList();
  }

  static Future<List<AudioCandidate>> _audioCandidates(
    String videoId,
  ) async {
    final yt = YoutubeExplode();
    try {
      final manifest = await yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(_timeout);
      final out = <AudioCandidate>[];
      final audioOnly = manifest.audioOnly.toList();
      audioOnly.sort((a, b) {
        final aMp4 = a.container.name == 'mp4' ? 0 : 1;
        final bMp4 = b.container.name == 'mp4' ? 0 : 1;
        if (aMp4 != bMp4) return aMp4 - bMp4;
        return b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond);
      });
      for (final s in audioOnly) {
        out.add(AudioCandidate(
          url: s.url.toString(),
          mimeType: 'audio/${s.container.name}',
          bitrateKbps: s.bitrate.bitsPerSecond ~/ 1000,
        ));
      }
      final muxed = manifest.muxed.toList();
      muxed.sort(
        (a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
      );
      for (final s in muxed) {
        out.add(AudioCandidate(
          url: s.url.toString(),
          mimeType: 'video/${s.container.name}',
          bitrateKbps: s.bitrate.bitsPerSecond ~/ 1000,
        ));
      }
      return out;
    } catch (_) {
      return const [];
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
