import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/omnix_theme.dart';
import 'widgets/liquid_glass_box.dart';

class ProfileView extends ConsumerWidget {
  final double bottomSafePadding;

  const ProfileView({
    super.key,
    required this.bottomSafePadding,
  });

  static const List<String> _qualities = [
    'Lossless FLAC 24-bit / 96kHz',
    'Sangat Tinggi (320 kbps)',
    'Hemat Data (AAC 128 kbps)',
  ];

  static const List<String> _devices = [
    'AirPods Pro (Spatial 3D)',
    'External USB DAC (Bit-Perfect 24-bit/96kHz)',
    'Speaker Sistem Studio',
    'Living Room Smart TV (OmniX Connect)',
    'Mobil (Android Auto / CarPlay)',
  ];

  static const List<String> _eqPresets = [
    'Spatial 3D',
    'Flat',
    'Bass Boost',
    'Vocal & Podcast',
    'Acoustic',
  ];

  static const List<String> _eqFreqLabels = [
    '60Hz',
    '230Hz',
    '910Hz',
    '3.6kHz',
    '14kHz',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(audioEngineProvider);
    final engineCtrl = ref.read(audioEngineProvider.notifier);
    final themeMode = ref.watch(themeModeProvider);
    final reducedTransparency = ref.watch(reducedTransparencyProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMobile =
        MediaQuery.sizeOf(context).width < OmniXTokens.breakpointTablet;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        isMobile ? 16 : 24,
        isMobile ? 16 : 28,
        bottomSafePadding,
      ),
      children: [
        Text('Profil & Pengaturan Audio', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        LiquidGlassBox(
          tier: GlassTier.glass2,
          borderRadius: OmniXTokens.radiusCard,
          padding: const EdgeInsets.all(20),
          child: engine.hasUserProfile
              ? Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: scheme.primary,
                      child: Text(
                        engine.userDisplayName![0].toUpperCase(),
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            engine.userDisplayName!,
                            style: theme.textTheme.titleLarge,
                          ),
                          if (engine.userBio != null &&
                              engine.userBio!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              engine.userBio!,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: engineCtrl.clearUserProfile,
                      child: const Text('Kosongkan Profil'),
                    ),
                  ],
                )
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person_outline_rounded,
                        size: 32,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Belum Ada Pengguna (Profil Kosong)',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Aplikasi berjalan dalam mode tanpa akun. Seluruh fitur Lossless 24-bit, Unduhan Offline, Antrean Penuh, dan AI DJ aktif gratis tanpa perlu login.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _showEditProfileDialog(context, engineCtrl),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Atur Profil'),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        Text(
          'Koneksi Backend Python (FastAPI)',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
            border: Border.all(color: scheme.outline),
          ),
          child: Row(
            children: [
              Icon(Icons.dns_rounded, color: scheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FastAPI + ytmusicapi + yt-dlp',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'URL Server: ${ref.watch(backendBaseUrlProvider)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Backend menangani pencarian lagu, metadata, lirik sinkron, dan resolusi stream video klip.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _showBackendUrlDialog(context, ref),
                child: const Text('Ganti URL'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Mesin Audio & Kualitas Streaming (Lossless)',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Kualitas Audio & Unduhan', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in _qualities)
                    ChoiceChip(
                      label: Text(q),
                      selected: engine.audioQuality == q,
                      onSelected: (_) => engineCtrl.setQuality(q),
                    ),
                ],
              ),
              const Divider(height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gapless Playback (0ms Transisi Mulus)'),
                subtitle: const Text(
                  'Putar album bersambung tanpa jeda hening antarlagu',
                ),
                value: engine.gaplessPlayback,
                onChanged: engineCtrl.toggleGapless,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automix & Smart Transition'),
                subtitle: const Text(
                  'Penyesuaian beat otomatis saat berpindah lagu di playlist',
                ),
                value: engine.automix,
                onChanged: engineCtrl.toggleAutomix,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Normalisasi Volume Audio'),
                subtitle: const Text(
                  'Samakan tingkat kekerasan suara di seluruh lagu dan podcast',
                ),
                value: engine.volumeNormalization,
                onChanged: engineCtrl.toggleNormalization,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Crossfade Antarlagu', style: theme.textTheme.titleMedium),
                  Text(
                    '${engine.crossfadeSeconds.round()} detik',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: engine.crossfadeSeconds,
                min: 0,
                max: 12,
                divisions: 12,
                label: '${engine.crossfadeSeconds.round()} dtk',
                onChanged: engineCtrl.setCrossfade,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Equalizer 5-Band & Preset', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in _eqPresets)
                    ChoiceChip(
                      label: Text(preset),
                      selected: engine.equalizerPreset == preset,
                      onSelected: (_) => engineCtrl.selectEqPreset(preset),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              for (int i = 0; i < _eqFreqLabels.length; i++)
                Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        _eqFreqLabels[i],
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: engine.eqBands[i],
                        min: -6.0,
                        max: 6.0,
                        onChanged: (v) => engineCtrl.updateEqBand(i, v),
                      ),
                    ),
                    SizedBox(
                      width: 52,
                      child: Text(
                        '${engine.eqBands[i] >= 0 ? '+' : ''}${engine.eqBands[i].toStringAsFixed(1)} dB',
                        style: theme.textTheme.bodyMedium,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'OmniX Connect, DAC & Sesi Jam Bersama',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perangkat Output Aktif',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final dev in _devices)
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(dev),
                  value: dev,
                  groupValue: engine.activeDeviceName,
                  onChanged: (val) {
                    if (val != null) engineCtrl.selectDevice(val);
                  },
                ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sesi Jam Real-Time (${engine.jamCode})',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          engine.jamSessionActive
                              ? 'Sesi Jam sedang aktif. Bagikan kode ${engine.jamCode} ke teman.'
                              : 'Mulai sesi dengar bersama teman secara real-time tanpa batasan paket.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: engineCtrl.toggleJamSession,
                    child: Text(
                      engine.jamSessionActive ? 'Akhiri Jam' : 'Mulai Jam',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Privasi, Taste Profile & Tampilan Liquid Glass',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
            border: Border.all(color: scheme.outline),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mode Transparansi Kaca (Liquid Glass 24px)'),
                subtitle: const Text(
                  'Matikan untuk beralih ke permukaan solid #16161D (Mode Hemat Daya / Kontras Tinggi)',
                ),
                value: !reducedTransparency,
                onChanged: (enableGlass) {
                  ref.read(reducedTransparencyProvider.notifier).state =
                      !enableGlass;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tema OLED Dark (#0B0B10)'),
                subtitle: const Text(
                  'Gunakan latar gelap pekat khas OmniX',
                ),
                value: themeMode == ThemeMode.dark,
                onChanged: (isDark) {
                  ref.read(themeModeProvider.notifier).state =
                      isDark ? ThemeMode.dark : ThemeMode.light;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sesi Privat (Private Session)'),
                subtitle: const Text(
                  'Sembunyikan lagu yang sedang diputar dari aktivitas publik sementara',
                ),
                value: engine.privateSession,
                onChanged: engineCtrl.togglePrivateSession,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tampilkan Aktivitas Teman (Friend Activity)'),
                subtitle: const Text(
                  'Lihat musik yang sedang didengarkan teman secara langsung',
                ),
                value: engine.showFriendActivity,
                onChanged: engineCtrl.toggleFriendActivity,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Izinkan Konten Eksplisit'),
                subtitle: const Text(
                  'Putar lagu dan episode podcast dengan tanda eksplisit',
                ),
                value: engine.explicitContentAllowed,
                onChanged: engineCtrl.toggleExplicitContent,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Kecualikan Sesi Ini dari Taste Profile'),
                subtitle: const Text(
                  'Jangan gunakan pemutaran saat ini untuk memengaruhi Discover Weekly',
                ),
                value: engine.excludeFromTasteProfile,
                onChanged: engineCtrl.toggleExcludeTaste,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    AudioEngineSettingsController ctrl,
  ) {
    final nameCtrl = TextEditingController();
    final bioCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Atur Profil Lokal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Tampilan',
                  hintText: 'Masukkan nama Anda',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bio Singkat (Opsional)',
                  hintText: 'Catatan profil',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (nameCtrl.text.trim().isNotEmpty) {
                  ctrl.setUserProfile(
                    name: nameCtrl.text,
                    bio: bioCtrl.text,
                  );
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _showBackendUrlDialog(BuildContext context, WidgetRef ref) {
    final currentUrl = ref.read(backendBaseUrlProvider);
    final ctrl = TextEditingController(text: currentUrl);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Konfigurasi URL Backend Python'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aplikasi terhubung ke backend FastAPI untuk mengambil data YouTube Music & streaming.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Alamat Host / URL Backend',
                  hintText: 'http://127.0.0.1:8000',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ActionChip(
                    label: const Text('Localhost (127.0.0.1)'),
                    onPressed: () {
                      ctrl.text = 'http://127.0.0.1:8000';
                    },
                  ),
                  ActionChip(
                    label: const Text('Android Emulator (10.0.2.2)'),
                    onPressed: () {
                      ctrl.text = 'http://10.0.2.2:8000';
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final text = ctrl.text.trim();
                if (text.isNotEmpty) {
                  ref.read(backendBaseUrlProvider.notifier).state = text;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('URL backend diperbarui ke: $text'),
                    ),
                  );
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Terapkan'),
            ),
          ],
        );
      },
    );
  }
}
