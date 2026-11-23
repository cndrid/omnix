import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import '../views/widgets/liquid_glass_box.dart';
import 'feedback_states.dart';
import 'pressable.dart';

/// Gaya tombol Putar (components.md §9).
enum PlayButtonStyle {
  /// Lingkaran hijau play (72 px pemutar penuh / 40 px mini player).
  filled,

  /// Lingkaran kaca Glass 3 44 px (Putar cepat di sudut sampul kartu).
  glass,
}

/// Tombol Putar/Jeda.
///
/// Ikon di atas hijau memakai [OmniXTokens.onPlay] (GELAP) — putih di atas
/// hijau hanya 2,28:1 dan gagal kontras. State buffering memakai skeleton
/// seukuran tombol, bukan spinner. Label aksesibel menyebut tindakan dan
/// judul lagu ("Putar, [judul]").
class PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isBuffering;
  final double size;
  final PlayButtonStyle style;
  final String trackTitle;
  final VoidCallback? onPressed;

  const PlayButton({
    super.key,
    required this.isPlaying,
    required this.trackTitle,
    required this.onPressed,
    this.size = 72,
    this.style = PlayButtonStyle.filled,
    this.isBuffering = false,
  });

  /// 72 px — pemutar penuh.
  const PlayButton.large({
    super.key,
    required this.isPlaying,
    required this.trackTitle,
    required this.onPressed,
    this.isBuffering = false,
  })  : size = 72,
        style = PlayButtonStyle.filled;

  /// 40 px — mini player / baris.
  const PlayButton.small({
    super.key,
    required this.isPlaying,
    required this.trackTitle,
    required this.onPressed,
    this.isBuffering = false,
  })  : size = 40,
        style = PlayButtonStyle.filled;

  /// 44 px kaca — Putar cepat di kartu konten.
  const PlayButton.quick({
    super.key,
    required this.isPlaying,
    required this.trackTitle,
    required this.onPressed,
    this.isBuffering = false,
  })  : size = 44,
        style = PlayButtonStyle.glass;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onPressed == null;
    final iconSize = size >= 72 ? 32.0 : 24.0;
    final label =
        '${isPlaying ? 'Jeda' : 'Putar'}, $trackTitle';

    final Widget visual;
    if (isBuffering) {
      visual = OmniXSkeleton.circle(size: size);
    } else if (style == PlayButtonStyle.glass) {
      visual = LiquidGlassBox(
        tier: GlassTier.glass3,
        borderRadius: OmniXTokens.radiusPill,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: iconSize,
            color: scheme.onSurface,
          ),
        ),
      );
    } else {
      visual = Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: OmniXTokens.playGreen,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: iconSize,
          // GELAP di atas hijau — bukan putih (lihat komentar kelas).
          color: OmniXTokens.onPlay,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Pressable(
          onTap: disabled || isBuffering ? null : onPressed,
          borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
          enabled: !disabled && !isBuffering,
          child: SizedBox(
            width: size < OmniXTokens.minTouchTarget
                ? OmniXTokens.minTouchTarget
                : size,
            height: size < OmniXTokens.minTouchTarget
                ? OmniXTokens.minTouchTarget
                : size,
            child: Center(child: visual),
          ),
        ),
      ),
    );
  }
}
