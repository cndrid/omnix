import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_providers.dart';
import 'theme/omnix_theme.dart';
import 'views/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: OmniXApp(),
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
