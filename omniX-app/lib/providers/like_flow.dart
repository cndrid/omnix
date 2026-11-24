import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/liked_songs_repository.dart';
import '../models/track_model.dart';
import 'app_providers.dart';
import 'auth_provider.dart';
import 'data_providers.dart';
import '../views/widgets/login_sheet.dart';

/// Alur like terpusat M0 (components.md §10, state "butuh login").
///
/// Dipakai SEMUA call site — jangan panggil
/// `libraryProvider.notifier.toggleLike` langsung dari UI.
///
/// * Tamu: ketuk like → Bottom Sheet login (BUKAN error, BUKAN toast
///   merah). Setelah login berhasil, aksi like yang diminta langsung
///   dijalankan ulang.
/// * Login: like disimpan lewat [LibraryController.toggleLike] (optimistic
///   in-memory + repository Drift/Supabase), lalu [likedTracksProvider]
///   dan [isLikedProvider] di-refresh.
/// * Sinkron gagal ([SupabaseSyncException]/[ProfileMissingException]):
///   toast "Gagal menyimpan like, coba lagi" dan hati kembali ke state
///   semula (controller sudah mengembalikan state optimistic-nya).
class LikeFlow {
  LikeFlow._();

  /// Alur like lengkap. Mengembalikan `true` bila state suka berhasil
  /// berubah & tersimpan — dipakai [LikeHeartButton] untuk menentukan
  /// apakah pop dimainkan.
  static Future<bool> toggleLikeWithResult(
    WidgetRef ref,
    TrackModel track, {
    BuildContext? context,
  }) async {
    final loggedIn = _isLoggedInSafe(ref);
    if (!loggedIn) {
      if (context == null) return false;
      await showLoginSheet(
        context: context,
        onLoggedIn: () {
          // Sheet sudah tertutup; stream auth butuh sepersekian detik
          // untuk menyampaikan sesi baru ke provider — tunggu dulu
          // supaya retry tidak membaca status tamu yang basi.
          unawaited(_toggleAfterLogin(ref, track, context));
        },
      );
      return false;
    }

    // Resolusi lazy Spotify -> YouTube (24 Nov 2026): lagu Spotify yang
    // belum diputar punya videoId '' — like mengunci pada videoId (lihat
    // LibraryController.toggleLike), jadi resolve dulu supaya like
    // tersimpan di bawah videoId aslinya, bukan kunci '' yang dipakai
    // bersama semua lagu yang belum ter-resolve.
    if (track.videoId.isEmpty && track.spotifyId != null) {
      try {
        track = await ref.read(apiServiceProvider).resolveTrackForPlayback(
              track,
            );
      } catch (_) {
        if (context != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Tidak menemukan video untuk lagu ini, coba lagi'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return false;
      }
      if (track.videoId.isEmpty) return false;
    }

    final ok = await ref.read(libraryProvider.notifier).toggleLike(track);
    // Segarkan daftar Liked Songs + status like lagu ini.
    try {
      ref.invalidate(likedTracksProvider);
    } catch (_) {
      // Abaikan: provider data belum bisa dibuat (mis. Supabase belum
      // di-init) — state in-memory tetap jadi sumber tampilan.
    }
    try {
      ref.invalidate(isLikedProvider(track.videoId));
    } catch (_) {
      // Sama seperti di atas.
    }
    if (!ok && context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal menyimpan like, coba lagi'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return ok;
  }

  /// Tanda tangan sesuai spesifikasi tugas (versi `void`).
  /// Sama seperti [toggleLikeWithResult], hanya hasil bool-nya dibuang.
  static Future<void> toggleLike(
    WidgetRef ref,
    TrackModel track, {
    BuildContext? context,
  }) async {
    await toggleLikeWithResult(ref, track, context: context);
  }

  /// Retry like setelah login dari sheet: tunggu status login benar-benar
  /// jadi `true` (maks ~2 detik) baru jalankan alur login.
  static Future<void> _toggleAfterLogin(
    WidgetRef ref,
    TrackModel track,
    BuildContext context,
  ) async {
    for (var i = 0; i < 10; i++) {
      if (_isLoggedInSafe(ref)) break;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!context.mounted) return;
    await toggleLikeWithResult(ref, track, context: context);
  }

  /// Baca status login tanpa melempar: kalau lapisan auth belum bisa
  /// dibuat (mis. Supabase belum di-init di main), anggap tamu.
  static bool _isLoggedInSafe(WidgetRef ref) {
    try {
      return ref.read(isLoggedInProvider);
    } catch (_) {
      return false;
    }
  }
}
