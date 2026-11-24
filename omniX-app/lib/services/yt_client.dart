import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track_model.dart';
import 'shared_stream_client.dart';
import 'spotify_service.dart';

/// Layanan musik 100% client-side (InnerTube, lewat youtube_explode_dart).
///
/// Semua pencarian, metadata, dan feed beranda diambil langsung dari
/// perangkat pengguna — tidak ada lagi server cloud di tengah jalan, jadi
/// tidak ada risiko server mati, IP server diblokir platform, atau
/// SocketException ke backend sendiri.
///
/// Pencarian lagu (24 Nov 2026): katalog Spotify dipakai DULUAN untuk
/// metadata/cover — hasil cari Spotify jauh lebih bersih (satu lagu =
/// satu track, bukan video mix/kompilasi puluhan lagu). Audio TETAP dari
/// YouTube: resolusi ke video dilakukan LAZY saat lagu akan diputar
/// ([resolvePlaybackVideoId]), bukan untuk semua hasil sekaligus.
/// Kalau kunci Spotify kosong (build lokal tanpa --dart-define) atau
/// katalog gagal, pencarian jatuh kembali ke YouTube seperti semula —
/// aplikasi tidak crash dan tidak menampilkan error ke pengguna.
class YtClientService {
  final SpotifyService _spotify;

  YtClientService({SpotifyService? spotifyService})
      : _spotify = spotifyService ?? SpotifyService();

  static const Duration _timeout = Duration(seconds: 30);

  // Jeda antar percobaan pencarian: hasil platform berubah-ubah antar
  // request, jadi jeda singkat memberi peluang shelf yang berbeda.
  static const Duration _retryDelay = Duration(seconds: 2);

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  List<ThumbnailModel> _thumbs(ThumbnailSet t) {
    return [
      ThumbnailModel(url: t.mediumResUrl, width: 320, height: 180),
      ThumbnailModel(url: t.highResUrl, width: 480, height: 360),
      ThumbnailModel(url: t.maxResUrl, width: 1280, height: 720),
    ];
  }

  TrackModel _videoToTrack(Video v) {
    final secs = v.duration?.inSeconds;
    return TrackModel(
      videoId: v.id.value,
      title: v.title,
      artists: [ArtistModel(name: v.author)],
      duration: secs != null ? _formatDuration(secs) : null,
      durationSeconds: secs,
      thumbnails: _thumbs(v.thumbnails),
      // Tanpa badge kualitas palsu: info asli diisi dari stream saat diputar.
      audioQualityBadge: '',
    );
  }

  /// Cari lagu: katalog Spotify dulu (metadata + cover resmi), lalu
  /// fallback diam-diam ke YouTube kalau kunci kosong / katalog gagal /
  /// hasil kosong. Hasil Spotify punya `videoId` kosong + `spotifyId`
  /// terisi — video YouTube-nya baru dicari saat lagu akan diputar
  /// ([resolvePlaybackVideoId]).
  Future<List<TrackModel>> searchMusic(
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    if (_spotify.isConfigured) {
      try {
        final found = await _spotify.searchTracks(trimmed, limit: 10);
        if (found.isNotEmpty) {
          return found.map(_spotifyTrackToTrack).toList();
        }
      } catch (_) {
        // Katalog gagal: jatuh ke YouTube di bawah, tanpa error ke UI.
      }
    }
    return _searchMusicYouTube(trimmed, limit: limit);
  }

  TrackModel _spotifyTrackToTrack(SpotifyTrack t) {
    final secs = t.durationMs > 0 ? t.durationMs ~/ 1000 : null;
    return TrackModel(
      videoId: '',
      title: t.title,
      artists: t.artists.map((name) => ArtistModel(name: name)).toList(),
      album: t.album.isEmpty ? null : AlbumModel(name: t.album),
      duration: secs != null ? _formatDuration(secs) : null,
      durationSeconds: secs,
      thumbnails: t.coverUrl.isEmpty
          ? const []
          : [ThumbnailModel(url: t.coverUrl, width: 640, height: 640)],
      isExplicit: t.isExplicit,
      spotifyId: t.id,
    );
  }

