// Repository lagu disukai (Liked Songs) M0 revamp OmniX.
//
// Tamu: hanya Drift lokal. Login: Supabase sebagai sumber kebenaran,
// Drift sebagai cache + fallback saat offline/gagal.
//
// Repository ini UI-agnostic: status login disuntik lewat fungsi
// [isLoggedIn]/[currentUserId], bukan lewat provider auth.
//
// PENTING (skema Supabase): tabel `users` TIDAK punya policy INSERT, jadi
// baris profil users mungkin belum ada walau pengguna sudah login. Kalau
// insert ke `liked_songs` gagal karena FK ke `users` (Postgres 23503),
// dilempar [ProfileMissingException] — BUKAN crash, BUKAN dianggap berhasil.
// UI bisa menampilkan ajakan melengkapi profil / login ulang.
import 'package:drift/drift.dart';
// package:supabase dipakai — bukan supabase_flutter — supaya file ini
// tetap bisa dipakai dari `dart run` murni; pubspec.yaml di luar
// kewenangan worker ini, supabase adalah dep transitif supabase_flutter.
// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

import '../models/track_model.dart';
import 'local_db.dart';

/// Sinkronisasi ke Supabase gagal (offline / RLS / server). Like lokal
/// TETAP tersimpan — UI boleh toast "Gagal menyimpan like, coba lagi" dan
/// mengembalikan hati ke state semula dari [LikedSongsRepository.isLiked].
class SupabaseSyncException implements Exception {
  final String message;
  const SupabaseSyncException(this.message);

  @override
  String toString() => 'SupabaseSyncException: $message';
}

/// Baris profil di tabel `users` belum ada, sehingga baris yang merujuk
/// `users(id)` (mis. `liked_songs`) ditolak FK. Perlu policy INSERT users
/// dari dashboard Supabase, atau pembuatan profil saat login.
class ProfileMissingException implements Exception {
  final String message;
  const ProfileMissingException({
    this.message =
        'Profil pengguna belum ada di Supabase (tabel users). '
        'Like tersimpan lokal, belum tersinkron.',
  });

  @override
  String toString() => 'ProfileMissingException: $message';
}

class LikedSongsRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final bool Function() _isLoggedIn;
  final String? Function() _currentUserId;

  LikedSongsRepository({
    required SupabaseClient supabase,
    required AppDatabase db,
    required bool Function() isLoggedIn,
    required String? Function() currentUserId,
  })  : _supabase = supabase,
        _db = db,
        _isLoggedIn = isLoggedIn,
        _currentUserId = currentUserId;

  bool get _loggedIn => _isLoggedIn() && _currentUserId() != null;

  // ------------------------------------------------------------------
  // Baca
  // ------------------------------------------------------------------

  /// Tamu: cek Drift. Login: cek Supabase dulu, fallback Drift bila
  /// offline/gagal (atau bila lagu belum ada di cache `tracks` Supabase).
  Future<bool> isLiked(String videoId) async {
    // Guard (24 Nov 2026): videoId kosong bukan kunci like yang valid
    // (semua lagu Spotify yang belum ter-resolve berbagi '').
    if (videoId.isEmpty) return false;
    if (_loggedIn) {
      final userId = _currentUserId()!;
      try {
        final trackRow = await _supabase
            .from('tracks')
            .select('id')
            .eq('youtube_video_id', videoId)
            .maybeSingle();
        if (trackRow != null) {
          final likeRow = await _supabase
              .from('liked_songs')
              .select('track_id')
              .eq('user_id', userId)
              .eq('track_id', trackRow['id'] as String)
              .maybeSingle();
          return likeRow != null;
        }
        // Lagu belum ada di cache tracks Supabase -> tidak mungkin
        // ter-like di server; cek like lokal (optimistic/offline).
      } catch (_) {
        // Offline / gagal: jatuh ke Drift di bawah.
      }
    }
    final row = await (_db.select(_db.likedSongsLocal)
          ..where((t) => t.videoId.equals(videoId)))
        .getSingleOrNull();
    return row != null;
  }

  /// Login: baca `liked_songs` + join `tracks` dari Supabase (urut
  /// `liked_at` desc), simpan hasilnya ke Drift sebagai cache.
  /// Tamu/offline: baca Drift.
  Future<List<TrackModel>> getLikedTracks() async {
    if (_loggedIn) {
      final userId = _currentUserId()!;
      try {
        final likeRows = await _supabase
            .from('liked_songs')
            .select('track_id, liked_at')
            .eq('user_id', userId)
            .order('liked_at', ascending: false);
        final likeList = (likeRows as List).cast<Map<String, dynamic>>();
        if (likeList.isEmpty) return const [];
        final trackIds =
            likeList.map((r) => r['track_id'] as String).toList();
        final likedAtByTrackId = <String, int>{};
        for (final r in likeList) {
          final at = r['liked_at'];
          if (at is String) {
            likedAtByTrackId[r['track_id'] as String] =
                DateTime.parse(at).millisecondsSinceEpoch;
          }
        }
        final trackRows = await _supabase
            .from('tracks')
            .select(
              'id, youtube_video_id, title, duration_ms, cover_url, '
              'track_artists(position, artists(name))',
            )
            .inFilter('id', trackIds);
        final byId = <String, TrackModel>{};
        for (final row in (trackRows as List).cast<Map<String, dynamic>>()) {
          byId[row['id'] as String] = _trackFromSupabaseRow(row);
        }
        final result = <TrackModel>[];
        for (final id in trackIds) {
          final track = byId[id];
          if (track == null) continue;
          result.add(track);
          // Cache ke Drift (pertahankan liked_at asli dari server).
          await _saveLocalLike(track, likedAtMs: likedAtByTrackId[id]);
        }
        return result;
      } catch (_) {
        // Gagal / offline: jatuh ke Drift di bawah.
      }
    }
    final rows = await (_db.select(_db.likedSongsLocal)
          ..orderBy([(t) => OrderingTerm.desc(t.likedAt)]))
        .get();
    return rows.map(_trackFromLocalRow).toList();
  }

  // ------------------------------------------------------------------
  // Tulis
  // ------------------------------------------------------------------

  /// Toggle like. Bila belum suka: simpan ke Drift dulu (optimistic),
  /// lalu sinkron ke Supabase bila login. Bila sinkron gagal, like lokal
  /// TIDAK dihapus — dilempar [SupabaseSyncException] (atau
  /// [ProfileMissingException] bila FK users yang gagal) supaya UI bisa
  /// toast dan mengembalikan hati ke state semula. Bila sudah suka:
  /// hapus dari Drift + delete `liked_songs` di Supabase (bila login).
  Future<void> toggleLike(TrackModel track) async {
    // Guard (24 Nov 2026): jangan pernah menyimpan baris like dengan
    // videoId kosong (lihat isLiked di atas).
    if (track.videoId.isEmpty) return;
    final liked = await isLiked(track.videoId);
    if (!liked) {
      await _saveLocalLike(track);
      if (_loggedIn) {
        final userId = _currentUserId()!;
        try {
          final trackId = await _ensureTrackId(track);
          // Artis best-effort: track boleh tanpa artis.
          await _syncArtists(trackId, track);
          await _supabase.from('liked_songs').insert({
            'user_id': userId,
            'track_id': trackId,
          });
        } on ProfileMissingException {
          rethrow;
        } on PostgrestException catch (e) {
          throw _mapPostgrestError(e, 'menyimpan like');
        } catch (e) {
          throw SupabaseSyncException('Gagal menyimpan like: $e');
        }
      }
    } else {
      await (_db.delete(_db.likedSongsLocal)
            ..where((t) => t.videoId.equals(track.videoId)))
          .go();
      if (_loggedIn) {
        final userId = _currentUserId()!;
        try {
          final trackRow = await _supabase
              .from('tracks')
              .select('id')
              .eq('youtube_video_id', track.videoId)
              .maybeSingle();
          if (trackRow != null) {
            await _supabase
                .from('liked_songs')
                .delete()
                .eq('user_id', userId)
                .eq('track_id', trackRow['id'] as String);
          }
        } on PostgrestException catch (e) {
          throw _mapPostgrestError(e, 'menghapus like');
        } catch (e) {
          throw SupabaseSyncException('Gagal menghapus like: $e');
        }
      }
    }
  }

  // ------------------------------------------------------------------
  // Helper lokal
  // ------------------------------------------------------------------

  Future<void> _saveLocalLike(TrackModel track, {int? likedAtMs}) async {
    await _db.into(_db.likedSongsLocal).insertOnConflictUpdate(
          LikedSongsLocalCompanion.insert(
            videoId: track.videoId,
            title: track.title,
            artistLine: track.artistLine,
            coverUrl: track.bestThumbnailUrl,
            durationMs: Value(
              track.durationSeconds == null
                  ? null
                  : track.durationSeconds! * 1000,
            ),
            likedAt:
                likedAtMs ?? DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  TrackModel _trackFromLocalRow(LikedSongLocal row) {
    return TrackModel(
      videoId: row.videoId,
      title: row.title,
      // artist_line disimpan sebagai satu string gabungan; tampilannya
      // dipertahankan sebagai satu ArtistModel.
      artists: row.artistLine.isEmpty
          ? const []
          : [ArtistModel(name: row.artistLine)],
      durationSeconds:
          row.durationMs == null ? null : row.durationMs! ~/ 1000,
      thumbnails: row.coverUrl.isEmpty
          ? const []
          : [ThumbnailModel(url: row.coverUrl)],
    );
  }

  // ------------------------------------------------------------------
  // Helper Supabase
  // ------------------------------------------------------------------

  /// Pastikan baris `tracks` ada (upsert by `youtube_video_id`, cache
  /// metadata bersama). Mengembalikan id uuid baris tracks.
  /// TIDAK PERNAH menyimpan audio_url.
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

  /// Upsert artis + relasi track_artists. Best-effort: kegagalan apa pun
  /// diabaikan (track boleh tanpa artis). Hanya artis yang punya id
  /// channel YouTube yang disinkron.
  Future<void> _syncArtists(String trackId, TrackModel track) async {
    try {
      for (var i = 0; i < track.artists.length; i++) {
        final artist = track.artists[i];
        final channelId = artist.id;
        if (channelId == null || channelId.isEmpty) continue;
        final row = await _supabase
            .from('artists')
            .upsert({
              'youtube_channel_id': channelId,
              'name': artist.name,
            }, onConflict: 'youtube_channel_id')
            .select('id')
            .single();
        await _supabase.from('track_artists').upsert({
          'track_id': trackId,
          'artist_id': row['id'] as String,
          'position': i,
        }, onConflict: 'track_id,artist_id');
      }
    } catch (_) {
      // Best-effort: abaikan.
    }
  }

  /// Bangun TrackModel dari baris `tracks` + nama artis dari join
  /// `track_artists` bila ada (bila tidak ada, artists kosong).
  TrackModel _trackFromSupabaseRow(Map<String, dynamic> row) {
    final rawArtists = (row['track_artists'] as List?) ?? const [];
    final entries = rawArtists.cast<Map<String, dynamic>>().toList()
      ..sort(
        (a, b) => ((a['position'] as num?) ?? 0)
            .compareTo((b['position'] as num?) ?? 0),
      );
    final artists = <ArtistModel>[];
    for (final entry in entries) {
      final artistMap = entry['artists'] as Map<String, dynamic>?;
      final name = artistMap?['name'] as String?;
      if (name != null && name.isNotEmpty) {
        artists.add(ArtistModel(name: name));
      }
    }
    final cover = row['cover_url'] as String?;
    final durationMs = (row['duration_ms'] as num?)?.toInt();
    return TrackModel(
      videoId: row['youtube_video_id'] as String? ?? '',
      title: row['title'] as String? ?? 'Tanpa Judul',
      artists: artists,
      durationSeconds: durationMs == null ? null : durationMs ~/ 1000,
      thumbnails: cover == null || cover.isEmpty
          ? const []
          : [ThumbnailModel(url: cover)],
    );
  }

  Exception _mapPostgrestError(PostgrestException e, String aksi) {
    // 23503 = foreign_key_violation. Untuk liked_songs, FK yang bisa
    // gagal adalah user_id -> users(id): profil belum ada (tidak ada
    // policy INSERT users). Bedakan supaya UI bisa memberi pesan yang
    // tepat, bukan sekadar "gagal".
    if (e.code == '23503') return const ProfileMissingException();
    return SupabaseSyncException('Gagal $aksi: ${e.message}');
  }
}
