import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track_model.dart';
import '../providers/app_providers.dart';
import '../theme/omnix_theme.dart';
import 'widgets/liquid_glass_box.dart';
import 'widgets/track_tile.dart';

class LibraryView extends ConsumerWidget {
  final double bottomSafePadding;

  const LibraryView({
    super.key,
    required this.bottomSafePadding,
  });

  static const List<String> _chips = [
    'Semua',
    'Playlist',
    'Disukai',
    'Unduhan Offline',
    'Folder Lokal',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(libraryProvider);
    final libraryCtrl = ref.read(libraryProvider.notifier);
    final playerState = ref.watch(playerControllerProvider);
    final exploreData = ref.watch(exploreDataProvider).valueOrNull;
    final seedTracks = [
      for (final sec in exploreData?.sections ?? const <ExploreSectionModel>[])
        ...sec.items,
    ];

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile =
        MediaQuery.sizeOf(context).width < OmniXTokens.breakpointTablet;

    final displayedTracks = _resolveDisplayedTracks(libraryState);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        isMobile ? 16 : 24,
        isMobile ? 16 : 28,
        bottomSafePadding,
      ),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text('Koleksi & Penyimpanan Hi-Res', style: theme.textTheme.headlineMedium),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () =>
                      _showCreatePlaylistDialog(context, libraryCtrl, seedTracks),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('+ Playlist Baru'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      _showCreateBlendDialog(context, libraryCtrl, seedTracks),
                  icon: const Icon(Icons.join_inner_rounded, size: 18),
                  label: const Text('Buat Blend'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    libraryCtrl.indexSampleLocalFolder(seedTracks);
                    libraryCtrl.setCategoryChip('Folder Lokal');
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Indeks Folder Lokal'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final chip in _chips) ...[
                _LibraryFilterChip(
                  label: chip,
                  selected: libraryState.activeCategoryChip == chip,
                  onTap: () => libraryCtrl.setCategoryChip(chip),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildStorageAndPinnedRow(
          context,
          ref,
          theme,
          scheme,
          libraryState,
          seedTracks,
        ),
        const SizedBox(height: 24),
        if (libraryState.activeCategoryChip == 'Semua' ||
            libraryState.activeCategoryChip == 'Playlist') ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Playlist Anda & Kolaborasi (${libraryState.playlists.length})',
                style: theme.textTheme.titleLarge,
              ),
              DropdownButton<LibrarySortMode>(
                value: libraryState.sortMode,
                underline: const SizedBox.shrink(),
                onChanged: (mode) {
                  if (mode != null) libraryCtrl.setSortMode(mode);
                },
                items: const [
                  DropdownMenuItem(
                    value: LibrarySortMode.recentPlayed,
                    child: Text('Urutkan: Terakhir Diputar'),
                  ),
                  DropdownMenuItem(
                    value: LibrarySortMode.recentAdded,
                    child: Text('Urutkan: Terakhir Ditambah'),
                  ),
                  DropdownMenuItem(
                    value: LibrarySortMode.alphabetical,
                    child: Text('Urutkan: Abjad (A-Z)'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final pl in _sortedPlaylists(libraryState)) ...[
            _PlaylistCard(
              playlist: pl,
              onPlay: () {
                final tracksToPlay =
                    pl.tracks.isNotEmpty ? pl.tracks : seedTracks;
                if (tracksToPlay.isNotEmpty) {
                  ref.read(playerControllerProvider.notifier).selectTrack(
                        tracksToPlay.first,
                        customQueue: tracksToPlay,
                      );
                }
              },
              onTogglePin: () => libraryCtrl.togglePinPlaylist(pl.id),
              onDelete: () => libraryCtrl.deletePlaylist(pl.id),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 20),
        ],
        Text(
          _sectionHeading(libraryState.activeCategoryChip, displayedTracks.length),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (displayedTracks.isEmpty)
          LiquidGlassBox(
            tier: GlassTier.glass2,
            borderRadius: OmniXTokens.radiusCard,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.library_music_outlined,
                  size: 44,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  'Belum ada lagu pada kategori "${libraryState.activeCategoryChip}".',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ketuk ikon hati atau ikon unduh pada lagu di Beranda dan Cari untuk menyimpannya secara gratis tanpa batas.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(activeTabProvider.notifier).state = AppTab.cari;
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Jelajahi Lagu Sekarang'),
                ),
              ],
            ),
          )
        else
          for (final tr in displayedTracks) ...[
            TrackTile(
              track: tr,
              isActive: playerState.currentTrack?.videoId == tr.videoId,
              isPlaying: playerState.isPlaying &&
                  playerState.currentTrack?.videoId == tr.videoId,
              isLiked: libraryState.isLiked(tr.videoId),
              isDownloaded: libraryState.isDownloaded(tr.videoId),
              onPlay: () {
                ref.read(playerControllerProvider.notifier).selectTrack(
                      tr,
                      customQueue: displayedTracks,
                    );
              },
              onToggleLike: () => libraryCtrl.toggleLike(tr),
              onToggleDownload: () => libraryCtrl.toggleOfflineDownload(tr),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  List<UserPlaylistModel> _sortedPlaylists(LibraryState state) {
    final copy = List<UserPlaylistModel>.from(state.playlists);
    copy.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return a.isPinned ? -1 : 1;
      }
      if (state.sortMode == LibrarySortMode.alphabetical) {
        return a.name.compareTo(b.name);
      }
      return 0;
    });
    return copy;
  }

  List<TrackModel> _resolveDisplayedTracks(LibraryState state) {
    return switch (state.activeCategoryChip) {
      'Disukai' => state.likedTracks,
      'Unduhan Offline' => state.offlineDownloadedTracks,
      'Folder Lokal' => state.localFolderTracks,
      _ => [
          ...state.likedTracks,
          for (final t in state.offlineDownloadedTracks)
            if (!state.likedTracks.any((l) => l.videoId == t.videoId)) t,
          for (final t in state.recentTracks)
            if (!state.likedTracks.any((l) => l.videoId == t.videoId) &&
                !state.offlineDownloadedTracks.any((d) => d.videoId == t.videoId))
              t,
        ],
    };
  }

  String _sectionHeading(String chip, int count) {
    return switch (chip) {
      'Disukai' => 'Daftar Lagu Disukai ($count)',
      'Unduhan Offline' => 'Tersimpan Offline FLAC 24-bit ($count)',
      'Folder Lokal' => 'File Audio Lokal Perangkat ($count)',
      _ => 'Lagu Tersimpan & Terakhir Diputar ($count)',
    };
  }

  Widget _buildStorageAndPinnedRow(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme scheme,
    LibraryState libraryState,
    List<TrackModel> seedTracks,
  ) {
    final usedMb = libraryState.estimatedOfflineStorageMb;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final pinnedCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
            border: Border.all(color: scheme.primary, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(OmniXTokens.radiusThumb),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: scheme.onPrimary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.push_pin_rounded,
                          size: 15,
                          color: scheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'DISEMATKAN · FLAC 24-BIT',
                          style: TextStyle(
                            color: scheme.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Lagu Disukai (${libraryState.likedTracks.length})',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      'Sinkronisasi offline otomatis tanpa batas',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Putar cepat Lagu Disukai',
                onPressed: () {
                  final list = libraryState.likedTracks.isNotEmpty
                      ? libraryState.likedTracks
                      : seedTracks;
                  if (list.isNotEmpty) {
                    ref
                        .read(playerControllerProvider.notifier)
                        .selectTrack(list.first, customQueue: list);
                  }
                },
                icon: Icon(
                  Icons.play_circle_fill_rounded,
                  color: scheme.primary,
                  size: 40,
                ),
              ),
            ],
          ),
        );

        final storageCard = LiquidGlassBox(
          tier: GlassTier.glass2,
          borderRadius: OmniXTokens.radiusCard,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Penyimpanan Hi-Res Audio (FLAC Status)',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${usedMb.toStringAsFixed(0)} MB / Tanpa Batas',
                    style: TextStyle(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: (usedMb / 2048.0).clamp(0.06, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: scheme.outline,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.secondary),
              ),
              const SizedBox(height: 8),
              Text(
                'Alokasi cache lokal SSD/Flash untuk streaming Lossless 24-bit/96kHz & unduhan offline gratis.',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );

        if (isWide) {
          return Row(
            children: [
              Expanded(child: pinnedCard),
              const SizedBox(width: 16),
              Expanded(child: storageCard),
            ],
          );
        }
        return Column(
          children: [
            pinnedCard,
            const SizedBox(height: 14),
            storageCard,
          ],
        );
      },
    );
  }

  void _showCreatePlaylistDialog(
    BuildContext context,
    LibraryController ctrl,
    List<TrackModel> seedTracks,
  ) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool collaborative = true;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Buat Playlist Baru'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Playlist',
                      hintText: 'Contoh: Synthwave Coding Malam',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      hintText: 'Catatan suasana atau tema lagu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Playlist Kolaboratif'),
                    subtitle: const Text('Izinkan teman menambahkan lagu bersama'),
                    value: collaborative,
                    onChanged: (v) => setDialogState(() => collaborative = v),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Batal'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isNotEmpty) {
                      ctrl.createPlaylist(
                        name: name,
                        description: descCtrl.text.trim().isEmpty
                            ? 'Playlist kustom Hi-Res'
                            : descCtrl.text.trim(),
                        isCollaborative: collaborative,
                        tracks: seedTracks.take(6).toList(),
                      );
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Simpan Playlist'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateBlendDialog(
    BuildContext context,
    LibraryController ctrl,
    List<TrackModel> seedTracks,
  ) {
    final friendCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Buat Blend Selera Musik Bersama Teman'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gabungkan selera dengar Anda dengan teman dan lihat skor kecocokan musik secara instan:',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: friendCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Teman',
                  hintText: 'Masukkan nama teman untuk digabungkan',
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
              onPressed: () {
                final friend = friendCtrl.text.trim();
                if (friend.isNotEmpty) {
                  ctrl.createBlendWithFriend(friend, seedTracks.take(8).toList());
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Buat Blend Sekarang'),
            ),
          ],
        );
      },
    );
  }
}

