import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import '../views/widgets/liquid_glass_box.dart';
import 'pressable.dart';

/// Chip filter (components.md §7): pil Glass 3 tinggi 36 px, teks sm/500.
/// Aktif = isian accent + teks on-accent (berubah fast 150 ms).
/// Focus-visible: cincin 2 px aksen. Toggle yang diumumkan screen reader.
class OmniXFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final String? groupLabel;

  const OmniXFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.groupLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onSelected == null;

    final inner = AnimatedContainer(
      duration: OmniXTokens.motionFast,
      curve: Curves.easeInOut,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: selected
          ? BoxDecoration(
              color: scheme.primary,
              borderRadius:
                  BorderRadius.circular(OmniXTokens.radiusPill),
            )
          : null,
      child: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.onPrimary : scheme.onSurface,
          fontSize: OmniXTokens.typeSm,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    final chip = selected
        ? inner
        : LiquidGlassBox(
            tier: GlassTier.glass3,
            borderRadius: OmniXTokens.radiusPill,
            child: inner,
          );

    return Semantics(
      button: true,
      toggled: selected,
      enabled: !disabled,
      label: groupLabel == null ? label : '$groupLabel: $label',
      child: Opacity(
        opacity: disabled ? 0.4 : 1.0,
        child: Pressable(
          onTap: disabled ? null : () => onSelected!(!selected),
          borderRadius:
              BorderRadius.circular(OmniXTokens.radiusPill),
          enabled: !disabled,
          child: SizedBox(
            height: OmniXTokens.minTouchTarget,
            child: Center(child: chip),
          ),
        ),
      ),
    );
  }
}
