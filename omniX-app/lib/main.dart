import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'providers/app_providers.dart';
import 'services/audio_handler_service.dart';
import 'theme/omnix_theme.dart';
import 'views/app_shell.dart';

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

    return MaterialApp(
      title: 'OmniX Music Player',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: OmniXTheme.light(),
      darkTheme: OmniXTheme.dark(),
      home: const OmniXAppShell(),
    );
  }
}
