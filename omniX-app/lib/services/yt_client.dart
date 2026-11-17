import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track_model.dart';

/// Layanan YouTube 100% client-side (InnerTube, lewat youtube_explode_dart).
///
/// Semua pencarian, metadata, dan feed beranda diambil langsung dari
/// perangkat pengguna — tidak ada lagi server cloud di tengah jalan, jadi
/// tidak ada risiko server mati, IP server diblokir YouTube, atau
/// SocketException ke backend sendiri.
class YtClientService {
  static const Duration _timeout = Duration(seconds: 30);

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

  /// Cari lagu/video di YouTube langsung dari HP.
  /// Catatan: parser youtube_explode_dart 3.1.0 crash (NoSuchMethodError
  /// getT) untuk sebagian query — YouTube mengembalikan item khusus
  /// (shelf/kartu) yang tidak bisa di-parse. Kalau halaman pertama
  /// kosong, coba halaman berikutnya sekali.
  Future<List<TrackModel>> searchMusic(
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final yt = YoutubeExplode();
    try {
      var page = await yt.search.search(trimmed).timeout(_timeout);
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
    } finally {
      yt.close();
    }
  }

  /// Cari artis (channel) — dipakai filter "Artis" di layar Cari.
  Future<List<TrackModel>> searchArtists(
    String query, {
    int limit = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final yt = YoutubeExplode();
    try {
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
    } finally {
      yt.close();
    }
  }

  /// Cari playlist — dipakai filter "Playlist" di layar Cari.
  Future<List<TrackModel>> searchPlaylists(
    String query, {
    int limit = 10,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final yt = YoutubeExplode();
    try {
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
    } finally {
      yt.close();
    }
  }

  /// Isi sebuah playlist (video-video di dalamnya).
  Future<List<TrackModel>> getPlaylistVideos(
    String playlistId, {
    int limit = 30,
  }) async {
    final yt = YoutubeExplode();
    try {
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
    } finally {
      yt.close();
    }
  }

  /// Detail lagu: judul, artis, durasi, thumbnail, dan lagu terkait.
  /// Stream audio & lirik diisi oleh pemanggil (StreamExtractor + LRCLIB).
  Future<SongDetailModel> getSongDetail(String videoId) async {
    final yt = YoutubeExplode();
    try {
      final v =
          await yt.videos.get(videoId).timeout(_timeout);
      final track = _videoToTrack(v);
      List<TrackModel> related = const [];
      try {
        related = await searchMusic('${v.author} lagu', limit: 6);
        related =
            related.where((t) => t.videoId != videoId).toList();
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
    } finally {
      yt.close();
    }
  }

  /// Feed beranda client-side: beberapa seksi dari pencarian terkurasi.
  /// Bukan feed YouTube Music (itu hanya ada lewat server), tapi hasilnya
  /// lagu Indonesia karena kata kuncinya berbahasa Indonesia.
  Future<ExploreDataModel> getExploreData({int limit = 6}) async {
    // Query di bawah sudah diverifikasi lolos parser
    // youtube_explode_dart 3.1.0 (sebagian query lain crash di parser
    // karena item khusus YouTube — lihat searchMusic).
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

    // Sekuensial, bukan paralel: YouTube membatasi request pencarian
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
    final yt = YoutubeExplode();
    try {
      final v = await yt.videos.get(videoId).timeout(_timeout);
      final tracks = await searchMusic('${v.author} lagu', limit: 20);
      return tracks.where((t) => t.videoId != videoId).toList();
    } finally {
      yt.close();
    }
  }
}
