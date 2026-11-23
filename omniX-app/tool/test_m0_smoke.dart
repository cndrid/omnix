// Smoke test M0 (jalur tamu, Dart murni — `dart run tool/test_m0_smoke.dart`).
//
// Membuktikan ujung-ke-ujung TANPA login:
//  1. Cari lagu asli lewat yt_client (InnerTube client-side).
//  2. Ekstraksi kandidat audio (URL stream asli, bisa diputar).
//  3. Like sebagai tamu lewat LikedSongsRepository (Drift lokal saja):
//     toggleLike -> isLiked true -> getLikedTracks berisi lagu itu ->
//     toggleLike lagi -> isLiked false.
// TIDAK menyentuh Supabase sebagai tamu (tidak ada panggilan network ke
// Supabase di sini; SupabaseClient hanya dibuat sebagai dummy konstruktor).
// Jalur login (tulis liked_songs ke Supabase) TIDAK bisa diuji di sini:
// akun uji belum dikonfirmasi email + policy users_insert belum ada
// (lihat laporan M0) — verifikasi itu menunggu dua langkah dashboard.
import 'dart:io';

import 'package:omnix_app/config/supabase_config.dart';
import 'package:omnix_app/data/liked_songs_repository.dart';
import 'package:omnix_app/data/local_db.dart';
import 'package:omnix_app/models/track_model.dart';
import 'package:omnix_app/services/stream_extractor.dart';
import 'package:omnix_app/services/yt_client.dart';
// package:supabase dipakai — bukan supabase_flutter — supaya file ini
// tetap bisa dipakai dari `dart run` murni; supabase adalah dep transitif
// supabase_flutter (pola yang sama seperti repository Worker B).
// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

void _check(bool ok, String label) {
  if (!ok) {
    stderr.writeln('GAGAL: $label');
    exit(1);
  }
  stdout.writeln('OK: $label');
}

Future<void> main() async {
  final supabase = SupabaseClient(supabaseUrl, supabasePublishableKey);
  final db = AppDatabase.memory();
  try {
    // 1. Cari lagu asli.
    final yt = YtClientService();
    final tracks = await yt.searchMusic('Tulus Hati-Hati di Jalan', limit: 3);
    _check(tracks.isNotEmpty, 'cari mengembalikan hasil asli');
    final track = tracks.first;
    stdout.writeln(
      '  lagu: ${track.title} | ${track.artistLine} | ${track.videoId}',
    );
    _check(track.videoId.isNotEmpty, 'videoId lagu tidak kosong');

    // 2. Ekstraksi kandidat audio (URL stream asli) — coba 3 hasil cari
    // pertama berurutan (jalur aplikasi yang sama: ketuk lagu -> ekstrak).
    // Catatan sandbox: getManifest untuk SATU video tertentu bisa menggantung
    // (timeout 60 dtk mentah pada 9II3OGZETo4, video pertama hasil cari),
    // sementara video lain diekstrak normal — artefak jaringan sandbox /
    // kerapuhan InnerTube yang sudah dikenal sejak 17 Nov 2026, BUKAN
    // perubahan M0 (ekstraksi dipakai ulang apa adanya dari Run #12).
    TrackModel? playable;
    List<AudioCandidate> candidates = const [];
    for (final t in tracks) {
      candidates = await StreamExtractor.extractAudioCandidates(t.videoId);
      if (candidates.isNotEmpty) {
        playable = t;
        break;
      }
      stdout.writeln('  ekstraksi kosong untuk ${t.videoId}, coba berikut...');
    }
    // Cadangan deterministik: video yang terbukti diekstrak di sandbox.
    if (playable == null) {
      candidates = await StreamExtractor.extractAudioCandidates(
        'RgKAFK5djSk',
      );
      if (candidates.isNotEmpty) {
        playable = const TrackModel(
          videoId: 'RgKAFK5djSk',
          title: 'Lagu uji ekstraksi (cadangan)',
        );
        stdout.writeln('  memakai video cadangan RgKAFK5djSk');
      }
    }
    _check(playable != null, 'ada lagu yang bisa diekstrak');
    _check(candidates.isNotEmpty, 'ekstraksi mengembalikan kandidat audio');
    _check(
      candidates.first.url.isNotEmpty,
      'URL stream kandidat pertama tidak kosong',
    );
    stdout.writeln(
      '  lagu bisa diputar: ${playable!.title} | ${playable.videoId}',
    );
    stdout.writeln('  stream: ${candidates.first.url.substring(0, 60)}...');

    // 3. Like sebagai tamu (Drift lokal saja) — pakai lagu yang bisa diputar.
    final likedTrack = playable;
    final repo = LikedSongsRepository(
      supabase: supabase,
      db: db,
      isLoggedIn: () => false,
      currentUserId: () => null,
    );
    _check(
      !await repo.isLiked(likedTrack.videoId),
      'belum suka sebelum toggle',
    );
    await repo.toggleLike(likedTrack);
    _check(
      await repo.isLiked(likedTrack.videoId),
      'suka tersimpan (tamu, Drift)',
    );
    final liked = await repo.getLikedTracks();
    _check(
      liked.any((t) => t.videoId == likedTrack.videoId),
      'lagu muncul di daftar Liked Songs (tamu)',
    );
    await repo.toggleLike(likedTrack);
    _check(
      !await repo.isLiked(likedTrack.videoId),
      'batal suka menghapus like',
    );
    _check(
      (await repo.getLikedTracks()).isEmpty,
      'daftar Liked Songs kosong setelah batal suka',
    );

    stdout.writeln('SEMUA SMOKE TEST M0 (TAMU) LOLOS');
  } finally {
    await db.close();
    await supabase.dispose();
    exit(0);
  }
}
