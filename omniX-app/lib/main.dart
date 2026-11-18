import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';
import 'services/audio_handler_service.dart';
import 'theme/omnix_theme.dart';
import 'views/app_shell.dart';

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
