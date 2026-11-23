// Database lokal (Drift) untuk mode tamu + cache offline M0 revamp OmniX.
//
// CATATAN ARSITEKTUR (penting):
// File ini SENGAJA tidak mengimpor `package:drift_flutter` — paket itu
// mengimpor `dart:ui` sehingga file ini tidak bisa dipakai dari `dart run`
// murni (smoke test tool/test_m0_drift.dart). Karena itu AppDatabase
// menerima [QueryExecutor] lewat konstruktor; executor file untuk aplikasi
// (`driftDatabase(name: 'omnix_local')` dari drift_flutter — benar untuk
// Android/iOS karena memakai sqlite3_flutter_libs + path aplikasi) dibuat
// di providers/data_providers.dart, sedangkan test memakai
// [AppDatabase.memory].
//
// TIDAK ADA audio_url di tabel mana pun: URL stream kedaluwarsa ~6 jam dan
// terikat IP, jadi hanya metadata (videoId/judul/artis/cover/durasi) yang
// disimpan. Stream selalu diekstrak ulang client-side saat diputar.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'local_db.g.dart';

/// Lagu yang disukai — cache lokal + sumber kebenaran untuk mode tamu.
@DataClassName('LikedSongLocal')
class LikedSongsLocal extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artistLine => text()();
  TextColumn get coverUrl => text()();
  IntColumn get durationMs => integer().nullable()();
  IntColumn get likedAt => integer()();

  @override
  Set<Column> get primaryKey => {videoId};
}

/// Riwayat putar lokal (Recently Played). Maks 30 baris, yang terlama
/// dihapus — ditegakkan PlayHistoryRepository.
@DataClassName('RecentLocal')
class RecentsLocal extends Table {
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get artistLine => text()();
  TextColumn get coverUrl => text()();
  IntColumn get playedAt => integer()();

  @override
  Set<Column> get primaryKey => {videoId};
}

/// Antrean aktif. Seluruh isi diganti tiap kali antrean berubah
/// (QueueRepository.saveQueue). `kind`: 'upcoming' atau 'history'.
@DataClassName('QueueEntryLocal')
class QueueLocal extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get videoId => text()();
  IntColumn get position => integer()();
  TextColumn get kind => text()();
}

/// Pengaturan key-value lokal (cermin user_settings Supabase).
@DataClassName('SettingLocal')
class SettingsLocal extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [LikedSongsLocal, RecentsLocal, QueueLocal, SettingsLocal],
)
class AppDatabase extends _$AppDatabase {
  /// Konstruktor utama: [executor] di-supply pemanggil.
  /// Aplikasi memakai `driftDatabase(name: 'omnix_local')` dari
  /// drift_flutter (lihat providers/data_providers.dart).
  AppDatabase(super.executor);

  /// Database in-memory — untuk smoke test dan unit test. Tidak menyentuh
  /// file maupun Supabase.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
