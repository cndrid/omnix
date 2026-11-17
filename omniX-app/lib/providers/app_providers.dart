import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track_model.dart';
import '../services/api_service.dart';
import '../services/audio_handler_service.dart';
import '../services/stream_extractor.dart';

enum AppTab { beranda, cari, koleksi, profil }

enum LibrarySortMode { recentPlayed, recentAdded, alphabetical }

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

final reducedTransparencyProvider = StateProvider<bool>((ref) => false);

final activeTabProvider = StateProvider<AppTab>((ref) => AppTab.beranda);

final railCollapsedProvider = StateProvider<bool>((ref) => false);

final homeCategoryFilterProvider = StateProvider<String>((ref) => 'Semua');

final backendBaseUrlProvider =
    StateProvider<String>((ref) => 'http://127.0.0.1:8000');

final apiServiceProvider = Provider<OmniXApiService>((ref) {
  final baseUrl = ref.watch(backendBaseUrlProvider);
  final service = OmniXApiService(baseUrl: baseUrl);
  ref.onDispose(service.dispose);
  return service;
});

final audioHandlerProvider = Provider<OmniXAudioHandler>((ref) {
  final handler = OmniXAudioHandler();
  ref.onDispose(handler.dispose);
  return handler;
});

final exploreDataProvider = FutureProvider<ExploreDataModel>((ref) async {
  final api = ref.watch(apiServiceProvider);
  return api.getExploreData();
});

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchFilterProvider = StateProvider<String>((ref) => 'songs');

final searchResultsProvider = FutureProvider<List<TrackModel>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();
  final filter = ref.watch(searchFilterProvider);
  if (query.isEmpty) {
    return const [];
  }
  final api = ref.watch(apiServiceProvider);
  return api.search(query: query, filter: filter);
});

class AudioEngineSettingsState {
  final String? userDisplayName;
  final String? userBio;
  final String audioQuality;
  final bool gaplessPlayback;
  final double crossfadeSeconds;
  final bool automix;
  final bool volumeNormalization;
  final bool dataSaver;
  final bool privateSession;
  final bool showFriendActivity;
  final bool explicitContentAllowed;
  final bool excludeFromTasteProfile;
  final String activeDeviceName;
  final String equalizerPreset;
  final List<double> eqBands;
  final bool jamSessionActive;
  final String jamCode;
  final List<String> jamParticipants;

  const AudioEngineSettingsState({
    this.userDisplayName,
    this.userBio,
    this.audioQuality = 'Lossless FLAC 24-bit / 96kHz',
    this.gaplessPlayback = true,
    this.crossfadeSeconds = 4.0,
    this.automix = true,
    this.volumeNormalization = true,
    this.dataSaver = false,
    this.privateSession = false,
    this.showFriendActivity = true,
    this.explicitContentAllowed = true,
    this.excludeFromTasteProfile = false,
    this.activeDeviceName = 'AirPods Pro (Spatial 3D)',
    this.equalizerPreset = 'Spatial 3D',
    this.eqBands = const [2.5, 1.5, 0.5, 2.0, 3.5],
    this.jamSessionActive = false,
    this.jamCode = 'OMNIX-8824',
    this.jamParticipants = const [],
  });

  bool get hasUserProfile =>
      userDisplayName != null && userDisplayName!.trim().isNotEmpty;

