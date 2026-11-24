package com.example.omnix_app

import android.app.PendingIntent
import android.content.Intent
import android.os.Looper
import androidx.core.content.ContextCompat
import androidx.media3.common.util.UnstableApi
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.google.common.base.Function
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * MediaSessionService Media3 untuk OmniX (pengganti audio_service,
 * 24 Nov 2026).
 *
 * Satu-satunya tugas service ini: memegang [MediaSession] yang
 * player-nya [DartMirroringPlayer] (cermin state Dart). Media3 yang
 * memposting notifikasi media otomatis saat lagu diputar — notifikasi
 * inilah yang dulu tidak pernah muncul lewat audio_service di Poco F7.
 *
 * Siklus hidup service mengikuti Media3 default: service menjadi
 * foreground saat memutar; saat jeda, foreground dilepas (lihat
 * [onUpdateNotificationAsync]) tapi notifikasi tetap tampil supaya
 * pengguna bisa lanjut memutar dari pusat kontrol / lock screen.
 * Service berhenti sendiri kalau session dilepas dan tidak ada
 * controller yang terikat.
 */
class OmniXPlaybackService : MediaSessionService() {

    private var mediaSession: MediaSession? = null
    private var player: DartMirroringPlayer? = null

    override fun onCreate() {
        super.onCreate()
        val dartPlayer = DartMirroringPlayer(Looper.getMainLooper())
        player = dartPlayer
        // Ketuk notifikasi membuka aplikasi.
        val sessionActivity =
            PendingIntent.getActivity(
                this,
                0,
                Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE,
            )
        mediaSession =
            MediaSession.Builder(this, dartPlayer)
                .setSessionActivity(sessionActivity)
                .build()
        Media3Bridge.registerPlayer(dartPlayer)
    }

    // Session yang dikembalikan di sini otomatis dikelola service
    // (ditambah saat controller terhubung, dilepas saat session release)
    // — tidak perlu addSession manual.
    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? {
        return mediaSession
    }

    /**
     * Media3 default menahan foreground sampai 10 menit setelah jeda
     * (user-engaged timeout) supaya resume cepat tidak perlu restart
     * foreground. OmniX tidak butuh itu — lepas foreground segera saat
     * tidak memutar, supaya tidak menahan baterai / notif "aplikasi
     * berjalan" saat jeda. Notifikasi tetap tampil (STOP_FOREGROUND_DETACH
     * = lepas foreground, biarkan notifikasi), jadi pengguna tetap bisa
     * menekan putar dari pusat kontrol.
     *
     * Catatan: callback ini juga jalan saat artwork notifikasi selesai
     * dimuat — kalau pengguna menekan jeda tepat di jendela itu, service
     * bisa sebentar kembali foreground sampai update notifikasi
     * berikutnya; batas atasnya tetap timeout 10 menit Media3.
     */
    @OptIn(UnstableApi::class)
    override fun onUpdateNotificationAsync(
        session: MediaSession,
        startInForegroundRequired: Boolean,
    ): ListenableFuture<Void?> {
        val future = super.onUpdateNotificationAsync(session, startInForegroundRequired)
        return Futures.transform(
            future,
            Function<Void?, Void?> {
                if (!session.player.isPlaying) {
                    stopForeground(STOP_FOREGROUND_DETACH)
                }
                null
            },
            ContextCompat.getMainExecutor(this),
        )
    }

    override fun onDestroy() {
        mediaSession?.release()
        mediaSession = null
        Media3Bridge.unregisterPlayer()
        player?.release()
        player = null
        super.onDestroy()
    }
}
