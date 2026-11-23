import 'package:flutter/material.dart';
import '../views/widgets/liquid_glass_box.dart';

/// Kartu kaca — pembungkus tipis di atas [LiquidGlassBox] yang sudah ada
/// (resep kaca sudah benar, jangan diduplikasi).
///
/// - [GlassTier.glass1]: navbar / mini player;
/// - [GlassTier.glass2]: panel / sheet;
/// - [GlassTier.glass3]: chip / tombol bulat.
/// Di belakang kaca selalu ada tint tipis warna dominan sampul
/// (opacity 8–15%) — lewatkan lewat [tintColor].
class GlassCard extends StatelessWidget {
  final Widget child;
  final GlassTier tier;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? tintColor;
  final bool elevatedShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.tier = GlassTier.glass2,
    required this.borderRadius,
    this.padding,
    this.tintColor,
    this.elevatedShadow = false,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassBox(
      tier: tier,
      borderRadius: borderRadius,
      padding: padding,
      tintColor: tintColor,
      elevatedShadow: elevatedShadow,
      child: child,
    );
  }
}
