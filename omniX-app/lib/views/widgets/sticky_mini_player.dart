import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/omnix_theme.dart';
import 'liquid_glass_box.dart';
import 'like_plus_button.dart';
import 'queue_sheet.dart';
import 'sleep_timer_sheet.dart';
import 'track_artwork.dart';

class StickyMiniPlayer extends ConsumerStatefulWidget {
  const StickyMiniPlayer({super.key});

  @override
  ConsumerState<StickyMiniPlayer> createState() => _StickyMiniPlayerState();
}

class _StickyMiniPlayerState extends ConsumerState<StickyMiniPlayer> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final track = playerState.currentTrack;
    if (track == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(playerControllerProvider.notifier);
    final library = ref.watch(libraryProvider);
    final engine = ref.watch(audioEngineProvider);
    final isLiked = library.isLiked(track.videoId);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      container: true,
      label: 'Pemutar mini melayang: ${track.title} oleh ${track.artistLine}. Ketuk untuk membuka layar Sedang Diputar.',
      child: GestureDetector(
        onTap: controller.openFullscreen,
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -180) {
            controller.openFullscreen();
          }
        },
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (f) => setState(() => _isFocused = f),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                controller.openFullscreen();
                return null;
              },
            ),
          },
          child: LiquidGlassBox(
            tier: GlassTier.glass1,
            borderRadius: OmniXTokens.radiusMiniPlayer,
            elevatedShadow: true,
            child: Container(
              decoration: _isFocused
                  ? BoxDecoration(
                      border: Border.all(color: scheme.tertiary, width: 2),
                      borderRadius: BorderRadius.circular(
                        OmniXTokens.radiusMiniPlayer,
                      ),
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        TrackArtwork(
                          track: track,
                          size: 48,
                          borderRadius: OmniXTokens.radiusThumb,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.speaker_group_outlined,
                                    size: 13,
                                    color: scheme.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      playerState.isLoadingTrack
                                          ? 'Memuat Lossless stream...'
                                          : '${track.artistLine} · ${engine.activeDeviceName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Opsi Pemutaran (Titik 3)',
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: playerState.isSleepTimerActive
                                ? scheme.secondary
                                : scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          onSelected: (action) {
                            if (action == 'sleep_timer') {
                              showSleepTimerDialog(context, ref);
                            } else if (action == 'queue') {
                              showQueueManagerSheet(context, ref);
                            } else if (action == 'radio') {
                              controller.startSongRadio(track.videoId);
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'sleep_timer',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                  Icons.bedtime_outlined,
                                  color: playerState.isSleepTimerActive
                                      ? scheme.secondary
                                      : null,
                                ),
                                title: Text(
                                  playerState.isSleepTimerActive
                                      ? 'Sleep Timer (${playerState.formattedSleepTimer})'
                                      : 'Sleep Timer',
                                ),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'queue',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.queue_music_rounded),
                                title: Text(
                                  'Antrean (${playerState.queue.length})',
                                ),
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'radio',
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(Icons.radio_rounded),
                                title: Text('Mulai Radio Lagu'),
                              ),
                            ),
                          ],
                        ),
                        // Suka pakai "+" (preview v2), bukan hati.
                        LikePlusButton(
                          isLiked: isLiked,
                          onToggle: () {
                            ref
                                .read(libraryProvider.notifier)
                                .toggleLike(track);
                          },
                          tooltip: isLiked
                              ? 'Hapus dari lagu disukai'
                              : 'Tambahkan ke lagu disukai',
                        ),
                        IconButton(
                          tooltip: playerState.isPlaying ? 'Jeda lagu' : 'Putar lagu',
                          onPressed: playerState.isLoadingTrack
                              ? null
                              : controller.togglePlayPause,
                          icon: playerState.isLoadingTrack
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: scheme.secondary,
                                  ),
                                )
                              : Icon(
                                  playerState.isPlaying
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_fill_rounded,
                                  color: scheme.secondary,
                                  size: 32,
                                ),
                        ),
                        IconButton(
                          tooltip: 'Lagu berikutnya',
                          onPressed: controller.skipNext,
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: scheme.onSurface,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LinearProgressIndicator(
                    value: playerState.progressFraction,
                    minHeight: 2.5,
                    backgroundColor: scheme.outline.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(scheme.secondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
