package com.example.omnix_app

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Application OmniX — WAJIB ADA, jangan dihapus.
 *
 * MainActivity memakai cached engine ([MainActivity.ENGINE_ID]) supaya
 * isolate Dart — dan dengan itu just_audio — tetap hidup saat activity
 * di-swipe dari recent-apps. Tapi FlutterActivity TIDAK membuat engine
 * itu sendiri: dia hanya mengambil dari FlutterEngineCache. Kalau tidak
 * ada yang mengisi cache, aplikasi crash saat dibuka:
 *
 *   IllegalStateException: The requested cached FlutterEngine did not
 *   exist in the FlutterEngineCache: 'omnix_engine'
 *
 * (Kejadian di Run #18, 24 Nov 2026 — aplikasi tidak bisa dibuka sama
 * sekali.) Kelas inilah yang mengisinya: saat proses aplikasi mulai,
 * buat satu FlutterEngine, jalankan Dart (main.dart), daftarkan plugin,
 * lalu simpan ke cache sebelum activity pertama dibuka.
 *
 * Plugin didaftarkan di sini secara eksplisit karena Dart sudah jalan
 * sejak Application.onCreate — sebelum activity mana pun menempel dan
 * sebelum embedding sempat mendaftarkan plugin sendiri. Tanpa ini,
 * panggilan plugin pertama dari Dart (mis. just_audio) gagal dengan
 * MissingPluginException.
 */
class OmniXApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
        )
        GeneratedPluginRegistrant.registerWith(engine)
        FlutterEngineCache.getInstance().put(MainActivity.ENGINE_ID, engine)
    }
}
