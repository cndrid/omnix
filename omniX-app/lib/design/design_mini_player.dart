import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import '../views/widgets/liquid_glass_box.dart';
import '../views/widgets/like_plus_button.dart';
import 'design_artwork.dart';
import 'play_button.dart';

/// Mini player primitif (components.md §4), terisolasi dari pemutar asli:
/// Glass 1 radius 16 px, tinggi 64 px, sampul 48 px radius artwork 4 px,
/// judul + artis, tombol Suka + Putar/Jeda 40 px + Berikutnya, progress
/// 2 px di tepi bawah. Marquee judul hanya saat diputar (30 px/detik)
/// dan hanya bila judul terpotong; berhenti saat dijeda / reduced motion.
class DesignMiniPlayer extends StatefulWidget {
  final String title;
  final String artist;
  final double progress;
  final bool isPlaying;
  final bool isLiked;
  final VoidCallback? onOpen;
  final VoidCallback? onNext;

  const DesignMiniPlayer({
    super.key,
    required this.title,
    required this.artist,
    this.progress = 0,
    this.isPlaying = false,
    this.isLiked = false,
    this.onOpen,
    this.onNext,
  });

  @override
  State<DesignMiniPlayer> createState() => _DesignMiniPlayerState();
}

class _DesignMiniPlayerState extends State<DesignMiniPlayer> {
  late bool _isPlaying;
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isPlaying = widget.isPlaying;
    _isLiked = widget.isLiked;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      button: true,
      label: 'Sedang diputar: ${widget.title}, ${widget.artist}',
      child: GestureDetector(
        onTap: widget.onOpen,
        child: LiquidGlassBox(
          tier: GlassTier.glass1,
          borderRadius: OmniXTokens.radiusMiniPlayer,
          elevatedShadow: true,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        DesignArtworkPlaceholder(
                          size: 48,
                          seed: widget.title,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _MarqueeTitle(
                                text: widget.title,
                                isPlaying: _isPlaying,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: OmniXTokens.typeSm,
                                ),
                              ),
                            ],
                          ),
                        ),
                        LikeHeartButton(
                          isLiked: _isLiked,
                          trackTitle: widget.title,
                          onToggle: () async {
                            setState(() => _isLiked = !_isLiked);
                            return true;
                          },
                        ),
                        PlayButton.small(
                          isPlaying: _isPlaying,
                          trackTitle: widget.title,
                          onPressed: () => setState(
                            () => _isPlaying = !_isPlaying,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Berikutnya',
                          onPressed: widget.onNext,
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: scheme.onSurface,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                LinearProgressIndicator(
                  value: widget.progress.clamp(0, 1),
                  minHeight: 2,
                  backgroundColor: scheme.outline.withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    OmniXTokens.playGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Judul yang berjalan (marquee) hanya bila terpotong dan sedang diputar.
/// Kecepatan token: 30 px/detik.
class _MarqueeTitle extends StatefulWidget {
  final String text;
  final bool isPlaying;

  const _MarqueeTitle({required this.text, required this.isPlaying});

  @override
  State<_MarqueeTitle> createState() => _MarqueeTitleState();
}

class _MarqueeTitleState extends State<_MarqueeTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _overflow = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _MarqueeTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
    _syncPlaying();
  }

  void _measure() {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final painter = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: const TextStyle(
          fontSize: OmniXTokens.typeBase,
          fontWeight: FontWeight.w600,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    final overflow = painter.width - box.size.width;
    setState(() => _overflow = overflow > 0 ? overflow + 32 : 0);
    _syncPlaying();
  }

  void _syncPlaying() {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (!widget.isPlaying || _overflow <= 0 || reducedMotion) {
      _controller.stop();
      _controller.reset();
      return;
    }
    _controller.duration = Duration(
      milliseconds:
          (_overflow / OmniXTokens.marqueeSpeedPxPerSecond * 1000)
              .round(),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = TextStyle(
      color: scheme.onSurface,
      fontSize: OmniXTokens.typeBase,
      fontWeight: FontWeight.w600,
    );
    if (_overflow <= 0 || !widget.isPlaying) {
      return Text(
        widget.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Maju sekali lalu kembali: offset 0 -> -overflow -> 0.
          final t = _controller.value;
          final offset = t < 0.5 ? -_overflow * (t * 2) : -_overflow * (2 - t * 2);
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: Text(widget.text, maxLines: 1, style: style),
      ),
    );
  }
}
