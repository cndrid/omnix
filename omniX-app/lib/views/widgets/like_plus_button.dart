import 'package:flutter/material.dart';
import '../../theme/omnix_theme.dart';

/// Tombol suka gaya preview UI v2: lingkaran "+" (bukan hati).
/// Saat lagu sudah disukai, lingkaran jadi hijau dengan tanda centang.
/// Area sentuh 48px, lingkaran visual 32px seperti di preview.
class LikePlusButton extends StatelessWidget {
  final bool isLiked;
  final VoidCallback? onToggle;
  final String? tooltip;

  const LikePlusButton({
    super.key,
    required this.isLiked,
    required this.onToggle,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final button = Semantics(
      button: true,
      selected: isLiked,
      label: isLiked
          ? 'Hapus dari lagu disukai'
          : 'Tambahkan ke lagu disukai',
      child: InkWell(
        onTap: onToggle,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: OmniXTokens.minTouchTarget,
          height: OmniXTokens.minTouchTarget,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLiked ? scheme.secondary : Colors.transparent,
                border: Border.all(
                  color: isLiked
                      ? scheme.secondary
                      : scheme.onSurfaceVariant,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                isLiked ? '✓' : '+',
                style: TextStyle(
                  color: isLiked
                      ? scheme.onSecondary
                      : scheme.onSurfaceVariant,
                  fontSize: isLiked ? 16 : 19,
                  fontWeight:
                      isLiked ? FontWeight.w800 : FontWeight.w500,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Badge eksplisit "E" gaya preview UI v2: huruf E kecil di samping judul.
class ExplicitBadge extends StatelessWidget {
  const ExplicitBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      decoration: BoxDecoration(
        color: OmniXTokens.darkTextSecondary,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'E',
        style: TextStyle(
          color: Color(0xFF0F0F23),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
