import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../data/liked_songs_repository.dart';
import '../data/play_history_repository.dart';
import '../models/track_model.dart';
import '../services/api_service.dart';
import '../services/audio_handler_service.dart';
import '../services/skip_service.dart';
import '../services/stream_extractor.dart';
import 'data_providers.dart';

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

// Instance handler dibuat di main.dart (Media3Bridge.init) dan
// disuntikkan lewat ProviderScope override, supaya handler yang dipakai
// UI sama dengan yang terdaftar di media session. Buat instance baru
// di sini hanya kalau aplikasi dijalankan tanpa melewati main.dart.
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
    this.audioQuality = 'Standar',
    this.gaplessPlayback = true,
    this.crossfadeSeconds = 4.0,
    this.automix = true,
    this.volumeNormalization = true,
    this.dataSaver = false,
    this.privateSession = false,
    this.showFriendActivity = true,
    this.explicitContentAllowed = true,
    this.excludeFromTasteProfile = false,
    this.activeDeviceName = 'Perangkat ini',
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
  final List<UserPlaylistModel> playlists;
  final LibrarySortMode sortMode;
  final String activeCategoryChip;

  const LibraryState({
    this.likedTracks = const [],
    this.recentTracks = const [],
    this.offlineDownloadedTracks = const [],
    this.playlists = const [],
    this.sortMode = LibrarySortMode.recentPlayed,
    this.activeCategoryChip = 'Semua',
  });

  bool isLiked(String videoId) {
    // Guard (24 Nov 2026): videoId kosong bukan kunci like yang valid —
    // semua lagu Spotify yang belum ter-resolve berbagi '', jadi tanpa
    // ini satu baris '' membuat SEMUA lagu yang belum ter-resolve
    // terlihat disukai.
    if (videoId.isEmpty) return false;
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
    List<UserPlaylistModel>? playlists,
    LibrarySortMode? sortMode,
    String? activeCategoryChip,
  }) {
    return LibraryState(
      likedTracks: likedTracks ?? this.likedTracks,
      recentTracks: recentTracks ?? this.recentTracks,
      offlineDownloadedTracks:
          offlineDownloadedTracks ?? this.offlineDownloadedTracks,
      playlists: playlists ?? this.playlists,
      sortMode: sortMode ?? this.sortMode,
      activeCategoryChip: activeCategoryChip ?? this.activeCategoryChip,
    );
  }
}

class LibraryController extends StateNotifier<LibraryState> {
  /// Repository M0 (Worker B). Null bila lapisan data belum bisa dibuat
  /// (mis. Supabase belum di-init) — controller tetap jalan in-memory.
  final LikedSongsRepository? _likedSongsRepository;
  final PlayHistoryRepository? _playHistoryRepository;

  LibraryController({
    LikedSongsRepository? likedSongsRepository,
    PlayHistoryRepository? playHistoryRepository,
  })  : _likedSongsRepository = likedSongsRepository,
        _playHistoryRepository = playHistoryRepository,
        super(const LibraryState());

  void _applyLiked(TrackModel track, bool liked) {
    // Guard (24 Nov 2026): jangan pernah menyimpan baris like dengan
    // videoId kosong (lihat isLiked di atas).
    if (track.videoId.isEmpty) return;
    if (liked) {
      if (state.isLiked(track.videoId)) return;
      state = state.copyWith(
        likedTracks: [track, ...state.likedTracks],
      );
    } else {
      state = state.copyWith(
        likedTracks: state.likedTracks
            .where((t) => t.videoId != track.videoId)
            .toList(),
      );
    }
  }

