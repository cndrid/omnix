import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/omni_x_button.dart';
import '../providers/auth_provider.dart';
import '../theme/omnix_theme.dart';

/// Layar auth S02: Masuk / Daftar.
///
/// Mode tamu tetap bisa memakai aplikasi tanpa layar ini (cari + putar
/// lagu); layar ini dibuka saat pengguna memilih masuk — mis. dari
/// profil, atau saat aksi yang butuh akun (suka, playlist, Library).
/// Setelah masuk berhasil, layar menutup sendiri.
class AuthView extends ConsumerStatefulWidget {
  /// Buka langsung dalam mode daftar (dipakai tautan "Belum punya akun?
  /// Daftar" dari sheet login).
  final bool initialIsSignUp;

  /// Dipanggil saat masuk/daftar BERHASIL (ada sesi), sebelum layar
  /// ditutup — dipakai pemanggil yang punya aksi tertunda (mis. like
  /// dari sheet login yang diteruskan lewat jalur Daftar).
  final VoidCallback? onAuthenticated;

  const AuthView({
    super.key,
    this.initialIsSignUp = false,
    this.onAuthenticated,
  });

  @override
  ConsumerState<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends ConsumerState<AuthView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  late bool _isSignUp = widget.initialIsSignUp;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() => _isSignUp = !_isSignUp);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final controller = ref.read(authControllerProvider.notifier);
    if (_isSignUp) {
      await controller.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _displayNameController.text.trim().isEmpty
            ? null
            : _displayNameController.text.trim(),
      );
    } else {
      await controller.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    // Masuk berhasil (ada sesi): tutup layar, lanjut ke aplikasi.
    // State "cek email" (daftar, belum ada sesi) tetap di layar ini.
    if (state.status == AuthStatus.success &&
        !state.needsEmailConfirmation) {
      widget.onAuthenticated?.call();
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSignUp ? 'Buat Akun' : 'Masuk'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isSignUp
                      ? 'Buat akun untuk menyimpan lagu dan playlist kamu.'
                      : 'Masuk untuk menyimpan lagu dan playlist kamu.',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: OmniXTokens.typeBase,
                  ),
                ),
                const SizedBox(height: 24),

                // State "cek email" setelah daftar: konfirmasi email
                // aktif di proyek ini, jadi belum ada sesi login.
                if (authState.needsEmailConfirmation) ...[
                  _InfoCard(
                    icon: Icons.mark_email_read_outlined,
                    title: 'Periksa email kamu',
                    body: authState.message ??
                        'Periksa email kamu untuk konfirmasi akun.',
                  ),
                  const SizedBox(height: 16),
                  OmniXButton(
                    label: 'Kembali Masuk',
                    size: OmniXButtonSize.lg,
                    onPressed: () {
                      setState(() => _isSignUp = false);
                    },
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _displayNameController,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Nama tampil',
                        hintText: 'Nama yang dilihat pengguna lain',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Isi nama tampil kamu.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'nama@email.com',
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return 'Isi alamat email kamu.';
                      }
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(email)) {
                        return 'Alamat email tidak valid.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    enabled: !isLoading,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Kata sandi',
                      hintText: 'Minimal 6 karakter',
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Tampilkan kata sandi'
                            : 'Sembunyikan kata sandi',
                        onPressed: () {
                          setState(
                            () => _obscurePassword = !_obscurePassword,
                          );
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Isi kata sandi kamu.';
                      }
                      if (value.length < 6) {
                        return 'Kata sandi minimal 6 karakter.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Error dari server (mis. email/kata sandi salah)
                  // tampil di dekat field, bukan dialog.
                  if (authState.status == AuthStatus.error &&
                      authState.message != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        authState.message!,
                        style: TextStyle(
                          color: scheme.error,
                          fontSize: OmniXTokens.typeSm,
                        ),
                      ),
                    ),

                  OmniXButton(
                    label: _isSignUp ? 'Daftar' : 'Masuk',
                    size: OmniXButtonSize.lg,
                    isLoading: isLoading,
                    onPressed: isLoading ? null : _submit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isLoading ? null : _toggleMode,
                    child: Text(
                      _isSignUp
                          ? 'Sudah punya akun? Masuk'
                          : 'Belum punya akun? Daftar',
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                OmniXButton(
                  label: 'Masuk sebagai tamu',
                  variant: OmniXButtonVariant.secondary,
                  size: OmniXButtonSize.lg,
                  onPressed: isLoading
                      ? null
                      : () => Navigator.of(context).pop(false),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sebagai tamu kamu tetap bisa mencari dan memutar lagu. '
                  'Masuk hanya diperlukan untuk menyimpan lagu, playlist, '
                  'dan riwayat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: OmniXTokens.typeSm,
                  ),
                ),
                // Peringatan ringan: login berhasil tapi profil belum
                // tersimpan di database (policy INSERT belum ada).
                if (authState.profileSyncWarning) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Catatan: profil kamu belum tersimpan di server, '
                    'tapi kamu sudah masuk.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: OmniXTokens.typeSm,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kartu info netral (mis. state "cek email") — tanpa warna error.
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(OmniXTokens.radiusCard),
        border: Border.all(color: scheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: OmniXTokens.successGreen),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: OmniXTokens.typeLg,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: OmniXTokens.typeBase,
            ),
          ),
        ],
      ),
    );
  }
}
