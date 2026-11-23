import 'package:supabase_flutter/supabase_flutter.dart';

/// Hasil operasi auth yang ramah UI: tidak pernah melempar exception
/// mentah ke layar — semua kegagalan dibungkus jadi [AuthResult] dengan
/// pesan Bahasa Indonesia.
class AuthResult {
  /// True kalau operasi berhasil (masuk/daftar selesai).
  final bool ok;

  /// True kalau akun berhasil dibuat tapi email belum dikonfirmasi,
  /// sehingga belum ada sesi login. UI harus menampilkan state
  /// "cek email untuk konfirmasi" dan TIDAK menganggap pengguna masuk.
  final bool needsEmailConfirmation;

  /// Pesan untuk pengguna: ringkasan sukses, atau pesan error yang
  /// ramah kalau [ok] false.
  final String? message;

  const AuthResult({
    required this.ok,
    this.needsEmailConfirmation = false,
    this.message,
  });

  const AuthResult.success({this.message})
      : ok = true,
        needsEmailConfirmation = false;

  const AuthResult.needsEmailConfirmation({this.message})
      : ok = true,
        needsEmailConfirmation = true;

  const AuthResult.failure(this.message)
      : ok = false,
        needsEmailConfirmation = false;
}

/// Gagal menyinkronkan profil ke tabel `public.users`.
///
/// Penyebab yang diketahui (M0): skema saat ini TIDAK punya policy
/// INSERT untuk tabel users (hanya select/update/delete), jadi upsert
/// ditolak RLS sampai policy `users_insert` ditambah dari dashboard
/// Supabase. Bukan kegagalan login — pengguna tetap masuk, hanya
/// profilnya belum tersimpan di database.
class ProfileSyncException implements Exception {
  final String message;

  const ProfileSyncException(
      [this.message = 'Profil belum bisa dibuat, coba lagi nanti.']);

  @override
  String toString() => 'ProfileSyncException: $message';
}

/// Layanan autentikasi email + kata sandi via Supabase Auth (GoTrue).
///
/// Konfirmasi email AKTIF di proyek ini: [signUp] mengembalikan user
/// TANPA session (ada `confirmation_sent_at`), dan [signIn] untuk akun
/// yang belum dikonfirmasi akan gagal dengan pesan "periksa email".
class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  GoTrueClient get _auth => _client.auth;

  /// Stream perubahan status login; mengembalikan [User] yang sedang
  /// masuk, atau null kalau keluar / mode tamu.
  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((state) => state.session?.user);

  /// Pengguna yang sedang masuk, atau null kalau mode tamu.
  User? get currentUser => _auth.currentUser;

  /// Daftar akun baru dengan email + kata sandi.
  ///
  /// Karena konfirmasi email aktif, hasil normalnya adalah
  /// [AuthResult.needsEmailConfirmation] (akun dibuat, belum ada sesi).
  /// Kalau konfirmasi email dimatikan di dashboard suatu hari nanti,
  /// hasilnya langsung [AuthResult.success] dengan sesi aktif.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: displayName != null && displayName.trim().isNotEmpty
            ? {'display_name': displayName.trim()}
            : null,
      );
      if (response.session != null) {
        return const AuthResult.success(
          message: 'Akun berhasil dibuat. Selamat datang!',
        );
      }
      if (response.user != null) {
        return const AuthResult.needsEmailConfirmation(
          message:
              'Akun berhasil dibuat. Periksa email kamu untuk konfirmasi akun.',
        );
      }
      return const AuthResult.failure(
        'Pendaftaran gagal. Coba lagi.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthMessage(e));
    } catch (_) {
      return const AuthResult.failure(
        'Tidak bisa terhubung. Periksa koneksi internet kamu.',
      );
    }
  }

  /// Masuk dengan email + kata sandi.
  ///
  /// Akun yang belum dikonfirmasi emailnya akan gagal di sini dengan
  /// pesan "periksa email" (bukan error teknis).
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      if (response.session != null) {
        return const AuthResult.success(message: 'Selamat datang kembali!');
      }
      return const AuthResult.failure(
        'Periksa email kamu untuk konfirmasi akun.',
      );
    } on AuthException catch (e) {
      return AuthResult.failure(_friendlyAuthMessage(e));
    } catch (_) {
      return const AuthResult.failure(
        'Tidak bisa terhubung. Periksa koneksi internet kamu.',
      );
    }
  }

  /// Keluar dari akun (kembali ke mode tamu).
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Buat / perbarui baris profil di tabel `public.users` untuk pengguna
  /// yang sedang masuk (id = auth uid, email, display_name).
  ///
  /// PENTING — policy INSERT belum ada: skema saat ini hanya punya
  /// policy select/update/delete untuk tabel users, jadi upsert ini
  /// kemungkinan besar DITOLAK RLS sampai policy `users_insert`
  /// ditambahkan dari dashboard Supabase (mis. `for insert to
  /// authenticated with check (id = auth.uid())`). Kegagalan itu
  /// dilempar sebagai [ProfileSyncException] — pemanggil WAJIB
  /// menangkapnya dan tetap menganggap login berhasil (hanya mencatat
  /// peringatan sinkronisasi profil), jangan crash aplikasi.
  ///
  /// Tidak ada jalan lain dari sisi aplikasi: tidak ada service_role
  /// key (dan tidak boleh diminta/disimpan).
  Future<void> ensureUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ProfileSyncException(
        'Profil belum bisa dibuat: belum ada pengguna yang masuk.',
      );
    }
    try {
      await _client.from('users').upsert({
        'id': user.id,
        'email': user.email,
        'display_name':
            user.userMetadata?['display_name'] as String? ?? '',
      });
    } on PostgrestException catch (e) {
      // Penolakan RLS (policy INSERT belum ada) mendarat di sini.
      throw ProfileSyncException(
        'Profil belum bisa dibuat (${e.code ?? 'akses ditolak'}). '
        'Login tetap berhasil.',
      );
    } catch (_) {
      throw const ProfileSyncException();
    }
  }

  /// Terjemahkan error mentah GoTrue ke pesan Bahasa Indonesia yang
  /// ramah — tanpa istilah teknis (tanpa kode/status mentah).
  String _friendlyAuthMessage(AuthException e) {
    final code = e.code ?? '';
    final raw = e.message.toLowerCase();
    if (code == 'email_not_confirmed' ||
        raw.contains('email not confirmed')) {
      return 'Periksa email kamu untuk konfirmasi akun.';
    }
    if (code == 'invalid_credentials' ||
        raw.contains('invalid login credentials')) {
      return 'Email atau kata sandi salah.';
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        raw.contains('already registered') ||
        raw.contains('already exists')) {
      return 'Email ini sudah terdaftar, coba masuk.';
    }
    if (code == 'weak_password' || raw.contains('password')) {
      return 'Kata sandi terlalu pendek, minimal 6 karakter.';
    }
    if (code == 'invalid_email' || raw.contains('invalid email')) {
      return 'Alamat email tidak valid.';
    }
    if (code == 'over_email_send_rate_limit' ||
        raw.contains('rate limit')) {
      return 'Terlalu banyak percobaan. Tunggu sebentar lalu coba lagi.';
    }
    return 'Terjadi kesalahan, coba lagi.';
  }
}
