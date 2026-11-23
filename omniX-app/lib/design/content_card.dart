import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import 'design_artwork.dart';
import 'play_button.dart';
import 'pressable.dart';

/// Kartu konten (components.md §5): lebar 152 px di rak horizontal,
/// sampul radius card, judul di bawah sampul (maks 2 baris), subjudul
/// sm text-muted (maks 1 baris). Tombol Putar cepat Glass 3 44 px muncul
/// saat disentuh / hover / fokus keyboard. Kartu yang sedang diputar:
/// judul accent-bright + label "sedang diputar" (bukan hanya warna).
class ContentCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;

  const ContentCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.isPlaying = false,
    required this.onTap,
    required this.onPlay,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final showQuickPlay =
        _hovered || _focused || widget.isPlaying;

    return Semantics(
      button: true,
      label:
          '${widget.title}, ${widget.subtitle}'
          '${widget.isPlaying ? ', sedang diputar' : ''}',
      child: Focus(
        onFocusChange: (focused) {
          if (mounted) setState(() => _focused = focused);
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Pressable(
            onTap: widget.onTap,
            borderRadius:
                BorderRadius.circular(OmniXTokens.radiusCard),
            child: SizedBox(
              width: 152,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      DesignArtworkPlaceholder(
                        size: 152,
                        seed: widget.title,
                        borderRadius: OmniXTokens.radiusCard,
                      ),
                      if (showQuickPlay)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: PlayButton.quick(
                            isPlaying: widget.isPlaying,
                            trackTitle: widget.title,
                            onPressed: widget.onPlay,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.isPlaying
                          ? scheme.tertiary
                          : scheme.onSurface,
                      fontSize: OmniXTokens.typeBase,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: OmniXTokens.typeSm,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu artis bulat (components.md §5): lingkaran penuh + nama di bawah.
class ArtistCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback? onTap;

  const ArtistCard({
    super.key,
    required this.name,
    this.subtitle = 'Artis',
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: '$name, $subtitle',
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
        child: SizedBox(
          width: 152,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: DesignArtworkPlaceholder(
                  size: 152,
                  seed: name,
                  borderRadius: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: OmniXTokens.typeBase,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: OmniXTokens.typeSm,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
