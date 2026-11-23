import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import 'ai_dj_card.dart';
import 'content_card.dart';
import 'design_mini_player.dart';
import 'design_track_row.dart';
import 'feedback_states.dart';
import 'filter_chip.dart';
import 'glass_card.dart';
import 'omni_x_bottom_sheet.dart';
import 'omni_x_button.dart';
import 'omni_x_search_bar.dart';
import 'omni_x_slider.dart';
import 'play_button.dart';
import '../views/widgets/liquid_glass_box.dart';

/// Showcase primitif desain — SATU route terisolasi '/design', hanya bisa
/// dicapai lewat deep link / navigasi bernama. Tidak ada tombol/menu ke
/// sini dari layar utama, dan alur aplikasi normal tidak berubah.
/// Semua primitif di sini memakai token (OmniXTokens / ThemeData).
class DesignShowcaseView extends StatefulWidget {
  const DesignShowcaseView({super.key});

  @override
  State<DesignShowcaseView> createState() => _DesignShowcaseViewState();
}

class _DesignShowcaseViewState extends State<DesignShowcaseView> {
  double _seekValue = 74;
  double _volumeValue = 0.7;
  int _selectedChip = 0;
  String _searchText = '';

  static const _filters = ['Semua', 'Lagu', 'Artis', 'Playlist'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Primitif Desain'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Section(
            title: '1 · Tombol',
            description:
                'primary / secondary (Glass 3) / ghost / danger — sm 32, md 40, lg 48. Area sentuh minimal 48 px.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OmniXButton(
                  label: 'Simpan',
                  variant: OmniXButtonVariant.primary,
                  size: OmniXButtonSize.sm,
                  onPressed: () {},
                ),
                OmniXButton(
                  label: 'Simpan',
                  variant: OmniXButtonVariant.primary,
                  size: OmniXButtonSize.md,
                  onPressed: () {},
                ),
                OmniXButton(
                  label: 'Simpan playlist',
                  variant: OmniXButtonVariant.primary,
                  size: OmniXButtonSize.lg,
                  onPressed: () {},
                ),
                OmniXButton(
                  label: 'Batal',
                  variant: OmniXButtonVariant.secondary,
                  size: OmniXButtonSize.md,
                  onPressed: () {},
                ),
                OmniXButton(
                  label: 'Lewati',
                  variant: OmniXButtonVariant.ghost,
                  size: OmniXButtonSize.md,
                  onPressed: () {},
                ),
                OmniXButton(
                  label: 'Hapus',
                  variant: OmniXButtonVariant.danger,
                  size: OmniXButtonSize.md,
                  onPressed: () {},
                ),
                const OmniXButton(
                  label: 'Tidak aktif',
                  variant: OmniXButtonVariant.primary,
                  size: OmniXButtonSize.md,
                  onPressed: null,
                ),
                const OmniXButton(
                  label: 'Memuat',
                  variant: OmniXButtonVariant.primary,
                  size: OmniXButtonSize.md,
                  onPressed: null,
                  isLoading: true,
                ),
              ],
            ),
          ),
          const _Section(
            title: '2 · Tombol Putar',
            description:
                'Ikon GELAP di atas hijau (bukan putih). 72 px pemutar penuh, 40 px mini player, buffering = skeleton.',
            child: Row(
              children: [
                PlayButton.large(
                  isPlaying: false,
                  trackTitle: 'Hati-Hati di Jalan',
                  onPressed: null,
                ),
                SizedBox(width: 24),
                PlayButton.small(
                  isPlaying: true,
                  trackTitle: 'Hati-Hati di Jalan',
                  onPressed: null,
                ),
                SizedBox(width: 24),
                PlayButton.large(
                  isPlaying: false,
                  trackTitle: 'Hati-Hati di Jalan',
                  onPressed: null,
                  isBuffering: true,
                ),
                SizedBox(width: 24),
                PlayButton.quick(
                  isPlaying: false,
                  trackTitle: 'Hati-Hati di Jalan',
                  onPressed: null,
                ),
              ],
            ),
          ),
          _Section(
            title: '3 · Kartu kaca',
            description:
                'Glass 1 (navbar/mini player), Glass 2 (panel/sheet), Glass 3 (chip/tombol bulat) di atas latar gradasi warna sampul.',
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(OmniXTokens.radiusCard),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.secondary],
                ),
              ),
              child: Column(
                children: [
                  GlassCard(
                    tier: GlassTier.glass1,
                    borderRadius: OmniXTokens.radiusMiniPlayer,
                    tintColor: scheme.secondary,
                    padding: const EdgeInsets.all(16),
                    child: const _GlassLabel(text: 'Glass 1 — navbar / mini player'),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    tier: GlassTier.glass2,
                    borderRadius: OmniXTokens.radiusCard,
                    tintColor: scheme.secondary,
                    padding: const EdgeInsets.all(16),
                    child: const _GlassLabel(text: 'Glass 2 — panel / sheet'),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    tier: GlassTier.glass3,
                    borderRadius: OmniXTokens.radiusPill,
                    tintColor: scheme.secondary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: const _GlassLabel(text: 'Glass 3 — chip / tombol bulat'),
                  ),
                ],
              ),
            ),
          ),
          _Section(
            title: '4 · Bottom Sheet',
            description:
                'Glass 2, radius atas 28 px, pegangan seret 36×4 px, muncul 300 ms ease-out.',
            child: OmniXButton(
              label: 'Buka menu lagu',
              variant: OmniXButtonVariant.secondary,
              size: OmniXButtonSize.md,
              onPressed: () => showTrackMenuSheet(
                context: context,
                trackTitle: 'Hati-Hati di Jalan',
                onPlayNext: () {},
                onAddToQueue: () {},
                onAddToPlaylist: () {},
                onShare: () {},
              ),
            ),
          ),
          _Section(
            title: '5 · Slider seek & volume',
            description:
                'Track 4 px, thumb 12 px (16 px saat diseret), area sentuh 24 px, warna play. Seret dan nilai berubah.',
            child: Column(
              children: [
                OmniXSeekSlider(
                  value: _seekValue,
                  max: 214,
                  label: 'Posisi lagu',
                  onChanged: (v) => setState(() => _seekValue = v),
                ),
                const SizedBox(height: 16),
                OmniXSeekSlider(
                  value: _volumeValue,
                  max: 1,
                  label: 'Volume',
                  showTimes: false,
                  onChanged: (v) => setState(() => _volumeValue = v),
                ),
              ],
            ),
          ),
          _Section(
            title: '6 · Chip filter',
            description: 'Pil Glass 3 tinggi 36 px; aktif = isian accent.',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _filters.length; i++)
                  OmniXFilterChip(
                    label: _filters[i],
                    groupLabel: 'Filter hasil',
                    selected: _selectedChip == i,
                    onSelected: (_) =>
                        setState(() => _selectedChip = i),
                  ),
                const OmniXFilterChip(
                  label: 'Tanpa hasil',
                  selected: false,
                  onSelected: null,
                ),
              ],
            ),
          ),
          _Section(
            title: '7 · Search bar',
            description:
                'Pil Glass 3 saat tidak fokus; fokus = border border-input 2 px. Tombol tutup muncul saat terisi.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OmniXSearchBar(
                  onChanged: (v) => setState(() => _searchText = v),
                ),
                if (_searchText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Kata kunci: "$_searchText"',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: OmniXTokens.typeSm,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const _Section(
            title: '8 · Mini player',
            description:
                'Glass 1 radius 16 px, tinggi 64 px, sampul 48 px, progress 2 px di tepi bawah. Judul berjalan hanya saat diputar.',
            child: Column(
              children: [
                DesignMiniPlayer(
                  title:
                      'Hati-Hati di Jalan — judul yang cukup panjang supaya terpotong dan berjalan',
                  artist: 'Tulus',
                  progress: 0.35,
                  isPlaying: true,
                  isLiked: true,
                ),
                SizedBox(height: 12),
                DesignMiniPlayer(
                  title: 'Ruang Sendiri',
                  artist: 'Tulus',
                  progress: 0.1,
                  isPlaying: false,
                ),
              ],
            ),
          ),
          _Section(
            title: '9 · Baris lagu',
            description:
                'Tinggi 64 px. Diputar: judul accent-bright + equalizer 3 batang (berhenti saat dijeda).',
            child: Column(
              children: [
                DesignTrackRow(
                  title: 'Hati-Hati di Jalan',
                  artist: 'Tulus',
                  duration: '3:34',
                  isActive: true,
                  isPlaying: true,
                  isDownloaded: true,
                  isExplicit: true,
                  isLiked: true,
                  onPlay: () {},
                ),
                const SizedBox(height: 8),
                DesignTrackRow(
                  title: 'Ruang Sendiri',
                  artist: 'Tulus',
                  duration: '4:02',
                  isActive: true,
                  isPlaying: false,
                  onPlay: () {},
                ),
                const SizedBox(height: 8),
                const DesignTrackRow(
                  title: 'Interaksi',
                  artist: 'Tulus',
                  duration: '3:12',
                  onPlay: null,
                ),
              ],
            ),
          ),
          _Section(
            title: '10 · Kartu konten',
            description:
                'Kartu lagu/album/playlist 152 px + kartu artis bulat. Tombol Putar cepat Glass 3 44 px muncul saat disentuh.',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ContentCard(
                    title: 'Manusia',
                    subtitle: 'Album · Tulus',
                    isPlaying: true,
                    onTap: () {},
                    onPlay: () {},
                  ),
                  const SizedBox(width: 16),
                  ContentCard(
                    title: 'Monokrom',
                    subtitle: 'Album · Tulus',
                    onTap: () {},
                    onPlay: () {},
                  ),
                  const SizedBox(width: 16),
                  ArtistCard(
                    name: 'Tulus',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
          const _Section(
            title: '11 · Kartu AI DJ',
            description:
                'Kartu kaca + tombol putar. Komentar mengetik SATU KALI saat sesi mulai, lalu berhenti.',
            child: AiDjCard(),
          ),
          _Section(
            title: '12 · Skeleton, Empty & Error',
            description:
                'Loading = skeleton (bukan spinner). Error netral, bukan merah penuh.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    OmniXSkeleton(width: 48, height: 48),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          OmniXSkeleton(width: 160, height: 14),
                          SizedBox(height: 8),
                          OmniXSkeleton(width: 110, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OmniXErrorBar(
                  message: 'Gagal memutar lagu. Periksa koneksimu.',
                  onRetry: () {},
                ),
                const SizedBox(height: 16),
                OmniXErrorState(
                  title: 'Tidak dapat memuat',
                  message:
                      'Periksa koneksi internetmu, lalu coba lagi.',
                  onRetry: () {},
                ),
                const SizedBox(height: 16),
                OmniXEmptyState(
                  icon: Icons.library_music_outlined,
                  title: 'Koleksi masih kosong',
                  message:
                      'Lagu yang kamu sukai akan tersimpan di sini.',
                  actionLabel: 'Cari Lagu',
                  onAction: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _Section({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: OmniXTokens.typeLg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: OmniXTokens.typeSm,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _GlassLabel extends StatelessWidget {
  final String text;

  const _GlassLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: OmniXTokens.typeBase,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
