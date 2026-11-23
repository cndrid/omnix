import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';

/// Pembungkus tekan + fokus bersama untuk semua primitif desain.
///
/// Perilaku (tokens.json / components.md §33):
/// - ditekan: skala 97% selama [OmniXTokens.motionInstant] (100 ms);
/// - focus-visible: cincin 2 px warna aksen ([ColorScheme.tertiary] =
///   accent-bright gelap / accent terang) di luar komponen;
/// - tidak ada warna/ukuran mentah di sini — semua dari token/tema.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadiusGeometry borderRadius;
  final bool enabled;

  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.borderRadius,
    this.enabled = true,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.enabled && widget.onTap != null;

    return Focus(
      onFocusChange: (focused) {
        if (_focused != focused && mounted) {
          setState(() => _focused = focused);
        }
      },
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: OmniXTokens.motionInstant,
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: _focused
                  ? Border.all(color: scheme.tertiary, width: 2)
                  : null,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
