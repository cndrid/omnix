import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_app/views/app_shell.dart';

void main() {
  group('resolveBackAction', () {
    test('pemutar fullscreen terbuka -> tutup pemutar', () {
      expect(
        resolveBackAction(isPlayerOpen: true, isHomeTab: false),
        BackAction.closePlayer,
      );
      // Pemutar menang atas tab: walau sudah di Beranda, back menutup
      // pemutar dulu, bukan keluar aplikasi.
      expect(
        resolveBackAction(isPlayerOpen: true, isHomeTab: true),
        BackAction.closePlayer,
      );
    });

    test('pemutar tertutup, tab bukan Beranda -> pindah ke Beranda', () {
      expect(
        resolveBackAction(isPlayerOpen: false, isHomeTab: false),
        BackAction.goHome,
      );
    });

    test('pemutar tertutup, sudah di Beranda -> keluar aplikasi', () {
      expect(
        resolveBackAction(isPlayerOpen: false, isHomeTab: true),
        BackAction.exitApp,
      );
    });
  });
}
