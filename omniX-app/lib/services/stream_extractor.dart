import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'shared_stream_client.dart';

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

class _CachedCandidates {
  final List<AudioCandidate> candidates;
  final DateTime fetchedAt;

  const _CachedCandidates(this.candidates, this.fetchedAt);
}

/// Ekstraksi direct stream URL langsung di HP pengguna.
///
/// Alasan: IP server Fly.io diblokir platform untuk pengambilan stream,
/// sedangkan request dari IP HP (Wi-Fi rumah / seluler) tidak diblokir.
/// Sejak arsitektur client-side, SEMUA logika (pencarian, metadata,
/// ekstraksi) jalan di HP — tidak ada lagi backend di tengah jalan.
///
/// Perbaikan 18 Nov 2026 (fast start + buffering):
/// - Satu kali `getManifest` untuk URL + info format
///   ([extractAudioCandidates]): sebelumnya `extractAudioUrls` dan
///   `extractBestAudioInfo` masing-masing memanggil `getManifest`
///   sendiri-sendiri.
/// - Satu instance [YoutubeExplode] bersama (lihat
///   [SharedStreamClient]) — tidak lagi dibuat baru + di-close tiap
///   panggilan.
/// - Cache URL hasil ekstraksi di memori per videoId (TTL ~6 jam): lagu
///   yang diulang / di-prefetch tidak ekstraksi ulang.
/// - Piped sebagai jalur CADANGAN kalau ekstraksi langsung gagal total
///   (lihat [_pipedInstances]): dicoba berurutan dengan timeout singkat,
///   kegagalan satu instance tidak pernah menggagalkan pemutaran.
class StreamExtractor {
  static const _timeout = Duration(seconds: 15);

  /// Cache URL hasil ekstraksi di memori per videoId (TTL ~6 jam):
  /// lagu yang diulang dalam TTL langsung pakai cache tanpa ekstraksi
  /// ulang. URL stream sendiri kedaluwarsa dalam hitungan jam,
  /// jadi TTL sengaja tidak lebih panjang dari itu.
  static const _cacheTtl = Duration(hours: 6);
  static const _maxCachedVideoIds = 200;
  static final Map<String, _CachedCandidates> _candidatesCache = {};

