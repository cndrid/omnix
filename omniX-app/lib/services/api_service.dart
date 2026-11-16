import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track_model.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class OmniXApiService {
  final String baseUrl;
  final http.Client _client;

  OmniXApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? 'http://127.0.0.1:8000')
            .replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  void dispose() {
    _client.close();
  }

  Future<bool> healthCheck() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<TrackModel>> search({
    required String query,
    String filter = 'songs',
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse('$baseUrl/api/search').replace(queryParameters: {
      'query': trimmed,
      'filter': filter,
      'limit': limit.toString(),
    });

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw ApiException('Server mengembalikan status ${res.statusCode}');
      }
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final rawResults = (data['results'] as List<dynamic>?) ?? const [];
      return rawResults
          .whereType<Map<String, dynamic>>()
          .map(TrackModel.fromJson)
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal memuat hasil pencarian dari backend: $e');
    }
  }

  Future<SongDetailModel> getSongDetail(
    String videoId, {
    bool includeStreams = true,
  }) async {
    final uri = Uri.parse('$baseUrl/api/song/$videoId').replace(
      queryParameters: {
        'include_streams': includeStreams.toString(),
      },
    );

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw ApiException('Gagal memuat detail lagu (status ${res.statusCode})');
      }
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return SongDetailModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal mengambil data lagu dari backend: $e');
    }
  }

  Future<ExploreDataModel> getExploreData({int limit = 6}) async {
    final uri = Uri.parse('$baseUrl/api/explore').replace(
      queryParameters: {
        'limit': limit.toString(),
      },
    );

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw ApiException('Gagal memuat feed explore (status ${res.statusCode})');
      }
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return ExploreDataModel.fromJson(data);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal memuat beranda dari backend Python: $e');
    }
  }

  Future<(String, String, List<TrackModel>)> getAiDjSession({
    String mood = 'Lofi Fokus & Energi Malam',
  }) async {
    final uri = Uri.parse('$baseUrl/api/ai-dj').replace(
      queryParameters: {
        'mood': mood,
      },
    );

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        throw ApiException('Gagal memuat AI DJ (status ${res.statusCode})');
      }
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final greeting =
          (data['greeting'] as String?) ?? 'Halo, saya AI DJ OmniX kamu.';
      final commentary = (data['commentary'] as String?) ??
          'Memutar kurasi lagu terbaik untuk suasana $mood.';
      final rawTracks = (data['tracks'] as List<dynamic>?) ?? const [];
      final tracks = rawTracks
          .whereType<Map<String, dynamic>>()
          .map(TrackModel.fromJson)
          .toList();
      return (greeting, commentary, tracks);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal menghubungi AI DJ di backend: $e');
    }
  }

  Future<UserPlaylistModel> generatePromptPlaylist(String prompt) async {
    final uri = Uri.parse('$baseUrl/api/prompt-playlist').replace(
      queryParameters: {
        'prompt': prompt,
      },
    );

    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        throw ApiException(
            'Gagal membuat playlist prompt (status ${res.statusCode})');
      }
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final name = (data['playlist_name'] as String?) ?? 'AI Mix: $prompt';
      final desc = (data['description'] as String?) ??
          'Playlist otomatis yang diracik oleh backend OmniX.';
      final rawTracks = (data['tracks'] as List<dynamic>?) ?? const [];
      final tracks = rawTracks
          .whereType<Map<String, dynamic>>()
          .map(TrackModel.fromJson)
          .toList();

      return UserPlaylistModel(
        id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        description: desc,
        isPublic: true,
        isPinned: true,
        tracks: tracks,
      );
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal membuat prompt playlist di backend: $e');
    }
  }

  Future<List<TrackModel>> getRadio(String videoId) async {
    final uri = Uri.parse('$baseUrl/api/radio/$videoId');
    try {
      final res = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw ApiException('Gagal memuat radio (status ${res.statusCode})');
      }
      final rawList = jsonDecode(utf8.decode(res.bodyBytes)) as List<dynamic>;
      return rawList
          .whereType<Map<String, dynamic>>()
          .map(TrackModel.fromJson)
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Gagal memuat stasiun radio untuk $videoId: $e');
    }
  }

  String proxyImageUrl(String? url, {String? videoId}) {
    final params = <String, String>{};
    if (url != null && url.isNotEmpty) {
      params['url'] = url;
    }
    if (videoId != null && videoId.isNotEmpty) {
      params['video_id'] = videoId;
    }
    return Uri.parse('$baseUrl/api/proxy-image')
        .replace(queryParameters: params)
        .toString();
  }

  String streamVideoUrl(String videoId, {String? title, String? artist}) {
    final params = <String, String>{};
    if (title != null && title.isNotEmpty) {
      params['title'] = title;
    }
    if (artist != null && artist.isNotEmpty) {
      params['artist'] = artist;
    }
    return Uri.parse('$baseUrl/api/stream-video/$videoId')
        .replace(queryParameters: params)
        .toString();
  }
}
