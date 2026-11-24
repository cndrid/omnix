package com.example.omnix_app

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Jembatan native sisi Media3 (pengganti audio_service, 24 Nov 2026).
 *
 * Satu-satunya penghubung antara isolate Dart dan MediaSession:
 * - Dart → native: `updateState` / `updateMediaItem` / `updateQueue`
 *   (lihat Media3Bridge di sisi Dart). Diteruskan ke
 *   [DartMirroringPlayer] milik [OmniXPlaybackService].
 * - Native → Dart: `play` / `pause` / `seekTo` / `skipToNext` /
 *   `skipToPrevious` (dipanggil player saat pengguna menekan tombol
 *   media). Dikirim lewat MethodChannel yang sama.
 *
 * Channel dibuat di sini (bukan di service) karena MethodChannel butuh
 * BinaryMessenger milik FlutterEngine — dan engine itu hidup di
 * MainActivity, bukan di service. Service dan activity satu proses, jadi
 * object ini bisa dipegang bersama.
 *
 * Kalau service belum jalan saat update pertama tiba (urutan normal:
 * Dart memutar lagu dulu, service baru start), update terakhir disimpan
 * ([pendingState] dkk.) dan diterapkan ke player begitu service
 * mendaftarkan player-nya — tidak ada update yang hilang.
 */
object Media3Bridge {

    const val CHANNEL_NAME = "com.example.omnix_app/media3"
    private const val TAG = "OmniXMedia3"

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var player: DartMirroringPlayer? = null
    private var serviceStartRequested = false

    private var pendingState: DartPlaybackState? = null
    private var pendingMediaItem: DartMediaItem? = null
    private var pendingMediaItemSet = false
    private var pendingQueue: List<DartMediaItem>? = null

    /** Dipanggil MainActivity saat engine Flutter siap. */
    fun attach(messenger: BinaryMessenger, context: Context) {
        appContext = context.applicationContext
        val methodChannel = MethodChannel(messenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(::onMethodCall)
        channel = methodChannel
    }

    /** Dipanggil OmniXPlaybackService saat player dibuat. */
    fun registerPlayer(newPlayer: DartMirroringPlayer) {
        player = newPlayer
        // Terapkan state terakhir yang sempat diterima sebelum service jalan.
        pendingState?.let { newPlayer.updateState(it) }
        if (pendingMediaItemSet) {
            newPlayer.updateMediaItem(pendingMediaItem)
        }
        pendingQueue?.let { newPlayer.updateQueue(it) }
    }

    /** Dipanggil OmniXPlaybackService saat dihancurkan. */
    fun unregisterPlayer() {
        player = null
        serviceStartRequested = false
    }

    /** Kirim perintah tombol media ke Dart (dipakai player). */
    fun sendToDart(method: String, arguments: Any? = null) {
        val target =
            channel ?: run {
                Log.d(TAG, "sendToDart($method) dibuang: channel belum terpasang")
                return
            }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            invoke(target, method, arguments)
        } else {
            mainHandler.post { invoke(target, method, arguments) }
        }
    }

    private fun invoke(channel: MethodChannel, method: String, arguments: Any?) {
        try {
            channel.invokeMethod(method, arguments)
        } catch (e: Exception) {
            Log.d(TAG, "invokeMethod($method) gagal: ${e.message}")
        }
    }

    /** Dart → native: updateState / updateMediaItem / updateQueue. */
    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "updateState" -> {
                    val state = parseState(call.arguments)
                    if (state != null) {
                        pendingState = state
                        ensureServiceStarted()
                        player?.updateState(state)
                    }
                }
                "updateMediaItem" -> {
                    pendingMediaItem = parseMediaItem(call.arguments)
                    pendingMediaItemSet = true
                    ensureServiceStarted()
                    player?.updateMediaItem(pendingMediaItem)
                }
                "updateQueue" -> {
                    val items = parseQueue(call.arguments)
                    pendingQueue = items
                    ensureServiceStarted()
                    player?.updateQueue(items)
                }
                else -> Log.d(TAG, "method tidak dikenal: ${call.method}")
            }
            result.success(null)
        } catch (e: Exception) {
            Log.w(TAG, "onMethodCall(${call.method}) gagal", e)
            result.error("MEDIA3_ERROR", e.message, null)
        }
    }

    /**
     * Start service saat update pertama tiba. Dipanggil dari handler
     * channel (main thread, aplikasi di foreground saat lagu pertama
     * diputar) — bukan dari background, jadi tidak kena larangan start
     * foreground service Android 12+.
     */
    private fun ensureServiceStarted() {
        if (player != null || serviceStartRequested) return
        val context = appContext ?: return
        serviceStartRequested = true
        try {
            val intent = Intent(context, OmniXPlaybackService::class.java)
            ContextCompat.startForegroundService(context, intent)
        } catch (e: Exception) {
            Log.w(TAG, "startForegroundService gagal", e)
            serviceStartRequested = false
        }
    }

    private fun parseState(arguments: Any?): DartPlaybackState? {
        val map = arguments as? Map<*, *> ?: return null
        val playing = map["playing"] as? Boolean ?: return null
        val processingState = map["processingState"] as? String ?: "idle"
        val positionMs = (map["positionMs"] as? Number)?.toLong() ?: 0L
        val bufferedPositionMs = (map["bufferedPositionMs"] as? Number)?.toLong() ?: 0L
        return DartPlaybackState(
            playing = playing,
            processingState = processingState,
            positionMs = positionMs,
            bufferedPositionMs = bufferedPositionMs,
        )
    }

    /** arguments null = tidak ada lagu (mediaItem Dart null). */
    private fun parseMediaItem(arguments: Any?): DartMediaItem? {
        if (arguments == null) return null
        val map = arguments as? Map<*, *> ?: return null
        val id = map["id"] as? String ?: return null
        val title = map["title"] as? String ?: return null
        return DartMediaItem(
            id = id,
            title = title,
            artist = map["artist"] as? String,
            album = map["album"] as? String,
            durationMs = (map["durationMs"] as? Number)?.toLong(),
            artUri = map["artUri"] as? String,
        )
    }

    private fun parseQueue(arguments: Any?): List<DartMediaItem> {
        val map = arguments as? Map<*, *> ?: return emptyList()
        val items = map["items"] as? List<*> ?: return emptyList()
        return items.mapNotNull { parseMediaItem(it) }
    }
}
