import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import '../views/widgets/liquid_glass_box.dart';
import 'feedback_states.dart';
import 'pressable.dart';

/// Varian tombol umum (components.md §33).
enum OmniXButtonVariant { primary, secondary, ghost, danger }

/// Ukuran tombol: tinggi visual sm 32 / md 40 / lg 48. Area sentuh selalu
/// minimal 48 px (token touch) — tombol kecil dipusatkan dalam area 48 px.
enum OmniXButtonSize { sm, md, lg }

/// Tombol umum OmniX. Semua warna/ukuran/durasi dari token; tidak ada
/// nilai mentah. States: default, ditekan (skala 97%, 100 ms),
/// focus-visible (cincin 2 px aksen), disabled (opacity 40%),
/// loading (skeleton seukuran tombol, label tetap terbaca screen reader).
class OmniXButton extends StatelessWidget {
  final String label;
  final OmniXButtonVariant variant;
  final OmniXButtonSize size;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final String? semanticLabel;

  const OmniXButton({
    super.key,
    required this.label,
    this.variant = OmniXButtonVariant.primary,
    this.size = OmniXButtonSize.md,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.semanticLabel,
  });

  double get _height => switch (size) {
        OmniXButtonSize.sm => 32,
        OmniXButtonSize.md => 40,
        OmniXButtonSize.lg => 48,
      };

  double get _horizontalPadding => switch (size) {
        OmniXButtonSize.sm => 16,
        OmniXButtonSize.md => 20,
        OmniXButtonSize.lg => 24,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onPressed == null && !isLoading;

    final (Color fill, Color textColor, bool isGlass) = switch (variant) {
      OmniXButtonVariant.primary => (scheme.primary, scheme.onPrimary, false),
      OmniXButtonVariant.secondary =>
        (Colors.transparent, scheme.onSurface, true),
      OmniXButtonVariant.ghost => (Colors.transparent, scheme.tertiary, false),
      OmniXButtonVariant.danger => (
          scheme.error,
          isDark ? OmniXTokens.darkOnDanger : Colors.white,
          false,
        ),
    };

    final labelStyle = TextStyle(
      color: textColor,
      fontSize: size == OmniXButtonSize.lg
          ? OmniXTokens.typeBase
          : OmniXTokens.typeSm,
      fontWeight: FontWeight.w600,
    );

    final content = isLoading
        ? OmniXSkeleton(
            width: 96,
            height: _height - 16,
            borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: textColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ],
          );

    final visual = isGlass
        ? LiquidGlassBox(
            tier: GlassTier.glass3,
            borderRadius: OmniXTokens.radiusPill,
            padding: EdgeInsets.symmetric(
              horizontal: _horizontalPadding,
              vertical: 0,
            ),
            child: SizedBox(
              height: _height,
              child: Center(child: content),
            ),
          )
        : Container(
            height: _height,
            padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
            decoration: BoxDecoration(
              color: fill,
              borderRadius:
                  BorderRadius.circular(OmniXTokens.radiusPill),
            ),
            alignment: Alignment.center,
            child: content,
          );

    final button = Semantics(
      button: true,
      enabled: !disabled,
      label: semanticLabel ?? label,
      child: Pressable(
        onTap: disabled || isLoading ? null : onPressed,
        borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
        enabled: !disabled && !isLoading,
        child: SizedBox(
          height: OmniXTokens.minTouchTarget,
          child: Center(child: visual),
        ),
      ),
    );

    // Loading: label tetap diumumkan screen reader walau visualnya
    // skeleton; disabled: opacity 40% (components.md §33).
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: isLoading
          ? Semantics(label: semanticLabel ?? label, child: button)
          : button,
    );
  }
}
