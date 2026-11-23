import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import 'omni_x_button.dart';

/// Skeleton loading — satu-satunya animasi berulang yang diizinkan selain
/// equalizer (tokens.json: siklus 1200 ms, berkedip lembut, warna
/// surface-elevated). Disembunyikan dari screen reader; ukuran dan radius
/// mengikuti komponen yang digantikannya.
class OmniXSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadiusGeometry borderRadius;

  const OmniXSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  /// Skeleton lingkaran (avatar / tombol putar).
  const OmniXSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  @override
  State<OmniXSkeleton> createState() => _OmniXSkeletonState();
}

class _OmniXSkeletonState extends State<OmniXSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: OmniXTokens.skeletonCycle,
    );
    // Berkedip lembut selama terlihat; saat reduced motion, build()
    // mengembalikan kotak statis sehingga animasinya tidak terlihat.
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: widget.borderRadius,
      ),
    );
    if (reducedMotion) return ExcludeSemantics(child: box);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: 0.45 + 0.55 * _controller.value,
          child: child,
        ),
        child: box,
      ),
    );
  }
}

/// Empty state: ikon 64 px + judul + satu kalimat + satu tombol utama.
/// Masuk fade-in standard 250 ms (components.md §22).
class OmniXEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback? onAction;

  const OmniXEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: OmniXTokens.typeLg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: OmniXTokens.typeBase,
              ),
            ),
            const SizedBox(height: 24),
            OmniXButton(
              label: actionLabel,
              variant: OmniXButtonVariant.primary,
              size: OmniXButtonSize.lg,
              onPressed: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

/// Error state netral (components.md §23): latar surface-elevated + ikon
/// warna danger + teks warna text — BUKAN bar merah penuh. Selalu ada
/// tombol pemulihan ("Coba Lagi").
class OmniXErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;
  final bool isRetrying;

  const OmniXErrorState({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel = 'Coba Lagi',
    required this.onRetry,
    this.isRetrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Terjadi kesalahan: $title. $message',
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(OmniXTokens.radiusCard),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: scheme.error,
              semanticLabel: 'Gagal memuat',
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: OmniXTokens.typeLg,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: OmniXTokens.typeBase,
              ),
            ),
            const SizedBox(height: 24),
            if (isRetrying)
              const OmniXSkeleton(width: 140, height: 40)
            else
              OmniXButton(
                label: retryLabel,
                variant: OmniXButtonVariant.secondary,
                size: OmniXButtonSize.md,
                onPressed: onRetry,
              ),
          ],
        ),
      ),
    );
  }
}

/// Bar error tipis di atas mini player (gagal putar): latar
/// surface-elevated, teks warna text, ikon danger, tombol "Coba Lagi".
class OmniXErrorBar extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const OmniXErrorBar({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Gagal memutar: $message',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(OmniXTokens.radiusInput),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: scheme.error,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: OmniXTokens.typeSm,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