  /// Toggle like (API kompatibel, kini async + delegasi ke repository).
  ///
  /// Arah toggle ditentukan dari repository bila ada (sumber kebenaran
  /// Drift/Supabase), kalau tidak dari state in-memory. State in-memory
  /// diubah optimistic dulu, lalu repository dipanggil (tamu: Drift saja;
  /// login: Supabase + Drift). Bila sinkron gagal
  /// ([SupabaseSyncException]/[ProfileMissingException]/lainnya), state
  /// in-memory dikembalikan dan `false` dikembalikan supaya pemanggil
  /// (LikeFlow) bisa toast + hati kembali ke state semula.
  Future<bool> toggleLike(TrackModel track) async {
    // Guard (24 Nov 2026): videoId kosong bukan kunci like yang valid.
    // Jalur normal sudah resolve dulu di LikeFlow; kalau sampai sini
    // masih kosong, tolak supaya tidak ada baris '' yang tersimpan.
    if (track.videoId.isEmpty) return false;
    final repo = _likedSongsRepository;
    bool currentlyLiked;
    if (repo != null) {
      try {
        currentlyLiked = await repo.isLiked(track.videoId);
      } catch (_) {
        currentlyLiked = state.isLiked(track.videoId);
      }
    } else {
      currentlyLiked = state.isLiked(track.videoId);
    }
    final targetLiked = !currentlyLiked;
    _applyLiked(track, targetLiked);
    if (repo != null) {
      try {
        await repo.toggleLike(track);
      } catch (_) {
        // Gagal simpan: kembalikan hati ke state semula.
        _applyLiked(track, currentlyLiked);
        return false;
      }
    }
    return true;
  }