  /// Cari lagu/video langsung dari HP.
  /// Catatan: parser youtube_explode_dart 3.1.0 crash (NoSuchMethodError
  /// getT) untuk sebagian query — platform mengembalikan item khusus
  /// (shelf/kartu) yang tidak bisa di-parse. Crash-nya tidak
  /// deterministis: query yang sama kadang lolos kadang crash, jadi coba
  /// sampai 3 kali dengan reformulasi query + fallback umum di ujungnya.
  Future<List<TrackModel>> _searchMusicYouTube(
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    // Urutan percobaan: query asli, query diubah, lalu fallback umum
    // yang sudah terverifikasi lolos parser ("musik Indonesia terpopuler").
    // Reformulasi yang terverifikasi: tambah " indonesia" kalau query
    // belum mengandungnya, kalau sudah → tambah " terbaru".
    final attempts = <String>[
      trimmed,
      trimmed.toLowerCase().contains('indonesia')
          ? '$trimmed terbaru'
          : '$trimmed indonesia',
      'musik Indonesia terpopuler',
    ];

    Object? lastError;
    StackTrace? lastStack;
    for (var i = 0; i < attempts.length; i++) {
      if (i > 0) await Future.delayed(_retryDelay);
      try {
        final tracks = await _searchOnce(attempts[i], limit);
        if (tracks.isNotEmpty) return tracks;
      } catch (e, s) {
        lastError = e;
        lastStack = s;
      }
    }
    // Semua percobaan gagal/kosong: lempar error seperti sebelumnya,
    // supaya UI tetap menampilkan kartu error + tombol coba lagi.
    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStack!);
    }
    throw StateError('Pencarian tidak menemukan hasil.');
  }

  /// Satu percobaan pencarian: halaman pertama, lalu halaman berikutnya
  /// sekali kalau halaman pertama kosong. Error parser diteruskan apa
  /// adanya ke pemanggil (searchMusic) untuk di-retry.
  Future<List<TrackModel>> _searchOnce(String query, int limit) async {
    final yt = SharedStreamClient.instance;
    var page = await yt.search.search(query).timeout(_timeout);
    var videos = page.toList();
    if (videos.isEmpty) {
      final next = await page.nextPage().timeout(_timeout);
      if (next != null) videos = next.toList();
    }
    final tracks = <TrackModel>[];
    for (final v in videos) {
      // Lewati live stream / video tanpa durasi.
      if (v.duration == null) continue;
      tracks.add(_videoToTrack(v));
      if (tracks.length >= limit) break;
    }
    return tracks;
  }

  /// Durasi maksimum video yang boleh diputar sebagai lagu: video di
  /// atas ini hampir pasti mix/kompilasi/full album, bukan satu lagu.
  static const int maxPlayableSeconds = 15 * 60;

  /// Pola judul video yang menandakan BUKAN satu lagu (mix/kompilasi/
  /// full album/maraton jam-jaman). `\bmix\b` sengaja ber-word-boundary
  /// supaya "Remix" (satu lagu yang sah) tetap lolos.
  static final List<RegExp> _rejectedTitlePatterns = [
    RegExp(r'\bmix\b', caseSensitive: false),
    RegExp(r'\bkompilasi\b', caseSensitive: false),
    RegExp(r'compilation', caseSensitive: false),
    RegExp(r'full album', caseSensitive: false),
    RegExp(r'\bnonstop\b', caseSensitive: false),
    RegExp(r'non-stop', caseSensitive: false),
    RegExp(r'\b\d+\s*(hour|hours|jam)\b', caseSensitive: false),
    RegExp(r'\bplaylist\b', caseSensitive: false),
  ];

  /// Apakah sebuah video YouTube layak diputar sebagai lagu ini.
  /// Dipakai sebagai pure function supaya bisa diuji tanpa network.
  /// Selisih durasi dengan target TIDAK menolak — hanya dipakai untuk
  /// perangkingan di [resolvePlaybackVideoId] (versi live/lyrics yang
  /// durasinya agak beda tetap boleh diputar).
  static bool matchesPlaybackCandidate({
    required String title,
    required int? durationSeconds,
    int? targetDurationSeconds,
  }) {
    if (durationSeconds == null || durationSeconds <= 0) return false;
    if (durationSeconds > maxPlayableSeconds) return false;
    for (final pattern in _rejectedTitlePatterns) {
      if (pattern.hasMatch(title)) return false;
    }
    return true;
  }

  /// Resolusi LAZY Spotify -> YouTube: dipanggil SAAT lagu akan diputar
  /// (seam di PlayerController.selectTrack — lihat patch yang diusulkan),
  /// BUKAN saat hasil cari ditampilkan. Hasil cari tampil dari metadata
  /// Spotify (cover + durasi dari katalog); video YouTube hanya dicari
  /// untuk lagu yang benar-benar diketuk.
  ///
  /// Cocokkan berdasarkan judul+artis + saringan durasi: buang video
  /// >15 menit dan judul mix/kompilasi/full album/maraton; dari yang
  /// lolos, pilih yang durasinya paling dekat dengan durasi katalog.
  /// Lagu yang sudah punya `videoId` (asal YouTube) dikembalikan apa
  /// adanya. Melempar [StateError] kalau tidak ada video yang cocok.
  Future<TrackModel> resolvePlaybackVideoId(TrackModel track) async {
    if (track.videoId.isNotEmpty) return track;
    final spotifyId = track.spotifyId;
    if (spotifyId == null || spotifyId.isEmpty) return track;
    final artist = track.artistLine;
    final queries = <String>[
      if (artist.isNotEmpty && artist != 'Artis Tidak Diketahui')
        '${track.title} $artist',
      track.title,
    ];
    for (final query in queries) {
      List<TrackModel> candidates;
      try {
        candidates = await _searchOnce(query, 10);
      } catch (_) {
        continue;
      }
      final passing = candidates
          .where((t) => matchesPlaybackCandidate(
                title: t.title,
                durationSeconds: t.durationSeconds,
                targetDurationSeconds: track.durationSeconds,
              ))
          .toList();
      if (passing.isEmpty) continue;
      final target = track.durationSeconds;
      if (target != null) {
        passing.sort((a, b) =>
            (a.durationSeconds! - target).abs().compareTo(
                  (b.durationSeconds! - target).abs(),
                ));
      }
      final best = passing.first;
      return TrackModel(
        videoId: best.videoId,
        title: track.title,
        artists: track.artists,
        album: track.album,
        duration: track.duration,
        durationSeconds: track.durationSeconds,
        thumbnails: track.thumbnails,
        isExplicit: track.isExplicit,
        resultType: track.resultType,
        category: track.category,
        audioQualityBadge: track.audioQualityBadge,
        spotifyId: track.spotifyId,
      );
    }
    throw StateError(
      'Tidak ditemukan video yang cocok untuk "${track.title}".',
    );
  }

  /// Cari artis (channel) — dipakai filter "Artis" di layar Cari.
  Future<List<TrackModel>> searchArtists(
    String query, {
    int limit = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final yt = SharedStreamClient.instance;
    final results =
        await yt.search.searchContent(trimmed).timeout(_timeout);
    final out = <TrackModel>[];
    for (final r in results) {
      if (r is! SearchChannel) continue;
      out.add(TrackModel(
        videoId: '',
        title: r.name,
        artists: [ArtistModel(name: r.name)],
        resultType: 'artist',
        category: 'artist',
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Cari playlist — dipakai filter "Playlist" di layar Cari.
  Future<List<TrackModel>> searchPlaylists(
    String query, {
    int limit = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final yt = SharedStreamClient.instance;
    final results =
        await yt.search.searchContent(trimmed).timeout(_timeout);
    final out = <TrackModel>[];
    for (final r in results) {
      if (r is! SearchPlaylist) continue;
      out.add(TrackModel(
        // videoId dipakai untuk menyimpan id playlist di pseudo-track.
        videoId: r.id.value,
        title: r.title,
        artists: const [],
        resultType: 'playlist',
        category: 'playlist',
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Isi sebuah playlist (video-video di dalamnya).
  Future<List<TrackModel>> getPlaylistVideos(
    String playlistId, {
    int limit = 30,
  }) async {
    final yt = SharedStreamClient.instance;
    final videos = await yt.playlists
        .getVideos(PlaylistId(playlistId))
        .take(limit)
        .toList()
        .timeout(_timeout);
    final tracks = <TrackModel>[];
    for (final v in videos) {
      if (v.duration == null) continue;
      tracks.add(_videoToTrack(v));
      if (tracks.length >= limit) break;
    }
    return tracks;
  }

  /// Detail lagu: judul, artis, durasi, thumbnail, dan lagu terkait.
  /// Stream audio & lirik diisi oleh pemanggil (StreamExtractor + LRCLIB).
  Future<SongDetailModel> getSongDetail(String videoId) async {
    final yt = SharedStreamClient.instance;
    final v = await yt.videos.get(videoId).timeout(_timeout);
    final track = _videoToTrack(v);
    List<TrackModel> related = const [];
    try {
      related = await searchMusic('${v.author} lagu', limit: 6);
      related = related.where((t) => t.videoId != videoId).toList();
    } catch (_) {
      related = const [];
    }
    return SongDetailModel(
      videoId: track.videoId,
      title: track.title,
      artists: track.artists,
      lengthSeconds: track.durationSeconds ?? 0,
      thumbnails: track.thumbnails,
      relatedTracks: related,
    );
  }

  /// Feed beranda client-side: beberapa seksi dari pencarian terkurasi.
  /// Bukan feed kurasi server (itu hanya ada lewat server), tapi hasilnya
  /// lagu Indonesia karena kata kuncinya berbahasa Indonesia.
  Future<ExploreDataModel> getExploreData({int limit = 6}) async {
    // Query di bawah sudah diverifikasi lolos parser
    // youtube_explode_dart 3.1.0 (sebagian query lain crash di parser
    // karena item khusus platform — lihat searchMusic).
    const defs = <(String, String)>[
      ('Trending Indonesia', 'musik Indonesia terpopuler'),
      ('Pop Indonesia', 'lagu pop Indonesia'),
      ('Lofi Indonesia', 'lofi indonesia'),
      ('Dangdut Koplo', 'dangdut koplo terbaru'),
    ];

    Future<ExploreSectionModel?> loadSection((String, String) def) async {
      try {
        final items = await searchMusic(def.$2, limit: limit);
        if (items.isEmpty) return null;
        return ExploreSectionModel(
          title: def.$1,
          subtitle: 'Pilihan dari pencarian populer',
          category: 'music',
          items: items,
        );
      } catch (_) {
        return null;
      }
    }

    // Sekuensial, bukan paralel: platform membatasi request pencarian
    // bersamaan dari satu IP — paralel sering membuat sebagian seksi
    // gagal dimuat (terbukti di pengujian: hanya 1 dari 4 yang lolos).
    final sections = <ExploreSectionModel>[];
    for (final def in defs) {
      final sec = await loadSection(def);
      if (sec != null) sections.add(sec);
    }

    final artistMap = <String, ArtistModel>{};
    for (final sec in sections) {
      for (final item in sec.items) {
        for (final art in item.artists) {
          artistMap.putIfAbsent(art.name, () => art);
        }
      }
    }
    final allTracks = [
      for (final sec in sections) ...sec.items,
    ];

    return ExploreDataModel(
      sections: sections,
      trendingTags: const [
        '#PopIndo',
        '#LoFiSenja',
        '#DangdutKoplo',
        '#IndieAkustik',
        '#LaguGalau',
      ],
      rankedSearches: allTracks.take(5).toList(),
      topArtists: artistMap.values.take(10).toList(),
    );
  }

  // Kata kunci mood -> query yang sudah diverifikasi lolos parser.
  static const Map<String, String> _moodQueries = {
    'Lofi Fokus & Energi Malam': 'lofi indonesia',
    'Semangat Pagi': 'lagu pop Indonesia',
    'Galau Hujan': 'lagu pop Indonesia',
    'Fokus Kerja': 'lofi indonesia',
    'Santai Sore': 'dangdut koplo terbaru',
  };

  /// AI DJ versi client-side: kurasi dari kata kunci mood, tanpa server.
  /// Sapaan & komentar memakai template lokal (bukan Gemini).
  Future<(String, String, List<TrackModel>)> getAiDjSession({
    String mood = 'Lofi Fokus & Energi Malam',
  }) async {
    final query = _moodQueries[mood] ?? mood;
    List<TrackModel> tracks;
    try {
      tracks = await searchMusic(query, limit: 12);
    } catch (_) {
      // Fallback kalau query mood crash di parser.
      tracks = await searchMusic('musik Indonesia terpopuler', limit: 12);
    }
    final greeting = 'Halo, ini DJ OmniX kamu. Suasana $mood, ya?';
    final commentary =
        'Saya pilihkan ${tracks.length} lagu yang cocok buat $mood. Selamat mendengarkan.';
    return (greeting, commentary, tracks);
  }

  /// Playlist dari prompt: cari langsung dengan teks prompt-nya.
  /// Kalau prompt crash di parser, pakai pencarian umum sebagai fallback.
  Future<UserPlaylistModel> generatePromptPlaylist(String prompt) async {
    List<TrackModel> tracks;
    try {
      tracks = await searchMusic(prompt, limit: 20);
    } catch (_) {
      tracks = await searchMusic('musik Indonesia terpopuler', limit: 20);
    }
    return UserPlaylistModel(
      id: 'ai_${DateTime.now().millisecondsSinceEpoch}',
      name: 'AI Mix: $prompt',
      description: 'Playlist otomatis dari pencarian "$prompt".',
      isPublic: true,
      isPinned: true,
      tracks: tracks,
    );
  }

  /// Radio: lagu-lagu dari artis yang sama.
  Future<List<TrackModel>> getRadio(String videoId) async {
    final yt = SharedStreamClient.instance;
    final v = await yt.videos.get(videoId).timeout(_timeout);
    final tracks = await searchMusic('${v.author} lagu', limit: 20);
    return tracks.where((t) => t.videoId != videoId).toList();
  }
}
