package com.example.omnix_app

import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.Player
import androidx.media3.common.SimpleBasePlayer
import androidx.media3.common.util.UnstableApi
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/** Satu lagu sebagaimana dikirim Dart (lihat Media3Bridge di sisi Dart). */
data class DartMediaItem(
    val id: String,
    val title: String,
    val artist: String?,
    val album: String?,
    val durationMs: Long?,
    val artUri: String?,
)

/** Status putar sebagaimana dikirim Dart (lihat Media3Bridge di sisi Dart). */
data class DartPlaybackState(
    val playing: Boolean,
    /** 'idle' | 'loading' | 'buffering' | 'ready' | 'completed' | 'error'. */
    val processingState: String,
    val positionMs: Long,
    val bufferedPositionMs: Long,
)

/**
 * Player Media3 yang TIDAK memutar audio sendiri — ia hanya mencerminkan
 * state pemutar Dart (just_audio lewat OmniXAudioHandler) supaya
 * MediaSession / notifikasi media sistem menampilkan judul, posisi, dan
 * tombol yang benar, dan supaya ketukan tombol media bisa diteruskan
 * kembali ke Dart lewat [Media3Bridge.sendToDart].
 *
 * Kenapa cermin, bukan ExoPlayer: audio tetap dipegang just_audio di Dart
 * (cache lokal, auto-recovery, lewati segmen sponsor). Kalau Media3 ikut
 * memutar audio, ada dua pemutar yang berebut audio focus. Jadi player ini
 * adalah [SimpleBasePlayer]: Media3 yang mengurus listener, timeline, dan
 * notifikasi — kita hanya menyuplai state lewat [getState] dan meneruskan
 * perintah pengguna ke Dart lewat handler `handle*`.
 *
 * Semua update state masuk lewat [updateState]/[updateMediaItem]/
 * [updateQueue] di thread aplikasi (main looper); kalau dipanggil dari
 * thread lain, dilempar ke main thread dulu — SimpleBasePlayer menuntut
 * semua akses dari thread looper-nya.
 */