  /// Sinkronisasi awal dari repository (dipanggil sekali saat Library
  /// dibuka / setelah login). Gagal dibiarkan diam — state in-memory
  /// tetap dipakai.
  Future<void> syncLikedTracksFromRepository() async {
    final repo = _likedSongsRepository;
    if (repo == null) return;
    try {
      final tracks = await repo.getLikedTracks();
      state = state.copyWith(likedTracks: tracks);
    } catch (_) {
      // Abaikan: tampilan memakai state in-memory yang ada.
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
    // Riwayat ke repository best-effort: kegagalan tidak boleh mengganggu
    // pemutaran (repository sendiri sudah best-effort untuk Supabase).
    final repo = _playHistoryRepository;
    if (repo != null) {
      unawaited(repo.recordPlay(track).catchError((_) {}));
    }
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
}

final libraryProvider =
    StateNotifierProvider<LibraryController, LibraryState>((ref) {
  // Repository disuntik bila lapisan data bisa dibuat; kalau Supabase
  // belum di-init (tugas koordinator di main.dart), controller tetap
  // jalan in-memory saja dan tidak melempar di sini.
  LikedSongsRepository? likedRepo;
  PlayHistoryRepository? historyRepo;
  try {
    likedRepo = ref.read(likedSongsRepositoryProvider);
  } catch (_) {
    likedRepo = null;
  }
  try {
    historyRepo = ref.read(playHistoryRepositoryProvider);
  } catch (_) {
    historyRepo = null;
  }
  return LibraryController(
    likedSongsRepository: likedRepo,
    playHistoryRepository: historyRepo,
  );
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

  /// Generasi selectTrack: naik tiap kali lagu baru dipilih. Dipakai
  /// supaya selectTrack lama (ekstraksi/detail yang masih jalan di
  /// background) tidak menimpa state milik lagu yang baru dipilih.
  int _selectGeneration = 0;

  /// Lagu yang selectTrack-nya sedang berjalan (ekstraksi/pemuatan).
  /// Ketukan ganda pada baris lagu yang sama (tile tetap bisa diketuk
  /// saat loading — tidak ada guard di TrackTile) tidak boleh membuat dua
  /// selectTrack bersamaan: keduanya berebut setAudioSource/player yang
  /// sama dan yang kalah menandai "gagal" padahal lagu sudah bunyi
  /// (bug 2). Ketukan kedua pada lagu yang sama saat masih dimuat
  /// diabaikan; selectTrack yang sedang jalan akan memutarnya.
  String? _selectingVideoId;

  void _clearSelecting(String videoId) {
    if (_selectingVideoId == videoId) _selectingVideoId = null;
  }

  PlayerController({
    required OmniXApiService api,
    required OmniXAudioHandler audioHandler,
    required LibraryController library,
  })  : _api = api,
        _audioHandler = audioHandler,
        _library = library,
        super(const PlayerViewState()) {
    _bindStreams();
    // Auto-recovery dari handler (18 Nov 2026): selama recovery, tombol
    // play nonaktif + spinner tampil (sama seperti saat lagu baru dimuat);
    // kartu error netral + tombol Coba Lagi baru muncul kalau 3x gagal.
    _audioHandler.onRecoveryStateChanged = (recovering) {
      state = state.copyWith(isLoadingTrack: recovering);
    };
    _audioHandler.onRecoveryFailed = (message) {
      state = state.copyWith(
        isLoadingTrack: false,
        errorMessage: message,
      );
    };
    // Tombol next/prev notifikasi / media session (24 Nov 2026): handler
    // tidak boleh import file ini, jadi controller mendaftarkan callback
    // ke handler (lihat onSkipNext/onSkipPrevious di handler).
    _audioHandler.onSkipNext = () => unawaited(skipNext());
    _audioHandler.onSkipPrevious = () => unawaited(skipPrevious());
    // Dorong antrean ke handler.queue setiap kali antrean berubah, supaya
    // media session / notifikasi melihat antrean yang benar (dan
    // queueIndex-nya benar). Tanpa ini queue handler selalu kosong.
    addListener((s) {
      unawaited(_audioHandler.setQueueItems(
        s.queue.map(OmniXAudioHandler.mediaItemForTrack).toList(),
        currentIndex: s.currentIndex,
      ));
    });
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
        // Bukti keras lagu benar-benar bunyi: posisi maju hanya kalau
        // platform sedang me-render audio. Kalau kartu error (dari
        // percobaan play yang kedaluwarsa) masih tampil saat posisi sudah
        // maju, error itu palsu — sembunyikan. Ini jaring pengaman bug 2
        // untuk kasus play() yatim yang baru menyampaikan perintah putar
        // ke platform SETELAH selectTrack menyatakan gagal.
        if (pos > Duration.zero &&
            state.errorMessage != null &&
            state.currentTrack != null) {
          state = state.copyWith(clearError: true);
        }
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
    // Ketukan ganda pada lagu yang sama saat masih dimuat: abaikan —
    // selectTrack yang sedang jalan akan memutarnya (lihat
    // _selectingVideoId). Guard ini dicek SEBELUM generation naik, supaya
    // ketukan kedua tidak ikut mengacaukan selectTrack pertama.
    // Kunci guard (24 Nov 2026): videoId kalau ada, kalau tidak spotifyId
    // — lagu Spotify yang belum ter-resolve SEMUANYA punya videoId '',
    // jadi guard videoId saja akan mengabaikan lagu kedua yang berbeda
    // DAN, setelah resolve, flag '' tidak pernah ter-clear (finally di
    // bawah memakai videoId hasil resolve, bukan '').
    final selectKey = track.videoId.isNotEmpty
        ? track.videoId
        : (track.spotifyId ?? '');
    if (_selectingVideoId == selectKey) return;
    _selectingVideoId = selectKey;
    // Resolusi lazy Spotify -> YouTube (24 Nov 2026): lagu dari katalog
    // belum punya videoId — cari video YouTube yang cocok dulu.
    if (track.videoId.isEmpty && track.spotifyId != null) {
      try {
        track = await _api.resolveTrackForPlayback(track);
      } catch (e) {
        state = state.copyWith(
          isLoadingTrack: false,
          errorMessage: e.toString(),
        );
        _clearSelecting(selectKey);
        return;
      }
    }
    // Stopwatch diagnosis (bug start lambat): berapa lama dari ketuk
    // sampai bunyi / gagal — supaya video berikutnya bisa dipastikan
    // bagiannya, bukan ditebak. Lihat debugPrint di bawah.
    final selectStopwatch = Stopwatch()..start();

    _library.recordRecent(track);
    final generation = ++_selectGeneration;

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

    // Fast start (18 Nov 2026, direvisi bug start lambat): jalur start
    // HANYA menunggu ekstraksi stream. Segmen sponsor (SponsorBlock,
    // timeout sampai 8 detik) TIDAK LAGI ikut di Future.wait — datanya
    // baru dipakai untuk lompat otomatis, jadi diambil menyusul setelah
    // lagu bunyi (lihat _attachSkipSegments). Sebelumnya fetch ini ikut
    // mengunci start sampai 8 detik walau stream sudah didapat.
    // Detail lagu (termasuk lirik LRCLIB + vote RYD) juga tetap paralel
    // dan tidak ditunggu sebelum putar. Detail dilampirkan menyusul lewat
    // _attachDetail.
    final detailFuture = _api.getSongDetail(track.videoId);

    try {
      final candidates =
          await StreamExtractor.extractAudioCandidates(track.videoId);
      debugPrint(
        '[OmniX-timing] extract ${track.videoId}: '
        '${selectStopwatch.elapsedMilliseconds} ms, '
        '${candidates.length} kandidat',
      );
      // Lagu lain sudah dipilih selama menunggu: serahkan state ke
      // selectTrack yang baru, jangan sentuh apa pun lagi.
      if (generation != _selectGeneration) return;
      final bestInfo = candidates.isEmpty ? null : candidates.first;

      // Coba kandidat satu per satu: kalau URL pertama gagal dimuat
      // (mis. format ditolak player), coba format berikutnya — bukan
      // langsung error. Tapi kalau yang gagal adalah `play()`-nya
      // (PlayStartException: audio focus ditolak / pemutar tidak
      // merespons), JANGAN lanjut ke kandidat berikut: itu kondisi
      // global pemutar, bukan URL-nya — tiap kandidat hanya mengulang
      // jeda timeout yang sama (±12 detik per kandidat).
      String? lastError;
      var played = false;
      for (final candidate in candidates) {
        if (generation != _selectGeneration) return;
        try {
          await _audioHandler.loadAndPlay(
            track: track,
            streamUrl: candidate.url,
          );
          played = true;
          break;
        } catch (e) {
          if (generation != _selectGeneration) return;
          lastError = e.toString();
          if (e is PlayStartException) break;
        }
      }
      if (generation != _selectGeneration) return;
      if (!played) {
        // Sebelum menampilkan kartu error, periksa kebenaran di
        // lapangan (bug 2): `play()` yang timeout TIDAK membatalkan
        // perintah putarnya — future yatim itu bisa tetap menyampaikan
        // play ke platform belakangan, jadi lagu bisa sudah bunyi walau
        // semua kandidat "gagal". Posisi yang sudah maju adalah bukti
        // keras audio me-render — kalau begitu, anggap berhasil dan
        // jangan tampilkan error palsu.
        if (_audioHandler.player.playing &&
            _audioHandler.player.position > Duration.zero) {
          state = state.copyWith(isLoadingTrack: false, clearError: true);
          debugPrint(
            '[OmniX-timing] selectTrack ${track.videoId}: error '
            'ditahan — posisi sudah ${_audioHandler.player.position}',
          );
          _prefetchNext();
          unawaited(_attachDetail(
            detailFuture,
            track,
            customQueue,
            generation,
            bestInfo,
          ));
          return;
        }
        debugPrint(
          '[OmniX-timing] selectTrack ${track.videoId}: gagal setelah '
          '${selectStopwatch.elapsedMilliseconds} ms: $lastError',
        );
        state = state.copyWith(
          isLoadingTrack: false,
          errorMessage: lastError ??
              'Stream audio langsung tidak tersedia untuk lagu ini.',
        );
        // Detail tetap dilampirkan menyusul (tidak menghalangi error).
        unawaited(_attachDetail(
          detailFuture,
          track,
          customQueue,
          generation,
          bestInfo,
        ));
        return;
      }

      // Perbaikan bug klik play 2x (18 Nov 2026, item A): isLoadingTrack
      // baru false DI SINI — setelah loadAndPlay berhasil — bukan setelah
      // getSongDetail. Selama ekstraksi + load, tombol play tetap nonaktif
      // sehingga ketukan play dini tidak bisa membuat flag playing basi.
      // clearError: percobaan sebelumnya (atau selectTrack lain yang
      // tumpang tindih) bisa saja sudah menandai error padahal lagu ini
      // akhirnya bunyi — kartu error tidak boleh bertahan di atas lagu
      // yang sedang jalan (bug 2).
      state = state.copyWith(isLoadingTrack: false, clearError: true);
      debugPrint(
        '[OmniX-timing] selectTrack ${track.videoId}: mulai bunyi '
        'setelah ${selectStopwatch.elapsedMilliseconds} ms',
      );
      // Segmen sponsor diambil menyusul (tidak mengunci start).
      unawaited(_attachSkipSegments(track.videoId, generation));
      // Prefetch lagu berikutnya di background supaya pencet next langsung
      // jalan (cache memori StreamExtractor sudah hangat).
      _prefetchNext();
      unawaited(_attachDetail(
        detailFuture,
        track,
        customQueue,
        generation,
        bestInfo,
      ));
    } catch (e) {
      // Jalur keluar darurat: kembalikan isLoadingTrack ke false + isi
      // error, supaya UI tidak macet di spinner tanpa pesan apa pun.
      if (generation != _selectGeneration) return;
      state = state.copyWith(
        isLoadingTrack: false,
        errorMessage: e.toString(),
      );
    } finally {
      // Lepas guard ketukan ganda. No-op kalau lagu lain sudah dipilih
      // (flag sudah milik selectTrack yang baru). Pakai selectKey (bukan
      // track.videoId hasil resolve) supaya flag ter-clear walau lagu
      // masuk sebagai Spotify yang belum ter-resolve.
      _clearSelecting(selectKey);
    }
  }

  /// Segmen sponsor (SponsorBlock) diambil MENYUSUL setelah lagu mulai
  /// bunyi — tidak mengunci start (bug start lambat: fetch ini dulu ikut
  /// di Future.wait dengan timeout 8 detik). Kalau pengguna sudah pindah
  /// lagu lain, hasilnya dibuang. Kalau fetch gagal, lagu tetap jalan
  /// tanpa lompat otomatis.
  Future<void> _attachSkipSegments(String videoId, int generation) async {
    List<SkipSegment> segments;
    try {
      segments = await _api.getSkipSegments(videoId);
    } catch (_) {
      return;
    }
    if (generation != _selectGeneration) return;
    if (state.currentTrack?.videoId != videoId) return;
    _audioHandler.updateSkipSegments(segments);
  }

  /// Detail lagu (judul lengkap, lirik, vote, lagu terkait) dilampirkan
  /// MENYUSUL setelah lagu mulai bunyi — tidak menghalangi putar (fast
  /// start, 18 Nov 2026). Kalau pengguna sudah pindah lagu lain, hasilnya
  /// dibuang. Kalau detail gagal, lagu yang sudah bunyi tetap jalan —
  /// tampilan memakai data dasar dari TrackModel.
  Future<void> _attachDetail(
    Future<SongDetailModel> detailFuture,
    TrackModel track,
    List<TrackModel>? customQueue,
    int generation,
    AudioCandidate? bestInfo,
  ) async {
    SongDetailModel detail;
    try {
      detail = await detailFuture;
    } catch (_) {
      return;
    }
    if (generation != _selectGeneration) return;
    if (state.currentTrack?.videoId != track.videoId) return;
    final enriched = bestInfo == null
        ? detail
        : detail.copyWith(
            audioMimeType: bestInfo.mimeType,
            audioBitrateKbps: bestInfo.bitrateKbps,
          );
    if (customQueue == null && detail.relatedTracks.isNotEmpty) {
      final updatedQueue = [
        track,
        ...detail.relatedTracks.where(
          (t) => t.videoId != track.videoId,
        ),
      ];
      state = state.copyWith(
        songDetail: enriched,
        queue: updatedQueue,
        duration: detail.lengthSeconds > 0
            ? Duration(seconds: detail.lengthSeconds)
            : state.duration,
      );
    } else {
      state = state.copyWith(
        songDetail: enriched,
        duration: detail.lengthSeconds > 0
            ? Duration(seconds: detail.lengthSeconds)
            : state.duration,
      );
    }
  }

  /// Prefetch lagu berikutnya (18 Nov 2026): saat lagu sekarang mulai
  /// diputar, resolve link lagu berikutnya di background supaya pencet
  /// next langsung jalan — hasilnya tersimpan di cache memori
  /// StreamExtractor (TTL ~6 jam), jadi selectTrack berikutnya tidak
  /// ekstraksi ulang. Gagal prefetch tidak apa-apa (diabaikan diam-diam);
  /// selectTrack berikutnya akan ekstraksi seperti biasa.
  void _prefetchNext() {
    if (state.queue.isEmpty) return;
    var nextIndex = state.currentIndex + 1;
    if (nextIndex >= state.queue.length) {
      // Antrean habis tapi mode ulang-semua: siapkan lagu pertama lagi.
      if (state.loopMode != LoopMode.all) return;
      nextIndex = 0;
    }
    final next = state.queue[nextIndex];
    if (next.videoId.isEmpty) return;
    if (next.videoId == state.currentTrack?.videoId) return;
    unawaited(
      StreamExtractor.extractAudioCandidates(next.videoId).catchError(
            (_) => <AudioCandidate>[],
          ),
    );
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
    // Jangan biarkan handler memanggil controller yang sudah di-dispose
    // (mis. recovery yang selesai belakangan).
    _audioHandler.onRecoveryStateChanged = null;
    _audioHandler.onRecoveryFailed = null;
    _audioHandler.onSkipNext = null;
    _audioHandler.onSkipPrevious = null;
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
