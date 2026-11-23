import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/supabase_service.dart';

/// Instance [SupabaseService] (sudah di-init di `main()`).
final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  return SupabaseService();
});

/// Layanan auth; dibuat dari klien Supabase yang sudah terinisialisasi.
final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseServiceProvider);
  return AuthService(supabase.client);
});

/// Stream pengguna yang sedang masuk (null = mode tamu / belum login).
final authStateProvider = StreamProvider<User?>((ref) {
  final auth = ref.watch(authServiceProvider);
  return auth.authStateChanges;
});

/// True kalau ada pengguna yang sedang masuk.
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

/// Status proses login/daftar di [AuthController].
enum AuthStatus { idle, loading, error, success }

/// State form auth: status + pesan + penanda khusus.
class AuthState {
  final AuthStatus status;
  final String? message;

  /// True kalau akun baru dibuat tapi email belum dikonfirmasi —
  /// UI menampilkan state "cek email", bukan menganggap pengguna masuk.
  final bool needsEmailConfirmation;

  /// True kalau login berhasil tapi profil gagal disinkronkan ke tabel
  /// `public.users` (policy INSERT belum ada — lihat
  /// [AuthService.ensureUserProfile]). Login tetap berhasil; UI boleh
  /// menampilkan peringatan ringan, bukan error.
  final bool profileSyncWarning;

  const AuthState({
    this.status = AuthStatus.idle,
    this.message,
    this.needsEmailConfirmation = false,
    this.profileSyncWarning = false,
  });

  const AuthState.idle() : this();

  const AuthState.loading() : this(status: AuthStatus.loading);

  const AuthState.error(this.message)
      : status = AuthStatus.error,
        needsEmailConfirmation = false,
        profileSyncWarning = false;

  const AuthState.success({
    this.message,
    this.profileSyncWarning = false,
  })  : status = AuthStatus.success,
        needsEmailConfirmation = false;

  const AuthState.needsEmailConfirmation(this.message)
      : status = AuthStatus.success,
        needsEmailConfirmation = true,
        profileSyncWarning = false;

  bool get isLoading => status == AuthStatus.loading;
}

/// Controller login/daftar/keluar untuk layar auth.
class AuthController extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthController(this._authService) : super(const AuthState.idle());

  /// Daftar akun baru. Hasil "cek email" masuk ke state
  /// [AuthState.needsEmailConfirmation], bukan error.
  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    state = const AuthState.loading();
    final result = await _authService.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    if (!result.ok) {
      state = AuthState.error(result.message ?? 'Pendaftaran gagal.');
      return;
    }
    if (result.needsEmailConfirmation) {
      state = AuthState.needsEmailConfirmation(result.message);
      return;
    }
    await _finishSuccessfulAuth(result.message);
  }

  /// Masuk dengan email + kata sandi.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    final result = await _authService.signIn(
      email: email,
      password: password,
    );
    if (!result.ok) {
      state = AuthState.error(result.message ?? 'Tidak bisa masuk.');
      return;
    }
    await _finishSuccessfulAuth(result.message);
  }

  /// Keluar dari akun (kembali ke mode tamu).
  Future<void> signOut() async {
    state = const AuthState.loading();
    try {
      await _authService.signOut();
      state = const AuthState.idle();
    } catch (_) {
      state = const AuthState.error('Tidak bisa keluar, coba lagi.');
    }
  }

  /// Setelah login/daftar berhasil (ada sesi): sinkronkan profil ke
  /// tabel `public.users`. Kalau sinkronisasi gagal (mis. policy INSERT
  /// belum ada), login TETAP dianggap berhasil — state hanya mencatat
  /// [AuthState.profileSyncWarning].
  Future<void> _finishSuccessfulAuth(String? message) async {
    try {
      await _authService.ensureUserProfile();
      state = AuthState.success(message: message);
    } on ProfileSyncException {
      state = AuthState.success(
        message: message,
        profileSyncWarning: true,
      );
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthController(authService);
});
