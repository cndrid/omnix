import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Titik masuk tunggal ke Supabase untuk aplikasi.
///
/// Dipanggil sekali dari `main()` sebelum `runApp` (lihat cuplikan di
/// laporan M0). [initialize] aman dipanggil berulang: panggilan kedua
/// dan seterusnya langsung kembali tanpa menginisialisasi ulang.
class SupabaseService {
  bool _initialized = false;

  /// Inisialisasi Supabase. Wajib dipanggil (dan di-`await`) sebelum
  /// provider auth atau layanan lain memakai [client].
  ///
  /// Aman dipanggil dari instance mana pun: kalau klien global sudah
  /// di-init (mis. dari `main()` dengan instance lain, atau dari test),
  /// instance ini hanya menandai dirinya ter-init tanpa init ulang.
  Future<void> initialize() async {
    if (_initialized) return;
    if (_globallyInitialized) {
      _initialized = true;
      return;
    }
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
    );
    _initialized = true;
  }

  /// Apakah klien global sudah di-init (oleh instance mana pun).
  /// `Supabase.instance` melempar StateError kalau belum di-init.
  bool get _globallyInitialized {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Apakah [initialize] sudah berhasil dipanggil.
  bool get isInitialized => _initialized;

  /// Klien Supabase yang sudah terinisialisasi.
  ///
  /// Melempar [StateError] kalau [initialize] belum dipanggil — pemanggil
  /// (mis. provider) hanya boleh membaca ini setelah `main()` selesai
  /// menginisialisasi. Instance yang tidak di-init sendiri tetap bisa
  /// membaca klien global yang sudah di-init instance lain.
  SupabaseClient get client {
    if (!_initialized && !_globallyInitialized) {
      throw StateError(
        'Supabase belum diinisialisasi. Panggil '
        'SupabaseService.initialize() di main() sebelum runApp.',
      );
    }
    return Supabase.instance.client;
  }

  /// Klien Auth (GoTrue) — pintu masuk login/daftar/keluar.
  GoTrueClient get auth => client.auth;

  /// True kalau ada sesi login aktif (pengguna sudah masuk).
  bool get isLoggedIn => auth.currentUser != null;

  /// UID pengguna yang sedang masuk, atau null kalau mode tamu.
  String? get userId => auth.currentUser?.id;

  /// Email pengguna yang sedang masuk, atau null kalau mode tamu.
  String? get userEmail => auth.currentUser?.email;
}
