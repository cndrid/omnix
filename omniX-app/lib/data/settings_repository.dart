// Repository pengaturan M0 revamp OmniX.
//
// Sumber kebenaran lokal: settings_local (key-value string). Bila login,
// pengaturan juga di-upsert ke `user_settings` Supabase secara best-effort.
// [syncFromServer] membaca `user_settings` dan menimpa lokal — dipakai
// sekali setelah login.
import 'dart:developer' as developer;

// package:supabase dipakai — bukan supabase_flutter — supaya file ini
// tetap bisa dipakai dari `dart run` murni; pubspec.yaml di luar
// kewenangan worker ini, supabase adalah dep transitif supabase_flutter.
// ignore: depend_on_referenced_packages
import 'package:supabase/supabase.dart';

import 'local_db.dart';

class SettingsRepository {
  final SupabaseClient _supabase;
  final AppDatabase _db;
  final bool Function() _isLoggedIn;
  final String? Function() _currentUserId;

  // Kunci lokal == nama kolom user_settings Supabase.
  static const keyAudioQuality = 'audio_quality';
  static const keyDataSaver = 'data_saver';
  static const keyPrivateSession = 'private_session';
  static const keyFriendActivity = 'friend_activity';
  static const keyCrossfadeSeconds = 'crossfade_seconds';
  static const keyGapless = 'gapless';
  static const keyAutomix = 'automix';
  static const keyNormalization = 'normalization';
  static const keyEqPreset = 'eq_preset';

  static const audioQualities = <String>{'low', 'standard', 'high'};

  SettingsRepository({
    required SupabaseClient supabase,
    required AppDatabase db,
    required bool Function() isLoggedIn,
    required String? Function() currentUserId,
  })  : _supabase = supabase,
        _db = db,
        _isLoggedIn = isLoggedIn,
        _currentUserId = currentUserId;

  bool get _loggedIn => _isLoggedIn() && _currentUserId() != null;

  // ------------------------------------------------------------------
  // API generik key-value lokal
  // ------------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final row = await (_db.select(_db.settingsLocal)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) async {
    await _db.into(_db.settingsLocal).insertOnConflictUpdate(
          SettingsLocalCompanion.insert(key: key, value: value),
        );
  }

  // ------------------------------------------------------------------
  // API bertipe (dipakai UI)
  // ------------------------------------------------------------------

  Future<String> getAudioQuality() async =>
      (await getSetting(keyAudioQuality)) ?? 'standard';

  /// Hanya 'low' / 'standard' / 'high' (check constraint Supabase).
  /// Nilai lain diabaikan.
  Future<void> setAudioQuality(String value) async {
    if (!audioQualities.contains(value)) return;
    await setSetting(keyAudioQuality, value);
    await _pushToServer();
  }

  Future<bool> getBoolSetting(String key, {bool defaultValue = false}) async {
    final raw = await getSetting(key);
    if (raw == null) return defaultValue;
    return raw == 'true';
  }

  Future<void> setBoolSetting(String key, bool value) async {
    await setSetting(key, value.toString());
    await _pushToServer();
  }

  Future<double> getCrossfadeSeconds() async {
    final raw = await getSetting(keyCrossfadeSeconds);
    return double.tryParse(raw ?? '') ?? 0.0;
  }

  /// Dijepit 0..12 (check constraint Supabase).
  Future<void> setCrossfadeSeconds(double seconds) async {
    await setSetting(
      keyCrossfadeSeconds,
      seconds.clamp(0.0, 12.0).toString(),
    );
    await _pushToServer();
  }

  Future<String?> getEqPreset() => getSetting(keyEqPreset);

  Future<void> setEqPreset(String? preset) async {
    if (preset == null || preset.isEmpty) {
      await (_db.delete(_db.settingsLocal)
            ..where((t) => t.key.equals(keyEqPreset)))
          .go();
    } else {
      await setSetting(keyEqPreset, preset);
    }
    await _pushToServer();
  }

  // ------------------------------------------------------------------
  // Sinkronisasi Supabase
  // ------------------------------------------------------------------

  /// Baca `user_settings` dari server (bila login dan barisnya ada) lalu
  /// timpa pengaturan lokal. Dipakai sekali setelah login. Tidak melempar
  /// bila offline / baris belum ada.
  Future<void> syncFromServer() async {
    if (!_loggedIn) return;
    final userId = _currentUserId()!;
    try {
      final row = await _supabase
          .from('user_settings')
          .select(
            'audio_quality, data_saver, private_session, friend_activity, '
            'crossfade_seconds, gapless, automix, normalization, eq_preset',
          )
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return;
      await _db.transaction(() async {
        await _applyServerValue(keyAudioQuality, row['audio_quality']);
        await _applyServerValue(keyDataSaver, row['data_saver']);
        await _applyServerValue(keyPrivateSession, row['private_session']);
        await _applyServerValue(keyFriendActivity, row['friend_activity']);
        await _applyServerValue(
          keyCrossfadeSeconds,
          row['crossfade_seconds'],
        );
        await _applyServerValue(keyGapless, row['gapless']);
        await _applyServerValue(keyAutomix, row['automix']);
        await _applyServerValue(keyNormalization, row['normalization']);
        await _applyServerValue(keyEqPreset, row['eq_preset']);
      });
    } catch (e) {
      developer.log(
        'Gagal sync pengaturan dari server: $e',
        name: 'omnix.settings',
      );
    }
  }

  /// Upsert seluruh pengaturan lokal ke `user_settings` (best-effort).
  Future<void> pushToServer() => _pushToServer();

  Future<void> _pushToServer() async {
    if (!_loggedIn) return;
    final userId = _currentUserId()!;
    try {
      await _supabase.from('user_settings').upsert({
        'user_id': userId,
        'audio_quality': await getAudioQuality(),
        'data_saver': await getBoolSetting(keyDataSaver),
        'private_session': await getBoolSetting(keyPrivateSession),
        'friend_activity':
            await getBoolSetting(keyFriendActivity, defaultValue: true),
        'crossfade_seconds': await getCrossfadeSeconds(),
        'gapless': await getBoolSetting(keyGapless, defaultValue: true),
        'automix': await getBoolSetting(keyAutomix),
        'normalization': await getBoolSetting(keyNormalization),
        'eq_preset': await getEqPreset(),
      }, onConflict: 'user_id');
    } catch (e) {
      developer.log(
        'Gagal push pengaturan ke server: $e',
        name: 'omnix.settings',
      );
    }
  }

  Future<void> _applyServerValue(String key, Object? value) async {
    if (value == null) return;
    await _db.into(_db.settingsLocal).insertOnConflictUpdate(
          SettingsLocalCompanion.insert(key: key, value: value.toString()),
        );
  }
}
