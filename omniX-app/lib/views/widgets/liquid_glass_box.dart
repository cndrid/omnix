import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';

enum GlassTier {
  // Blur 24px, Fill 12%, Border 25% (Floating Pill Navbar & Stacked Mini Player)
  glass1,
  // Blur 24px, Fill 16%, Border 20% (Panels, Bottom Sheets & Synced Lyrics)
  glass2,
  // Blur 16px, Fill 18%, Border 30% (Chips, Small Icon Buttons & Interactive Badges)
  glass3,
}

class LiquidGlassBox extends ConsumerWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final GlassTier tier;
  final bool elevatedShadow;
  final Color? tintColor;

  const LiquidGlassBox({
    super.key,
    required this.child,
    required this.borderRadius,
    this.padding,
    this.tier = GlassTier.glass1,
    this.elevatedShadow = false,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reducedTransparency = ref.watch(reducedTransparencyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final (double sigma, double fillOpacity, double borderOpacity) = switch (tier) {
      GlassTier.glass1 => (24.0, 0.12, 0.25),
      GlassTier.glass2 => (24.0, 0.16, 0.20),
      GlassTier.glass3 => (16.0, 0.18, 0.30),
    };

    final Color baseFill = reducedTransparency
        ? scheme.surface
        : (isDark
            ? (tintColor ?? Colors.white).withValues(alpha: fillOpacity)
            : Colors.white.withValues(alpha: 0.86));

    final Color borderColor = reducedTransparency
        ? scheme.outline
        : (isDark
            ? Colors.white.withValues(alpha: borderOpacity)
            : Colors.black.withValues(alpha: 0.14));

    final container = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: baseFill,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: elevatedShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (reducedTransparency) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: container,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: container,
      ),
    );
  }
}
