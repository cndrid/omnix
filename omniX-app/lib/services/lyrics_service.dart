import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track_model.dart';

/// Lirik dari LRCLIB (https://lrclib.net) — API publik gratis, tanpa kunci.
///
/// Coba dulu endpoint /api/get (cocok persis: artis + judul + durasi),
/// kalau tidak ketemu pakai /api/search dan pilih hasil dengan durasi
/// paling dekat. Selalu mengembalikan null (bukan error) kalau tidak ada.
class LyricsResult {
  final String? plainLyrics;
  final List<LyricLineModel> syncedLyrics;

  const LyricsResult({this.plainLyrics, this.syncedLyrics = const []});

  bool get hasSynced => syncedLyrics.isNotEmpty;
}

class LrclibService {
  final http.Client _client;

  LrclibService({http.Client? client}) : _client = client ?? http.Client();

  void dispose() => _client.close();

  Future<LyricsResult?> fetchLyrics({
    required String artist,
    required String track,
    String? album,
    int? durationSeconds,
  }) async {
    final a = artist.trim();
    final t = track.trim();
    if (a.isEmpty || t.isEmpty) return null;

    // 1) Cocok persis.
    try {
      final params = <String, String>{
        'artist_name': a,
        'track_name': t,
        if (album != null && album.isNotEmpty) 'album_name': album,
        if (durationSeconds != null) 'duration': '$durationSeconds',
      };
      final uri = Uri.https('lrclib.net', '/api/get', params);
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic>) {
          final parsed = _parse(data);
          if (parsed != null) return parsed;
        }
      }
    } catch (_) {
      // Lanjut ke pencarian longgar.
    }

    // 2) Pencarian longgar, pilih durasi terdekat.
    try {
      final uri = Uri.https('lrclib.net', '/api/search', {
        'artist_name': a,
        'track_name': t,
      });
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! List) return null;
      Map<String, dynamic>? best;
      var bestDiff = 1 << 30;
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final parsed = _parse(item);
        if (parsed == null) continue;
        final dur = (item['duration'] as num?)?.toDouble();
        final diff = durationSeconds == null || dur == null
            ? 0
            : (dur - durationSeconds).abs().toInt();
        if (diff < bestDiff) {
          bestDiff = diff;
          best = item;
        }
      }
      if (best != null) return _parse(best);
    } catch (_) {
      return null;
    }
    return null;
  }

  LyricsResult? _parse(Map<String, dynamic> json) {
    final plain = json['plainLyrics'] as String?;
    final syncedRaw = json['syncedLyrics'] as String?;
    final synced = <LyricLineModel>[];
    if (syncedRaw != null && syncedRaw.isNotEmpty) {
      for (final line in syncedRaw.split('\n')) {
        final m = RegExp(r'^\[(\d+):(\d+)(?:[.:](\d+))?\]\s*(.*)$')
            .firstMatch(line.trim());
        if (m == null) continue;
        final min = int.tryParse(m.group(1) ?? '0') ?? 0;
        final sec = int.tryParse(m.group(2) ?? '0') ?? 0;
        final text = (m.group(4) ?? '').trim();
        if (text.isEmpty) continue;
        synced.add(LyricLineModel(
          timeSeconds: min * 60 + sec,
          text: text,
        ));
      }
    }
    if ((plain == null || plain.isEmpty) && synced.isEmpty) return null;
    return LyricsResult(plainLyrics: plain, syncedLyrics: synced);
  }
}
