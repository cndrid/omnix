// Smoke test M0: Drift lokal + repository data (mode tamu).
//
// Dart MURNI — dijalankan dengan `dart run tool/test_m0_drift.dart`.
// TIDAK menyentuh Supabase sama sekali: database in-memory
// (AppDatabase.memory) dan repository dibuat dengan isLoggedIn = false,
// sehingga tidak ada request jaringan. SupabaseClient dummy di bawah
// hanya konstruktor (tidak pernah dipakai / tidak ada I/O jaringan);
// URL + anon key di sini PALSU dan bukan kredensial asli.
//
// Membuktikan:
//   1. toggleLike: simpan -> baca kembali -> hapus.
//   2. recents: maks 30 baris, yang terlama terhapus.
//   3. queue: simpan -> muat kembali (urutan + kind benar).
// Keluar 0 bila semua lolos, 1 bila ada yang gagal.
import 'dart:io';

// package:supabase dipakai — bukan supabase_flutter — supaya file ini
// tetap bisa dipakai dari `dart run` murni; pubspec.yaml di luar
// kewenangan worker ini, supabase adalah dep transitif supabase_flutter.
// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

import 'package:omnix_app/data/liked_songs_repository.dart';
import 'package:omnix_app/data/local_db.dart';
import 'package:omnix_app/data/play_history_repository.dart';
import 'package:omnix_app/data/queue_repository.dart';
import 'package:omnix_app/models/track_model.dart';

TrackModel _track(String videoId, String title) => TrackModel(
      videoId: videoId,
      title: title,
      artists: const [ArtistModel(name: 'Artis Tes')],
      durationSeconds: 200,
    );

void _check(bool ok, String label) {
  if (!ok) throw StateError('GAGAL: $label');
  stdout.writeln('  OK: $label');
}

Future<void> main() async {
  final db = AppDatabase.memory();
  // Client dummy — tidak pernah dipakai karena mode tamu.
  final supabase = SupabaseClient(
    'https://dummy.supabase.co',
    'dummy-anon-key-bukan-kredensial-asli',
  );
  const loggedOut = false;
  final likedRepo = LikedSongsRepository(
    supabase: supabase,
    db: db,
    isLoggedIn: () => loggedOut,
    currentUserId: () => null,
  );
  final historyRepo = PlayHistoryRepository(
    supabase: supabase,
    db: db,
    isLoggedIn: () => loggedOut,
    currentUserId: () => null,
  );
  final queueRepo = QueueRepository(
    supabase: supabase,
    db: db,
    isLoggedIn: () => loggedOut,
    currentUserId: () => null,
  );

  try {
    stdout.writeln('[1] toggleLike (mode tamu)');
    final track = _track('vid00000001', 'Lagu Tes Satu');
    _check(!await likedRepo.isLiked(track.videoId), 'belum disukai');
    await likedRepo.toggleLike(track);
    _check(await likedRepo.isLiked(track.videoId), 'disukai setelah toggle');
    final liked = await likedRepo.getLikedTracks();
    _check(
      liked.length == 1 && liked.first.videoId == track.videoId,
      'getLikedTracks mengembalikan 1 lagu',
    );
    _check(
      liked.first.title == 'Lagu Tes Satu',
      'judul lagu dari cache benar',
    );
    await likedRepo.toggleLike(track);
    _check(!await likedRepo.isLiked(track.videoId), 'tidak disukai lagi');
    _check(
      (await likedRepo.getLikedTracks()).isEmpty,
      'getLikedTracks kosong setelah unlike',
    );

    stdout.writeln('[2] recents maks 30 baris');
    for (var i = 0; i < 35; i++) {
      await historyRepo.recordPlay(
        _track('rec${i.toString().padLeft(8, '0')}', 'Recent $i'),
      );
    }
    final recents = await historyRepo.getRecents();
    _check(recents.length == 30, 'recents berisi tepat 30 baris');
    _check(
      recents.first.title == 'Recent 34',
      'baris terbaru (Recent 34) di urutan pertama',
    );
    _check(
      recents.every((t) => t.title != 'Recent 0'),
      'baris terlama (Recent 0) sudah terhapus',
    );

    stdout.writeln('[3] queue simpan + muat');
    final queue = [
      _track('que00000001', 'Antre 1'),
      _track('que00000002', 'Antre 2'),
      _track('que00000003', 'Antre 3'),
    ];
    await queueRepo.saveQueue(queue, currentIndex: 1);
    final loaded = await queueRepo.loadQueue();
    _check(loaded.length == 3, 'queue berisi 3 entri');
    _check(
      loaded[0].videoId == 'que00000001' && loaded[0].kind == 'history',
      'entri 0 = history (sebelum indeks aktif)',
    );
    _check(
      loaded[1].videoId == 'que00000002' &&
          loaded[1].position == 1 &&
          loaded[1].kind == 'upcoming',
      'entri 1 = upcoming (lagu aktif)',
    );
    _check(
      loaded[2].videoId == 'que00000003' && loaded[2].kind == 'upcoming',
      'entri 2 = upcoming',
    );
    // Simpan ulang menimpa seluruh isi (bukan menumpuk).
    await queueRepo.saveQueue([queue.first], currentIndex: 0);
    final reloaded = await queueRepo.loadQueue();
    _check(
      reloaded.length == 1 && reloaded.first.videoId == 'que00000001',
      'saveQueue kedua mengganti seluruh isi',
    );

    stdout.writeln('SEMUA SMOKE TEST M0 LOLOS');
  } finally {
    await db.close();
    // SupabaseClient dummy menahan event loop (timer internal GoTrue)
    // walau tidak pernah dipakai — dispose eksplisit + exit supaya
    // `dart run` benar-benar selesai dengan exit 0.
    await supabase.dispose();
  }
  exit(0);
}
