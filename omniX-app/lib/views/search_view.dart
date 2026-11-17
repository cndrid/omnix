import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track_model.dart';
import '../providers/app_providers.dart';
import '../theme/omnix_theme.dart';
import 'widgets/liquid_glass_box.dart';
import 'widgets/track_tile.dart';

class SearchView extends ConsumerStatefulWidget {
  final double bottomSafePadding;

  const SearchView({
    super.key,
    required this.bottomSafePadding,
  });

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  late final TextEditingController _textController;
  Timer? _debounce;

  static const List<(String, String)> _filters = [
    ('all', 'Semua'),
    ('songs', 'Lagu'),
    ('artists', 'Artis'),
    ('playlists', 'Playlist'),
  ];

  static const List<(String, String, Color)> _genreCards = [
    ('Pop Indonesia', 'Lagu Pop Indonesia Terbaru', Color(0xFF6340F5)),
    ('Lo-Fi & Fokus Kerja', 'lofi chill beats focus', Color(0xFF1F6E58)),
    ('Indie Senja Akustik', 'Indie Indonesia Senja', Color(0xFF8E3B46)),
    ('Hip-Hop & R&B', 'hip hop rnb hits', Color(0xFF5A2A82)),
    ('Live Session', 'live session concert indonesia', Color(0xFF1E555C)),
  ];

