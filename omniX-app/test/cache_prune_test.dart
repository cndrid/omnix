import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omnix_app/services/audio_handler_service.dart';

/// Test logika prune cache audio (OmniXAudioHandler.selectCacheFilesToDelete):
/// dua batas — maks. 20 file DAN maks. ~200 MB total, file terlama dihapus
/// dulu. Murni file lokal (Directory.systemTemp), tanpa platform channel:
/// handler TIDAK di-instantiate di sini (AudioPlayer butuh platform).
void main() {
  group('selectCacheFilesToDelete', () {
    late Directory tmp;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('omnix_cache_prune_');
    });

    tearDown(() async {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    });

    Future<File> makeFile(String name, int bytes, DateTime modified) async {
      final f = File('${tmp.path}/$name');
      await f.writeAsBytes(List.filled(bytes, 0));
      await f.setLastModified(modified);
      return f;
    }

    String baseName(File f) => f.path.split('/').last;

    test('batas 20 file: 5 file terlama dihapus dulu', () async {
      final now = DateTime.now();
      final files = <File>[];
      for (var i = 0; i < 25; i++) {
        // f0 paling lama, f24 paling baru.
        files.add(
          await makeFile(
            'f$i.cache',
            1024,
            now.subtract(Duration(minutes: 25 - i)),
          ),
        );
      }

      final toDelete = OmniXAudioHandler.selectCacheFilesToDelete(files);

      expect(toDelete.length, 5);
      expect(
        toDelete.map(baseName).toSet(),
        {'f0.cache', 'f1.cache', 'f2.cache', 'f3.cache', 'f4.cache'},
      );
    });

    test('batas 200 MB: total dijaga, file terlama dihapus dulu', () async {
      final now = DateTime.now();
      final files = <File>[];
      // 5 file @ 50 MB = 250 MB; 4 file terbaru = 200 MB pas.
      for (var i = 0; i < 5; i++) {
        files.add(
          await makeFile(
            'big$i.cache',
            50 * 1024 * 1024,
            now.subtract(Duration(minutes: 5 - i)),
          ),
        );
      }

      final toDelete = OmniXAudioHandler.selectCacheFilesToDelete(files);

      expect(toDelete.length, 1);
      expect(baseName(toDelete.first), 'big0.cache');
    });

    test('di bawah kedua batas: tidak ada yang dihapus', () async {
      final now = DateTime.now();
      final files = <File>[];
      for (var i = 0; i < 3; i++) {
        files.add(
          await makeFile(
            'small$i.cache',
            1024 * 1024,
            now.subtract(Duration(minutes: 3 - i)),
          ),
        );
      }

      expect(OmniXAudioHandler.selectCacheFilesToDelete(files), isEmpty);
    });

    test('file terbaru dipertahankan walau sendirian melewati 200 MB',
        () async {
      final file = await makeFile(
        'huge.cache',
        210 * 1024 * 1024,
        DateTime.now(),
      );

      expect(OmniXAudioHandler.selectCacheFilesToDelete([file]), isEmpty);
    });
  });
}