@OptIn(UnstableApi::class)
class DartMirroringPlayer(
    private val appLooper: Looper,
) : SimpleBasePlayer(appLooper) {

    private val appHandler = Handler(appLooper)

    private var state = DartPlaybackState(
        playing = false,
        processingState = "idle",
        positionMs = 0L,
        bufferedPositionMs = 0L,
    )
    private var currentItem: DartMediaItem? = null
    private var queue: List<DartMediaItem> = emptyList()

    private val availableCommands: Player.Commands =
        Player.Commands.Builder()
            .add(Player.COMMAND_PLAY_PAUSE)
            .add(Player.COMMAND_PREPARE)
            .add(Player.COMMAND_STOP)
            .add(Player.COMMAND_SEEK_TO_NEXT)
            .add(Player.COMMAND_SEEK_TO_PREVIOUS)
            .add(Player.COMMAND_SEEK_BACK)
            .add(Player.COMMAND_SEEK_FORWARD)
            .add(Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM)
            .add(Player.COMMAND_GET_CURRENT_MEDIA_ITEM)
            .add(Player.COMMAND_GET_TIMELINE)
            .add(Player.COMMAND_GET_METADATA)
            .add(Player.COMMAND_GET_VOLUME)
            .add(Player.COMMAND_GET_AUDIO_ATTRIBUTES)
            .add(Player.COMMAND_GET_TRACKS)
            .build()

    // --- Update dari Dart -------------------------------------------------

    fun updateState(newState: DartPlaybackState) {
        runOnAppThread {
            state = newState
            invalidateState()
        }
    }

    fun updateMediaItem(item: DartMediaItem?) {
        runOnAppThread {
            currentItem = item
            invalidateState()
        }
    }

    fun updateQueue(items: List<DartMediaItem>) {
        runOnAppThread {
            queue = items
            invalidateState()
        }
    }

    // --- SimpleBasePlayer -------------------------------------------------

    override fun getState(): State {
        val (items, currentIndex) = currentPlaylist()
        val playlist = items.mapIndexed { index, dartItem -> dartItem.toMediaItemData(index) }

        // SimpleBasePlayer.State hanya mengizinkan playlist kosong di
        // STATE_IDLE / STATE_ENDED — paksa IDLE kalau belum ada lagu.
        var playbackState =
            when (state.processingState) {
                "loading", "buffering" -> Player.STATE_BUFFERING
                "ready" -> Player.STATE_READY
                "completed" -> Player.STATE_ENDED
                else -> Player.STATE_IDLE
            }
        if (playlist.isEmpty() && playbackState != Player.STATE_ENDED) {
            playbackState = Player.STATE_IDLE
        }
        // isLoading hanya boleh di luar STATE_IDLE / STATE_ENDED.
        val isLoading =
            playbackState == Player.STATE_BUFFERING &&
                (state.processingState == "loading" || state.processingState == "buffering")

        // Posisi TIME_UNSET kalau belum ada lagu (State menolak posisi
        // konkret tanpa timeline); kalau durasi diketahui, jepit posisi
        // supaya posisi ekstrapolasi tidak melewati ujung lagu.
        val durationMs = items.getOrNull(currentIndex)?.durationMs
        val positionMs =
            if (playlist.isEmpty()) {
                C.TIME_UNSET
            } else if (durationMs != null) {
                state.positionMs.coerceIn(0L, durationMs)
            } else {
                state.positionMs.coerceAtLeast(0L)
            }
        val bufferedMs =
            if (playlist.isEmpty()) {
                C.TIME_UNSET
            } else {
                state.bufferedPositionMs.coerceAtLeast(0L)
            }

        return State.Builder()
            .setAvailableCommands(availableCommands)
            .setPlayWhenReady(
                state.playing,
                Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST,
            )
            .setPlaybackState(playbackState)
            .setIsLoading(isLoading)
            .setPlaylist(playlist)
            .setCurrentMediaItemIndex(
                if (playlist.isEmpty()) C.INDEX_UNSET else currentIndex,
            )
            // Posisi long di sini otomatis jadi PositionSupplier yang
            // mengekstrapolasi saat memutar (playWhenReady + STATE_READY).
            .setContentPositionMs(positionMs)
            .setContentBufferedPositionMs(
                SimpleBasePlayer.PositionSupplier.getConstant(bufferedMs),
            )
            .setTotalBufferedDurationMs(
                SimpleBasePlayer.PositionSupplier.getConstant(
                    if (bufferedMs == C.TIME_UNSET || positionMs == C.TIME_UNSET) {
                        0L
                    } else {
                        (bufferedMs - positionMs).coerceAtLeast(0L)
                    },
                ),
            )
            .build()
    }

    /**
     * Tombol putar/jeda notifikasi: teruskan ke Dart, jangan ubah state
     * lokal — state yang tampil selalu cermin Dart, jadi kalau Dart gagal
     * memutar (mis. stream error), notifikasi ikut terkoreksi lewat
     * updateState berikutnya, bukan menampilkan status palsu.
     */
    override fun handleSetPlayWhenReady(playWhenReady: Boolean): ListenableFuture<*> {
        Media3Bridge.sendToDart(if (playWhenReady) "play" else "pause")
        return Futures.immediateVoidFuture()
    }

    override fun handlePrepare(): ListenableFuture<*> {
        // Tidak ada yang perlu disiapkan di sisi native: sumber audio
        // dipegang Dart. Kembalikan langsung; perintah play yang menyusul
        // akan diteruskan lewat handleSetPlayWhenReady.
        return Futures.immediateVoidFuture()
    }

    override fun handleStop(): ListenableFuture<*> {
        // Tidak ada perintah 'stop' di kontrak MethodChannel — jeda saja
        // (audio berhenti, notifikasi tetap ada supaya bisa lanjut lagi).
        Media3Bridge.sendToDart("pause")
        return Futures.immediateVoidFuture()
    }

    override fun handleSeek(
        mediaItemIndex: Int,
        positionMs: Long,
        seekCommand: Int,
    ): ListenableFuture<*> {
        when (seekCommand) {
            Player.COMMAND_SEEK_TO_NEXT -> Media3Bridge.sendToDart("skipToNext")
            Player.COMMAND_SEEK_TO_PREVIOUS -> Media3Bridge.sendToDart("skipToPrevious")
            Player.COMMAND_SEEK_IN_CURRENT_MEDIA_ITEM,
            Player.COMMAND_SEEK_BACK,
            Player.COMMAND_SEEK_FORWARD,
            -> {
                if (positionMs != C.TIME_UNSET) {
                    Media3Bridge.sendToDart("seekTo", mapOf("positionMs" to positionMs))
                }
            }
            // COMMAND_SEEK_TO_MEDIA_ITEM tidak diiklankan di
            // availableCommands (Dart tidak punya perintah "putar indeks
            // antrean ke-N"), jadi tidak seharusnya sampai ke sini.
            else -> Unit
        }
        return Futures.immediateVoidFuture()
    }

    // --- Bantuan ----------------------------------------------------------

    private fun runOnAppThread(block: () -> Unit) {
        if (Looper.myLooper() == appLooper) {
            block()
        } else {
            appHandler.post(block)
        }
    }

    /**
     * Playlist yang ditampilkan di session: antrean Dart kalau ada;
     * kalau lagu yang sedang diputar tidak ada di antrean, taruh di depan
     * supaya notifikasi menampilkan lagu yang benar, bukan lagu lain.
     */
    private fun currentPlaylist(): Pair<List<DartMediaItem>, Int> {
        val queueItems = queue
        val current = currentItem
        return when {
            queueItems.isEmpty() -> {
                if (current == null) {
                    emptyList<DartMediaItem>() to C.INDEX_UNSET
                } else {
                    listOf(current) to 0
                }
            }
            current == null -> queueItems to 0
            else -> {
                val index = queueItems.indexOfFirst { it.id == current.id }
                if (index >= 0) {
                    queueItems to index
                } else {
                    listOf(current) + queueItems to 0
                }
            }
        }
    }

    private fun DartMediaItem.toMediaItemData(index: Int): SimpleBasePlayer.MediaItemData {
        val durationUs = durationMs?.let { it * 1000 } ?: C.TIME_UNSET
        val mediaItem =
            MediaItem.Builder()
                .setMediaId(id)
                .setMediaMetadata(
                    MediaMetadata.Builder()
                        .setTitle(title)
                        .setArtist(artist)
                        .setAlbumTitle(album)
                        .setArtworkUri(artUri?.let { Uri.parse(it) })
                        .build(),
                )
                .build()
        return SimpleBasePlayer.MediaItemData.Builder("$index:$id")
            .setMediaItem(mediaItem)
            .setDurationUs(durationUs)
            .setIsSeekable(true)
            .build()
    }
}