  List<TrackModel>? _playlistTracks;
  String? _playlistTitle;
  bool _playlistLoading = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: ref.read(searchQueryProvider),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _playlistTitle = null;
          _playlistTracks = null;
        });
        ref.read(searchQueryProvider.notifier).state = value;
      }
    });
  }

  void _submitImmediate(String value) {
    _debounce?.cancel();
    _textController.text = value;
    setState(() {
      _playlistTitle = null;
      _playlistTracks = null;
    });
    ref.read(searchQueryProvider.notifier).state = value;
  }

  Future<void> _openPlaylist(TrackModel playlist) async {
    setState(() {
      _playlistTitle = playlist.title;
      _playlistTracks = null;
      _playlistLoading = true;
    });
    try {
      final tracks = await ref
          .read(apiServiceProvider)
          .getPlaylistVideos(playlist.videoId);
      if (mounted) {
        setState(() {
          _playlistTracks = tracks;
          _playlistLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _playlistTracks = const [];
          _playlistLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final activeFilter = ref.watch(searchFilterProvider);
    final resultsAsync = ref.watch(searchResultsProvider);
    final exploreAsync = ref.watch(exploreDataProvider);
    final playerState = ref.watch(playerControllerProvider);
    final libraryState = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile =
        MediaQuery.sizeOf(context).width < OmniXTokens.breakpointTablet;
    final viewInsetsBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        isMobile ? 16 : 24,
        isMobile ? 16 : 28,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cari',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Semantics(
            textField: true,
            label: 'Cari lagu, artis, atau playlist',
            child: TextField(
              controller: _textController,
              onChanged: _onQueryChanged,
              onSubmitted: _submitImmediate,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Lagu, artis, atau playlist...',
                hintText: 'Ketik kata kunci atau pilih tag populer di bawah',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        tooltip: 'Bersihkan pencarian',
                        onPressed: () => _submitImmediate(''),
                        icon: const Icon(Icons.clear),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (value, label) in _filters) ...[
                  _FilterPillButton(
                    label: label,
                    selected: activeFilter == value,
                    onTap: () {
                      ref.read(searchFilterProvider.notifier).state = value;
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: query.trim().isEmpty
                ? _buildDiscoveryBrowse(
                    context,
                    exploreAsync.valueOrNull,
                    playerState,
                    libraryState,
                    widget.bottomSafePadding + viewInsetsBottom,
                  )
                : _playlistTitle != null
                    ? _buildPlaylistTracks(
                        context,
                        playerState,
                        libraryState,
                        viewInsetsBottom,
                      )
                    : resultsAsync.when(
                    loading: () => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: scheme.primary),
                          const SizedBox(height: 14),
                          Text(
                            'Mencari "$query" di katalog OmniX...',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                    error: (err, _) => Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: LiquidGlassBox(
                          tier: GlassTier.glass2,
                          borderRadius: OmniXTokens.radiusCard,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pencarian Gagal Dimuat',
                                style: theme.textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                err.toString(),
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () =>
                                    ref.invalidate(searchResultsProvider),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Coba Cari Lagi'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    data: (tracks) {
                      if (tracks.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 48,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ditemukan hasil untuk "$query".',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Periksa kata kunci atau ubah filter pencarian ke Semua.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: EdgeInsets.only(
                          bottom: widget.bottomSafePadding + viewInsetsBottom,
                        ),
                        itemCount: tracks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          final isPseudo = track.resultType == 'artist' ||
                              track.resultType == 'playlist';
                          return TrackTile(
                            track: track,
                            isActive:
                                playerState.currentTrack?.videoId == track.videoId,
                            isPlaying: playerState.isPlaying &&
                                playerState.currentTrack?.videoId == track.videoId,
                            isLiked: libraryState.isLiked(track.videoId),
                            isDownloaded:
                                libraryState.isDownloaded(track.videoId),
                            showActions: !isPseudo,
                            onPlay: () {
                              if (track.resultType == 'artist') {
                                _submitImmediate(track.title);
                                return;
                              }
                              if (track.resultType == 'playlist') {
                                _openPlaylist(track);
                                return;
                              }
                              ref
                                  .read(playerControllerProvider.notifier)
                                  .selectTrack(track, customQueue: tracks);
                            },
                            onToggleLike: isPseudo
                                ? null
                                : () {
                                    ref
                                        .read(libraryProvider.notifier)
                                        .toggleLike(track);
                                  },
                            onToggleDownload: isPseudo
                                ? null
                                : () {
                                    ref
                                        .read(libraryProvider.notifier)
                                        .toggleOfflineDownload(track);
                                  },
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistTracks(
    BuildContext context,
    PlayerViewState playerState,
    LibraryState libraryState,
    double viewInsetsBottom,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_playlistLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 14),
            Text(
              'Memuat isi playlist…',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    final tracks = _playlistTracks ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Kembali ke hasil pencarian',
              onPressed: () => setState(() {
                _playlistTitle = null;
                _playlistTracks = null;
              }),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                _playlistTitle ?? 'Playlist',
                style: theme.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: tracks.isEmpty
              ? Center(
                  child: Text(
                    'Playlist ini kosong.',
                    style: theme.textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(
                    bottom: widget.bottomSafePadding + viewInsetsBottom,
                  ),
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    return TrackTile(
                      track: track,
                      isActive:
                          playerState.currentTrack?.videoId == track.videoId,
                      isPlaying: playerState.isPlaying &&
                          playerState.currentTrack?.videoId == track.videoId,
                      isLiked: libraryState.isLiked(track.videoId),
                      isDownloaded:
                          libraryState.isDownloaded(track.videoId),
                      onPlay: () {
                        ref
                            .read(playerControllerProvider.notifier)
                            .selectTrack(track, customQueue: tracks);
                      },
                      onToggleLike: () {
                        ref.read(libraryProvider.notifier).toggleLike(track);
                      },
                      onToggleDownload: () {
                        ref
                            .read(libraryProvider.notifier)
                            .toggleOfflineDownload(track);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDiscoveryBrowse(
    BuildContext context,
    ExploreDataModel? exploreData,
    PlayerViewState playerState,
    LibraryState libraryState,
    double bottomPad,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tags = exploreData?.trendingTags ??
        const [
          '#PopIndo',
          '#LoFiSenja',
          '#IndieAkustik',
          '#DangdutKoplo',
          '#LaguGalau',
        ];
    final ranked = exploreData?.rankedSearches ?? const [];

    return ListView(
      padding: EdgeInsets.only(bottom: bottomPad),
      children: [
        Text('Tag Pencarian Populer', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tags)
              InkWell(
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
                onTap: () => _submitImmediate(tag.replaceAll('#', '')),
                child: LiquidGlassBox(
                  tier: GlassTier.glass3,
                  borderRadius: OmniXTokens.radiusPill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    tag,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (ranked.isNotEmpty) ...[
          Text(
            'Tangga Lagu Pencarian Teratas (01 sampai 05)',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < ranked.length; i++) ...[
            TrackTile(
              track: ranked[i],
              rankNumber: (i + 1).toString().padLeft(2, '0'),
              isActive: playerState.currentTrack?.videoId == ranked[i].videoId,
              isPlaying: playerState.isPlaying &&
                  playerState.currentTrack?.videoId == ranked[i].videoId,
              isLiked: libraryState.isLiked(ranked[i].videoId),
              isDownloaded: libraryState.isDownloaded(ranked[i].videoId),
              onPlay: () {
                ref
                    .read(playerControllerProvider.notifier)
                    .selectTrack(ranked[i], customQueue: ranked);
              },
              onToggleLike: () {
                ref.read(libraryProvider.notifier).toggleLike(ranked[i]);
              },
              onToggleDownload: () {
                ref
                    .read(libraryProvider.notifier)
                    .toggleOfflineDownload(ranked[i]);
              },
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
        ],
        const SizedBox(height: 24),
        Text(
          'Jelajah Genre & Mood',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cols = constraints.maxWidth >= 720 ? 4 : 2;
            final spacing = 12.0;
            final cardWidth =
                (constraints.maxWidth - (spacing * (cols - 1))) / cols;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final (title, queryText, color) in _genreCards)
                  SizedBox(
                    width: cardWidth,
                    height: 92,
                    child: InkWell(
                      mouseCursor: SystemMouseCursors.click,
                      borderRadius:
                          BorderRadius.circular(OmniXTokens.radiusCard),
                      onTap: () => _submitImmediate(queryText),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius:
                              BorderRadius.circular(OmniXTokens.radiusCard),
                        ),
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _FilterPillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPillButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
      onTap: onTap,
      child: LiquidGlassBox(
        tier: GlassTier.glass3,
        borderRadius: OmniXTokens.radiusPill,
        tintColor: selected ? scheme.primary : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? scheme.onPrimary : scheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
