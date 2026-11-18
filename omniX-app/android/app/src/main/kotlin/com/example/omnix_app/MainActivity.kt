package com.example.omnix_app

import com.ryanheise.audioservice.AudioServiceActivity

// Mewarisi AudioServiceActivity supaya activity memakai FlutterEngine
// bersama milik audio_service — syarat agar media session / notifikasi
// media audio_service terhubung ke aplikasi.
class MainActivity : AudioServiceActivity()
