import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track_model.dart';
import '../providers/app_providers.dart';
import '../theme/omnix_theme.dart';
import 'widgets/liquid_glass_box.dart';
import 'widgets/queue_sheet.dart';
import 'widgets/track_artwork.dart';
import 'widgets/track_tile.dart';

class ExploreView extends ConsumerWidget {
  final double bottomSafePadding;

  const ExploreView({
    super.key,
    required this.bottomSafePadding,
  });

  static const List<String> _categories = [
    'Semua',
    'Musik',
  ];

  String _contextualGreeting(String? userName) {
    final hour = DateTime.now().hour;
    final String base;
    if (hour < 11) {
      base = 'Selamat Pagi';
    } else if (hour < 15) {
      base = 'Selamat Siang';
    } else if (hour < 19) {
      base = 'Selamat Sore';
    } else {
      base = 'Selamat Malam';
    }

    if (userName != null && userName.trim().isNotEmpty) {
      return '$base, ${userName.trim()}';
    }
    return base;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exploreAsync = ref.watch(exploreDataProvider);
    final activeCategory = ref.watch(homeCategoryFilterProvider);
    final playerState = ref.watch(playerControllerProvider);
    final libraryState = ref.watch(libraryProvider);
    final engineState = ref.watch(audioEngineProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < OmniXTokens.breakpointTablet;

    return exploreAsync.when(
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: scheme.primary),
              const SizedBox(height: 16),
              Text(
                'Menyiapkan Beranda…',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
      error: (err, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LiquidGlassBox(
              tier: GlassTier.glass2,
              borderRadius: OmniXTokens.radiusCard,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: scheme.error, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Gagal Memuat Beranda',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(err.toString(), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(exploreDataProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Muat Ulang Beranda'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          ref.read(activeTabProvider.notifier).state =
                              AppTab.cari;
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Buka Pencarian'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      data: (exploreData) {
        final allTracks = [
          for (final sec in exploreData.sections) ...sec.items,
        ];
        final quickRecents = libraryState.recentTracks.isNotEmpty
            ? libraryState.recentTracks.take(6).toList()
            : allTracks.take(6).toList();

        final filteredSections = exploreData.sections.where((sec) {
          if (activeCategory == 'Semua') return true;
          if (activeCategory == 'Musik') return sec.category == 'music';
          return true;
        }).toList();

        final displaySections = filteredSections.isNotEmpty
            ? filteredSections
            : exploreData.sections;

        final heroTrack = allTracks.isNotEmpty ? allTracks.first : null;

        return ListView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 28,
            isMobile ? 16 : 24,
            isMobile ? 16 : 28,
            bottomSafePadding,
          ),
          children: [
            _buildTopGreetingHeader(
              context,
              ref,
              theme,
              scheme,
              engineState,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final cat in _categories) ...[
                    _GlassCategoryChip(
                      label: cat,
                      selected: activeCategory == cat,
                      onTap: () {
                        ref.read(homeCategoryFilterProvider.notifier).state = cat;
                      },
                    ),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildAiQuickRow(
              context,
              ref,
              theme,
              scheme,
            ),
            const SizedBox(height: 24),
            if (quickRecents.isNotEmpty) ...[
              Text(
                'Baru diputar',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _QuickRecentsGrid(
                tracks: quickRecents,
                activeVideoId: playerState.currentTrack?.videoId,
                onTapTrack: (tr) {
                  ref
                      .read(playerControllerProvider.notifier)
                      .selectTrack(tr, customQueue: quickRecents);
                },
                onAddToQueue: (tr) {
                  ref.read(playerControllerProvider.notifier).addToQueue(tr);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Ditambahkan ke antrean: ${tr.title}'),
                      action: SnackBarAction(
                        label: 'Lihat Antrean',
                        onPressed: () => showQueueManagerSheet(context, ref),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (heroTrack != null) ...[
              _HeroShowcaseCard(
                track: heroTrack,
                isActive:
                    playerState.currentTrack?.videoId == heroTrack.videoId,
                isPlaying: playerState.isPlaying,
                onPlay: () {
                  ref.read(playerControllerProvider.notifier).selectTrack(
                        heroTrack,
                        customQueue: allTracks,
                        openFullscreen: true,
                      );
                },
                onAddQueue: () {
                  ref
                      .read(playerControllerProvider.notifier)
                      .addToQueue(heroTrack);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('Ditambahkan ke antrean: ${heroTrack.title}'),
                      action: SnackBarAction(
                        label: 'Lihat Antrean',
                        onPressed: () => showQueueManagerSheet(context, ref),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (exploreData.topArtists.isNotEmpty) ...[
              Text(
                'Artis Favorit & Teratas',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: exploreData.topArtists.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (context, idx) {
                    final artist = exploreData.topArtists[idx];
                    return _ArtistAvatarButton(
                      artist: artist,
                      onTap: () {
                        ref.read(searchQueryProvider.notifier).state =
                            artist.name;
                        ref.read(activeTabProvider.notifier).state = AppTab.cari;
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
            for (final section in displaySections) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(section.title, style: theme.textTheme.titleLarge),
                        if (section.subtitle != null)
                          Text(
                            section.subtitle!,
                            style: theme.textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: section.items.isEmpty
                        ? null
                        : () {
                            ref
                                .read(playerControllerProvider.notifier)
                                .selectTrack(
                                  section.items.first,
                                  customQueue: section.items,
                                );
                          },
                    icon: const Icon(Icons.playlist_play, size: 20),
                    label: const Text('Putar Semua'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResponsiveTrackSection(
                tracks: section.items,
                activeVideoId: playerState.currentTrack?.videoId,
                isPlaying: playerState.isPlaying,
                libraryState: libraryState,
                onPlayTrack: (track) {
                  ref.read(playerControllerProvider.notifier).selectTrack(
                        track,
                        customQueue: section.items,
                      );
                },
                onToggleLike: (track) {
                  ref.read(libraryProvider.notifier).toggleLike(track);
                },
                onToggleDownload: (track) {
                  ref
                      .read(libraryProvider.notifier)
                      .toggleOfflineDownload(track);
                },
              ),
              const SizedBox(height: 24),
            ],
          ],
        );
      },
    );
  }

  Widget _buildTopGreetingHeader(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme scheme,
    AudioEngineSettingsState engineState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _contextualGreeting(engineState.userDisplayName),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Musik dari YouTube, langsung dari HP kamu.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  /// Satu aksi utama per layar: AI DJ. Antrean ada di mini player &
  /// pemutar; prompt playlist jadi aksi sekunder di sampingnya.
  /// Sesi Jam dihapus: butuh server, dan aplikasi kini client-side.
  Widget _buildAiQuickRow(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        FilledButton.icon(
          onPressed: () {
            ref
                .read(playerControllerProvider.notifier)
                .startAiDj(mood: 'Lofi Fokus & Energi Malam');
          },
          icon: const Icon(Icons.record_voice_over_rounded, size: 18),
          label: const Text('Mulai AI DJ'),
        ),
        OutlinedButton.icon(
          onPressed: () => _showPromptPlaylistDialog(context, ref),
          icon: const Icon(Icons.playlist_add_check_rounded, size: 20),
          label: const Text('Playlist dari Prompt'),
        ),
      ],
    );
  }

  void _showPromptPlaylistDialog(BuildContext context, WidgetRef ref) {
    final promptCtrl = TextEditingController(
      text: 'Lo-Fi hujan malam untuk fokus kerja',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Buat AI Playlist dari Prompt Teks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ketik suasana hati, aktivitas, atau genre. Sistem akan menyusun playlist dari hasil pencarian YouTube:',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: promptCtrl,
                decoration: const InputDecoration(
                  labelText: 'Prompt suasana atau tema musik',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                final text = promptCtrl.text.trim();
                Navigator.of(ctx).pop();
                if (text.isEmpty) return;
                final api = ref.read(apiServiceProvider);
                final created = await api.generatePromptPlaylist(text);
                ref.read(libraryProvider.notifier).addPlaylistModel(created);
                if (created.tracks.isNotEmpty) {
                  await ref.read(playerControllerProvider.notifier).selectTrack(
                        created.tracks.first,
                        customQueue: created.tracks,
                        openFullscreen: true,
                      );
                }
              },
              child: const Text('Buat & Putar Sekarang'),
            ),
          ],
        );
      },
    );
  }
}

class _GlassCategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GlassCategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filter kategori $label',
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
        onTap: onTap,
        child: LiquidGlassBox(
          tier: GlassTier.glass3,
          borderRadius: OmniXTokens.radiusPill,
          tintColor: selected ? scheme.primary : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_circle, size: 15, color: scheme.onPrimary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? scheme.onPrimary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickRecentsGrid extends StatelessWidget {
  final List<TrackModel> tracks;
  final String? activeVideoId;
  final ValueChanged<TrackModel> onTapTrack;
  final ValueChanged<TrackModel> onAddToQueue;

  const _QuickRecentsGrid({
    required this.tracks,
    required this.activeVideoId,
    required this.onTapTrack,
    required this.onAddToQueue,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 860 ? 3 : 2;
        final spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (cols - 1))) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tr in tracks)
              SizedBox(
                width: itemWidth,
                child: InkWell(
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(OmniXTokens.radiusThumb),
                  onTap: () => onTapTrack(tr),
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      color: activeVideoId == tr.videoId
                          ? scheme.surfaceContainerHighest
                          : scheme.surface,
                      borderRadius:
                          BorderRadius.circular(OmniXTokens.radiusThumb),
                      border: Border.all(
                        color: activeVideoId == tr.videoId
                            ? scheme.primary
                            : scheme.outline,
                      ),
                    ),
                    child: Row(
                      children: [
                        TrackArtwork(
                          track: tr,
                          size: 60,
                          borderRadius: OmniXTokens.radiusThumb,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tambahkan ${tr.title} ke antrean',
                          onPressed: () => onAddToQueue(tr),
                          icon: Icon(
                            Icons.playlist_add_rounded,
                            color: scheme.onSurface,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeroShowcaseCard extends StatelessWidget {
  final TrackModel track;
  final bool isActive;
  final bool isPlaying;
  final VoidCallback onPlay;
  final VoidCallback onAddQueue;

  const _HeroShowcaseCard({
    required this.track,
    required this.isActive,
    required this.isPlaying,
    required this.onPlay,
    required this.onAddQueue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCompact =
        MediaQuery.sizeOf(context).width < OmniXTokens.breakpointTablet;

    return LiquidGlassBox(
      tier: GlassTier.glass2,
      borderRadius: OmniXTokens.radiusCard,
      padding: EdgeInsets.all(isCompact ? 18 : 24),
      elevatedShadow: true,
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TrackArtwork(
                  track: track,
                  size: 156,
                  borderRadius: OmniXTokens.radiusCard,
                ),
                const SizedBox(height: 16),
                _buildDetails(theme, scheme),
              ],
            )
          : Row(
              children: [
                TrackArtwork(
                  track: track,
                  size: 152,
                  borderRadius: OmniXTokens.radiusCard,
                ),
                const SizedBox(width: 24),
                Expanded(child: _buildDetails(theme, scheme)),
              ],
            ),
    );
  }

  Widget _buildDetails(ThemeData theme, ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          track.title,
          style: theme.textTheme.headlineMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        Text(
          track.artistLine,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onPlay,
              icon: Icon(
                isActive && isPlaying
                    ? Icons.equalizer
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                isActive && isPlaying ? 'Buka Pemutar' : 'Putar',
              ),
            ),
            OutlinedButton.icon(
              onPressed: onAddQueue,
              icon: const Icon(Icons.playlist_add_rounded, size: 20),
              label: const Text('+ Antrean'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ArtistAvatarButton extends StatelessWidget {
  final ArtistModel artist;
  final VoidCallback onTap;

  const _ArtistAvatarButton({
    required this.artist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial =
        artist.name.trim().isNotEmpty ? artist.name.trim()[0].toUpperCase() : 'A';

    return InkWell(
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: scheme.surfaceContainerHighest,
              child: Text(
                initial,
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              artist.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsiveTrackSection extends StatelessWidget {
  final List<TrackModel> tracks;
  final String? activeVideoId;
  final bool isPlaying;
  final LibraryState libraryState;
  final ValueChanged<TrackModel> onPlayTrack;
  final ValueChanged<TrackModel> onToggleLike;
  final ValueChanged<TrackModel> onToggleDownload;

  const _ResponsiveTrackSection({
    required this.tracks,
    required this.activeVideoId,
    required this.isPlaying,
    required this.libraryState,
    required this.onPlayTrack,
    required this.onToggleLike,
    required this.onToggleDownload,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns;
        if (constraints.maxWidth >= 980) {
          columns = 3;
        } else if (constraints.maxWidth >= 620) {
          columns = 2;
        } else {
          columns = 1;
        }

        if (columns == 1) {
          return Column(
            children: [
              for (int i = 0; i < tracks.length; i++) ...[
                TrackTile(
                  track: tracks[i],
                  isActive: activeVideoId == tracks[i].videoId,
                  isPlaying: isPlaying && activeVideoId == tracks[i].videoId,
                  isLiked: libraryState.isLiked(tracks[i].videoId),
                  isDownloaded: libraryState.isDownloaded(tracks[i].videoId),
                  onPlay: () => onPlayTrack(tracks[i]),
                  onToggleLike: () => onToggleLike(tracks[i]),
                  onToggleDownload: () => onToggleDownload(tracks[i]),
                ),
                if (i < tracks.length - 1) const SizedBox(height: 10),
              ],
            ],
          );
        }

        final spacing = 12.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final track in tracks)
              SizedBox(
                width: itemWidth,
                child: TrackTile(
                  track: track,
                  isActive: activeVideoId == track.videoId,
                  isPlaying: isPlaying && activeVideoId == track.videoId,
                  isLiked: libraryState.isLiked(track.videoId),
                  isDownloaded: libraryState.isDownloaded(track.videoId),
                  onPlay: () => onPlayTrack(track),
                  onToggleLike: () => onToggleLike(track),
                  onToggleDownload: () => onToggleDownload(track),
                ),
              ),
          ],
        );
      },
    );
  }
}
