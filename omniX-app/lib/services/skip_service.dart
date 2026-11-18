import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Segmen yang bisa dilewati dari SponsorBlock
/// (https://sponsor.ajay.app) — API publik gratis, tanpa kunci.
/// 404 berarti video ini tidak punya segmen: kembalikan list kosong,
/// bukan error.
class SkipSegment {
  final double startSeconds;
  final double endSeconds;
  final String category;

  const SkipSegment({
    required this.startSeconds,
    required this.endSeconds,
    required this.category,
  });
}

/// Rasio suka/tidak suka dari layanan pihak ketiga
/// (API publik gratis).
class VideoVotes {
  final int likes;
  final int dislikes;
  final int viewCount;

  const VideoVotes({
    required this.likes,
    required this.dislikes,
    required this.viewCount,
  });
}

class SkipService {
  final http.Client _client;

  SkipService({http.Client? client}) : _client = client ?? http.Client();

  void dispose() => _client.close();

  static const _categories = [
    'sponsor',
    'intro',
    'outro',
    'selfpromo',
    'interaction',
    'music_offtopic',
  ];

  Future<List<SkipSegment>> fetchSkipSegments(String videoId) async {
    if (videoId.isEmpty) return const [];
    try {
      final uri = Uri.parse(
        'https://sponsor.ajay.app/api/skipSegments?videoID=$videoId'
        '&categories=${Uri.encodeComponent(jsonEncode(_categories))}',
      );
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 404) return const [];
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! List) return const [];
      final out = <SkipSegment>[];
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final seg = item['segment'] as List<dynamic>?;
        if (seg == null || seg.length < 2) continue;
        out.add(SkipSegment(
          startSeconds: (seg[0] as num).toDouble(),
          endSeconds: (seg[1] as num).toDouble(),
          category: (item['category'] as String?) ?? 'sponsor',
        ));
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<VideoVotes?> fetchVotes(String videoId) async {
    if (videoId.isEmpty) return null;
    try {
      final uri = Uri.parse(
        'https://returnyoutubedislikeapi.com/votes?videoId=$videoId',
      );
      final res =
          await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! Map<String, dynamic>) return null;
      return VideoVotes(
        likes: (data['likes'] as num?)?.toInt() ?? 0,
        dislikes: (data['dislikes'] as num?)?.toInt() ?? 0,
        viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
