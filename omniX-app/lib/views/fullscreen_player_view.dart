import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track_model.dart';
import '../providers/app_providers.dart';
import '../theme/omnix_theme.dart';
import 'widgets/liquid_glass_box.dart';
import 'widgets/like_plus_button.dart';
import 'widgets/queue_sheet.dart';
import 'widgets/sleep_timer_sheet.dart';
import 'widgets/track_artwork.dart';

class FullscreenPlayerView extends ConsumerStatefulWidget {
  const FullscreenPlayerView({super.key});

  @override
  ConsumerState<FullscreenPlayerView> createState() =>
      _FullscreenPlayerViewState();
}

class _FullscreenPlayerViewState extends ConsumerState<FullscreenPlayerView> {
  int _rightPaneTabIndex = 0;

  String _formatDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Angka ringkas ala Indonesia: 47.174.483 -> "47 jt", 1.325.532 -> "1,3 jt".
  String _formatCount(int n) {
    if (n >= 1000000) {
      final v = n / 1000000;
      final s = v >= 10
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(1).replaceAll('.', ',');
      return '$s jt';
    }
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)} rb';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final track = playerState.currentTrack;
    if (track == null) {
      return const SizedBox.shrink();
    }

    final controller = ref.read(playerControllerProvider.notifier);
    final libraryState = ref.watch(libraryProvider);
    final engineState = ref.watch(audioEngineProvider);
    final isLiked = libraryState.isLiked(track.videoId);
    final isDownloaded = libraryState.isDownloaded(track.videoId);
    final detail = playerState.songDetail;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final thumbUrl = track.bestThumbnailUrl;
    final isDesktop =
        MediaQuery.sizeOf(context).width >= OmniXTokens.breakpointDesktop;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (thumbUrl.isNotEmpty &&
              !ref.watch(reducedTransparencyProvider)) ...[
            Image.network(
              thumbUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 44, sigmaY: 44),
              child: Container(
                color: isDark
                    ? OmniXTokens.darkCanvas.withValues(alpha: 0.85)
                    : OmniXTokens.lightCanvas.withValues(alpha: 0.88),
              ),
            ),
          ] else
            Container(color: theme.scaffoldBackgroundColor),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: 'Minimalkan layar Sedang Diputar (Escape)',
                        onPressed: controller.closeFullscreen,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 32,
                        ),
                      ),
                      // Pilihan mode Song/Video/Canvas dihapus bersama
                      // canvas video (preview v2: artwork statis saja).
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (playerState.isSleepTimerActive)
                            Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                  OmniXTokens.radiusPill,
                                ),
                                border: Border.all(color: scheme.secondary),
                              ),
                              child: Text(
                                playerState.formattedSleepTimer ?? '',
                                style: TextStyle(
                                  color: scheme.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          PopupMenuButton<String>(
                            tooltip: 'Menu Opsi Pemutaran (Titik 3)',
                            icon: const Icon(Icons.more_vert_rounded),
                            onSelected: (action) {
                              if (action == 'sleep_timer') {
                                showSleepTimerDialog(context, ref);
                              } else if (action == 'queue') {
                                showQueueManagerSheet(context, ref);
                              } else if (action == 'radio') {
                                controller.startSongRadio(track.videoId);
                              } else if (action == 'download') {
                                ref
                                    .read(libraryProvider.notifier)
                                    .toggleOfflineDownload(track);
                              } else if (action == 'output') {
                                _showOutputSelectorSheet(context);
                              } else if (action == 'share') {
                                _showShareCodeDialog(context, track);
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
                                        : scheme.onSurface,
                                  ),
                                  title: Text(
                                    playerState.isSleepTimerActive
                                        ? 'Sleep Timer (Aktif: ${playerState.formattedSleepTimer})'
                                        : 'Sleep Timer (Pengatur Waktu Tidur)',
                                  ),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'queue',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading:
                                      const Icon(Icons.queue_music_rounded),
                                  title: Text(
                                    'Kelola Antrean (${playerState.queue.length} Lagu)',
                                  ),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'radio',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.radio_rounded),
                                  title: Text('Mulai Stasiun Radio Lagu'),
                                ),
                              ),
                              PopupMenuItem(
                                value: 'download',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    isDownloaded
                                        ? Icons.download_done_rounded
                                        : Icons.download_for_offline_outlined,
                                    color:
                                        isDownloaded ? scheme.secondary : null,
                                  ),
                                  title: Text(
                                    isDownloaded
                                        ? 'Hapus Unduhan Offline'
                                        : 'Unduh Offline',
                                  ),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'output',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.speaker_group_rounded),
                                  title: Text('Pilih Output Audio / Connect'),
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.qr_code_2_rounded),
                                  title: Text('Bagikan & Kode QR OmniX'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (playerState.aiDjBanner != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
                    child: LiquidGlassBox(
                      tier: GlassTier.glass3,
                      borderRadius: OmniXTokens.radiusInput,
                      tintColor: scheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.record_voice_over_rounded,
                            size: 18,
                            color: scheme.secondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              playerState.aiDjBanner!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              flex: 6,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildMainPlayerTop(
                                      context,
                                      track,
                                      detail,
                                      playerState,
                                      controller,
                                    ),
                                    _buildPlaybackControls(
                                      context,
                                      track,
                                      playerState,
                                      engineState,
                                      isLiked,
                                      isDownloaded,
                                      controller,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            VerticalDivider(color: scheme.outline, width: 1),
                            Expanded(
                              flex: 5,
                              child: _buildSidePanel(
                                context,
                                detail,
                                playerState,
                                libraryState,
                                controller,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  12,
                                ),
                                children: [
                                  _buildMainPlayerTop(
                                    context,
                                    track,
                                    detail,
                                    playerState,
                                    controller,
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    height: 460,
                                    child: _buildSidePanel(
                                      context,
                                      detail,
                                      playerState,
                                      libraryState,
                                      controller,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Kontrol putar di-pin di bawah area scroll:
                            // kartu error di atas tidak bisa lagi mendorong
                            // tombol play sampai terpotong tepi bawah layar.
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                12,
                              ),
                              child: _buildPlaybackControls(
                                context,
                                track,
                                playerState,
                                engineState,
                                isLiked,
                                isDownloaded,
                                controller,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Bagian atas pemutar (artwork, judul, kartu error, slider): boleh
  /// di-scroll. Kartu error tinggal di sini supaya kemunculannya tidak
  /// pernah menggeser kontrol putar — kontrol di-pin di bawah lewat
  /// [_buildPlaybackControls] (bug 3: tombol play terpotong).
  Widget _buildMainPlayerTop(
    BuildContext context,
    TrackModel track,
    SongDetailModel? detail,
    PlayerViewState playerState,
    PlayerController controller,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formatLabel = detail?.streamFormatLabel ?? 'Audio';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          // Artwork statis (preview v2): thumbnail lagu, kotak radius 4px.
          // Canvas video dihapus — tidak ada lagi stream video di pemutar.
          child: Container(
            key: ValueKey('song_art_${track.videoId}'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(OmniXTokens.radiusThumb),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.36),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: TrackArtwork(
              track: track,
              size: 296,
              borderRadius: OmniXTokens.radiusThumb,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
            border: Border.all(color: scheme.primary),
          ),
          child: Text(
            formatLabel,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                track.title,
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Badge eksplisit "E" di samping judul (preview v2).
            if (track.isExplicit) ...[
              const SizedBox(width: 6),
              const ExplicitBadge(),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          track.album != null
              ? '${track.artistLine} · ${track.album!.name}'
              : track.artistLine,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        if (detail?.likes != null && detail!.likes! > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.thumb_up_alt_outlined,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatCount(detail.likes!),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 14),
              Icon(
                Icons.thumb_down_alt_outlined,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                _formatCount(detail.dislikes ?? 0),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
        if (playerState.errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(OmniXTokens.radiusInput),
              border: Border.all(color: scheme.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Koneksi bermasalah. ${playerState.errorMessage!}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => controller.selectTrack(
                    track,
                    customQueue: playerState.queue,
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        Semantics(
          slider: true,
          label: 'Posisi pemutaran lagu',
          value: _formatDuration(playerState.position),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: scheme.secondary,
              inactiveTrackColor: scheme.outline,
              thumbColor: scheme.secondary,
              overlayColor: scheme.secondary.withValues(alpha: 0.18),
            ),
            child: Slider(
              value: playerState.position.inSeconds
                  .toDouble()
                  .clamp(
                    0.0,
                    playerState.duration.inSeconds > 0
                        ? playerState.duration.inSeconds.toDouble()
                        : 1.0,
                  ),
              max: playerState.duration.inSeconds > 0
                  ? playerState.duration.inSeconds.toDouble()
                  : 1.0,
              onChanged: (seconds) {
                final target = Duration(seconds: seconds.round());
                controller.seekTo(target);
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(playerState.position),
                style: theme.textTheme.bodyMedium,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => controller.jumpRelativeSeconds(-15),
                    child: const Text('-15 dtk'),
                  ),
                  PopupMenuButton<double>(
                    tooltip: 'Kecepatan Pemutaran',
                    initialValue: playerState.playbackSpeed,
                    onSelected: controller.setPlaybackSpeed,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 0.8, child: Text('0.8x')),
                      PopupMenuItem(value: 1.0, child: Text('1.0x (Normal)')),
                      PopupMenuItem(value: 1.25, child: Text('1.25x')),
                      PopupMenuItem(value: 1.5, child: Text('1.5x')),
                      PopupMenuItem(value: 2.0, child: Text('2.0x')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${playerState.playbackSpeed}x',
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.jumpRelativeSeconds(15),
                    child: const Text('+15 dtk'),
                  ),
                ],
              ),
              Text(
                _formatDuration(playerState.duration),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Kontrol putar + aksi (Antrean/Suka/Unduh/Output): selalu terlihat
  /// penuh. Di layar kecil (mobile) widget ini di-pin di bawah area
  /// scroll, jadi kartu error atau banner tidak bisa mendorong tombol
  /// play sampai keluar layar.
  Widget _buildPlaybackControls(
    BuildContext context,
    TrackModel track,
    PlayerViewState playerState,
    AudioEngineSettingsState engineState,
    bool isLiked,
    bool isDownloaded,
    PlayerController controller,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: switch (playerState.shuffleMode) {
                ShuffleMode.off => 'Aktifkan Shuffle',
                ShuffleMode.normal => 'Aktifkan Smart Shuffle (Rekomendasi Serupa)',
                ShuffleMode.smart => 'Matikan Smart Shuffle',
              },
              onPressed: controller.cycleShuffleMode,
              icon: Icon(
                playerState.shuffleMode == ShuffleMode.smart
                    ? Icons.auto_awesome_motion_rounded
                    : Icons.shuffle_rounded,
                color: playerState.shuffleMode != ShuffleMode.off
                    ? scheme.secondary
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Lagu sebelumnya',
              onPressed: controller.skipPrevious,
              icon: Icon(
                Icons.skip_previous_rounded,
                size: 32,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 72,
              height: 72,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  backgroundColor: scheme.secondary,
                  foregroundColor: scheme.onSecondary,
                ),
                onPressed:
                    playerState.isLoadingTrack ? null : controller.togglePlayPause,
                child: playerState.isLoadingTrack
                    ? SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: scheme.onSecondary,
                        ),
                      )
                    : Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 38,
                        semanticLabel:
                            playerState.isPlaying ? 'Jeda' : 'Putar',
                      ),
              ),
            ),
            const SizedBox(width: 14),
            IconButton(
              tooltip: 'Lagu berikutnya',
              onPressed: controller.skipNext,
              icon: Icon(
                Icons.skip_next_rounded,
                size: 32,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Mode ulangi (${playerState.loopMode.name})',
              onPressed: controller.cycleLoopMode,
              icon: Icon(
                playerState.loopMode == LoopMode.one
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                color: playerState.loopMode != LoopMode.off
                    ? scheme.secondary
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: () => showQueueManagerSheet(context, ref),
              icon: const Icon(Icons.queue_music_rounded, size: 18),
              label: Text('Antrean (${playerState.queue.length})'),
            ),
            // Suka pakai "+" (preview v2), bukan hati.
            LikePlusButton(
              isLiked: isLiked,
              onToggle: () {
                ref.read(libraryProvider.notifier).toggleLike(track);
              },
              tooltip: isLiked ? 'Hapus dari lagu disukai' : 'Suka',
            ),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(libraryProvider.notifier).toggleOfflineDownload(track);
              },
              icon: Icon(
                isDownloaded
                    ? Icons.download_done_rounded
                    : Icons.download_for_offline_outlined,
                size: 18,
                color: isDownloaded ? scheme.secondary : scheme.onSurface,
              ),
              label: Text(isDownloaded ? 'Tersimpan Offline' : 'Unduh'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showOutputSelectorSheet(context),
              icon: Icon(
                Icons.speaker_group_rounded,
                size: 18,
                color: scheme.secondary,
              ),
              label: Text(engineState.activeDeviceName),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSidePanel(
    BuildContext context,
    SongDetailModel? detail,
    PlayerViewState playerState,
    LibraryState libraryState,
    PlayerController controller,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final tabs = [
      (0, 'Lirik Sinkron', Icons.lyrics_outlined),
      (1, 'Antrean (${playerState.queue.length})', Icons.queue_music_rounded),
      (2, 'Bab & Transkrip', Icons.bookmarks_outlined),
      (3, 'Info & Kredit', Icons.info_outline_rounded),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (idx, label, icon) in tabs) ...[
                  if (_rightPaneTabIndex == idx)
                    FilledButton.icon(
                      onPressed: () => setState(() => _rightPaneTabIndex = idx),
                      icon: Icon(icon, size: 17),
                      label: Text(label),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _rightPaneTabIndex = idx),
                      icon: Icon(icon, size: 17),
                      label: Text(label),
                    ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: LiquidGlassBox(
              tier: GlassTier.glass2,
              borderRadius: OmniXTokens.radiusCard,
              padding: const EdgeInsets.all(12),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey('side_tab_$_rightPaneTabIndex'),
                  child: switch (_rightPaneTabIndex) {
                    0 => _buildSyncedLyricsView(
                        theme,
                        scheme,
                        detail,
                        playerState,
                        controller,
                      ),
                    1 => const QueueManagerPanel(),
                    2 => _buildChaptersAndTranscriptView(
                        theme,
                        scheme,
                        detail,
                        controller,
                      ),
                    _ => _buildCreditsAndConcertsView(theme, scheme, detail),
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncedLyricsView(
    ThemeData theme,
    ColorScheme scheme,
    SongDetailModel? detail,
    PlayerViewState playerState,
    PlayerController controller,
  ) {
    if (playerState.isLoadingTrack) {
      return Center(child: CircularProgressIndicator(color: scheme.primary));
    }

    final synced = detail?.syncedLyrics ?? const [];
    if (synced.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lyrics_outlined,
              size: 40,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'Lirik tersinkronisasi belum tersedia untuk lagu ini.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final currentSec = playerState.position.inSeconds;
    int activeLineIdx = 0;
    for (int i = 0; i < synced.length; i++) {
      if (currentSec >= synced[i].timeSeconds) {
        activeLineIdx = i;
      }
    }

    return ListView.separated(
      itemCount: synced.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, idx) {
        final line = synced[idx];
        final isCurrent = idx == activeLineIdx;
        return InkWell(
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(OmniXTokens.radiusThumb),
          onTap: () => controller.seekTo(Duration(seconds: line.timeSeconds)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: isCurrent
                  ? scheme.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(OmniXTokens.radiusThumb),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    _formatDuration(Duration(seconds: line.timeSeconds)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isCurrent
                          ? scheme.secondary
                          : scheme.onSurfaceVariant,
                      fontWeight:
                          isCurrent ? FontWeight.w800 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.text,
                    style: TextStyle(
                      color: isCurrent
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                      fontSize: isCurrent ? 18 : 15,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildChaptersAndTranscriptView(
    ThemeData theme,
    ColorScheme scheme,
    SongDetailModel? detail,
    PlayerController controller,
  ) {
    final chapters = detail?.chapters ?? const [];
    final transcript = detail?.transcript;

    return ListView(
      children: [
        Text(
          'Penanda Bab (Chapters) Podcast & Audiobook',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        for (final ch in chapters)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.bookmark_border_rounded, color: scheme.primary),
            title: Text(ch.title, style: theme.textTheme.bodyLarge),
            subtitle: Text(
              'Mulai pada ${_formatDuration(Duration(seconds: ch.startSeconds))}',
              style: theme.textTheme.bodyMedium,
            ),
            trailing: OutlinedButton(
              onPressed: () =>
                  controller.seekTo(Duration(seconds: ch.startSeconds)),
              child: const Text('Lompat'),
            ),
          ),
        const Divider(height: 24),
        Text(
          'Transkrip Otomatis & Catatan Episode',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          (transcript != null && transcript.trim().isNotEmpty)
              ? transcript
              : 'Transkrip episode akan muncul secara otomatis saat materi podcast atau audiobook memiliki teks narasi.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildCreditsAndConcertsView(
    ThemeData theme,
    ColorScheme scheme,
    SongDetailModel? detail,
  ) {
    final credits = detail?.credits ?? const SongCreditsModel();
    return ListView(
      children: [
        Text('Kredit Lagu & Produksi', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Penulis / Komposer: ${credits.writers.join(', ')}',
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'Produser: ${credits.producers.join(', ')}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Label & Tahun: ${credits.label} (${credits.releaseYear ?? '2026'})',
          style: theme.textTheme.bodyMedium,
        ),
        const Divider(height: 24),
        Text('Tentang Artis', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          credits.artistBio ?? 'Biografi resmi artis.',
          style: theme.textTheme.bodyMedium,
        ),
        const Divider(height: 24),
        Text('Konser & Acara Terdekat', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final concert in credits.upcomingConcerts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded,
                    size: 18, color: scheme.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(concert, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showShareCodeDialog(BuildContext context, TrackModel track) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Bagikan Lagu & Kode OmniX'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Judul: ${track.title}'),
              Text('Artis: ${track.artistLine}'),
              const SizedBox(height: 12),
              SelectableText(
                'Tautan: https://omnix.audio/track/${track.videoId}\nKode OmniX: OMNIX:${track.videoId}',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Selesai'),
            ),
          ],
        );
      },
    );
  }

  void _showOutputSelectorSheet(BuildContext context) {
    final engine = ref.read(audioEngineProvider);
    final engineCtrl = ref.read(audioEngineProvider.notifier);
    // Audio keluar lewat perangkat ini — tidak ada perangkat lain.
    const devices = ['Perangkat ini'];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Output Audio',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final dev in devices)
                ListTile(
                  leading: Icon(
                    Icons.speaker_group_rounded,
                    color: engine.activeDeviceName == dev
                        ? Theme.of(context).colorScheme.secondary
                        : null,
                  ),
                  title: Text(dev),
                  onTap: () {
                    engineCtrl.selectDevice(dev);
                    Navigator.of(ctx).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