  AudioEngineSettingsState copyWith({
    String? userDisplayName,
    bool clearUser = false,
    String? userBio,
    String? audioQuality,
    bool? gaplessPlayback,
    double? crossfadeSeconds,
    bool? automix,
    bool? volumeNormalization,
    bool? dataSaver,
    bool? privateSession,
    bool? showFriendActivity,
    bool? explicitContentAllowed,
    bool? excludeFromTasteProfile,
    String? activeDeviceName,
    String? equalizerPreset,
    List<double>? eqBands,
    bool? jamSessionActive,
    String? jamCode,
    List<String>? jamParticipants,
  }) {
    return AudioEngineSettingsState(
      userDisplayName:
          clearUser ? null : (userDisplayName ?? this.userDisplayName),
      userBio: clearUser ? null : (userBio ?? this.userBio),
      audioQuality: audioQuality ?? this.audioQuality,
      gaplessPlayback: gaplessPlayback ?? this.gaplessPlayback,
      crossfadeSeconds: crossfadeSeconds ?? this.crossfadeSeconds,
      automix: automix ?? this.automix,
      volumeNormalization: volumeNormalization ?? this.volumeNormalization,
      dataSaver: dataSaver ?? this.dataSaver,
      privateSession: privateSession ?? this.privateSession,
      showFriendActivity: showFriendActivity ?? this.showFriendActivity,
      explicitContentAllowed:
          explicitContentAllowed ?? this.explicitContentAllowed,
      excludeFromTasteProfile:
          excludeFromTasteProfile ?? this.excludeFromTasteProfile,
      activeDeviceName: activeDeviceName ?? this.activeDeviceName,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      eqBands: eqBands ?? this.eqBands,
      jamSessionActive: jamSessionActive ?? this.jamSessionActive,
      jamCode: jamCode ?? this.jamCode,
      jamParticipants: jamParticipants ?? this.jamParticipants,
    );
  }
}

class AudioEngineSettingsController
    extends StateNotifier<AudioEngineSettingsState> {
  AudioEngineSettingsController() : super(const AudioEngineSettingsState());

  void setUserProfile({required String name, String? bio}) {
    state = state.copyWith(
      userDisplayName: name.trim(),
      userBio: bio?.trim(),
    );
  }

  void clearUserProfile() {
    state = state.copyWith(clearUser: true);
  }

  void setQuality(String quality) => state = state.copyWith(audioQuality: quality);

  void toggleGapless(bool val) => state = state.copyWith(gaplessPlayback: val);

  void setCrossfade(double seconds) =>
      state = state.copyWith(crossfadeSeconds: seconds);

  void toggleAutomix(bool val) => state = state.copyWith(automix: val);

  void toggleNormalization(bool val) =>
      state = state.copyWith(volumeNormalization: val);

  void toggleDataSaver(bool val) => state = state.copyWith(dataSaver: val);

  void togglePrivateSession(bool val) =>
      state = state.copyWith(privateSession: val);

  void toggleFriendActivity(bool val) =>
      state = state.copyWith(showFriendActivity: val);

  void toggleExplicitContent(bool val) =>
      state = state.copyWith(explicitContentAllowed: val);

  void toggleExcludeTaste(bool val) =>
      state = state.copyWith(excludeFromTasteProfile: val);

  void selectDevice(String deviceName) =>
      state = state.copyWith(activeDeviceName: deviceName);

  void selectEqPreset(String preset) {
    final bands = switch (preset) {
      'Flat' => [0.0, 0.0, 0.0, 0.0, 0.0],
      'Bass Boost' => [5.0, 3.5, 0.0, 0.5, 1.0],
      'Vocal & Podcast' => [-1.0, 1.0, 4.0, 3.5, 1.0],
      'Acoustic' => [2.0, 1.5, 1.0, 3.0, 2.5],
      _ => [2.5, 1.5, 0.5, 2.0, 3.5],
    };
    state = state.copyWith(equalizerPreset: preset, eqBands: bands);
  }

  void updateEqBand(int index, double gainDb) {
    final updated = List<double>.from(state.eqBands);
    updated[index] = gainDb;
    state = state.copyWith(equalizerPreset: 'Custom', eqBands: updated);
  }

  void toggleJamSession() {
    state = state.copyWith(jamSessionActive: !state.jamSessionActive);
  }
}

final audioEngineProvider = StateNotifierProvider<AudioEngineSettingsController,
    AudioEngineSettingsState>((ref) {
  return AudioEngineSettingsController();
});

class LibraryState {
  final List<TrackModel> likedTracks;
  final List<TrackModel> recentTracks;
  final List<TrackModel> offlineDownloadedTracks;
  final List<TrackModel> localFolderTracks;
  final List<UserPlaylistModel> playlists;
  final LibrarySortMode sortMode;
  final String activeCategoryChip;

