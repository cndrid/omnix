import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';

/// Sampul placeholder untuk primitif showcase: gradien dari warna tema
/// (bukan sampul asli) + ikon not musik, supaya primitif tidak bergantung
/// pada model lagu / jaringan.
class DesignArtworkPlaceholder extends StatelessWidget {
  final double size;
  final String seed;
  final double borderRadius;

  const DesignArtworkPlaceholder({
    super.key,
    required this.size,
    required this.seed,
    this.borderRadius = OmniXTokens.radiusThumb,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.secondary],
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: size * 0.4,
      ),
    );
  }
}
