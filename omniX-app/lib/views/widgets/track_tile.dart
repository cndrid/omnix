import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/track_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/omnix_theme.dart';
import 'queue_sheet.dart';
import 'track_artwork.dart';

class TrackTile extends ConsumerStatefulWidget {
  final TrackModel track;
  final String? rankNumber;
  final bool isActive;
  final bool isPlaying;
  final bool isLiked;
  final bool isDownloaded;
  final VoidCallback onPlay;
  final VoidCallback onToggleLike;
  final VoidCallback? onToggleDownload;

  const TrackTile({
    super.key,
    required this.track,
    this.rankNumber,
    required this.isActive,
    required this.isPlaying,
    required this.isLiked,
    this.isDownloaded = false,
    required this.onPlay,
    required this.onToggleLike,
    this.onToggleDownload,
  });

  @override
  ConsumerState<TrackTile> createState() => _TrackTileState();
}

class _TrackTileState extends ConsumerState<TrackTile> {
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: widget.isActive,
      label: 'Putar ${widget.track.title} oleh ${widget.track.artistLine}',
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (focused) => setState(() => _isFocused = focused),
        onShowHoverHighlight: (hovered) => setState(() => _isHovered = hovered),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPlay();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: widget.onPlay,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isActive
                  ? scheme.surfaceContainerHighest
                  : (_isHovered ? scheme.surfaceContainerHighest : scheme.surface),
              borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
              border: Border.all(
                color: _isFocused
                    ? scheme.tertiary
                    : (widget.isActive ? scheme.primary : scheme.outline),
                width: _isFocused || widget.isActive ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                if (widget.rankNumber != null) ...[
                  SizedBox(
                    width: 28,
                    child: Text(
                      widget.rankNumber!,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                SizedBox(
                  width: 50,
                  height: 50,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TrackArtwork(
                        track: widget.track,
                        size: 50,
                        borderRadius: OmniXTokens.radiusThumb,
                      ),
                      if (widget.isActive)
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(OmniXTokens.radiusThumb),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.58),
                            alignment: Alignment.center,
                            child: Icon(
                              widget.isPlaying ? Icons.equalizer : Icons.pause,
                              color: Colors.white,
                              size: 24,
                              semanticLabel: widget.isPlaying
                                  ? 'Sedang diputar'
                                  : 'Dijeda',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (widget.isActive) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                widget.isPlaying ? 'AKTIF' : 'JEDA',
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              widget.track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
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
                              semanticLabel: 'Tersimpan offline',
                            ),
                            const SizedBox(width: 4),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: scheme.outline),
                            ),
                            child: Text(
                              widget.track.audioQualityBadge,
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.track.album != null
                                  ? '${widget.track.artistLine} · ${widget.track.album!.name}'
                                  : widget.track.artistLine,
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
                if (widget.track.duration != null &&
                    widget.track.duration!.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    widget.track.duration!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                PopupMenuButton<String>(
                  tooltip: 'Tambah ke Antrean (${widget.track.title})',
                  icon: Icon(
                    Icons.playlist_add_rounded,
                    color: scheme.onSurface,
                    size: 22,
                  ),
                  onSelected: (action) {
                    final ctrl = ref.read(playerControllerProvider.notifier);
                    if (action == 'next') {
                      ctrl.playNextInQueue(widget.track);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Diputar berikutnya: ${widget.track.title}',
                          ),
                          action: SnackBarAction(
                            label: 'Lihat Antrean',
                            onPressed: () => showQueueManagerSheet(context, ref),
                          ),
                        ),
                      );
                    } else if (action == 'queue') {
                      ctrl.addToQueue(widget.track);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Ditambahkan ke antrean: ${widget.track.title}',
                          ),
                          action: SnackBarAction(
                            label: 'Lihat Antrean',
                            onPressed: () => showQueueManagerSheet(context, ref),
                          ),
                        ),
                      );
                    } else if (action == 'view_queue') {
                      showQueueManagerSheet(context, ref);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'next',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.playlist_play_rounded),
                        title: Text('Putar Berikutnya (Play Next)'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'queue',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.add_to_queue_rounded),
                        title: Text('Tambahkan ke Antrean (Add to Queue)'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'view_queue',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.queue_music_rounded),
                        title: Text('Buka Daftar Antrean'),
                      ),
                    ),
                  ],
                ),
                if (widget.onToggleDownload != null)
                  IconButton(
                    tooltip: widget.isDownloaded
                        ? 'Hapus unduhan offline ${widget.track.title}'
                        : 'Unduh offline ${widget.track.title} (Gratis FLAC)',
                    onPressed: widget.onToggleDownload,
                    icon: Icon(
                      widget.isDownloaded
                          ? Icons.download_done_rounded
                          : Icons.download_for_offline_outlined,
                      color: widget.isDownloaded
                          ? scheme.secondary
                          : scheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                IconButton(
                  tooltip: widget.isLiked
                      ? 'Hapus ${widget.track.title} dari lagu disukai'
                      : 'Simpan ${widget.track.title} ke lagu disukai',
                  onPressed: widget.onToggleLike,
                  icon: Icon(
                    widget.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: widget.isLiked
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                    size: 20,
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