  const LibraryState({
    this.likedTracks = const [],
    this.recentTracks = const [],
    this.offlineDownloadedTracks = const [],
    this.localFolderTracks = const [],
    this.playlists = const [
      UserPlaylistModel(
        id: 'pl_lofi_senja',
        name: 'Lofi Senja & Hujan Tropis',
        description: 'Kurasi fokus kerja malam dalam format Lossless FLAC 24-bit.',
        isPinned: true,
        isOfflineSynced: true,
      ),
      UserPlaylistModel(
        id: 'pl_discover_weekly',
        name: 'Discover Weekly',
        description: 'Rekomendasi personal mingguan tanpa batas dan bebas iklan.',
        isPinned: true,
      ),
    ],
    this.sortMode = LibrarySortMode.recentPlayed,
    this.activeCategoryChip = 'Semua',
  });

  bool isLiked(String videoId) {
    return likedTracks.any((t) => t.videoId == videoId);
  }

  bool isDownloaded(String videoId) {
    return offlineDownloadedTracks.any((t) => t.videoId == videoId);
  }

  double get estimatedOfflineStorageMb {
    return (offlineDownloadedTracks.length * 34.5) +
        (playlists.where((p) => p.isOfflineSynced).length * 128.0);
  }

  LibraryState copyWith({
    List<TrackModel>? likedTracks,
    List<TrackModel>? recentTracks,
    List<TrackModel>? offlineDownloadedTracks,
    List<TrackModel>? localFolderTracks,
    List<UserPlaylistModel>? playlists,
    LibrarySortMode? sortMode,
    String? activeCategoryChip,
  }) {
    return LibraryState(
      likedTracks: likedTracks ?? this.likedTracks,
      recentTracks: recentTracks ?? this.recentTracks,
      offlineDownloadedTracks:
          offlineDownloadedTracks ?? this.offlineDownloadedTracks,
      localFolderTracks: localFolderTracks ?? this.localFolderTracks,
      playlists: playlists ?? this.playlists,
      sortMode: sortMode ?? this.sortMode,
      activeCategoryChip: activeCategoryChip ?? this.activeCategoryChip,
    );
  }
}

class LibraryController extends StateNotifier<LibraryState> {
  LibraryController() : super(const LibraryState());

  void toggleLike(TrackModel track) {
    final exists = state.isLiked(track.videoId);
    if (exists) {
      state = state.copyWith(
        likedTracks: state.likedTracks
            .where((t) => t.videoId != track.videoId)
            .toList(),
      );
    } else {
      state = state.copyWith(
        likedTracks: [track, ...state.likedTracks],
      );
    }
  }

  void toggleOfflineDownload(TrackModel track) {
    final exists = state.isDownloaded(track.videoId);
    if (exists) {
      state = state.copyWith(
        offlineDownloadedTracks: state.offlineDownloadedTracks
            .where((t) => t.videoId != track.videoId)
            .toList(),
      );
    } else {
      state = state.copyWith(
        offlineDownloadedTracks: [track, ...state.offlineDownloadedTracks],
      );
    }
  }

  void recordRecent(TrackModel track) {
    final filtered = state.recentTracks
        .where((t) => t.videoId != track.videoId)
        .toList();
    state = state.copyWith(
      recentTracks: [track, ...filtered].take(30).toList(),
    );
  }

  void setCategoryChip(String chip) {
    state = state.copyWith(activeCategoryChip: chip);
  }

  void setSortMode(LibrarySortMode mode) {
    state = state.copyWith(sortMode: mode);
  }

  void createPlaylist({
    required String name,
    required String description,
    bool isCollaborative = false,
    bool isPublic = true,
    List<TrackModel> tracks = const [],
  }) {
    final newPl = UserPlaylistModel(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      isCollaborative: isCollaborative,
      isPublic: isPublic,
      isOfflineSynced: true,
      tracks: tracks,
    );
    state = state.copyWith(playlists: [newPl, ...state.playlists]);
  }

