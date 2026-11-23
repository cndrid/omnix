import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';

/// Slider seek / volume (components.md §13): track 4 px, thumb 12 px
/// (membesar 16 px saat diseret, kembali fast 150 ms saat dilepas),
/// area sentuh tinggi 24 px, warna play. Waktu berjalan/total di ujung
/// (sm, text-muted). Slider nyata: bisa digeser keyboard dan screen
/// reader mengumumkan posisi dalam menit:detik.
class OmniXSeekSlider extends StatefulWidget {
  final double value;
  final double max;
  final ValueChanged<double>? onChanged;
  final String label;
  final bool showTimes;

  const OmniXSeekSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.label = 'Posisi lagu',
    this.showTimes = true,
  });

  @override
  State<OmniXSeekSlider> createState() => _OmniXSeekSliderState();
}

class _OmniXSeekSliderState extends State<OmniXSeekSlider> {
  bool _dragging = false;

  static String _format(double seconds) {
    final total = seconds.round();
    final minutes = total ~/ 60;
    final secs = total % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = widget.onChanged != null && widget.max > 0;

    final slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 4,
        activeTrackColor: OmniXTokens.playGreen,
        inactiveTrackColor: scheme.outline,
        thumbColor: OmniXTokens.playGreen,
        overlayColor: OmniXTokens.playGreen.withValues(alpha: 0.14),
        thumbShape: _OmniXThumbShape(
          radius: _dragging ? 8 : 6,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
      ),
      child: Slider(
        value: widget.value.clamp(0, widget.max),
        min: 0,
        max: widget.max,
        label: widget.label,
        semanticFormatterCallback: (value) => _format(value),
        onChanged: enabled ? widget.onChanged : null,
        onChangeStart: enabled
            ? (_) {
                if (mounted) setState(() => _dragging = true);
              }
            : null,
        onChangeEnd: enabled
            ? (_) {
                if (mounted) setState(() => _dragging = false);
              }
            : null,
      ),
    );

    final sliderWithSemantics = Semantics(
      label: widget.label,
      slider: true,
      enabled: enabled,
      child: SizedBox(
        height: 24,
        child: slider,
      ),
    );

    if (!widget.showTimes) return sliderWithSemantics;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sliderWithSemantics,
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _format(widget.value),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: OmniXTokens.typeSm,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              _format(widget.max),
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: OmniXTokens.typeSm,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Thumb bulat yang radiusnya mengikuti state seret (12 px diam,
/// 16 px diseret). Perubahan ukuran dianimasikan fast 150 ms oleh
/// AnimatedContainer di dalam shape tidak tersedia, jadi perubahan
/// terjadi bersama rebuild saat drag mulai/berakhir.
class _OmniXThumbShape extends SliderComponentShape {
  final double radius;

  const _OmniXThumbShape({required this.radius});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      Size.fromRadius(radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = sliderTheme.thumbColor ?? OmniXTokens.playGreen,
    );
  }
}
