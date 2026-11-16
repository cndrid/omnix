import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_app/main.dart';
import 'package:omnix_app/models/track_model.dart';
import 'package:omnix_app/providers/app_providers.dart';

void main() {
  testWidgets(
      'Aura Audio shell renders 4 tabs (Beranda, Cari, Koleksi, Profil) and theme toggle',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          exploreDataProvider.overrideWith((ref) async {
            return const ExploreDataModel(
              sections: [
                ExploreSectionModel(
                  title: 'Dibuat Untukmu: Daily Mix',
                  items: [
                    TrackModel(
                      videoId: 'vid_001',
                      title: 'Evaluasi',
                      artists: [ArtistModel(name: 'Hindia')],
                      duration: '03:15',
                      durationSeconds: 195,
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
        child: const OmniXApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('OmniX'), findsOneWidget);
    expect(find.text('Evaluasi'), findsWidgets);

    // Switch to Cari tab
    await tester.tap(find.text('Cari'));
    await tester.pumpAndSettle();
    expect(find.text('Cari & Jelajah Katalog'), findsOneWidget);

    // Switch to Koleksi tab
    await tester.tap(find.text('Koleksi'));
    await tester.pumpAndSettle();
    expect(find.text('Koleksi & Penyimpanan Hi-Res'), findsOneWidget);

    // Switch to Profil tab
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Profil & Pengaturan Audio'), findsOneWidget);

    // Toggle theme from Dark to Light
    await tester.tap(find.byTooltip('Beralih ke Mode Terang'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Beralih ke Mode Gelap'), findsOneWidget);
  });
}
