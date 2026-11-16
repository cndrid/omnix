enum PlaybackMode { song, video, canvas }

enum ShuffleMode { off, normal, smart }

class ThumbnailModel {
  final String url;
  final int width;
  final int height;

  const ThumbnailModel({
    required this.url,
    this.width = 0,
    this.height = 0,
  });

  factory ThumbnailModel.fromJson(Map<String, dynamic> json) {
    return ThumbnailModel(
      url: (json['url'] as String?) ?? '',
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
    );
  }
}

class ArtistModel {
  final String name;
  final String? id;

  const ArtistModel({required this.name, this.id});

  factory ArtistModel.fromJson(Map<String, dynamic> json) {
    return ArtistModel(
      name: (json['name'] as String?) ?? 'Artis Tidak Diketahui',
      id: json['id'] as String?,
    );
  }
}

class AlbumModel {
  final String name;
  final String? id;

  const AlbumModel({required this.name, this.id});

  factory AlbumModel.fromJson(Map<String, dynamic> json) {
    return AlbumModel(
      name: (json['name'] as String?) ?? '',
      id: json['id'] as String?,
    );
  }
}

class ChapterModel {
  final String title;
  final int startSeconds;
  final int durationSeconds;

  const ChapterModel({
    required this.title,
    required this.startSeconds,
    required this.durationSeconds,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      title: (json['title'] as String?) ?? 'Bab Audio',
      startSeconds: (json['start_seconds'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}

class LyricLineModel {
  final int timeSeconds;
  final String text;

  const LyricLineModel({
    required this.timeSeconds,
    required this.text,
  });

  factory LyricLineModel.fromJson(Map<String, dynamic> json) {
    return LyricLineModel(
      timeSeconds: (json['time_seconds'] as num?)?.toInt() ?? 0,
      text: (json['text'] as String?) ?? '',
    );
  }
}

class SongCreditsModel {
  final List<String> writers;
  final List<String> producers;
  final String? releaseYear;
  final String label;
  final String? artistBio;
  final List<String> upcomingConcerts;

  const SongCreditsModel({
    this.writers = const [],
    this.producers = const [],
    this.releaseYear,
    this.label = 'YouTube Music / OmniX Lossless 24-bit',
    this.artistBio,
    this.upcomingConcerts = const [],
  });

  factory SongCreditsModel.fromJson(Map<String, dynamic> json) {
    return SongCreditsModel(
      writers: ((json['writers'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      producers: ((json['producers'] as List<dynamic>?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      releaseYear: json['release_year'] as String?,
      label: (json['label'] as String?) ?? 'OmniX Lossless 24-bit',
      artistBio: json['artist_bio'] as String?,
      upcomingConcerts:
          ((json['upcoming_concerts'] as List<dynamic>?) ?? const [])
              .map((e) => e.toString())
              .toList(),
    );
  }
}

class TrackModel {
  final String videoId;
  final String title;
  final List<ArtistModel> artists;
  final AlbumModel? album;
  final String? duration;
  final int? durationSeconds;
  final List<ThumbnailModel> thumbnails;
  final bool isExplicit;
  final String resultType;
  final String category;
  final String audioQualityBadge;

  const TrackModel({
    required this.videoId,
    required this.title,
    this.artists = const [],
    this.album,
    this.duration,
    this.durationSeconds,
    this.thumbnails = const [],
    this.isExplicit = false,
    this.resultType = 'song',
    this.category = 'music',
    this.audioQualityBadge = 'FLAC 24-bit',
  });

  String get artistLine {
    if (artists.isEmpty) return 'Artis Tidak Diketahui';
    return artists.map((a) => a.name).join(', ');
  }

  // Always returns a valid cover URL; falls back to i.ytimg.com (CORS-friendly on Web).
  String get bestThumbnailUrl {
    if (thumbnails.isNotEmpty && thumbnails.last.url.trim().isNotEmpty) {
      final raw = thumbnails.last.url.trim();
      if (raw.contains('googleusercontent.com') || raw.contains('ggpht.com')) {
        if (videoId.isNotEmpty && videoId.length == 11) {
          return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
        }
      }
      return raw;
    }
    if (videoId.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
    }
    return '';
  }

  String get backupYoutubeThumbnailUrl {
    if (videoId.isNotEmpty) {
      return 'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';
    }
    return '';
  }

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    final rawArtists = (json['artists'] as List<dynamic>?) ?? const [];
    final rawThumbs = (json['thumbnails'] as List<dynamic>?) ?? const [];
    final rawAlbum = json['album'] as Map<String, dynamic>?;

    return TrackModel(
      videoId: (json['video_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Tanpa Judul',
      artists: rawArtists
          .whereType<Map<String, dynamic>>()
          .map(ArtistModel.fromJson)
          .toList(),
      album: rawAlbum != null ? AlbumModel.fromJson(rawAlbum) : null,
      duration: json['duration'] as String?,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      thumbnails: rawThumbs
          .whereType<Map<String, dynamic>>()
          .map(ThumbnailModel.fromJson)
          .toList(),
      isExplicit: (json['is_explicit'] as bool?) ?? false,
      resultType: (json['result_type'] as String?) ?? 'song',
      category: (json['category'] as String?) ?? 'music',
      audioQualityBadge:
          (json['audio_quality_badge'] as String?) ?? 'FLAC 24-bit',
    );
  }
}

class SongDetailModel {
  final String videoId;
  final String title;
  final List<ArtistModel> artists;
  final AlbumModel? album;
  final int lengthSeconds;
  final List<ThumbnailModel> thumbnails;
  final String? audioStreamUrl;
  final String? audioMimeType;
  final int? audioBitrateKbps;
  final String? videoStreamUrl;
  final String? canvasLoopUrl;
  final String? lyrics;
  final bool hasSyncedLyrics;
  final List<LyricLineModel> syncedLyrics;
  final List<ChapterModel> chapters;
  final String? transcript;
  final SongCreditsModel credits;
  final List<TrackModel> relatedTracks;

  const SongDetailModel({
    required this.videoId,
    required this.title,
    this.artists = const [],
    this.album,
    this.lengthSeconds = 0,
    this.thumbnails = const [],
    this.audioStreamUrl,
    this.audioMimeType,
    this.audioBitrateKbps,
    this.videoStreamUrl,
    this.canvasLoopUrl,
    this.lyrics,
    this.hasSyncedLyrics = false,
    this.syncedLyrics = const [],
    this.chapters = const [],
    this.transcript,
    this.credits = const SongCreditsModel(),
    this.relatedTracks = const [],
  });

  String get streamFormatLabel {
    if (audioMimeType == null && audioBitrateKbps == null) {
      return 'FLAC 24-bit / 96kHz';
    }
    final codec = (audioMimeType ?? 'FLAC').toUpperCase();
    if (audioBitrateKbps != null && audioBitrateKbps! > 0) {
      return 'FLAC 24-bit · $codec ${audioBitrateKbps}kbps';
    }
    return 'FLAC 24-bit · $codec';
  }

  factory SongDetailModel.fromJson(Map<String, dynamic> json) {
    final rawArtists = (json['artists'] as List<dynamic>?) ?? const [];
    final rawThumbs = (json['thumbnails'] as List<dynamic>?) ?? const [];
    final rawRelated = (json['related_tracks'] as List<dynamic>?) ?? const [];
    final rawSynced = (json['synced_lyrics'] as List<dynamic>?) ?? const [];
    final rawChapters = (json['chapters'] as List<dynamic>?) ?? const [];
    final rawAlbum = json['album'] as Map<String, dynamic>?;
    final rawCredits = json['credits'] as Map<String, dynamic>?;

    return SongDetailModel(
      videoId: (json['video_id'] as String?) ?? '',
      title: (json['title'] as String?) ?? 'Tanpa Judul',
      artists: rawArtists
          .whereType<Map<String, dynamic>>()
          .map(ArtistModel.fromJson)
          .toList(),
      album: rawAlbum != null ? AlbumModel.fromJson(rawAlbum) : null,
      lengthSeconds: (json['length_seconds'] as num?)?.toInt() ?? 0,
      thumbnails: rawThumbs
          .whereType<Map<String, dynamic>>()
          .map(ThumbnailModel.fromJson)
          .toList(),
      audioStreamUrl: json['audio_stream_url'] as String?,
      audioMimeType: json['audio_mime_type'] as String?,
      audioBitrateKbps: (json['audio_bitrate_kbps'] as num?)?.toInt(),
      videoStreamUrl: json['video_stream_url'] as String?,
      canvasLoopUrl: json['canvas_loop_url'] as String?,
      lyrics: json['lyrics'] as String?,
      hasSyncedLyrics: (json['has_Synced_lyrics'] as bool?) ?? false,
      syncedLyrics: rawSynced
          .whereType<Map<String, dynamic>>()
          .map(LyricLineModel.fromJson)
          .toList(),
      chapters: rawChapters
          .whereType<Map<String, dynamic>>()
          .map(ChapterModel.fromJson)
          .toList(),
      transcript: json['transcript'] as String?,
      credits: rawCredits != null
          ? SongCreditsModel.fromJson(rawCredits)
          : const SongCreditsModel(),
      relatedTracks: rawRelated
          .whereType<Map<String, dynamic>>()
          .map(TrackModel.fromJson)
          .toList(),
    );
  }
}

class ExploreSectionModel {
  final String title;
  final String? subtitle;
  final String category;
  final List<TrackModel> items;

  const ExploreSectionModel({
    required this.title,
    this.subtitle,
    this.category = 'all',
    this.items = const [],
  });

  factory ExploreSectionModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>?) ?? const [];
    return ExploreSectionModel(
      title: (json['title'] as String?) ?? '',
      subtitle: json['subtitle'] as String?,
      category: (json['category'] as String?) ?? 'all',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(TrackModel.fromJson)
          .toList(),
    );
  }
}

class ExploreDataModel {
  final List<ExploreSectionModel> sections;
  final List<String> trendingTags;
  final List<TrackModel> rankedSearches;
  final List<ArtistModel> topArtists;

  const ExploreDataModel({
    this.sections = const [],
    this.trendingTags = const [],
    this.rankedSearches = const [],
    this.topArtists = const [],
  });

  factory ExploreDataModel.fromJson(Map<String, dynamic> json) {
    final rawSections = (json['sections'] as List<dynamic>?) ?? const [];
    final rawTags = (json['trending_tags'] as List<dynamic>?) ?? const [];
    final rawRanked = (json['ranked_searches'] as List<dynamic>?) ?? const [];
    final rawArtists = (json['top_artists'] as List<dynamic>?) ?? const [];

    return ExploreDataModel(
      sections: rawSections
          .whereType<Map<String, dynamic>>()
          .map(ExploreSectionModel.fromJson)
          .toList(),
      trendingTags: rawTags.map((e) => e.toString()).toList(),
      rankedSearches: rawRanked
          .whereType<Map<String, dynamic>>()
          .map(TrackModel.fromJson)
          .toList(),
      topArtists: rawArtists
          .whereType<Map<String, dynamic>>()
          .map(ArtistModel.fromJson)
          .toList(),
    );
  }
}

class UserPlaylistModel {
  final String id;
  final String name;
  final String description;
  final bool isCollaborative;
  final bool isPublic;
  final bool isPinned;
  final bool isOfflineSynced;
  final int? blendMatchScore;
  final List<TrackModel> tracks;

  const UserPlaylistModel({
    required this.id,
    required this.name,
    required this.description,
    this.isCollaborative = false,
    this.isPublic = true,
    this.isPinned = false,
    this.isOfflineSynced = false,
    this.blendMatchScore,
    this.tracks = const [],
  });

  UserPlaylistModel copyWith({
    String? name,
    String? description,
    bool? isCollaborative,
    bool? isPublic,
    bool? isPinned,
    bool? isOfflineSynced,
    int? blendMatchScore,
    List<TrackModel>? tracks,
  }) {
    return UserPlaylistModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      isCollaborative: isCollaborative ?? this.isCollaborative,
      isPublic: isPublic ?? this.isPublic,
      isPinned: isPinned ?? this.isPinned,
      isOfflineSynced: isOfflineSynced ?? this.isOfflineSynced,
      blendMatchScore: blendMatchScore ?? this.blendMatchScore,
      tracks: tracks ?? this.tracks,
    );
  }
}
