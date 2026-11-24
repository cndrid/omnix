package com.example.omnix_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Activity utama OmniX.
 *
 * Dulu mewarisi AudioServiceActivity (audio_service) supaya activity
 * memakai FlutterEngine bersama milik audio_service. Media3 tidak butuh
 * itu — diganti FlutterActivity biasa (24 Nov 2026).
 *
 * Dua hal yang dilakukan activity ini untuk Media3:
 * 1. Memakai engine dari cache ([ENGINE_ID]) supaya isolate Dart — dan
 *    dengan itu just_audio — tetap hidup saat activity di-swipe dari
 *    recent-apps. Kalau engine ikut hancur bersama activity, lagu
 *    berhenti begitu pengguna meninggalkan aplikasi, dan tombol media
 *    di notifikasi tidak punya Dart untuk diteruskan. Engine cache tidak
 *    dihancurkan FlutterActivity saat activity destroy; proses tetap
 *    hidup karena service Media3 berstatus foreground saat memutar.
 * 2. Mendaftarkan MethodChannel Media3 ([Media3Bridge.attach]) supaya
 *    service bisa mengirim perintah tombol media ke Dart dan menerima
 *    update state dari Dart.
 */
class MainActivity : FlutterActivity() {

    override fun getCachedEngineId(): String = ENGINE_ID

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Media3Bridge.attach(
            flutterEngine.dartExecutor.binaryMessenger,
            applicationContext,
        )
    }

    companion object {
        const val ENGINE_ID = "omnix_engine"
    }
}
