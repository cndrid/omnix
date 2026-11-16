import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../theme/omnix_theme.dart';

Future<void> showSleepTimerDialog(BuildContext context, WidgetRef ref) {
  final customCtrl = TextEditingController();
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return Consumer(
        builder: (context, ref, _) {
          final playerState = ref.watch(playerControllerProvider);
          final ctrl = ref.read(playerControllerProvider.notifier);
          final scheme = Theme.of(context).colorScheme;
          final theme = Theme.of(context);

          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.bedtime_rounded, color: scheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Pengatur Waktu Tidur (Sleep Timer)'),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (playerState.isSleepTimerActive)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.secondary.withValues(alpha: 0.18),
                        borderRadius:
                            BorderRadius.circular(OmniXTokens.radiusThumb),
                        border: Border.all(color: scheme.secondary),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Status Aktif: ${playerState.formattedSleepTimer}',
                            style: TextStyle(
                              color: scheme.secondary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              ctrl.setSleepTimer(null);
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Matikan'),
                          ),
                        ],
                      ),
                    ),
                  Text(
                    'Hentikan pemutaran musik atau podcast secara otomatis setelah:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mins in [5, 10, 15, 30, 45, 60, 90])
                        OutlinedButton.icon(
                          onPressed: () {
                            ctrl.setSleepTimer(mins);
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Sleep Timer diatur selama $mins menit.',
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.timer_outlined, size: 16),
                          label: Text('$mins Menit'),
                        ),
                      FilledButton.icon(
                        onPressed: () {
                          ctrl.setSleepTimer(null, stopAtEndOfTrack: true);
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Sleep Timer diatur untuk berhenti di akhir lagu ini.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.music_off_rounded, size: 16),
                        label: const Text('Akhir Lagu Ini'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Durasi kustom (menit)',
                            hintText: 'Misal: 25',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () {
                          final parsed = int.tryParse(customCtrl.text.trim());
                          if (parsed != null && parsed > 0) {
                            ctrl.setSleepTimer(parsed);
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Sleep Timer kustom diatur selama $parsed menit.',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Atur'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Tutup'),
              ),
            ],
          );
        },
      );
    },
  );
}
