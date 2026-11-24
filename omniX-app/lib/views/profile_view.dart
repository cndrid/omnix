import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../providers/auth_provider.dart';
import '../theme/omnix_theme.dart';
import 'auth_view.dart';
import 'widgets/liquid_glass_box.dart';

class ProfileView extends ConsumerWidget {
  final double bottomSafePadding;

  const ProfileView({
    super.key,
    required this.bottomSafePadding,
  });

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

    // Status akun (M0). Baca defensif: kalau lapisan auth belum bisa
    // dibuat (Supabase belum di-init), tampil sebagai tamu.
    bool isLoggedIn = false;
    String? accountEmail;
    try {
      isLoggedIn = ref.watch(isLoggedInProvider);
      accountEmail = ref.watch(authStateProvider).valueOrNull?.email;
    } catch (_) {
      isLoggedIn = false;
      accountEmail = null;
    }

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
        _buildAccountSection(
          context,
          ref,
          theme,
          scheme,
          isLoggedIn,
          accountEmail,
        ),
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
          'Mode Client-Side (Tanpa Server)',
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
              Icon(Icons.phone_android_rounded, color: scheme.primary, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Langsung dari HP',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pencarian, metadata, lirik, dan stream diambil langsung dari perangkat — tidak ada server di tengah jalan.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Mesin Audio',
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
          'Privasi & Tampilan',
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
                title: const Text('Mode Transparansi Kaca (Liquid Glass)'),
                subtitle: const Text(
                  'Matikan untuk beralih ke permukaan solid (Mode Kontras Tinggi)',
                ),
                value: !reducedTransparency,
                onChanged: (enableGlass) {
                  ref.read(reducedTransparencyProvider.notifier).state =
                      !enableGlass;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tema Gelap'),
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
                title: const Text('Izinkan Konten Eksplisit'),
                subtitle: const Text(
                  'Putar lagu dengan tanda eksplisit',
                ),
                value: engine.explicitContentAllowed,
                onChanged: engineCtrl.toggleExplicitContent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Penyimpanan',
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        const _AudioCacheCard(),
      ],
    );
  }

  /// Baris status akun (M0) — paling atas tab Profil.
  /// Tamu: tombol "Masuk / Daftar" (buka AuthView). Login: tampilkan
  /// email + tombol "Keluar" (signOut, kembali ke mode tamu).
  Widget _buildAccountSection(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    ColorScheme scheme,
    bool isLoggedIn,
    String? accountEmail,
  ) {
    return LiquidGlassBox(
      tier: GlassTier.glass2,
      borderRadius: OmniXTokens.radiusCard,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isLoggedIn
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            child: Icon(
              isLoggedIn
                  ? Icons.person_rounded
                  : Icons.person_outline_rounded,
              size: 26,
              color: isLoggedIn
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedIn ? 'Masuk sebagai' : 'Mode tamu',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  isLoggedIn
                      ? (accountEmail ?? 'Akun OmniX')
                      : 'Cari dan putar lagu tanpa akun. Masuk untuk menyimpan lagu, playlist, dan riwayat.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isLoggedIn)
            OutlinedButton(
              onPressed: () {
                ref.read(authControllerProvider.notifier).signOut();
              },
              child: const Text('Keluar'),
            )
          else
            FilledButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AuthView(),
                  ),
                );
              },
              child: const Text('Masuk / Daftar'),
            ),
        ],
      ),
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
}

/// Kartu cache audio (24 Nov 2026): menampilkan ukuran cache audio saat
/// ini + tombol "Hapus cache" dengan dialog konfirmasi.
///
/// Catatan cache artwork: aplikasi TIDAK memakai cache artwork di disk —
/// artwork hanya dimuat lewat Image.network (cache memori Flutter saja,
/// tanpa cached_network_image / flutter_cache_manager), jadi tidak ada
/// cache artwork terpisah yang perlu dibersihkan. Yang dibersihkan di
/// sini hanya cache audio (LockCachingAudioSource).
class _AudioCacheCard extends ConsumerStatefulWidget {
  const _AudioCacheCard();

  @override
  ConsumerState<_AudioCacheCard> createState() => _AudioCacheCardState();
}

class _AudioCacheCardState extends ConsumerState<_AudioCacheCard> {
  Future<int>? _sizeFuture;

  @override
  void initState() {
    super.initState();
    _sizeFuture = ref.read(audioHandlerProvider).audioCacheSizeBytes();
  }

  void _refreshSize() {
    setState(() {
      _sizeFuture = ref.read(audioHandlerProvider).audioCacheSizeBytes();
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmAndClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus cache audio?'),
        content: const Text(
          'Lagu yang sudah diunduh akan diunduh ulang saat diputar lagi. '
          'Lagu yang sedang diputar tidak ikut dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(audioHandlerProvider).clearAudioCache();
    if (!mounted) return;
    _refreshSize();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache audio dihapus.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(OmniXTokens.radiusCard),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: [
          Icon(Icons.storage_rounded, color: scheme.primary, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cache Audio',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                FutureBuilder<int>(
                  future: _sizeFuture,
                  builder: (context, snap) {
                    final text = switch (snap.connectionState) {
                      ConnectionState.waiting => 'Menghitung…',
                      _ when snap.hasError => 'Ukuran tidak diketahui',
                      _ => 'Ukuran cache: ${_formatBytes(snap.data ?? 0)}',
                    };
                    return Text(text, style: theme.textTheme.bodyMedium);
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  'Lagu yang sudah diputar tersimpan supaya bisa diputar ulang tanpa mengunduh lagi (maks. 20 lagu / 200 MB).',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _confirmAndClear,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Hapus cache'),
          ),
        ],
      ),
    );
  }
}
