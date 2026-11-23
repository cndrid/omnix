// Repository antrean aktif (M0 minimal) revamp OmniX.
//
// Antrean disimpan lokal (queue_local) — seluruh isi diganti tiap kali
// antrean berubah. Bila login, antrean juga ditulis ke `queue_states` +
// `queue_items` di Supabase secara best-effort (kegagalan ditangkap
// diam-diam). M0 TIDAK ada sinkronisasi antrean antar-perangkat real-time.
import 'dart:developer' as developer;

import 'package:drift/drift.dart';
// package:supabase dipakai — bukan supabase_flutter — supaya file ini
// tetap bisa dipakai dari `dart run` murni; pubspec.yaml di luar
// kewenangan worker ini, supabase adalah dep transitif supabase_flutter.
// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

import '../models/track_model.dart';
import 'local_db.dart';

/// Satu entri antrean hasil [QueueRepository.loadQueue].
class QueueEntry {
  final String videoId;
  final int position;

  /// 'upcoming' (lagu saat ini + berikutnya) atau 'history' (sudah lewat).
  final String kind;

  const QueueEntry({
    required this.videoId,
    required this.position,
    required this.kind,
  });
}

class QueueRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final bool Function() _isLoggedIn;
  final String? Function() _currentUserId;

  QueueRepository({
    required SupabaseClient supabase,
    required AppDatabase db,
    required bool Function() isLoggedIn,
    required String? Function() currentUserId,
  })  : _supabase = supabase,
        _db = db,
        _isLoggedIn = isLoggedIn,
        _currentUserId = currentUserId;

  bool get _loggedIn => _isLoggedIn() && _currentUserId() != null;

  /// Simpan antrean aktif: ganti seluruh isi queue_local. Entri sebelum
  /// indeks lagu saat ini dicatat 'history', sisanya 'upcoming'.
  /// [currentVideoId] (bila cocok dengan salah satu lagu) lebih diutamakan
  /// daripada [currentIndex].
  Future<void> saveQueue(
    List<TrackModel> queue, {
    int currentIndex = 0,
    String? currentVideoId,
  }) async {
    var activeIndex = currentIndex.clamp(0, queue.isEmpty ? 0 : queue.length - 1);
    if (currentVideoId != null) {
      final found =
          queue.indexWhere((t) => t.videoId == currentVideoId);
      if (found >= 0) activeIndex = found;
    }
    await _db.transaction(() async {
      await _db.delete(_db.queueLocal).go();
      for (var i = 0; i < queue.length; i++) {
        await _db.into(_db.queueLocal).insert(
              QueueLocalCompanion.insert(
                videoId: queue[i].videoId,
                position: i,
                kind: i < activeIndex ? 'history' : 'upcoming',
              ),
            );
      }
    });

    if (_loggedIn) {
      final userId = _currentUserId()!;
      try {
        // Upsert semua track dulu supaya ada id uuid-nya (cache bersama).
        final trackIds = <String, String>{};
        for (final track in queue) {
          trackIds[track.videoId] = await _ensureTrackId(track);
        }
        final currentVideo = queue.isEmpty
            ? null
            : queue[activeIndex.clamp(0, queue.length - 1)].videoId;
        await _supabase.from('queue_states').upsert({
          'user_id': userId,
          'current_track_id':
              currentVideo == null ? null : trackIds[currentVideo],
          'position_ms': 0,
          'autoplay': true,
          'shuffle': false,
          'repeat_mode': 'off',
        }, onConflict: 'user_id');
        await _supabase
            .from('queue_items')
            .delete()
            .eq('user_id', userId);
        for (var i = 0; i < queue.length; i++) {
          await _supabase.from('queue_items').insert({
            'user_id': userId,
            'track_id': trackIds[queue[i].videoId],
            'position': i,
            'kind': i < activeIndex ? 'history' : 'upcoming',
          });
        }
      } catch (e) {
        // Best-effort: antrean server gagal tidak boleh mengganggu pemutar.
        developer.log(
          'Gagal sinkron antrean: $e',
          name: 'omnix.queue',
        );
      }
    }
  }

  /// Muat antrean lokal: daftar videoId + posisi + kind, urut posisi.
  /// Mengembalikan daftar kosong bila belum ada antrean tersimpan.
  Future<List<QueueEntry>> loadQueue() async {
    final rows = await (_db.select(_db.queueLocal)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    return rows
        .map(
          (row) => QueueEntry(
            videoId: row.videoId,
            position: row.position,
            kind: row.kind,
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
