import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track_model.dart';
import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../providers/like_flow.dart';
import '../theme/omnix_theme.dart';
import 'widgets/liquid_glass_box.dart';
import 'widgets/track_tile.dart';

/// S12 Koleksi + S13 Liked Songs (M0).
///
/// Daftar Liked Songs dibaca dari [likedTracksProvider] (login: Supabase +
/// cache Drift; tamu: Drift) dengan fallback ke state in-memory library.
/// Saat Library dibuka pertama kali — dan setiap kali pengguna baru saja
/// login — daftar disinkronkan sekali dari repository lewat
/// [LibraryController.syncLikedTracksFromRepository].
class LibraryView extends ConsumerStatefulWidget {
  final double bottomSafePadding;

  const LibraryView({
    super.key,
    required this.bottomSafePadding,
  });

  @override
  ConsumerState<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends ConsumerState<LibraryView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncLiked();
    });
  }

  void _syncLiked() {
    unawaited(
      ref.read(libraryProvider.notifier).syncLikedTracksFromRepository(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final libraryCtrl = ref.read(libraryProvider.notifier);
    final playerState = ref.watch(playerControllerProvider);

    // Sinkron ulang saat pengguna baru saja login (tamu -> login).
    try {
      ref.listen<bool>(isLoggedInProvider, (prev, next) {
        if (next && prev != true) _syncLiked();
      });
    } catch (_) {
      // Lapisan auth belum siap — sinkron dilewati, state in-memory
      // tetap dipakai.
    }

    // S13: Liked Songs dari repository; fallback state in-memory bila
    // provider data belum ada nilainya / gagal dimuat.
    final likedAsync = ref.watch(likedTracksProvider);
    final likedTracks = likedAsync.valueOrNull ?? libraryState.likedTracks;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile =
        MediaQuery.sizeOf(context).width < OmniXTokens.breakpointTablet;

    final displayedTracks =
        _resolveDisplayedTracks(libraryState, likedTracks);
    final isLikedEmpty =
        libraryState.activeCategoryChip == 'Disukai' && likedTracks.isEmpty;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        isMobile ? 16 : 24,
        isMobile ? 16 : 28,
        widget.bottomSafePadding,
      ),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text('Koleksi', style: theme.textTheme.headlineMedium),
            FilledButton.icon(
              onPressed: () =>
                  _showCreatePlaylistDialog(context, libraryCtrl),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('+ Playlist Baru'),
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
          likedTracks,
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
                if (pl.tracks.isNotEmpty) {
                  ref.read(playerControllerProvider.notifier).selectTrack(
                        pl.tracks.first,
                        customQueue: pl.tracks,
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
                  isLikedEmpty
                      ? Icons.favorite_border_rounded
                      : Icons.library_music_outlined,
                  size: 64,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 12),
                Text(
                  isLikedEmpty
                      ? 'Belum ada lagu disukai.'
                      : 'Belum ada lagu pada kategori "${libraryState.activeCategoryChip}".',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  isLikedEmpty
                      ? 'Cari lagu untuk disukai — ketuk ikon hati pada lagu.'
                      : 'Ketuk ikon hati atau ikon unduh pada lagu di Beranda dan Cari untuk menyimpannya di Koleksi.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.read(activeTabProvider.notifier).state = AppTab.cari;
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Cari Lagu'),
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
              onToggleLike: () => LikeFlow.toggleLikeWithResult(
                ref,
                tr,
                context: context,
              ),
              onToggleDownload: () => libraryCtrl.toggleOfflineDownload(tr),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  static const List<String> _chips = [
    'Semua',
    'Playlist',
    'Disukai',
    'Unduhan Offline',
  ];

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

  List<TrackModel> _resolveDisplayedTracks(
    LibraryState state,
    List<TrackModel> likedTracks,
  ) {
    return switch (state.activeCategoryChip) {
      'Disukai' => likedTracks,
      'Unduhan Offline' => state.offlineDownloadedTracks,
      _ => [
          ...likedTracks,
          for (final t in state.offlineDownloadedTracks)
            if (!likedTracks.any((l) => l.videoId == t.videoId)) t,
          for (final t in state.recentTracks)
            if (!likedTracks.any((l) => l.videoId == t.videoId) &&
                !state.offlineDownloadedTracks.any((d) => d.videoId == t.videoId))
              t,
        ],
    };
  }

  String _sectionHeading(String chip, int count) {
    return switch (chip) {
      'Disukai' => 'Lagu Disukai ($count)',
      'Unduhan Offline' => 'Tersimpan Offline ($count)',
      _ => 'Lagu Tersimpan & Terakhir Diputar ($count)',
    };
  }

  Widget _buildStorageAndPinnedRow(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme scheme,
    LibraryState libraryState,
    List<TrackModel> likedTracks,
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
                          'DISEMATKAN',
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
                      'Lagu Disukai (${likedTracks.length})',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      'Lagu yang kamu sukai',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Putar semua Lagu Disukai',
                onPressed: () {
                  if (likedTracks.isNotEmpty) {
                    ref
                        .read(playerControllerProvider.notifier)
                        .selectTrack(likedTracks.first, customQueue: likedTracks);
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
                    'Cache Audio Lokal',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${usedMb.toStringAsFixed(0)} MB cache',
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
                'Cache lagu yang sudah diputar, supaya bisa diputar ulang tanpa mengunduh lagi.',
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
                            ? 'Playlist kustom'
                            : descCtrl.text.trim(),
                        isCollaborative: collaborative,
                        tracks: const [],
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
