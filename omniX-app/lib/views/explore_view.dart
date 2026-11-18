import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/track_model.dart';
import '../providers/app_providers.dart';
import '../theme/omnix_theme.dart';
import 'widgets/liquid_glass_box.dart';
import 'widgets/track_artwork.dart';

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

        final filteredSections = exploreData.sections.where((sec) {
          if (activeCategory == 'Semua') return true;
          if (activeCategory == 'Musik') return sec.category == 'music';
          return true;
        }).toList();

        final displaySections = filteredSections.isNotEmpty
            ? filteredSections
            : exploreData.sections;

        // Rak 1 "Rekomendasi Lagu": 6 lagu pertama dari seksi yang tampil.
        final recommendedTracks = displaySections
            .expand((sec) => sec.items)
            .take(6)
            .toList();

        // Rak 2 "Artis": 6 artis teratas dari feed.
        final topArtists = exploreData.topArtists.take(6).toList();

        // Rak 3 "Album": album unik dari semua lagu (lagu pertama tiap
        // album jadi sumber artwork & artis), maks 6 album.
        final albumEntries = <({AlbumModel album, TrackModel track})>[];
        final seenAlbumNames = <String>{};
        for (final tr in allTracks) {
          final album = tr.album;
          if (album == null || album.name.trim().isEmpty) continue;
          if (seenAlbumNames.add(album.name)) {
            albumEntries.add((album: album, track: tr));
          }
          if (albumEntries.length >= 6) break;
        }

        // Rak 4 "Playlist": 6 playlist pertama milik pengguna.
        final userPlaylists = libraryState.playlists.take(6).toList();

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
            if (recommendedTracks.isNotEmpty) ...[
              _RailHeader(
                title: 'Rekomendasi Lagu',
                onSeeAll: () {
                  ref.read(playerControllerProvider.notifier).selectTrack(
                        recommendedTracks.first,
                        customQueue: recommendedTracks,
                      );
                },
              ),
              const SizedBox(height: 12),
              _HorizontalRail(
                itemCount: recommendedTracks.length,
                itemBuilder: (context, index) {
                  final tr = recommendedTracks[index];
                  return _RailCard(
                    artwork: TrackArtwork(
                      track: tr,
                      size: 152,
                      borderRadius: OmniXTokens.radiusThumb,
                    ),
                    title: tr.title,
                    subtitle: tr.artistLine,
                    onTap: () {
                      ref.read(playerControllerProvider.notifier).selectTrack(
                            tr,
                            customQueue: recommendedTracks,
                          );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (topArtists.isNotEmpty) ...[
              _RailHeader(
                title: 'Artis',
                onSeeAll: () {
                  ref.read(activeTabProvider.notifier).state = AppTab.cari;
                },
              ),
              const SizedBox(height: 12),
              _HorizontalRail(
                itemCount: topArtists.length,
                itemBuilder: (context, index) {
                  final artist = topArtists[index];
                  return _RailCard(
                    circularArtwork: true,
                    artwork: _ArtistCircleArtwork(name: artist.name),
                    title: artist.name,
                    subtitle: 'Artis',
                    onTap: () {
                      ref.read(searchQueryProvider.notifier).state =
                          artist.name;
                      ref.read(activeTabProvider.notifier).state = AppTab.cari;
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (albumEntries.isNotEmpty) ...[
              _RailHeader(
                title: 'Album',
                onSeeAll: () {
                  ref.read(activeTabProvider.notifier).state = AppTab.cari;
                },
              ),
              const SizedBox(height: 12),
              _HorizontalRail(
                itemCount: albumEntries.length,
                itemBuilder: (context, index) {
                  final entry = albumEntries[index];
                  return _RailCard(
                    artwork: TrackArtwork(
                      track: entry.track,
                      size: 152,
                      borderRadius: OmniXTokens.radiusThumb,
                    ),
                    title: entry.album.name,
                    subtitle: entry.track.artistLine,
                    onTap: () {
                      ref.read(searchQueryProvider.notifier).state =
                          entry.album.name;
                      ref.read(activeTabProvider.notifier).state = AppTab.cari;
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            if (userPlaylists.isNotEmpty) ...[
              _RailHeader(
                title: 'Playlist',
                onSeeAll: () {
                  ref.read(activeTabProvider.notifier).state = AppTab.koleksi;
                },
              ),
              const SizedBox(height: 12),
              _HorizontalRail(
                itemCount: userPlaylists.length,
                itemBuilder: (context, index) {
                  final pl = userPlaylists[index];
                  final firstTrack =
                      pl.tracks.isNotEmpty ? pl.tracks.first : null;
                  return _RailCard(
                    artwork: firstTrack != null
                        ? TrackArtwork(
                            track: firstTrack,
                            size: 152,
                            borderRadius: OmniXTokens.radiusThumb,
                          )
                        : _PlaylistPlaceholderArtwork(),
                    title: pl.name,
                    subtitle: '${pl.tracks.length} lagu',
                    onTap: () {
                      if (pl.tracks.isNotEmpty) {
                        ref.read(playerControllerProvider.notifier).selectTrack(
                              pl.tracks.first,
                              customQueue: pl.tracks,
                            );
                      }
                    },
                  );
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
                'Ketik suasana hati, aktivitas, atau genre. Sistem akan menyusun playlist dari hasil pencarian:',
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

/// Judul rak + tombol "Lihat semua" seperti preview UI v2.
class _RailHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;

  const _RailHeader({
    required this.title,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        TextButton(
          onPressed: onSeeAll,
          child: const Text('Lihat semua'),
        ),
      ],
    );
  }
}

/// Deret horizontal yang bisa di-scroll ke samping (preview UI v2).
/// Tinggi 216px: artwork 152 + jarak 8 + judul 1 baris + subjudul 2 baris.
class _HorizontalRail extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;

  const _HorizontalRail({
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 216,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// Kartu rak 152px ala preview v2: artwork di atas, judul tebal 1 baris,
/// subjudul redup maks 2 baris. Kartu artis memakai artwork bundar.
class _RailCard extends StatelessWidget {
  final Widget artwork;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool circularArtwork;

  const _RailCard({
    required this.artwork,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.circularArtwork = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 152,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(OmniXTokens.radiusThumb),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 152,
              height: 152,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  circularArtwork
                      ? OmniXTokens.radiusPill
                      : OmniXTokens.radiusThumb,
                ),
                child: artwork,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Artwork bundar artis: gradien + inisial nama seperti preview v2.
class _ArtistCircleArtwork extends StatelessWidget {
  final String name;

  const _ArtistCircleArtwork({required this.name});

  static const List<List<Color>> _palettes = [
    [Color(0xFF4338CA), Color(0xFF7C5CFF)],
    [Color(0xFF0EA5E9), Color(0xFF22C55E)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
    [Color(0xFFEC4899), Color(0xFF8B5CF6)],
    [Color(0xFF22C55E), Color(0xFF0EA5E9)],
    [Color(0xFF4338CA), Color(0xFFEC4899)],
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial =
        trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'A';
    final hash = trimmed.codeUnits.fold<int>(0, (a, b) => a + b);
    final palette = _palettes[hash % _palettes.length];
    return Container(
      width: 152,
      height: 152,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 52,
        ),
      ),
    );
  }
}

/// Placeholder playlist kosong: gradien + ikon not musik (preview v2).
class _PlaylistPlaceholderArtwork extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 152,
      height: 152,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4338CA), Color(0xFF7C5CFF)],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 40,
      ),
    );
  }
}
