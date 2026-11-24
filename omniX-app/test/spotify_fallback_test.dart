// Test fallback Spotify -> YouTube (`flutter test test/spotify_fallback_test.dart`).
//
// Membuktikan: build TANPA --dart-define (SPOTIFY_CLIENT_ID/SECRET
// kosong — persis seperti `flutter test` di sini) tetap bisa mencari
// lagu lewat YouTube, tanpa crash dan tanpa error ke pengguna.
//
// - Tes 1-3 murni (tanpa network): kunci kosong, saringan video
//   mix/kompilasi, dan resolve yang tidak mengubah lagu YouTube.
// - Tes 4 memakai network sungguhan (pencarian YouTube). Network
//   sandbox kadang sangat lambat — tes ini boleh diulang sekali bila
//   gagal karena network saja.
import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_app/models/track_model.dart';
import 'package:omnix_app/services/api_service.dart';
import 'package:omnix_app/services/spotify_service.dart';
import 'package:omnix_app/services/yt_client.dart';

void main() {
  test('tanpa dart-define: Spotify tidak terkonfigurasi', () {
    expect(SpotifyService().isConfigured, isFalse);
  });

  test('saringan video: mix/kompilasi/>15 menit ditolak, remix lolos', () {
    bool ok(String title, int secs) =>
        YtClientService.matchesPlaybackCandidate(
          title: title,
          durationSeconds: secs,
        );
    // Satu lagu biasa lolos.
    expect(ok('Peterpan - Semua Tentang Kita', 260), isTrue);
    // "Remix" itu satu lagu yang sah — kata "mix" di dalamnya tidak
    // boleh ikut menolak (word-boundary).
    expect(ok('DJ Snake - Taki Taki (Remix)', 230), isTrue);
    // Mix / kompilasi / full album / maraton ditolak.
    expect(ok('Best Hits 2024 Mix - 2 Hours', 7200), isFalse);
    expect(ok('Kompilasi Lagu Galau Terbaik', 1800), isFalse);
    expect(ok('Album Full - Full Album 2023', 2700), isFalse);
    expect(ok('Lofi hip hop radio - beats to relax (1 hour)', 3600),
        isFalse);
    expect(ok('Nonstop Dangdut Koplo Terbaru', 1500), isFalse);
    // Video 20 menit (di atas batas 15 menit) ditolak walau judul bersih.
    expect(ok('Peterpan - Semua Tentang Kita (Live)', 1200), isFalse);
    // Tanpa durasi (live stream) ditolak.
    expect(
      YtClientService.matchesPlaybackCandidate(
        title: 'Lagu Bagus',
        durationSeconds: null,
      ),
      isFalse,
    );
  });

  test('resolve: lagu YouTube (videoId terisi) dikembalikan apa adanya',
      () async {
    const track = TrackModel(
      videoId: 'dQw4w9WgXcQ',
      title: 'Lagu Tes',
      artists: [ArtistModel(name: 'Artis Tes')],
    );
    final resolved = await YtClientService().resolvePlaybackVideoId(track);
    expect(resolved.videoId, 'dQw4w9WgXcQ');
  });

  test('fallback tanpa kunci: pencarian tetap jalan via YouTube',
      () async {
    final api = OmniXApiService();
    List<TrackModel> results = const [];
    Object? lastError;
    // Ulangi sekali bila gagal karena network saja.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        results = await api
            .search(query: 'musik Indonesia terpopuler', limit: 5)
            .timeout(const Duration(seconds: 90));
        lastError = null;
        break;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) {
      fail('Pencarian fallback gagal 2x karena network: $lastError');
    }
    expect(results, isNotEmpty);
    // Hasil fallback HARUS lagu YouTube (videoId terisi), bukan hasil
    // katalog yang belum ter-resolve.
    expect(results.every((t) => t.videoId.isNotEmpty), isTrue);
    expect(results.every((t) => t.spotifyId == null), isTrue);
  }, timeout: const Timeout(Duration(minutes: 4)));
}
