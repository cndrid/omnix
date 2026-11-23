import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/omni_x_bottom_sheet.dart';
import '../../design/omni_x_button.dart';
import '../../providers/auth_provider.dart';
import '../../theme/omnix_theme.dart';
import '../auth_view.dart';

/// Bottom sheet login — dibuka saat aksi yang butuh akun (mis. suka lagu,
/// buat playlist, simpan ke Library) diketuk dalam mode tamu.
///
/// Setelah login berhasil, sheet menutup dan [onLoggedIn] dipanggil
/// supaya aksi yang tertunda (mis. like) langsung dijalankan pemanggil.
Future<void> showLoginSheet({
  required BuildContext context,
  VoidCallback? onLoggedIn,
}) {
  return showOmniXBottomSheet<void>(
    context: context,
    title: 'Masuk untuk menyimpan',
    children: [
      _LoginSheetForm(
        outerContext: context,
        onLoggedIn: onLoggedIn,
      ),
    ],
  );
}

class _LoginSheetForm extends ConsumerStatefulWidget {
  /// Context pemanggil sheet (tetap hidup setelah sheet ditutup) —
  /// dipakai untuk membuka layar daftar setelah sheet di-pop.
  final BuildContext outerContext;
  final VoidCallback? onLoggedIn;

  const _LoginSheetForm({
    required this.outerContext,
    this.onLoggedIn,
  });

  @override
  ConsumerState<_LoginSheetForm> createState() => _LoginSheetFormState();
}

class _LoginSheetFormState extends ConsumerState<_LoginSheetForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.status == AuthStatus.success) {
      Navigator.of(context).pop();
      widget.onLoggedIn?.call();
    }
  }

  void _openSignUp() {
    Navigator.of(context).pop();
    Navigator.of(widget.outerContext).push(
      MaterialPageRoute(
        builder: (_) => AuthView(
          initialIsSignUp: true,
          // Teruskan aksi tertunda (mis. like): AuthView memanggil ini
          // saat masuk/daftar berhasil, sebelum menutup layar.
          onAuthenticated: widget.onLoggedIn,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Masuk supaya lagu yang kamu sukai, playlist, dan riwayat '
              'tersimpan di akun kamu dan bisa dipakai di perangkat lain.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: OmniXTokens.typeBase,
              ),
            ),
            const SizedBox(height: 20),
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
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
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
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Tampilkan kata sandi'
                      : 'Sembunyikan kata sandi',
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
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
              label: 'Masuk',
              size: OmniXButtonSize.lg,
              isLoading: isLoading,
              onPressed: isLoading ? null : _submit,
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: isLoading ? null : _openSignUp,
              child: const Text('Belum punya akun? Daftar'),
            ),
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('Lanjutkan sebagai tamu'),
            ),
          ],
        ),
      ),
    );
  }
}
