import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/track_model.dart';
import 'lyrics_service.dart';
import 'skip_service.dart';
import 'yt_client.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

/// Fasade data OmniX — 100% client-side sejak 17 Nov 2026.
///
/// Dulu semua method ini menembak backend FastAPI di Fly.io (sering kena
/// SocketException, Failed host lookup, dan IP ban YouTube). Sekarang
/// semuanya jalan langsung dari HP:
/// - pencarian / metadata / feed: InnerTube via youtube_explode_dart
/// - lirik: LRCLIB (API publik, tanpa kunci)
/// - skip sponsor & rasio dislike: SponsorBlock + Return YouTube Dislike
///
/// Tanda tangan method dipertahankan supaya provider & view tidak berubah.
class OmniXApiService {
  // Dipertahankan untuk kompatibilitas (profile lama menampilkan URL).
  // Tidak lagi dipakai: tidak ada server yang dihubungi.
  final String baseUrl;
  final YtClientService _yt;
  final LrclibService _lyrics;
  final SkipService _skip;

  OmniXApiService({
    String? baseUrl,
    YtClientService? ytClient,
    LrclibService? lyricsService,
    SkipService? skipService,
  })  : baseUrl = (baseUrl ?? '').replaceAll(RegExp(r'/+$'), ''),
        _yt = ytClient ?? YtClientService(),
        _lyrics = lyricsService ?? LrclibService(),
        _skip = skipService ?? SkipService();

  void dispose() {
    _lyrics.dispose();
    _skip.dispose();
  }

  /// Cek konektivitas umum (bukan ke server OmniX lagi — tidak ada server).
  Future<bool> healthCheck() async {
    try {
      final res = await http
          .get(Uri.parse('https://www.youtube.com'))
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

    try {
      switch (filter) {
        case 'artists':
          return await _yt.searchArtists(trimmed, limit: limit);
        case 'playlists':
          return await _yt.searchPlaylists(trimmed, limit: limit);
        default:
          return await _yt.searchMusic(trimmed, limit: limit);
      }
    } catch (e) {
      throw ApiException('Gagal mencari "$trimmed" di YouTube: $e');
    }
  }

  /// Isi sebuah playlist hasil pencarian (dipakai layar Cari).
  Future<List<TrackModel>> getPlaylistVideos(
    String playlistId, {
    int limit = 30,
  }) async {
    try {
      return await _yt.getPlaylistVideos(playlistId, limit: limit);
    } catch (e) {
      throw ApiException('Gagal memuat isi playlist: $e');
    }
  }

  /// Detail lagu + lirik (LRCLIB) + rasio suka/tidak suka (RYD).
  /// Lirik & votes bersifat opsional: gagal mengambilnya tidak
  /// menggagalkan detail lagu.
  Future<SongDetailModel> getSongDetail(
    String videoId, {
    bool includeStreams = true,
  }) async {
    try {
      final detail = await _yt.getSongDetail(videoId);
      final artist = detail.artists.isEmpty
          ? ''
          : detail.artists.first.name;
      final results = await Future.wait([
        _lyrics
            .fetchLyrics(
              artist: artist,
              track: detail.title,
              album: detail.album?.name,
              durationSeconds:
                  detail.lengthSeconds > 0 ? detail.lengthSeconds : null,
            )
            .catchError((_) => null),
        _skip.fetchVotes(videoId).catchError((_) => null),
      ]);
      final lyrics = results[0] as LyricsResult?;
      final votes = results[1] as VideoVotes?;
      return detail.copyWith(
        lyrics: lyrics?.plainLyrics,
        hasSyncedLyrics: lyrics?.hasSynced ?? false,
        syncedLyrics: lyrics?.syncedLyrics ?? const [],
        likes: votes?.likes,
        dislikes: votes?.dislikes,
      );
    } catch (e) {
      throw ApiException('Gagal mengambil data lagu: $e');
    }
  }

  /// Segmen sponsor/intro/outro untuk dilewati otomatis saat pemutaran.
  Future<List<SkipSegment>> getSkipSegments(String videoId) {
    return _skip.fetchSkipSegments(videoId);
  }

  Future<ExploreDataModel> getExploreData({int limit = 6}) async {
    try {
      return await _yt.getExploreData(limit: limit);
    } catch (e) {
      throw ApiException('Gagal memuat beranda: $e');
    }
  }

  Future<(String, String, List<TrackModel>)> getAiDjSession({
    String mood = 'Lofi Fokus & Energi Malam',
  }) async {
    try {
      return await _yt.getAiDjSession(mood: mood);
    } catch (e) {
      throw ApiException('Gagal memuat AI DJ: $e');
    }
  }

  Future<UserPlaylistModel> generatePromptPlaylist(String prompt) async {
    try {
      return await _yt.generatePromptPlaylist(prompt);
    } catch (e) {
      throw ApiException('Gagal membuat playlist dari prompt: $e');
    }
  }

  Future<List<TrackModel>> getRadio(String videoId) async {
    try {
      return await _yt.getRadio(videoId);
    } catch (e) {
      throw ApiException('Gagal memuat radio: $e');
    }
  }

  /// Thumbnail kini dipakai langsung dari YouTube — tidak perlu proxy.
  String proxyImageUrl(String? url, {String? videoId}) {
    if (url != null && url.isNotEmpty) return url;
    if (videoId != null && videoId.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    }
    return '';
  }

  /// Tidak ada lagi backend stream-video: video diambil langsung lewat
  /// StreamExtractor di perangkat. Dipertahankan supaya pemanggil lama
  /// tidak pecah — mengembalikan string kosong.
  String streamVideoUrl(String videoId, {String? title, String? artist}) {
    return '';
  }
}
