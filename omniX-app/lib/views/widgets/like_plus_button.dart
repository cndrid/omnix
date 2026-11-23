import 'package:flutter/material.dart';
import '../../theme/omnix_theme.dart';

/// Tombol Suka — ikon HATI (components.md §10, keputusan Pak 23 Nov 2026).
///
/// Belum suka: hati outline warna text-muted. Sudah suka: hati filled
/// warna accent-bright (token `tertiary` di tema). Ikon 24px (44px di
/// pemutar bila [large]), area sentuh selalu 48px.
///
/// Perilaku pop: [onToggle] mengembalikan `true` bila state suka berhasil
/// berubah & tersimpan. Pop skala 120% lalu kembali 100% (standard 250ms)
/// baru dimainkan SETELAH [onToggle] selesai — saat masih menyimpan, ikon
/// tetap tampil tanpa animasi; bila simpan gagal (`false`/throw), hati
/// tidak pop dan kembali ke state semula (pemanggil menampilkan toast).
class LikeHeartButton extends StatefulWidget {
  final bool isLiked;

  /// Dipanggil saat diketuk. Kembalikan `true` bila like berhasil
  /// disimpan (state berubah), `false` bila gagal/dibatalkan.
  final Future<bool> Function()? onToggle;

  /// Judul lagu — dipakai label aksesibilitas "Suka, [judul]" /
  /// "Batal suka, [judul]".
  final String trackTitle;

  /// `true` di pemutar (ikon 44px); `false` di baris/mini player (24px).
  final bool large;

  final String? tooltip;

  const LikeHeartButton({
    super.key,
    required this.isLiked,
    required this.onToggle,
    required this.trackTitle,
    this.large = false,
    this.tooltip,
  });

  @override
  State<LikeHeartButton> createState() => _LikeHeartButtonState();
}

class _LikeHeartButtonState extends State<LikeHeartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _popController;
  late final Animation<double> _popScale;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pop 120% -> 100% dalam standard 250ms (token motionStandard).
    _popController = AnimationController(
      vsync: this,
      duration: OmniXTokens.motionStandard,
    );
    _popScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0),
        weight: 1,
      ),
    ]).animate(_popController);
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_saving || widget.onToggle == null) return;
    setState(() => _saving = true);
    bool ok = false;
    try {
      ok = await widget.onToggle!();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    // Pop hanya bila simpan berhasil; gagal = hati diam di state semula.
    if (ok && !MediaQuery.disableAnimationsOf(context)) {
      await _popController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconSize = widget.large ? 44.0 : 24.0;
    final label = widget.isLiked
        ? 'Batal suka, ${widget.trackTitle}'
        : 'Suka, ${widget.trackTitle}';

    final button = Semantics(
      button: true,
      selected: widget.isLiked,
      label: label,
      child: InkWell(
        onTap: _handleTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: OmniXTokens.minTouchTarget,
          height: OmniXTokens.minTouchTarget,
          child: Center(
            child: ScaleTransition(
              scale: _popScale,
              child: Icon(
                widget.isLiked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                size: iconSize,
                color: widget.isLiked
                    ? scheme.tertiary
                    : scheme.onSurfaceVariant,
                semanticLabel: label,
              ),
            ),
          ),
        ),
      ),
    );
    return Tooltip(message: widget.tooltip ?? label, child: button);
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
