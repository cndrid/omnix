// Live check M0 (jalur LOGIN) — sebagai flutter_test.
//
// Membuktikan ujung-ke-ujung DENGAN kode aplikasi sendiri (bukan curl):
//   (a) sign in akun uji via AuthService (lib/services/auth_service.dart)
//   (b) ensureUserProfile() -> baris users ada di Supabase
//   (c) cari lagu asli + like lewat LikedSongsRepository -> baris
//       liked_songs ada di Supabase (judul + youtube_video_id)
//   (d) Library membaca kembali lagu itu via repo.getLikedTracks()
//       (jalur yang dipakai S12/S13 lewat provider)
//   (e) BERSIHKAN: unlike -> baris liked_songs hilang lagi.
//
// CATATAN RUNNER (terbukti di sandbox, 23 Nov 2026):
//  - `dart run` murni TIDAK bisa: AuthService mengimpor supabase_flutter
//    yang transitif mengimpor dart:ui ("dart:ui is not available").
//  - `flutter test` dengan main() polos JUGA gagal: runner memakai
//    timeout load 60 detik yang tetap (tidak bisa diubah --timeout /
//    --ignore-timeouts), sementara alur ini butuh >60 detik (cari +
//    ekstraksi YouTube lewat proxy sandbox). Karena itu file ini memakai
//    test() flutter_test yang sesungguhnya: main() hanya mendaftarkan
//    test dan langsung kembali, lalu test case-nya berjalan dengan
//    timeout 10 menit.
//  Jalankan dengan:
//    M0_TEST_EMAIL=... M0_TEST_PASSWORD=... flutter test tool/test_m0_live.dart
//
// SupabaseClient dibuat langsung via package:supabase (konstruktor
// murni, tanpa Supabase.initialize / storage Flutter) lalu disuntik ke
// AuthService + repository — persis tipe yang dipakai aplikasi.
//
// Akun uji sekali pakai dibuat untuk pengujian ini; kredensialnya TIDAK
// ada di file ini (diberikan lewat env M0_TEST_EMAIL / M0_TEST_PASSWORD).
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_app/config/supabase_config.dart';
import 'package:omnix_app/data/liked_songs_repository.dart';
import 'package:omnix_app/data/local_db.dart';
import 'package:omnix_app/models/track_model.dart';
import 'package:omnix_app/services/auth_service.dart';
import 'package:omnix_app/services/stream_extractor.dart';
import 'package:omnix_app/services/yt_client.dart';
// package:supabase dipakai — bukan supabase_flutter — supaya
// SupabaseClient bisa dibuat langsung tanpa Supabase.initialize.
// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

void _check(bool ok, String label) {
  if (!ok) {
    throw StateError('GAGAL: $label');
  }
  // ignore: avoid_print
  print('OK: $label');
}