class _LibraryFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LibraryFilterChip({
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

class _PlaylistCard extends StatelessWidget {
  final UserPlaylistModel playlist;
  final VoidCallback onPlay;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _PlaylistCard({
    required this.playlist,
    required this.onPlay,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
        border: Border.all(
          color: playlist.isPinned ? scheme.primary : scheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(OmniXTokens.radiusThumb),
            ),
            child: Icon(
              playlist.blendMatchScore != null
                  ? Icons.join_inner_rounded
                  : Icons.queue_music_rounded,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (playlist.isPinned) ...[
                      Icon(
                        Icons.push_pin_rounded,
                        size: 14,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (playlist.isOfflineSynced) ...[
                      Icon(
                        Icons.download_done_rounded,
                        size: 15,
                        color: scheme.secondary,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (playlist.blendMatchScore != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${playlist.blendMatchScore}% Match',
                          style: TextStyle(
                            color: scheme.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        playlist.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  playlist.description,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: playlist.isPinned
                ? 'Lepas sematan playlist'
                : 'Sematkan playlist di atas',
            onPressed: onTogglePin,
            icon: Icon(
              playlist.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              color: playlist.isPinned
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Hapus playlist ${playlist.name}',
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline,
              color: scheme.error,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Putar playlist ${playlist.name}',
            onPressed: onPlay,
            icon: Icon(
              Icons.play_circle_fill_rounded,
              color: scheme.primary,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
