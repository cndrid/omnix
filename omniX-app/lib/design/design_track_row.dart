import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import '../views/widgets/like_plus_button.dart';
import 'design_artwork.dart';
import 'omni_x_bottom_sheet.dart';
import 'pressable.dart';

/// Baris lagu primitif (components.md §29): tinggi 64 px, sampul 48 px
/// radius artwork 4 px, judul + artis/durasi, tombol Suka, menu "...".
/// State diputar: judul accent-bright + equalizer 3 batang (berhenti
/// saat dijeda / reduced motion). State diunduh: ikon centang.
/// Eksplisit: badge E (dipakai ulang dari [ExplicitBadge]).
class DesignTrackRow extends StatefulWidget {
  final String title;
  final String artist;
  final String duration;
  final bool isPlaying;
  final bool isActive;
  final bool isDownloaded;
  final bool isExplicit;
  final bool isLiked;
  final VoidCallback? onPlay;

  const DesignTrackRow({
    super.key,
    required this.title,
    required this.artist,
    required this.duration,
    this.isPlaying = false,
    this.isActive = false,
    this.isDownloaded = false,
    this.isExplicit = false,
    this.isLiked = false,
    required this.onPlay,
  });

  @override
  State<DesignTrackRow> createState() => _DesignTrackRowState();
}

class _DesignTrackRowState extends State<DesignTrackRow> {
  late bool _isLiked;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleColor = widget.isActive
        ? scheme.tertiary
        : scheme.onSurface;

    return Semantics(
      button: true,
      selected: widget.isActive,
      label:
          '${widget.title}, ${widget.artist}, ${widget.duration}'
          '${widget.isActive ? (widget.isPlaying ? ', sedang diputar' : ', dijeda') : ''}'
          '${widget.isDownloaded ? ', diunduh' : ''}',
      child: Pressable(
        onTap: widget.onPlay,
        borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
        child: Container(
          height: 64,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  DesignArtworkPlaceholder(size: 48, seed: widget.title),
                  if (widget.isActive)
                    EqualizerBars(
                      isPlaying: widget.isPlaying,
                      color: scheme.tertiary,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: OmniXTokens.typeBase,
                              fontWeight: widget.isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (widget.isExplicit) ...[
                          const SizedBox(width: 5),
                          const ExplicitBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (widget.isDownloaded) ...[
                          Icon(
                            Icons.download_done_rounded,
                            size: 14,
                            color: scheme.secondary,
                            semanticLabel: 'Diunduh',
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            '${widget.artist} · ${widget.duration}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: OmniXTokens.typeSm,
                            ),
                          ),
                        ),
                      ],
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
              IconButton(
                tooltip: 'Opsi lainnya, ${widget.title}',
                onPressed: () => showTrackMenuSheet(
                  context: context,
                  trackTitle: widget.title,
                  onPlayNext: () {},
                  onAddToQueue: () {},
                  onAddToPlaylist: () {},
                  onShare: () {},
                ),
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Equalizer 3 batang (components.md §29): warna accent-bright, bergerak
/// selama lagu diputar; membeku saat dijeda dan mati saat reduced motion.
/// Satu dari dua animasi berulang yang diizinkan (satunya skeleton).
class EqualizerBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const EqualizerBars({
    super.key,
    required this.isPlaying,
    required this.color,
  });

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (reducedMotion || !widget.isPlaying) {
      return _bars(0.5);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => _bars(_controller.value),
      child: null,
    );
  }

  Widget _bars(double t) {
    // Tiga batang dengan fase berbeda; tinggi 4–14 px.
    final heights = <double>[
      4 + 10 * _wave(t),
      4 + 10 * _wave((t + 0.33) % 1),
      4 + 10 * _wave((t + 0.66) % 1),
    ];
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius:
            BorderRadius.circular(OmniXTokens.radiusThumb),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in heights) ...[
            Container(
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }

  double _wave(double t) =>
      (0.5 - 0.5 * math.cos(t * 2 * math.pi)).clamp(0, 1);
}
