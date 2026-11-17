import 'dart:math' as math;
import 'dart:ui';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../models/track_model.dart';
import '../../providers/app_providers.dart';
import '../../services/stream_extractor.dart';
import '../../theme/omnix_theme.dart';
import 'liquid_glass_box.dart';
import 'track_artwork.dart';

class VideoCanvasStage extends StatefulWidget {
  final TrackModel track;
  final SongDetailModel? detail;
  final PlayerViewState playerState;
  final PlayerController controller;

  const VideoCanvasStage({
    super.key,
    required this.track,
    required this.detail,
    required this.playerState,
    required this.controller,
  });

  @override
  State<VideoCanvasStage> createState() => _VideoCanvasStageState();
}

class _VideoCanvasStageState extends State<VideoCanvasStage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _loadedVideoKey;
  bool _isVideoLoading = false;
  bool _useVisualizerFallback = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
    _syncVideoSource();
  }

  @override
  void didUpdateWidget(covariant VideoCanvasStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.track.videoId != widget.track.videoId ||
        oldWidget.detail?.videoStreamUrl != widget.detail?.videoStreamUrl ||
        oldWidget.playerState.mode != widget.playerState.mode) {
      _syncVideoSource();
    }
    if (oldWidget.playerState.isPlaying != widget.playerState.isPlaying) {
      if (widget.playerState.isPlaying) {
        _videoController?.play();
      } else {
        _videoController?.pause();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _disposeVideo();
    super.dispose();
  }

  void _disposeVideo() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
    _loadedVideoKey = null;
  }

  String? _buildStreamUrl() {
    final fromDetail = widget.detail?.videoStreamUrl;
    if (fromDetail != null && fromDetail.isNotEmpty) {
      return fromDetail;
    }
    final vid = widget.track.videoId;
    if (vid.isNotEmpty && widget.controller.backendBaseUrl.isNotEmpty) {
      final base = widget.controller.backendBaseUrl;
      final titleParam = Uri.encodeComponent(widget.track.title);
      final artistParam = Uri.encodeComponent(widget.track.artistLine);
      return '$base/api/stream-video/$vid?title=$titleParam&artist=$artistParam';
    }
    return null;
  }

  Future<void> _syncVideoSource() async {
    if (widget.playerState.mode == PlaybackMode.canvas) {
      // Canvas uses the 60fps reactive motion visualizer immediately without waiting.
      return;
    }

    // Ekstraksi video di HP dulu (IP pengguna tidak diblokir YouTube);
    // URL dari backend dipakai sebagai fallback kalau ekstraksi gagal.
    final localUrl =
        await StreamExtractor.extractVideoUrl(widget.track.videoId);
    final streamUrl = (localUrl != null && localUrl.isNotEmpty)
        ? localUrl
        : _buildStreamUrl();
    if (streamUrl == null || streamUrl.isEmpty) {
      setState(() {
        _isVideoLoading = false;
        _useVisualizerFallback = true;
      });
      return;
    }
    final key = '${widget.track.videoId}_$streamUrl';
    if (_loadedVideoKey == key && _chewieController != null) {
      return;
    }

    _disposeVideo();
    if (!mounted) return;
    setState(() {
      _isVideoLoading = true;
      _useVisualizerFallback = false;
    });

    try {
      final vCtrl = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
      await vCtrl.initialize().timeout(const Duration(seconds: 12));
      await vCtrl.setVolume(0.0);
      await vCtrl.setLooping(true);
      await vCtrl.seekTo(widget.playerState.position);
      if (widget.playerState.isPlaying) {
        await vCtrl.play();
      }

      final cCtrl = ChewieController(
        videoPlayerController: vCtrl,
        autoPlay: false,
        looping: true,
        showControls: true,
        aspectRatio:
            vCtrl.value.aspectRatio > 0 ? vCtrl.value.aspectRatio : 16 / 9,
      );

      if (!mounted) {
        cCtrl.dispose();
        vCtrl.dispose();
        return;
      }

      setState(() {
        _videoController = vCtrl;
        _chewieController = cCtrl;
        _loadedVideoKey = key;
        _isVideoLoading = false;
        _useVisualizerFallback = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVideoLoading = false;
        _useVisualizerFallback = true;
      });
    }
  }

  String? _activeLyricText() {
    final synced = widget.detail?.syncedLyrics ?? const [];
    if (synced.isEmpty) return null;
    final sec = widget.playerState.position.inSeconds;
    String current = synced.first.text;
    for (final line in synced) {
      if (sec >= line.timeSeconds) {
        current = line.text;
      }
    }
    return current;
  }

  @override
  Widget build(BuildContext context) {
    final isCanvas = widget.playerState.mode == PlaybackMode.canvas;
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: isCanvas ? 420 : 640),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: AspectRatio(
          aspectRatio: isCanvas ? 4 / 4.2 : 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF07080E),
              borderRadius:
                  BorderRadius.circular(OmniXTokens.radiusMiniPlayer),
              border: Border.all(color: scheme.outline),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.28),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(OmniXTokens.radiusMiniPlayer),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: isCanvas
                    ? _buildAnimatedCanvasStage(context, isWideVideo: false)
                    : (_chewieController != null && !_useVisualizerFallback)
                        ? Stack(
                            key: const ValueKey('chewie_video_active'),
                            fit: StackFit.expand,
                            children: [
                              Chewie(controller: _chewieController!),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: LiquidGlassBox(
                                  tier: GlassTier.glass3,
                                  borderRadius: OmniXTokens.radiusPill,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.hd_rounded,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'VIDEO SYNC',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : _buildAnimatedCanvasStage(
                            context,
                            isWideVideo: true,
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedCanvasStage(
    BuildContext context, {
    required bool isWideVideo,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final lyricLine = _activeLyricText();

    return AnimatedBuilder(
      key: ValueKey(isWideVideo ? 'video_visualizer' : 'canvas_visualizer'),
      animation: _animController,
      builder: (context, _) {
        final t = _animController.value;
        final zoom = 1.06 + (0.08 * math.sin(t * 2 * math.pi));
        final offsetX = 10.0 * math.cos(t * 2 * math.pi);
        final offsetY = 8.0 * math.sin(t * 2 * math.pi);

        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Transform.scale(
                scale: zoom,
                child: TrackArtwork(
                  track: widget.track,
                  size: 640,
                  borderRadius: 0,
                ),
              ),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.black.withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),
            Center(
              child: CustomPaint(
                size: const Size(double.infinity, 150),
                painter: _LiquidWaveVisualPainter(
                  phase: t * 2 * math.pi,
                  isPlaying: widget.playerState.isPlaying,
                  accentColor: scheme.primary,
                  secondaryColor: const Color(0xFF00E5FF),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: TrackArtwork(
                      track: widget.track,
                      size: isWideVideo ? 96 : 136,
                      borderRadius: 18,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (lyricLine != null && lyricLine.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        lyricLine,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 12),
                          ],
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        widget.track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              left: 14,
              bottom: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  LiquidGlassBox(
                    tier: GlassTier.glass3,
                    borderRadius: OmniXTokens.radiusPill,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isWideVideo
                              ? Icons.slow_motion_video_rounded
                              : Icons.motion_photos_on_rounded,
                          size: 15,
                          color: const Color(0xFF00E5FF),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isWideVideo
                              ? (_isVideoLoading
                                  ? 'MEMUAT STREAM VIDEO KLIP...'
                                  : 'OMNIX MOTION VIDEO STAGE')
                              : 'OMNIX LIQUID CANVAS · 60 FPS',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isWideVideo && _useVisualizerFallback)
                    FilledButton.tonalIcon(
                      onPressed: _syncVideoSource,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Muat Ulang MP4'),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LiquidWaveVisualPainter extends CustomPainter {
  final double phase;
  final bool isPlaying;
  final Color accentColor;
  final Color secondaryColor;

  const _LiquidWaveVisualPainter({
    required this.phase,
    required this.isPlaying,
    required this.accentColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 28;
    final spacing = 6.0;
    final totalSpacing = spacing * (barCount - 1);
    final barWidth = ((size.width - 48 - totalSpacing) / barCount).clamp(4.0, 14.0);
    final startX = (size.width - ((barWidth * barCount) + totalSpacing)) / 2;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final norm = i / barCount;
      final envelope = math.sin(norm * math.pi);
      final wave = isPlaying
          ? (0.35 +
              0.65 *
                  ((math.sin(phase * 2 + (i * 0.45)) + 1) / 2) *
                  envelope)
          : (0.15 * envelope + 0.08);

      final barHeight = (size.height * 0.78 * wave).clamp(8.0, size.height * 0.85);
      final left = startX + i * (barWidth + spacing);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(left + barWidth / 2, centerY),
          width: barWidth,
          height: barHeight,
        ),
        const Radius.circular(99),
      );

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            secondaryColor.withValues(alpha: 0.75),
            accentColor.withValues(alpha: 0.75),
          ],
        ).createShader(rect.outerRect);

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidWaveVisualPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.isPlaying != isPlaying;
  }
}
