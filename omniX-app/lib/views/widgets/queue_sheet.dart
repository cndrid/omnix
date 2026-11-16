import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/track_model.dart';
import '../../providers/app_providers.dart';
import '../../theme/omnix_theme.dart';
import 'track_artwork.dart';

Future<void> showQueueManagerSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(OmniXTokens.radiusMiniPlayer),
      ),
    ),
    builder: (ctx) {
      return const FractionallySizedBox(
        heightFactor: 0.82,
        child: QueueManagerPanel(),
      );
    },
  );
}

class QueueManagerPanel extends ConsumerWidget {
  const QueueManagerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final exploreData = ref.watch(exploreDataProvider).valueOrNull;
    final suggestedTracks = [
      for (final sec in exploreData?.sections ?? const <ExploreSectionModel>[])
        ...sec.items,
    ];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final queue = playerState.queue;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Antrean Pemutaran (${queue.length} Lagu)',
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      'Seret ikon garis untuk mengubah urutan atau tambahkan lagu di bawah',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (queue.length > 1)
                OutlinedButton.icon(
                  onPressed: controller.clearUpcomingQueue,
                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Bersihkan'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 6,
            child: queue.isEmpty
                ? Center(
                    child: Text(
                      'Antrean masih kosong. Pilih lagu dari rekomendasi di bawah untuk langsung ditambahkan.',
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  )
                : ReorderableListView.builder(
                    itemCount: queue.length,
                    onReorder: controller.reorderQueue,
                    itemBuilder: (context, index) {
                      final item = queue[index];
                      final isCurrent =
                          playerState.currentTrack?.videoId == item.videoId &&
                              index == playerState.currentIndex;
                      return ListTile(
                        key: ValueKey('q_item_${item.videoId}_$index'),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCurrent
                                  ? Icons.equalizer_rounded
                                  : Icons.drag_handle_rounded,
                              color: isCurrent
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            TrackArtwork(
                              track: item,
                              size: 42,
                              borderRadius: 8,
                            ),
                          ],
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight:
                                isCurrent ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          item.artistLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Putar sekarang',
                              onPressed: () => controller.selectTrack(
                                item,
                                customQueue: queue,
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                            ),
                            if (!isCurrent)
                              IconButton(
                                tooltip: 'Hapus dari antrean',
                                onPressed: () =>
                                    controller.removeFromQueue(item.videoId),
                                icon: Icon(
                                  Icons.close_rounded,
                                  color: scheme.error,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (suggestedTracks.isNotEmpty) ...[
            const Divider(height: 20),
            Text(
              'Tambah Cepat ke Antrean',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 132,
              child: ListView.separated(
                itemCount: suggestedTracks.take(10).length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, idx) {
                  final tr = suggestedTracks[idx];
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(OmniXTokens.radiusThumb),
                    ),
                    child: Row(
                      children: [
                        TrackArtwork(track: tr, size: 38, borderRadius: 6),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge,
                              ),
                              Text(
                                tr.artistLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            controller.playNextInQueue(tr);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Diputar berikutnya: ${tr.title}',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.playlist_play, size: 18),
                          label: const Text('Berikutnya'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () {
                            controller.addToQueue(tr);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Ditambahkan ke antrean: ${tr.title}',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('+ Antrean'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