void main() {
  test(
    'M0 live: login -> like -> tersimpan di Supabase -> Library -> cleanup',
    () async {
      final email = Platform.environment['M0_TEST_EMAIL'] ?? '';
      final password = Platform.environment['M0_TEST_PASSWORD'] ?? '';
      if (email.isEmpty || password.isEmpty) {
        throw StateError(
          'GAGAL: M0_TEST_EMAIL / M0_TEST_PASSWORD belum diisi (env).',
        );
      }

      // Klien Supabase langsung (tanpa Supabase.initialize) — tipe yang
      // sama dengan yang dipakai AuthService + repository di aplikasi.
      final supabase =
          SupabaseClient(supabaseUrl, supabasePublishableKey);
      final auth = AuthService(supabase);
      final db = AppDatabase.memory();
      try {
        // (a) Sign in akun uji via AuthService.
        final signIn = await auth
            .signIn(email: email, password: password)
            .timeout(const Duration(seconds: 60));
        _check(signIn.ok, 'sign in akun uji via AuthService');
        final user = auth.currentUser;
        _check(user != null, 'session didapat (currentUser tidak null)');
        final uid = user!.id;
        // ignore: avoid_print
        print('  uid: $uid');
        // ignore: avoid_print
        print('  email: ${user.email}');

        // (b) ensureUserProfile() + baca balik baris users.
        await auth
            .ensureUserProfile()
            .timeout(const Duration(seconds: 60));
        // ignore: avoid_print
        print('OK: ensureUserProfile() tanpa lempar');
        final userRow = await supabase
            .from('users')
            .select('id, email, display_name')
            .eq('id', uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 60));
        _check(userRow != null, 'baris users ada di Supabase');
        // ignore: avoid_print
        print('  users row: $userRow');

        // (c) Cari lagu asli + pastikan bisa diputar (pola smoke test).
        final yt = YtClientService();
        final tracks = await yt
            .searchMusic('Tulus Hati-Hati di Jalan', limit: 3)
            .timeout(const Duration(seconds: 90));
        _check(tracks.isNotEmpty, 'cari mengembalikan hasil asli');
        TrackModel? playable;
        for (final t in tracks) {
          List<AudioCandidate> candidates = const [];
          try {
            candidates = await StreamExtractor.extractAudioCandidates(
              t.videoId,
            ).timeout(const Duration(seconds: 90));
          } on TimeoutException {
            // ignore: avoid_print
            print('  ekstraksi timeout untuk ${t.videoId}');
          }
          if (candidates.isNotEmpty) {
            playable = t;
            break;
          }
          // ignore: avoid_print
          print(
            '  ekstraksi kosong untuk ${t.videoId}, coba berikut...',
          );
        }
        // Cadangan deterministik: video yang terbukti diekstrak di sandbox.
        if (playable == null) {
          final candidates = await StreamExtractor.extractAudioCandidates(
            'RgKAFK5djSk',
          ).timeout(const Duration(seconds: 90));
          if (candidates.isNotEmpty) {
            playable = const TrackModel(
              videoId: 'RgKAFK5djSk',
              title: 'Lagu uji ekstraksi (cadangan)',
            );
            // ignore: avoid_print
            print('  memakai video cadangan RgKAFK5djSk');
          }
        }
        _check(playable != null, 'ada lagu yang bisa diekstrak');
        final likedTrack = playable!;
        // ignore: avoid_print
        print(
          '  lagu: ${likedTrack.title} | ${likedTrack.artistLine} | '
          '${likedTrack.videoId}',
        );

        final repo = LikedSongsRepository(
          supabase: supabase,
          db: db,
          isLoggedIn: () => auth.currentUser != null,
          currentUserId: () => auth.currentUser?.id,
        );

        // Idempoten: bila run sebelumnya terbunuh sebelum cleanup, like
        // lama masih ada — batalkan dulu supaya pre-check di bawah valid.
        if (await repo
            .isLiked(likedTrack.videoId)
            .timeout(const Duration(seconds: 60))) {
          // ignore: avoid_print
          print('  like lama dari run sebelumnya, batalkan dulu...');
          await repo
              .toggleLike(likedTrack)
              .timeout(const Duration(seconds: 60));
        }

        // Like lewat repository (jalur aplikasi: toggleLike).
        _check(
          !(await repo
              .isLiked(likedTrack.videoId)
              .timeout(const Duration(seconds: 60))),
          'belum suka sebelum like (bersih)',
        );
        await repo
            .toggleLike(likedTrack)
            .timeout(const Duration(seconds: 60));
        // ignore: avoid_print
        print('OK: toggleLike lewat repository tanpa lempar');
        _check(
          await repo
              .isLiked(likedTrack.videoId)
              .timeout(const Duration(seconds: 60)),
          'isLiked true setelah like',
        );

        // Verifikasi langsung di Supabase: tracks + liked_songs.
        final trackRow = await supabase
            .from('tracks')
            .select('id, youtube_video_id, title')
            .eq('youtube_video_id', likedTrack.videoId)
            .maybeSingle()
            .timeout(const Duration(seconds: 60));
        _check(trackRow != null, 'baris tracks ada di Supabase');
        // ignore: avoid_print
        print('  tracks row: $trackRow');
        final trackId = trackRow!['id'] as String;
        final likeRows = await supabase
            .from('liked_songs')
            .select('user_id, track_id, liked_at')
            .eq('user_id', uid)
            .eq('track_id', trackId)
            .timeout(const Duration(seconds: 60));
        _check(
          (likeRows as List).length == 1,
          'baris liked_songs ada di Supabase (1 baris)',
        );
        // ignore: avoid_print
        print('  liked_songs row: ${(likeRows as List).first}');

        // (d) Library membaca kembali lagu itu (jalur S12/S13).
        final liked = await repo
            .getLikedTracks()
            .timeout(const Duration(seconds: 60));
        _check(
          liked.any((t) => t.videoId == likedTrack.videoId),
          'lagu muncul di getLikedTracks (Library)',
        );
        final back = liked.firstWhere(
          (t) => t.videoId == likedTrack.videoId,
        );
        // ignore: avoid_print
        print(
          '  library: ${back.title} | ${back.artistLine} | ${back.videoId}',
        );

        // (e) BERSIHKAN: unlike, verifikasi baris hilang lagi.
        await repo
            .toggleLike(likedTrack)
            .timeout(const Duration(seconds: 60));
        // ignore: avoid_print
        print('OK: toggleLike kedua (unlike) tanpa lempar');
        _check(
          !await repo.isLiked(likedTrack.videoId),
          'isLiked false setelah unlike',
        );
        final likeRowsAfter = await supabase
            .from('liked_songs')
            .select('user_id, track_id')
            .eq('user_id', uid)
            .eq('track_id', trackId)
            .timeout(const Duration(seconds: 60));
        _check(
          (likeRowsAfter as List).isEmpty,
          'baris liked_songs hilang dari Supabase setelah unlike',
        );
        _check(
          (await repo.getLikedTracks()).isEmpty,
          'daftar Liked Songs kosong setelah unlike',
        );

        // ignore: avoid_print
        print('SEMUA LIVE CHECK M0 (LOGIN) LOLOS');
      } finally {
        await db.close();
        await supabase.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
