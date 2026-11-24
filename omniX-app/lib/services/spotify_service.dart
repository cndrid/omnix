import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Error dari layanan katalog musik (Spotify Web API).
///
/// Pesan sengaja generik: tidak pernah memuat kunci, token, atau isi
/// respons mentah — supaya tidak ada kredensial yang bocor ke log/UI.
class SpotifyException implements Exception {
  final String message;
  const SpotifyException(this.message);

  @override
  String toString() => message;
}

/// Satu lagu dari katalog Spotify: metadata + cover resmi saja.
///
/// TIDAK ada audio di sini — audio tetap diambil dari YouTube saat lagu
/// diputar (lihat [YtClientService.resolvePlaybackVideoId]).
class SpotifyTrack {
  final String id;
  final String title;
  final List<String> artists;
  final String album;
  final int durationMs;
  final String coverUrl;
  final bool isExplicit;

  const SpotifyTrack({
    required this.id,
    required this.title,
    this.artists = const [],
    this.album = '',
    this.durationMs = 0,
    this.coverUrl = '',
    this.isExplicit = false,
  });

  String get artistLine =>
      artists.isEmpty ? 'Artis Tidak Diketahui' : artists.join(', ');
}

/// Klien Spotify Web API — Client Credentials flow saja.
///
/// - Kunci dibaca dari `--dart-define=SPOTIFY_CLIENT_ID/SECRET` (build CI
///   meneruskan GitHub secrets; build lokal tanpa flag berarti kunci
///   kosong — lihat [isConfigured]).
/// - Kunci TIDAK PERNAH di-hardcode, di-log, atau dicetak.
/// - Token akses di-cache sampai mendekati expiry lalu di-refresh
///   otomatis; 401 di tengah jalan memicu satu kali percobaan ulang
///   dengan token baru.
/// - Hanya endpoint yang masih didukung yang dipakai:
///   `POST /api/token` dan `GET /v1/search?type=track&limit=10`.
///   Endpoint yang dihapus Spotify (mis. /v1/recommendations,
///   Artist's Top Tracks) TIDAK dipakai — rak/rekomendasi Beranda
///   memakai pencarian katalog terkurasi, bukan endpoint rekomendasi.
class SpotifyService {
  static const Duration _timeout = Duration(seconds: 20);

  /// Token di-refresh kalau sisa umurnya kurang dari ini.
  static const Duration _refreshMargin = Duration(seconds: 60);

  final http.Client _client;
  final bool _ownsClient;

  String? _accessToken;
  DateTime? _expiresAt;
  Future<String>? _tokenFuture;

  SpotifyService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  /// Kunci dibaca dari dart-define — kosong kalau build tanpa flag.
  static const String _clientId =
      String.fromEnvironment('SPOTIFY_CLIENT_ID');
  static const String _clientSecret =
      String.fromEnvironment('SPOTIFY_CLIENT_SECRET');

  /// `true` hanya kalau kedua kunci tersedia. Kalau `false`, pemanggil
  /// HARUS fallback ke pencarian YouTube (lihat [YtClientService]).
  bool get isConfigured =>
      _clientId.isNotEmpty && _clientSecret.isNotEmpty;

  void dispose() {
    if (_ownsClient) _client.close();
  }

  /// Token akses yang masih berlaku — ambil baru kalau belum ada atau
  /// hampir kedaluwarsa. Panggilan bersamaan berbagi satu fetch.
  Future<String> _validAccessToken() async {
    final now = DateTime.now();
    if (_accessToken != null &&
        _expiresAt != null &&
        now.isBefore(_expiresAt!.subtract(_refreshMargin))) {
      return _accessToken!;
    }
    return _tokenFuture ??= _fetchToken().whenComplete(
      () => _tokenFuture = null,
    );
  }

  Future<String> _fetchToken() async {
    final credentials =
        base64Encode(utf8.encode('$_clientId:$_clientSecret'));
    final res = await _client
        .post(
          Uri.parse('https://accounts.spotify.com/api/token'),
          headers: {
            'Authorization': 'Basic $credentials',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'grant_type': 'client_credentials'},
        )
        .timeout(_timeout);
    if (res.statusCode != 200) {
      throw SpotifyException(
        'Gagal mengambil token katalog (HTTP ${res.statusCode}).',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final token = body['access_token'] as String?;
    final expiresIn = (body['expires_in'] as num?)?.toInt() ?? 3600;
    if (token == null || token.isEmpty) {
      throw const SpotifyException('Token katalog tidak valid.');
    }
    _accessToken = token;
    _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    return token;
  }

  Future<http.Response> _get(Uri uri, String token) {
    return _client
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(_timeout);
  }

  /// Cari lagu di katalog Spotify (maks. 10 hasil per panggilan —
  /// itu batas search API saat ini).
  ///
  /// Melempar [SpotifyException] kalau kunci belum dikonfigurasi atau
  /// jaringan/API gagal — pemanggil menangkapnya dan fallback ke
  /// YouTube, JANGAN tampilkan error ke pengguna.
  Future<List<SpotifyTrack>> searchTracks(
    String query, {
    int limit = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    if (!isConfigured) {
      throw const SpotifyException('Kunci katalog musik belum dikonfigurasi.');
    }
    final capped = limit.clamp(1, 10);
    final uri = Uri.https('api.spotify.com', '/v1/search', {
      'q': trimmed,
      'type': 'track',
      'limit': '$capped',
    });

    var res = await _get(uri, await _validAccessToken());
    if (res.statusCode == 401) {
      // Token kedaluwarsa di tengah jalan: buang cache, ambil baru,
      // coba sekali lagi.
      _accessToken = null;
      _expiresAt = null;
      res = await _get(uri, await _validAccessToken());
    }
    if (res.statusCode != 200) {
      throw SpotifyException(
        'Pencarian katalog gagal (HTTP ${res.statusCode}).',
      );
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final tracksJson = body['tracks'] as Map<String, dynamic>?;
    final items = (tracksJson?['items'] as List<dynamic>?) ?? const [];
    final out = <SpotifyTrack>[];
    for (final raw in items) {
      final item = raw as Map<String, dynamic>?;
      if (item == null) continue;
      final id = item['id'] as String?;
      final name = item['name'] as String?;
      if (id == null || id.isEmpty || name == null || name.isEmpty) {
        continue;
      }
      final artistsJson = (item['artists'] as List<dynamic>?) ?? const [];
      final artists = artistsJson
          .whereType<Map<String, dynamic>>()
          .map((a) => (a['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      final albumJson = item['album'] as Map<String, dynamic>?;
      final images = (albumJson?['images'] as List<dynamic>?) ?? const [];
      var coverUrl = '';
      var widest = -1;
      for (final rawImage in images) {
        final image = rawImage as Map<String, dynamic>?;
        if (image == null) continue;
        final url = image['url'] as String?;
        final width = (image['width'] as num?)?.toInt() ?? 0;
        if (url != null && url.isNotEmpty && width >= widest) {
          coverUrl = url;
          widest = width;
        }
      }
      out.add(SpotifyTrack(
        id: id,
        title: name,
        artists: artists,
        album: (albumJson?['name'] as String?) ?? '',
        durationMs: (item['duration_ms'] as num?)?.toInt() ?? 0,
        coverUrl: coverUrl,
        isExplicit: (item['explicit'] as bool?) ?? false,
      ));
    }
    return out;
  }
}
