import 'package:flutter/material.dart';

import '../design/omni_x_button.dart';
import '../theme/omnix_theme.dart';
import 'auth_view.dart';

/// S01 Splash/welcome (M0) — layar sambut sederhana.
///
/// Dipakai koordinator sebagai gerbang awal aplikasi (lihat catatan di
/// bawah). Logo lama `assets/images/logo.png`, nama OmniX, dua aksi:
///
/// * "Masuk sebagai tamu" (utama) → [onContinueAsGuest]: lanjut ke
///   aplikasi tanpa akun (cari + putar lagu).
/// * "Masuk / Daftar" → buka [AuthView]; bila masuk berhasil, lanjut ke
///   aplikasi lewat [onContinueAsGuest] juga.
///
/// Cara memakai (koordinator, JANGAN ubah main.dart dari Worker C):
/// ```dart
/// // Opsi A — ganti home di MaterialApp:
/// home: WelcomeView(
///   onContinueAsGuest: () {
///     // tampilkan OmniXAppShell, mis. lewat state di widget induk
///     // atau Navigator.pushReplacement ke OmniXAppShell.
///   },
/// ),
/// // Opsi B — route bernama di MaterialApp.routes:
/// '/welcome': (_) => WelcomeView(onContinueAsGuest: _masukAplikasi),
/// ```
/// [onContinueAsGuest] dipanggil sekali tiap kali pengguna memilih
/// lanjut — tamu maupun setelah login berhasil dari AuthView.
class WelcomeView extends StatelessWidget {
  final VoidCallback onContinueAsGuest;

  const WelcomeView({
    super.key,
    required this.onContinueAsGuest,
  });

  Future<void> _openAuth(BuildContext context) async {
    final entered = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const AuthView(),
      ),
    );
    if (entered == true) {
      onContinueAsGuest();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.music_note_rounded,
                    size: 96,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'OmniX',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: OmniXTokens.typeDisplay,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Musik tanpa batas, gratis untuk semua.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: OmniXTokens.typeBase,
                ),
              ),
              const Spacer(),
              OmniXButton(
                label: 'Masuk sebagai tamu',
                size: OmniXButtonSize.lg,
                onPressed: onContinueAsGuest,
              ),
              const SizedBox(height: 12),
              OmniXButton(
                label: 'Masuk / Daftar',
                variant: OmniXButtonVariant.secondary,
                size: OmniXButtonSize.lg,
                onPressed: () => _openAuth(context),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
