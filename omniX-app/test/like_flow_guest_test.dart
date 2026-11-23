// Widget test alur like M0 — jalur TAMU (`flutter test`).
//
// Membuktikan: tamu mengetuk hati -> Bottom Sheet login muncul
// ("Masuk untuk menyimpan"), BUKAN error/toast merah.
//
// Supabase di-init sungguhan di sini (kunci publishable dari
// config — kunci publik, akses dibatasi RLS) dengan SharedPreferences
// mock, supaya provider auth memakai klien nyata TANPA sesi (mode tamu).
// Tidak ada panggilan network: test ini tidak masuk/daftar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_app/config/supabase_config.dart';
import 'package:omnix_app/models/track_model.dart';
import 'package:omnix_app/providers/like_flow.dart';
import 'package:omnix_app/views/widgets/like_plus_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _track = TrackModel(
  videoId: 'dQw4w9WgXcQ',
  title: 'Lagu Tes',
  artists: [ArtistModel(name: 'Artis Tes')],
);

/// Layar uji minimal: satu tombol hati yang memakai LikeFlow persis
/// seperti call site di aplikasi (track_tile / mini player / pemutar).
class _TestLikeScreen extends ConsumerWidget {
  const _TestLikeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: LikeHeartButton(
          isLiked: false,
          trackTitle: _track.title,
          onToggle: () =>
              LikeFlow.toggleLikeWithResult(ref, _track, context: context),
        ),
      ),
    );
  }
}

void main() {
  // Init Supabase HARUS di dalam zona test (setUpAll): di main() level
  // atas, package:http gagal ("no current invoker") karena
  // _MockHttpOverrides hanya hidup di dalam test; dan Supabase.initialize
  // memanggil WidgetsFlutterBinding.ensureInitialized() yang bertabrakan
  // dengan TestWidgetsFlutterBinding kalau dipanggil sebelum binding test
  // dibuat.
  setUpAll(() async {
    // Supabase butuh SharedPreferences mock di lingkungan test.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
  });

  testWidgets('tamu ketuk hati -> sheet login muncul', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: _TestLikeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Hati outline + label "Suka, Lagu Tes" (Tooltip memakai variabel
    // label yang sama dengan Semantics + Icon.semanticLabel di tombol).
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byTooltip('Suka, Lagu Tes'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    // Sheet login (bukan error): judul + penjelasan + tombol Masuk.
    expect(find.text('Masuk untuk menyimpan'), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
    expect(find.text('Lanjutkan sebagai tamu'), findsOneWidget);
  });
}