  /// Instance Piped cadangan, BERURUTAN (18 Nov 2026).
  ///
  /// Hasil cek langsung dari sandbox hari ini: TIDAK ADA satu pun instance
  /// yang mengembalikan `audioStreams` — kavin.rocks mati (dulu 526, kini
  /// koneksi gagal), pipedapi-libre.kavin.rocks mati, piped.lunar.icu 502,
  /// api-piped.mha.fi mati, pipedapi.leptons.xyz 502, pipedapi.r4fo.com
  /// mati, pipedapi.in.projectsegfau.lt balas "Service has been shutdown",
  /// api.piped.yt mati, pipedapi.darkness.services mati, dan
  /// pipedapi.adminforge.de redirect 301 ke domain frontend (bukan API).
  /// Catatan: cek itu lewat proxy egress sandbox — HTTP 000 sebagian bisa
  /// jadi proxy yang gagal CONNECT, bukan host-nya yang mati — jadi hasil
  /// ini tidak 100% meyakinkan untuk kondisi di HP. Karena itu Piped
  /// TETAP diimplementasikan sebagai cadangan berurutan dengan timeout
  /// singkat, tapi TIDAK PERNAH jadi jalur utama dan TIDAK PERNAH
  /// memblokir pemutaran: satu instance gagal -> lanjut ke berikutnya ->
  /// semua gagal -> kembalikan list kosong.
  static const List<String> _pipedInstances = [
    'https://pipedapi.kavin.rocks',
    'https://pipedapi.adminforge.de',
    'https://api-piped.mha.fi',
    'https://piped.lunar.icu',
    'https://pipedapi.leptons.xyz',
  ];
  static const _pipedTimeout = Duration(seconds: 5);

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
    final candidates = await extractAudioCandidates(videoId);
    return candidates.isEmpty ? null : candidates.first;
  }

  /// Daftar kandidat URL audio untuk [videoId], terurut dari yang terbaik:
  /// audio-only (m4a dulu, lalu bitrate tertinggi), lalu muxed.
  /// Dipakai pemutar untuk mencoba satu per satu kalau URL pertama gagal
  /// dimuat (mis. format ditolak player). List kosong kalau ekstraksi
  /// gagal total.
  static Future<List<String>> extractAudioUrls(String videoId) async {
    final candidates = await extractAudioCandidates(videoId);
    return candidates.map((c) => c.url).toList();
  }

  /// SATU kali panggil `getManifest` untuk [videoId]: hasilnya dipakai
  /// untuk URL dan info format sekaligus.
  ///
  /// [forceRefresh] = true mengabaikan cache memori — dipakai auto-recovery
  /// supaya selalu dapat link BARU, bukan URL lama yang sudah kedaluwarsa
  /// atau kena throttle. Tidak pernah throw: gagal total -> list kosong.
  static Future<List<AudioCandidate>> extractAudioCandidates(
    String videoId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _candidatesCache[videoId];
      if (cached != null &&
          DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
        return cached.candidates;
      }
    }
    // Ekstraksi langsung dulu; kalau gagal total, baru Piped.
    final stopwatch = Stopwatch()..start();
    var candidates = await _directCandidates(videoId);
    // Piped hanya dicoba kalau ekstraksi langsung gagal CEPAT. Kalau
    // langsung saja sudah makan waktu lama (mis. mendekati timeout 15
    // detik — jalur jaringan ke platform sedang lambat), Piped hampir
    // pasti tidak menyelamatkan dan hanya menambah sampai 25 detik
    // spinner (5 instance x 5 detik) sebelum UI boleh menampilkan
    // error / coba lagi. Gagal cepat di sini lebih berguna daripada
    // menunggu lama.
    if (candidates.isEmpty &&
        stopwatch.elapsed < const Duration(seconds: 10)) {
      candidates = await _pipedCandidates(videoId);
    }
    if (candidates.isNotEmpty) {
      _candidatesCache[videoId] =
          _CachedCandidates(candidates, DateTime.now());
      _pruneMemoryCache();
    }
    return candidates;
  }

  static void _pruneMemoryCache() {
    if (_candidatesCache.length <= _maxCachedVideoIds) return;
    final sorted = _candidatesCache.entries.toList()
      ..sort((a, b) => a.value.fetchedAt.compareTo(b.value.fetchedAt));
    for (final e in sorted.take(
      _candidatesCache.length - _maxCachedVideoIds + 50,
    )) {
      _candidatesCache.remove(e.key);
    }
  }

  static Future<List<AudioCandidate>> _directCandidates(
    String videoId,
  ) async {
    try {
      final manifest = await SharedStreamClient
          .instance.videos.streamsClient
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
    }
  }

  /// Jalur cadangan Piped: `GET {instance}/streams/{videoId}`, ambil
  /// `audioStreams` terbaik (Opus/AAC, bitrate tertinggi).
  ///
  /// Tiap instance diberi timeout singkat (~5 detik); gagal (mati, 502,
  /// redirect, bukan JSON, tanpa audioStreams) -> lanjut ke instance
  /// berikutnya. Semua gagal -> list kosong, pemanggil kembali ke hasil
  /// ekstraksi langsung (yang sudah kosong) tanpa throw.
  static Future<List<AudioCandidate>> _pipedCandidates(
    String videoId,
  ) async {
    for (final instance in _pipedInstances) {
      try {
        final res = await http
            .get(Uri.parse('$instance/streams/$videoId'))
            .timeout(_pipedTimeout);
        if (res.statusCode != 200) continue;
        final data = jsonDecode(res.body);
        if (data is! Map<String, dynamic>) continue;
        final streams = data['audioStreams'];
        if (streams is! List || streams.isEmpty) continue;
        final out = <AudioCandidate>[];
        for (final s in streams) {
          if (s is! Map<String, dynamic>) continue;
          final url = s['url'];
          if (url is! String || url.isEmpty) continue;
          final mime = (s['mimeType'] as String?) ?? '';
          final format = (s['format'] as String?) ?? '';
          final bitrateRaw = s['bitrate'];
          final bitrateBps = bitrateRaw is num ? bitrateRaw.toInt() : 0;
          // Piped mengembalikan bitrate dalam bps; kalau nilainya kecil
          // kemungkinan sudah kbps — jangan dibagi 1000 dua kali.
          final kbps = bitrateBps >= 10000 ? bitrateBps ~/ 1000 : bitrateBps;
          out.add(AudioCandidate(
            url: url,
            mimeType: mime.isNotEmpty
                ? mime
                : 'audio/${format.toLowerCase()}',
            bitrateKbps: kbps,
          ));
        }
        if (out.isEmpty) continue;
        // Bitrate tertinggi dulu; kalau imbang, utamakan mp4/AAC karena
        // bisa diputar di semua platform (Opus/WebM tidak didukung AVPlayer
        // iOS). Kandidat yang gagal dimuat tetap dicoba satu per satu oleh
        // pemutar, jadi urutan di sini bukan titik kegagalan tunggal.
        out.sort((a, b) {
          final byBitrate = b.bitrateKbps.compareTo(a.bitrateKbps);
          if (byBitrate != 0) return byBitrate;
          return _pipedPreference(a.mimeType) - _pipedPreference(b.mimeType);
        });
        return out;
      } catch (_) {
        // Instance mati / timeout / respons bukan JSON: lanjut ke berikut.
        continue;
      }
    }
    return const [];
  }

  static int _pipedPreference(String mimeType) {
    final m = mimeType.toLowerCase();
    if (m.contains('mp4') || m.contains('aac') || m.contains('m4a')) return 0;
    if (m.contains('opus') || m.contains('webm')) return 1;
    return 2;
  }

  /// URL video muxed (audio + video dalam satu file, itag 18/22) terbaik
  /// untuk [videoId], atau null kalau gagal / tidak ada stream muxed.
  static Future<String?> extractVideoUrl(String videoId) async {
    try {
      final manifest = await SharedStreamClient
          .instance.videos.streamsClient
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
    }
  }
}
