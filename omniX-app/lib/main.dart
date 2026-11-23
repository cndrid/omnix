import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/app_providers.dart';
import 'providers/auth_provider.dart';
import 'services/audio_handler_service.dart';
import 'services/supabase_service.dart';
import 'theme/omnix_theme.dart';
import 'design/design_showcase_view.dart';
import 'views/app_shell.dart';
import 'views/welcome_view.dart';

/// True setelah pengguna melewati layar sambut S01 (sebagai tamu maupun
/// setelah login). Sekali true, aplikasi tidak kembali ke S01 — keluar
/// dari akun (profil) hanya beralih ke mode tamu di dalam shell.
final welcomeDismissedProvider = StateProvider<bool>((ref) => false);

/// Minta izin notifikasi (POST_NOTIFICATIONS, Android 13+) saat pertama
/// kali lagu mulai diputar — momennya jelas bagi pengguna ("agar kontrol
/// lagu muncul di pusat kontrol"). Tanpa izin ini HyperOS bisa
/// menyembunyikan notifikasi media sehingga kartu media tidak muncul di
/// pusat kontrol / pil status bar. Kalau pengguna menolak, kartu tetap
/// bisa diaktifkan manual lewat Settings HP. Bukan fatal kalau gagal.
Future<void> _requestNotificationPermission() async {
  if (!Platform.isAndroid) return;
  try {
    final status = await Permission.notification.status;
    if (status.isGranted) return;
    await Permission.notification.request();
  } catch (_) {
    // Gagal meminta izin — bukan fatal; pengguna tetap bisa mengaktifkan
    // manual lewat Settings.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Inisialisasi Supabase (auth + database) sebelum aplikasi jalan.
  // Instance ini disuntikkan ke ProviderScope di bawah supaya
  // supabaseServiceProvider memakai instance yang SUDAH ter-init —
  // SupabaseService memakai flag instance (_initialized), jadi instance
  // baru tanpa override akan melempar StateError saat dibaca.
  final supabaseService = SupabaseService();
  await supabaseService.initialize();
  // Daftarkan handler ke audio_service sebelum aplikasi jalan, supaya
  // sistem Android membuat media session + notifikasi media: pusat
  // kontrol, lock screen, dan pil status bar HyperOS bisa menampilkan
  // dan mengontrol lagu yang sedang diputar.
  final audioHandler = await AudioService.init(
    builder: () => OmniXAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.omnix_app',
      androidNotificationChannelName: 'OmniX',
      androidNotificationIcon: 'mipmap/ic_launcher',
      // Percobaan 23 Nov 2026: notifikasi media tidak pernah muncul di
      // Poco F7 walau semua izin ON — buat notifikasi persisten supaya
      // HyperOS menampilkannya di shade / pusat kontrol / lock screen.
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  // Izin notifikasi diminta sekali, saat lagu pertama kali mulai diputar
  // (bukan saat aplikasi dibuka). onError dikosongkan sengaja: stream
  // ini bisa membawa error player, dan listener ini tidak boleh mati
  // karenanya.
  var notificationPermissionRequested = false;
  audioHandler.playbackState.listen(
    (state) {
      if (state.playing && !notificationPermissionRequested) {
        notificationPermissionRequested = true;
        unawaited(_requestNotificationPermission());
      }
    },
    onError: (_) {},
  );
  runApp(
    ProviderScope(
      overrides: [
        // Pakai handler hasil init di atas, jangan buat instance baru,
        // supaya semua pemakai (PlayerController dsb.) memakai handler
        // yang sama dengan yang terdaftar di media session.
        audioHandlerProvider.overrideWithValue(audioHandler),
        // Sama untuk Supabase: provider auth/data harus memakai
        // instance yang sudah di-init di atas.
        supabaseServiceProvider.overrideWithValue(supabaseService),
      ],
      child: const OmniXApp(),
    ),
  );
}

class OmniXApp extends ConsumerWidget {
  const OmniXApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    // Gerbang awal M0 (S01): sesi login yang tersimpan langsung masuk
    // shell; tamu melihat layar sambut sekali sampai memilih lanjut.
    // Saat stream auth masih memuat, tampilkan splash boot minimal
    // (bukan konten) supaya tidak ada kedipan welcome → shell.
    final authAsync = ref.watch(authStateProvider);
    final welcomeDismissed = ref.watch(welcomeDismissedProvider);
    final Widget home;
    if (authAsync.valueOrNull != null || welcomeDismissed) {
      home = const OmniXAppShell();
    } else if (authAsync.isLoading) {
      home = const _StartupSplash();
    } else {
      home = WelcomeView(
        onContinueAsGuest: () {
          ref.read(welcomeDismissedProvider.notifier).state = true;
        },
      );
    }

    return MaterialApp(
      title: 'OmniX Music Player',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: OmniXTheme.light(),
      darkTheme: OmniXTheme.dark(),
      home: home,
      // Route showcase primitif desain (replica-design Tahap 3) — hanya
      // bisa dicapai lewat deep link / navigasi bernama '/design'.
      // Tidak ada tombol/menu ke sini dari layar utama; alur normal
      // (initial route, navbar 4 tab) tidak berubah.
      routes: {
        '/design': (_) => const DesignShowcaseView(),
      },
    );
  }
}

/// Splash boot minimal saat sesi auth masih dipulihkan — logo + progres.
/// Bukan skeleton konten (aturan skeleton berlaku untuk isi layar).
class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 96,
              height: 96,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.music_note_rounded,
                size: 72,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
