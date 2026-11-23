// Riverpod providers untuk lapisan data M0 revamp OmniX (Drift + Supabase).
//
// SENGAJA tidak mengimpor provider auth worker lain: SupabaseClient diambil
// lewat `Supabase.instance.client` dan status login lewat
// `Supabase.instance.client.auth.currentUser` — jadi tidak ada dependensi
// antar-worker. (Supabase harus sudah di-`initialize` di main.dart oleh
// worker auth sebelum provider ini dipakai.)
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/liked_songs_repository.dart';
import '../data/local_db.dart';
import '../data/play_history_repository.dart';
import '../data/queue_repository.dart';
import '../data/settings_repository.dart';
import '../models/track_model.dart';

/// Database lokal. `driftDatabase(name: 'omnix_local')` dari drift_flutter
/// adalah pilihan yang benar untuk Android/iOS: memakai sqlite3_flutter_libs
/// (sqlite ter-bundle) + file `$name.sqlite` di application documents
/// directory, dan mendukung web (IndexedDB/WASM). Konstruktor AppDatabase
/// sendiri menerima executor apa pun — lihat local_db.dart.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(driftDatabase(name: 'omnix_local'));
  ref.onDispose(() {
    db.close();
  });
  return db;
});

bool _isLoggedIn() =>
    Supabase.instance.client.auth.currentUser != null;

String? _currentUserId() =>
    Supabase.instance.client.auth.currentUser?.id;

final likedSongsRepositoryProvider = Provider<LikedSongsRepository>((ref) {
  return LikedSongsRepository(
    supabase: Supabase.instance.client,
    db: ref.watch(appDatabaseProvider),
    isLoggedIn: _isLoggedIn,
    currentUserId: _currentUserId,
  );
});

final playHistoryRepositoryProvider = Provider<PlayHistoryRepository>((ref) {
  return PlayHistoryRepository(
    supabase: Supabase.instance.client,
    db: ref.watch(appDatabaseProvider),
    isLoggedIn: _isLoggedIn,
    currentUserId: _currentUserId,
  );
});

final queueRepositoryProvider = Provider<QueueRepository>((ref) {
  return QueueRepository(
    supabase: Supabase.instance.client,
    db: ref.watch(appDatabaseProvider),
    isLoggedIn: _isLoggedIn,
    currentUserId: _currentUserId,
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    supabase: Supabase.instance.client,
    db: ref.watch(appDatabaseProvider),
    isLoggedIn: _isLoggedIn,
    currentUserId: _currentUserId,
  );
});

/// Daftar lagu disukai (login: Supabase + cache Drift; tamu: Drift).
final likedTracksProvider = FutureProvider<List<TrackModel>>((ref) async {
  return ref.watch(likedSongsRepositoryProvider).getLikedTracks();
});

/// Apakah satu videoId sedang disukai.
final isLikedProvider =
    FutureProvider.family<bool, String>((ref, videoId) async {
  return ref.watch(likedSongsRepositoryProvider).isLiked(videoId);
});