  void addPlaylistModel(UserPlaylistModel playlist) {
    state = state.copyWith(playlists: [playlist, ...state.playlists]);
  }

  void createBlendWithFriend(String friendName, List<TrackModel> seedTracks) {
    final score = 88 + (friendName.length % 11);
    final blendPl = UserPlaylistModel(
      id: 'blend_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Blend Musik: $friendName',
      description:
          'Playlist gabungan otomatis dengan kecocokan selera $score% (Bebas Iklan & Lossless).',
      isCollaborative: true,
      isPinned: true,
      blendMatchScore: score,
      tracks: seedTracks,
    );
    state = state.copyWith(playlists: [blendPl, ...state.playlists]);
  }

  void togglePinPlaylist(String playlistId) {
    state = state.copyWith(
      playlists: [
        for (final pl in state.playlists)
          if (pl.id == playlistId)
            pl.copyWith(isPinned: !pl.isPinned)
          else
            pl,
      ],
    );
  }

  void deletePlaylist(String playlistId) {
    state = state.copyWith(
      playlists: state.playlists.where((p) => p.id != playlistId).toList(),
    );
  }

  void indexSampleLocalFolder(List<TrackModel> seedTracks) {
    final localItems = seedTracks.take(4).map((t) {
      return TrackModel(
        videoId: t.videoId,
        title: '${t.title} (Local Master.flac)',
        artists: t.artists,
        album: t.album,
        duration: t.duration,
        durationSeconds: t.durationSeconds,
        thumbnails: t.thumbnails,
        category: 'local',
        audioQualityBadge: 'FLAC 24-bit Local',
      );
    }).toList();
    state = state.copyWith(localFolderTracks: localItems);
  }
}

final libraryProvider =
    StateNotifierProvider<LibraryController, LibraryState>((ref) {
  return LibraryController();
});

class PlayerViewState {
  final TrackModel? currentTrack;
  final SongDetailModel? songDetail;
  final List<TrackModel> queue;
  final int currentIndex;
  final bool isLoadingTrack;
  final bool isPlaying;
  final ShuffleMode shuffleMode;
  final LoopMode loopMode;
  final PlaybackMode mode;
  final double playbackSpeed;
  final int? sleepTimerRemainingSeconds;
  final bool sleepStopAtEndOfTrack;
  final String? aiDjBanner;
  final Duration position;
  final Duration duration;
  final String? errorMessage;
  final bool isFullscreenOpen;

  const PlayerViewState({
    this.currentTrack,
    this.songDetail,
    this.queue = const [],
    this.currentIndex = 0,
    this.isLoadingTrack = false,
    this.isPlaying = false,
    this.shuffleMode = ShuffleMode.off,
    this.loopMode = LoopMode.off,
    this.mode = PlaybackMode.song,
    this.playbackSpeed = 1.0,
    this.sleepTimerRemainingSeconds,
    this.sleepStopAtEndOfTrack = false,
    this.aiDjBanner,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.errorMessage,
    this.isFullscreenOpen = false,
  });

  bool get isSleepTimerActive =>
      sleepStopAtEndOfTrack ||
      (sleepTimerRemainingSeconds != null && sleepTimerRemainingSeconds! > 0);

