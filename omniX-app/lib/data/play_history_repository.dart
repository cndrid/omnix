// Repository riwayat putar (Recently Played) M0 revamp OmniX.
//
// Selalu tulis ke Drift lokal (recents_local, maks 30 baris). Bila login,
// tulis juga `play_history` di Supabase — best-effort: kegagalan Supabase
// ditangkap + log saja, TIDAK PERNAH mengganggu pemutaran.
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
// package:supabase dipakai — bukan supabase_flutter — supaya file ini
// tetap bisa dipakai dari `dart run` murni; pubspec.yaml di luar
// kewenangan worker ini, supabase adalah dep transitif supabase_flutter.
// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

import '../models/track_model.dart';
import 'local_db.dart';

class PlayHistoryRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final bool Function() _isLoggedIn;
  final String? Function() _currentUserId;

  /// Jumlah maksimum baris recents lokal (sesuai LibraryController lama).
  static const maxRecents = 30;

  /// Nilai `context_type` yang diizinkan skema `play_history`. Nilai lain
  /// dikirim sebagai null.
  static const allowedContextTypes = <String>{
    'playlist',
    'album',
    'search',
    'radio',
    'home',
    'library',
    'ai_dj',
    'made_for_you',
  };

  PlayHistoryRepository({
    required SupabaseClient supabase,
    required AppDatabase db,
    required bool Function() isLoggedIn,
    required String? Function() currentUserId,
  })  : _supabase = supabase,
        _db = db,
        _isLoggedIn = isLoggedIn,
        _currentUserId = currentUserId;

  bool get _loggedIn => _isLoggedIn() && _currentUserId() != null;

  /// Catat satu pemutaran. Selalu tulis lokal (insert-or-replace + pangkas
  /// ke [maxRecents] baris terbaru); sinkron Supabase best-effort.
  Future<void> recordPlay(TrackModel track, {String? contextType}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _db.into(_db.recentsLocal).insertOnConflictUpdate(
            RecentsLocalCompanion.insert(
              videoId: track.videoId,
              title: track.title,
              artistLine: track.artistLine,
              coverUrl: track.bestThumbnailUrl,
              playedAt: now,
            ),
          );
      final all = await (_db.select(_db.recentsLocal)
            ..orderBy([(t) => OrderingTerm.desc(t.playedAt)]))
          .get();
      if (all.length > maxRecents) {
        for (final stale in all.sublist(maxRecents)) {
          await (_db.delete(_db.recentsLocal)
                ..where((t) => t.videoId.equals(stale.videoId)))
              .go();
        }
      }
    });

    if (_loggedIn) {
      final userId = _currentUserId()!;
      try {
        final trackId = await _ensureTrackId(track);
        await _supabase.from('play_history').insert({
          'user_id': userId,
          'track_id': trackId,
          'context_type': allowedContextTypes.contains(contextType)
              ? contextType
              : null,
        });
      } catch (e) {
        // Best-effort: riwayat server gagal tidak boleh mengganggu lagu
        // yang sedang diputar.
        developer.log(
          'Gagal sinkron play_history (${track.videoId}): $e',
          name: 'omnix.play_history',
        );
      }
    }
  }

  /// Daftar putar terakhir dari Drift (urut terbaru dulu, maks 30).
  Future<List<TrackModel>> getRecents() async {
    final rows = await (_db.select(_db.recentsLocal)
          ..orderBy([(t) => OrderingTerm.desc(t.playedAt)]))
        .get();
    return rows
        .map(
          (row) => TrackModel(
            videoId: row.videoId,
            title: row.title,
            artists: row.artistLine.isEmpty
                ? const []
                : [ArtistModel(name: row.artistLine)],
            thumbnails: row.coverUrl.isEmpty
                ? const []
                : [ThumbnailModel(url: row.coverUrl)],
          ),
        )
        .toList();
  }

  /// Pastikan baris `tracks` ada (upsert by `youtube_video_id`).
  /// Mengembalikan id uuid baris tracks. TIDAK PERNAH menyimpan audio_url.
  Future<String> _ensureTrackId(TrackModel track) async {
    final row = await _supabase
        .from('tracks')
        .upsert({
          'youtube_video_id': track.videoId,
          'title': track.title,
          'duration_ms': track.durationSeconds == null
              ? null
              : track.durationSeconds! * 1000,
          'cover_url': track.bestThumbnailUrl.isEmpty
              ? null
              : track.bestThumbnailUrl,
        }, onConflict: 'youtube_video_id')
        .select('id')
        .single();
    return row['id'] as String;
  }
}
