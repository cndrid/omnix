import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import '../views/widgets/liquid_glass_box.dart';

/// Satu baris opsi di dalam Bottom Sheet (tinggi 48 px, components.md §25).
class SheetMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDestructive;
  final bool enabled;

  const SheetMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.enabled = true,
  });
}

/// Bottom Sheet OmniX (components.md §15): material Glass 2, radius atas
/// 28 px, pegangan seret 36×4 px, muncul medium 300 ms ease-out, bisa
/// diinterupsi (geser ke bawah / ketuk luar / tombol tutup). Fokus pertama
/// jatuh ke judul sheet saat dibuka.
Future<T?> showOmniXBottomSheet<T>({
  required BuildContext context,
  required String title,
  required List<Widget> children,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Durasi default sheet Material adalah 300 ms ease-out — sama dengan
    // token motionMedium; tidak ada durasi kustom di sini.
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ClipRRect(
            // Radius sheet token = 28 px (radiusCard 20 + 8); sudut
            // bawah dipotong persegi oleh ClipRRect ini.
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(OmniXTokens.radiusCard + 8),
            ),
            child: LiquidGlassBox(
              tier: GlassTier.glass2,
              borderRadius: OmniXTokens.radiusCard + 8,
              elevatedShadow: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  // Pegangan seret 36×4 px.
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: OmniXTokens.typeLg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: children,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Baris opsi sheet: ikon 24 px + label base, tinggi 48 px; opsi merusak
/// (mis. Hapus) memakai teks warna danger.
class SheetOptionRow extends StatelessWidget {
  final SheetMenuItem item;

  const SheetOptionRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = item.isDestructive ? scheme.error : scheme.onSurface;
    return Opacity(
      opacity: item.enabled ? 1.0 : 0.4,
      child: ListTile(
        enabled: item.enabled,
        leading: Icon(item.icon, color: color, size: 24),
        title: Text(
          item.label,
          style: TextStyle(
            color: color,
            fontSize: OmniXTokens.typeBase,
          ),
        ),
        onTap: item.enabled
            ? () {
                Navigator.of(context).pop();
                item.onTap?.call();
              }
            : null,
      ),
    );
  }
}

/// Menu lagu (components.md §25): Putar Berikutnya, Tambah ke Antrean,
/// Tambah ke Playlist, Bagikan.
Future<void> showTrackMenuSheet({
  required BuildContext context,
  required String trackTitle,
  required VoidCallback onPlayNext,
  required VoidCallback onAddToQueue,
  required VoidCallback onAddToPlaylist,
  required VoidCallback onShare,
}) {
  return showOmniXBottomSheet<void>(
    context: context,
    title: trackTitle,
    children: [
      SheetOptionRow(
        item: SheetMenuItem(
          label: 'Putar Berikutnya',
          icon: Icons.playlist_play_rounded,
          onTap: onPlayNext,
        ),
      ),
      SheetOptionRow(
        item: SheetMenuItem(
          label: 'Tambah ke Antrean',
          icon: Icons.add_to_queue_rounded,
          onTap: onAddToQueue,
        ),
      ),
      SheetOptionRow(
        item: SheetMenuItem(
          label: 'Tambah ke Playlist',
          icon: Icons.playlist_add_rounded,
          onTap: onAddToPlaylist,
        ),
      ),
      SheetOptionRow(
        item: SheetMenuItem(
          label: 'Bagikan',
          icon: Icons.share_outlined,
          onTap: onShare,
        ),
      ),
    ],
  );
}