  String? get formattedSleepTimer {
    if (sleepStopAtEndOfTrack) return 'Akhir Lagu';
    final rem = sleepTimerRemainingSeconds;
    if (rem == null || rem <= 0) return null;
    final mins = (rem ~/ 60).toString().padLeft(2, '0');
    final secs = (rem % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  double get progressFraction {
    final totalMs = duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  PlayerViewState copyWith({
    TrackModel? currentTrack,
    SongDetailModel? songDetail,
    bool clearSongDetail = false,
    List<TrackModel>? queue,
    int? currentIndex,
    bool? isLoadingTrack,
    bool? isPlaying,
    ShuffleMode? shuffleMode,
    LoopMode? loopMode,
    PlaybackMode? mode,
    double? playbackSpeed,
    int? sleepTimerRemainingSeconds,
    bool clearSleepTimer = false,
    bool? sleepStopAtEndOfTrack,
    String? aiDjBanner,
    bool clearAiDjBanner = false,
    Duration? position,
    Duration? duration,
    String? errorMessage,
    bool clearError = false,
    bool? isFullscreenOpen,
  }) {
    return PlayerViewState(
      currentTrack: currentTrack ?? this.currentTrack,
      songDetail: clearSongDetail ? null : (songDetail ?? this.songDetail),
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoadingTrack: isLoadingTrack ?? this.isLoadingTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      shuffleMode: shuffleMode ?? this.shuffleMode,
      loopMode: loopMode ?? this.loopMode,
      mode: mode ?? this.mode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      sleepTimerRemainingSeconds: clearSleepTimer
          ? null
          : (sleepTimerRemainingSeconds ?? this.sleepTimerRemainingSeconds),
      sleepStopAtEndOfTrack: clearSleepTimer
          ? false
          : (sleepStopAtEndOfTrack ?? this.sleepStopAtEndOfTrack),
      aiDjBanner: clearAiDjBanner ? null : (aiDjBanner ?? this.aiDjBanner),
      position: position ?? this.position,
      duration: duration ?? this.duration,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isFullscreenOpen: isFullscreenOpen ?? this.isFullscreenOpen,
    );
  }
}

class PlayerController extends StateNotifier<PlayerViewState> {
  final OmniXApiService _api;
  final OmniXAudioHandler _audioHandler;
  final LibraryController _library;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _sleepTimer;

  PlayerController({
    required OmniXApiService api,
    required OmniXAudioHandler audioHandler,
    required LibraryController library,
  })  : _api = api,
        _audioHandler = audioHandler,
        _library = library,
        super(const PlayerViewState()) {
    _bindStreams();
  }

  String get backendBaseUrl => _api.baseUrl;

  void _bindStreams() {
    final player = _audioHandler.player;
    _subscriptions.add(
      player.playingStream.listen((playing) {
        state = state.copyWith(isPlaying: playing);
      }),
    );
    _subscriptions.add(
      player.positionStream.listen((pos) {
        state = state.copyWith(position: pos);
      }),
    );
    _subscriptions.add(
      player.durationStream.listen((dur) {
        if (dur != null) {
          state = state.copyWith(duration: dur);
        }
      }),
    );
    _subscriptions.add(
      player.playerStateStream.listen((ps) {
        if (ps.processingState == ProcessingState.completed) {
          if (state.sleepStopAtEndOfTrack) {
            _audioHandler.pause();
            state = state.copyWith(clearSleepTimer: true, isPlaying: false);
          } else {
            skipNext();
          }
        }
      }),
    );
  }

  Future<void> selectTrack(
    TrackModel track, {
    List<TrackModel>? customQueue,
    bool openFullscreen = false,
    String? djCommentary,
  }) async {
    _library.recordRecent(track);

    final initialQueue = customQueue ?? [track];
    final idx = initialQueue.indexWhere((t) => t.videoId == track.videoId);

    state = state.copyWith(
      currentTrack: track,
      clearSongDetail: true,
      queue: initialQueue,
      currentIndex: idx >= 0 ? idx : 0,
      isLoadingTrack: true,
      clearError: true,
      aiDjBanner: djCommentary,
      clearAiDjBanner: djCommentary == null,
      position: Duration.zero,
      duration: track.durationSeconds != null
          ? Duration(seconds: track.durationSeconds!)
          : Duration.zero,
      isFullscreenOpen: openFullscreen ? true : state.isFullscreenOpen,
    );

    try {
      final detail = await _api.getSongDetail(track.videoId);
      final updatedQueue = customQueue != null
          ? initialQueue
          : [track, ...detail.relatedTracks];

      state = state.copyWith(
        songDetail: detail,
        queue: updatedQueue,
        duration: detail.lengthSeconds > 0
            ? Duration(seconds: detail.lengthSeconds)
            : state.duration,
        isLoadingTrack: false,
      );

      // Ekstraksi stream di HP (IP pengguna tidak diblokir YouTube);
      // URL dari backend dipakai sebagai fallback kalau ekstraksi gagal.
      String? streamUrl = detail.audioStreamUrl;
      final localUrl = await StreamExtractor.extractAudioUrl(track.videoId);
      if (localUrl != null && localUrl.isNotEmpty) {
        streamUrl = localUrl;
      }
      if (streamUrl != null && streamUrl.isNotEmpty) {
        await _audioHandler.loadAndPlay(
          track: track,
          streamUrl: streamUrl,
        );
      } else {
        state = state.copyWith(
          errorMessage: 'Stream audio langsung tidak tersedia untuk lagu ini.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingTrack: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> startAiDj({String mood = 'Lofi Fokus & Energi Malam'}) async {
    state = state.copyWith(isLoadingTrack: true, clearError: true);
    try {
      final (greeting, commentary, tracks) =
          await _api.getAiDjSession(mood: mood);
      if (tracks.isEmpty) {
        state = state.copyWith(
          isLoadingTrack: false,
          errorMessage: 'AI DJ belum menemukan lagu untuk suasana "$mood".',
        );
        return;
      }
      await selectTrack(
        tracks.first,
        customQueue: tracks,
        openFullscreen: true,
        djCommentary: '$greeting $commentary',
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTrack: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> startSongRadio(String videoId) async {
    state = state.copyWith(isLoadingTrack: true, clearError: true);
    try {
      final radioTracks = await _api.getRadio(videoId);
      if (radioTracks.isNotEmpty) {
        await selectTrack(
          radioTracks.first,
          customQueue: radioTracks,
          openFullscreen: true,
          djCommentary:
              'Stasiun Radio Tanpa Akhir aktif (Gratis & Bebas Skip Tanpa Batas).',
        );
      } else {
        state = state.copyWith(isLoadingTrack: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoadingTrack: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> togglePlayPause() async {
    if (state.currentTrack == null) return;
    if (state.isPlaying) {
      await _audioHandler.pause();
    } else {
      await _audioHandler.play();
    }
  }

  Future<void> seekTo(Duration target) async {
    final maxSec = state.duration.inSeconds;
    final clamped = maxSec > 0
        ? Duration(seconds: target.inSeconds.clamp(0, maxSec))
        : target;
    state = state.copyWith(position: clamped);
    await _audioHandler.seek(clamped);
  }

  Future<void> jumpRelativeSeconds(int deltaSeconds) async {
    final target = Duration(seconds: state.position.inSeconds + deltaSeconds);
    await seekTo(target);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    state = state.copyWith(playbackSpeed: speed);
    await _audioHandler.setSpeed(speed);
  }

  void setSleepTimer(int? minutes, {bool stopAtEndOfTrack = false}) {
    _sleepTimer?.cancel();
    if (stopAtEndOfTrack) {
      state = state.copyWith(
        clearSleepTimer: true,
      );
      state = state.copyWith(sleepStopAtEndOfTrack: true);
      return;
    }
    if (minutes == null || minutes <= 0) {
      state = state.copyWith(clearSleepTimer: true);
      return;
    }

    final totalSeconds = minutes * 60;
    state = state.copyWith(
      sleepTimerRemainingSeconds: totalSeconds,
      sleepStopAtEndOfTrack: false,
    );

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentRem = state.sleepTimerRemainingSeconds ?? 0;
      if (currentRem <= 1) {
        timer.cancel();
        _audioHandler.pause();
        state = state.copyWith(clearSleepTimer: true, isPlaying: false);
      } else {
        state = state.copyWith(sleepTimerRemainingSeconds: currentRem - 1);
      }
    });
  }

  Future<void> skipNext() async {
    if (state.queue.isEmpty) return;
    final nextIndex = state.currentIndex + 1;
    if (nextIndex < state.queue.length) {
      await selectTrack(
        state.queue[nextIndex],
        customQueue: state.queue,
        djCommentary: state.aiDjBanner,
      );
    } else if (state.loopMode == LoopMode.all) {
      await selectTrack(
        state.queue.first,
        customQueue: state.queue,
        djCommentary: state.aiDjBanner,
      );
    }
  }

  Future<void> skipPrevious() async {
    if (state.position.inSeconds > 4) {
      await seekTo(Duration.zero);
      return;
    }
    if (state.queue.isEmpty) return;
    final prevIndex = state.currentIndex - 1;
    if (prevIndex >= 0) {
      await selectTrack(
        state.queue[prevIndex],
        customQueue: state.queue,
        djCommentary: state.aiDjBanner,
      );
    }
  }

  void setPlaybackMode(PlaybackMode newMode) {
    if (state.mode == newMode) return;
    state = state.copyWith(mode: newMode);
  }

  void cycleShuffleMode() {
    final next = switch (state.shuffleMode) {
      ShuffleMode.off => ShuffleMode.normal,
      ShuffleMode.normal => ShuffleMode.smart,
      ShuffleMode.smart => ShuffleMode.off,
    };

    var updatedQueue = List<TrackModel>.from(state.queue);
    if (next == ShuffleMode.smart && state.songDetail != null) {
      for (final rel in state.songDetail!.relatedTracks) {
        if (!updatedQueue.any((t) => t.videoId == rel.videoId)) {
          updatedQueue.add(rel);
        }
      }
    }
    state = state.copyWith(shuffleMode: next, queue: updatedQueue);
  }

  void reorderQueue(int oldIndex, int newIndex) {
    final updated = List<TrackModel>.from(state.queue);
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final moved = updated.removeAt(oldIndex);
    updated.insert(newIndex, moved);
    final activeId = state.currentTrack?.videoId;
    final newCurrentIndex = activeId != null
        ? updated.indexWhere((t) => t.videoId == activeId)
        : 0;
    state = state.copyWith(
      queue: updated,
      currentIndex: newCurrentIndex >= 0 ? newCurrentIndex : 0,
    );
  }

  void removeFromQueue(String videoId) {
    final updated = state.queue.where((t) => t.videoId != videoId).toList();
    state = state.copyWith(queue: updated);
  }

  Future<void> addToQueue(TrackModel track) async {
    if (state.currentTrack == null) {
      await selectTrack(track, customQueue: [track]);
      return;
    }
    state = state.copyWith(queue: [...state.queue, track]);
  }

  Future<void> playNextInQueue(TrackModel track) async {
    if (state.currentTrack == null) {
      await selectTrack(track, customQueue: [track]);
      return;
    }
    final updated = List<TrackModel>.from(state.queue);
    final insertIndex = (state.currentIndex + 1).clamp(0, updated.length);
    updated.insert(insertIndex, track);
    state = state.copyWith(queue: updated);
  }

  void clearUpcomingQueue() {
    if (state.currentTrack == null) {
      state = state.copyWith(queue: const [], currentIndex: 0);
      return;
    }
    state = state.copyWith(
      queue: [state.currentTrack!],
      currentIndex: 0,
    );
  }

  void cycleLoopMode() {
    final next = switch (state.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    _audioHandler.player.setLoopMode(next);
    state = state.copyWith(loopMode: next);
  }

  void openFullscreen() {
    if (state.currentTrack == null) return;
    state = state.copyWith(isFullscreenOpen: true);
  }

  void closeFullscreen() {
    state = state.copyWith(isFullscreenOpen: false);
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}

final playerControllerProvider =
    StateNotifierProvider<PlayerController, PlayerViewState>((ref) {
  final api = ref.watch(apiServiceProvider);
  final audioHandler = ref.watch(audioHandlerProvider);
  final library = ref.watch(libraryProvider.notifier);
  return PlayerController(
    api: api,
    audioHandler: audioHandler,
    library: library,
  );
});
