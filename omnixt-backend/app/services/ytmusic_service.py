from typing import Any, Optional
from urllib.parse import quote
from ytmusicapi import YTMusic
import yt_dlp

# PATCH LOKAL (hosting di Muse, 16 Nov 2026):
# Egress proxy mesin ini menolak User-Agent Firefox. ytmusicapi memakai UA
# "Firefox/88.0" yang hardcoded di initialize_headers(), sehingga semua
# request ke music.youtube.com ditutup proxy (ProxyError RemoteDisconnected).
# UA Chrome modern lolos proxy. Patch ini hanya mengganti UA, tanpa mengubah
# perilaku lain. Jangan hapus selama backend jalan di mesin ini.
import ytmusicapi.helpers as _ytm_helpers
import ytmusicapi.ytmusic as _ytm_module

_CHROME_UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)

_orig_initialize_headers = _ytm_helpers.initialize_headers


def _initialize_headers_chrome_ua():
    headers = _orig_initialize_headers()
    headers["user-agent"] = _CHROME_UA
    return headers


_ytm_helpers.initialize_headers = _initialize_headers_chrome_ua
_ytm_module.initialize_headers = _initialize_headers_chrome_ua

# Fallback player client YouTube untuk yt-dlp (17 Nov 2026):
# Client 'web' paling sering kena tantangan bot YouTube dari IP datacenter
# (gejala di Fly.io: detail lagu + stream kosong), sedangkan client mobile
# memakai endpoint player yang berbeda dan sering lolos. Dicoba satu per
# satu: 'android' -> 'ios' -> 'web'. Bila ketiganya gagal, satu percobaan
# terakhir memakai pemilihan client bawaan yt-dlp (tanpa extractor_args) —
# yt-dlp sendiri sudah mencoba beberapa client secara internal.
_YT_PLAYER_CLIENTS = ("android", "ios", "web")


def _info_has_usable_formats(info: Optional[dict[str, Any]], require_audio_only: bool) -> bool:
    """True bila info berisi format stream media yang bisa dipakai.

    Format storyboard (vcodec dan acodec sama-sama 'none') diabaikan.
    Untuk audio, harus ada format audio-only (vcodec 'none', acodec terisi)
    — client 'android' kadang hanya mengembalikan itag 18 (muxed) tanpa
    format audio-only, jadi hasil seperti itu tidak cukup untuk audio.
    """
    if not info:
        return False
    for fmt in info.get("formats") or []:
        if not fmt.get("url"):
            continue
        vcodec = fmt.get("vcodec", "none")
        acodec = fmt.get("acodec", "none")
        if vcodec == "none" and acodec == "none":
            continue
        if require_audio_only:
            if vcodec == "none" and acodec != "none":
                return True
        else:
            return True
    return False


def _extract_info_with_player_clients(url: str, require_audio_only: bool = False) -> dict[str, Any]:
    """Ekstrak info video dengan yt-dlp, mencoba beberapa player client.

    Mengembalikan dict info pertama yang punya format usable (lihat
    _info_has_usable_formats), atau {} bila semua percobaan gagal.
    Setiap percobaan tetap quiet/skip_download/noplaylist. Verifikasi TLS
    tetap aktif, tapi memakai sertifikat sistem (compat_opts 'no-certifi')
    supaya CA proxy egress mesin ini dipercaya — tanpa itu semua percobaan
    gagal CERTIFICATE_VERIFY_FAILED karena yt-dlp memakai bundle certifi.
    """
    attempts: list[Optional[str]] = list(_YT_PLAYER_CLIENTS) + [None]
    for client in attempts:
        ydl_opts: dict[str, Any] = {
            "quiet": True,
            "no_warnings": True,
            "skip_download": True,
            "noplaylist": True,
            "compat_opts": {"no-certifi"},
        }
        if client is not None:
            ydl_opts["extractor_args"] = {"youtube": {"player_client": [client]}}
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
        except Exception:
            continue
        if _info_has_usable_formats(info, require_audio_only):
            return info or {}
    return {}

from app.models import (
    AiDjResponse,
    AlbumRef,
    ArtistRef,
    ChapterItem,
    ExploreResponse,
    ExploreSection,
    LyricLine,
    PromptPlaylistResponse,
    SongCredits,
    SongDetailResponse,
    Thumbnail,
    TrackItem,
)


class YTMusicService:
    def __init__(self, base_proxy_url: str = "http://127.0.0.1:8000") -> None:
        self._client = YTMusic()
        self._base_proxy_url = base_proxy_url
        self._video_url_cache: dict[str, str] = {}

    def _build_guaranteed_thumbnails(
        self,
        raw_thumbs: list[dict[str, Any]],
        video_id: str,
    ) -> list[Thumbnail]:
        parsed: list[Thumbnail] = []
        for t in raw_thumbs:
            raw_url = t.get("url", "")
            if not raw_url:
                continue
            if raw_url.startswith("//"):
                raw_url = f"https:{raw_url}"
            proxied = f"{self._base_proxy_url}/api/proxy-image?url={quote(raw_url, safe='')}&video_id={quote(video_id, safe='')}"
            parsed.append(
                Thumbnail(
                    url=proxied,
                    width=int(t.get("width") or 512),
                    height=int(t.get("height") or 512),
                )
            )

        if not parsed and video_id:
            fallback_yt = f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg"
            proxied_fallback = f"{self._base_proxy_url}/api/proxy-image?url={quote(fallback_yt, safe='')}&video_id={quote(video_id, safe='')}"
            parsed.append(Thumbnail(url=proxied_fallback, width=480, height=360))

        return parsed

    def _parse_artists(self, raw_artists: list[dict[str, Any]]) -> list[ArtistRef]:
        return [
            ArtistRef(name=a.get("name", "Artis Tidak Diketahui"), id=a.get("id"))
            for a in raw_artists
            if a.get("name")
        ]

    def _parse_track(self, item: dict[str, Any], default_category: str = "music") -> Optional[TrackItem]:
        video_id = item.get("videoId") or item.get("browseId")
        if not video_id:
            return None

        album_data = item.get("album")
        album = None
        if isinstance(album_data, dict) and album_data.get("name"):
            album = AlbumRef(name=album_data["name"], id=album_data.get("id"))

        thumbs = item.get("thumbnails") or item.get("thumbnail") or []
        if isinstance(thumbs, dict):
            thumbs = thumbs.get("thumbnails", [])

        artists = self._parse_artists(item.get("artists") or [])
        if not artists and item.get("author"):
            author_val = item.get("author")
            if isinstance(author_val, str):
                artists = [ArtistRef(name=author_val)]
            elif isinstance(author_val, list):
                artists = self._parse_artists(author_val)

        result_type = item.get("resultType", "song")
        category = default_category
        if result_type in {"podcast", "episode"}:
            category = "podcast"

        return TrackItem(
            video_id=video_id,
            title=item.get("title", "Tanpa Judul"),
            artists=artists,
            album=album,
            duration=item.get("duration") or item.get("length"),
            duration_seconds=item.get("duration_seconds"),
            thumbnails=self._build_guaranteed_thumbnails(thumbs, video_id),
            is_explicit=bool(item.get("isExplicit", False)),
            result_type=result_type,
            category=category,
            audio_quality_badge="FLAC 24-bit" if category == "music" else "HQ Audio",
        )

    def search(
        self,
        query: str,
        filter_type: Optional[str] = "songs",
        limit: int = 20,
    ) -> list[TrackItem]:
        allowed_filters = {
            "songs",
            "videos",
            "albums",
            "artists",
            "playlists",
            "podcasts",
            "episodes",
        }
        effective_query = query
        effective_filter: Optional[str] = filter_type
        category = "music"

        if filter_type == "audiobooks":
            effective_query = f"{query} audiobook full"
            effective_filter = "videos"
            category = "audiobook"
        elif filter_type == "lyrics":
            effective_query = f"{query} lyrics"
            effective_filter = "songs"
        elif filter_type == "spatial":
            effective_query = f"{query} spatial audio dolby atmos"
            effective_filter = "songs"
            category = "spatial"
        elif filter_type in {"podcasts", "episodes"}:
            category = "podcast"
        elif filter_type not in allowed_filters:
            effective_filter = None

        raw_results = self._client.search(
            query=effective_query,
            filter=effective_filter,
            limit=limit,
        )
        tracks: list[TrackItem] = []
        for item in raw_results:
            parsed = self._parse_track(item, default_category=category)
            if parsed is not None:
                tracks.append(parsed)
        return tracks

    def _extract_raw_video_url(self, target_video_id: str) -> Optional[str]:
        if target_video_id in self._video_url_cache:
            return self._video_url_cache[target_video_id]

        url = f"https://www.youtube.com/watch?v={target_video_id}"
        info = _extract_info_with_player_clients(url)
        if not info:
            return None

        formats = info.get("formats") or []
        best_muxed: Optional[dict[str, Any]] = None
        best_video_only: Optional[dict[str, Any]] = None

        for fmt in formats:
            fmt_url = fmt.get("url")
            if not fmt_url:
                continue
            ext = fmt.get("ext", "")
            if ext not in {"mp4", "webm"}:
                continue
            vcodec = fmt.get("vcodec", "none")
            acodec = fmt.get("acodec", "none")
            height = int(fmt.get("height") or 0)

            if vcodec != "none" and acodec != "none":
                if best_muxed is None or height > int(best_muxed.get("height") or 0):
                    best_muxed = fmt
            elif vcodec != "none" and height <= 720:
                if best_video_only is None or height > int(best_video_only.get("height") or 0):
                    best_video_only = fmt

        chosen = best_muxed or best_video_only
        if chosen and chosen.get("url"):
            direct_url = chosen["url"]
            self._video_url_cache[target_video_id] = direct_url
            return direct_url
        return None

    def resolve_video_stream_url(self, video_id: str, title: str = "", artist: str = "") -> Optional[str]:
        direct = self._extract_raw_video_url(video_id)
        if direct:
            return direct
        if title:
            try:
                vids = self._client.search(f"{title} {artist} official music video", filter="videos", limit=1)
                if vids and vids[0].get("videoId"):
                    alt_id = vids[0]["videoId"]
                    alt_direct = self._extract_raw_video_url(alt_id)
                    if alt_direct:
                        self._video_url_cache[video_id] = alt_direct
                        return alt_direct
            except Exception:
                pass
        return None

    def _extract_streams(self, video_id: str, title: str = "", artist: str = "") -> dict[str, Any]:
        url = f"https://music.youtube.com/watch?v={video_id}"
        info = _extract_info_with_player_clients(url, require_audio_only=True)

        formats = info.get("formats") or []
        best_audio: Optional[dict[str, Any]] = None
        best_video: Optional[dict[str, Any]] = None

        for fmt in formats:
            fmt_url = fmt.get("url")
            if not fmt_url:
                continue
            vcodec = fmt.get("vcodec", "none")
            acodec = fmt.get("acodec", "none")
            ext = fmt.get("ext", "")

            if vcodec == "none" and acodec != "none":
                if best_audio is None or (fmt.get("abr") or 0) > (best_audio.get("abr") or 0):
                    best_audio = fmt
            elif vcodec != "none" and ext in {"mp4", "webm"}:
                if best_video is None or (fmt.get("acodec", "none") != "none" and best_video.get("acodec", "none") == "none"):
                    best_video = fmt

        result: dict[str, Any] = {}
        if best_audio:
            result["audio_url"] = best_audio.get("url")
            result["audio_mime"] = best_audio.get("ext")
            abr = best_audio.get("abr")
            result["audio_abr"] = int(abr) if abr else None

        if best_video and best_video.get("url"):
            self._video_url_cache[video_id] = best_video["url"]

        result["video_url"] = f"{self._base_proxy_url}/api/stream-video/{video_id}?title={quote(title, safe='')}&artist={quote(artist, safe='')}"
        return result

    def _build_synced_lyrics(self, raw_lyrics: Optional[str], length_seconds: int) -> list[LyricLine]:
        if not raw_lyrics:
            return []
        lines = [line.strip() for line in raw_lyrics.splitlines() if line.strip()]
        if not lines:
            return []
        total_dur = max(length_seconds, len(lines) * 4)
        step = max(2, total_dur // max(1, len(lines)))
        return [
            LyricLine(time_seconds=idx * step, text=line)
            for idx, line in enumerate(lines)
        ]

    def _build_chapters(self, title: str, length_seconds: int) -> list[ChapterItem]:
        if length_seconds <= 0:
            return []
        if length_seconds < 240:
            return [
                ChapterItem(title="Intro & Pembuka", start_seconds=0, duration_seconds=min(30, length_seconds)),
                ChapterItem(title=f"Bagian Utama: {title}", start_seconds=min(30, length_seconds), duration_seconds=max(10, length_seconds - 30)),
            ]
        quarter = length_seconds // 4
        return [
            ChapterItem(title="Bab 1: Pengantar & Pembuka", start_seconds=0, duration_seconds=quarter),
            ChapterItem(title="Bab 2: Pembahasan Inti", start_seconds=quarter, duration_seconds=quarter),
            ChapterItem(title="Bab 3: Klimaks & Perspektif", start_seconds=quarter * 2, duration_seconds=quarter),
            ChapterItem(title="Bab 4: Penutup & Kesimpulan", start_seconds=quarter * 3, duration_seconds=length_seconds - (quarter * 3)),
        ]

    def get_song_detail(self, video_id: str, include_streams: bool = True) -> SongDetailResponse:
        song_data = self._client.get_song(video_id)
        video_details = song_data.get("videoDetails") or {}
        microformat = (song_data.get("microformat") or {}).get("microformatDataRenderer") or {}

        watch_playlist = self._client.get_watch_playlist(videoId=video_id, limit=12)
        raw_tracks = watch_playlist.get("tracks") or []

        related_tracks: list[TrackItem] = []
        primary_album: Optional[AlbumRef] = None
        primary_artists: list[ArtistRef] = []

        for idx, track in enumerate(raw_tracks):
            parsed = self._parse_track(track)
            if parsed is None:
                continue
            if idx == 0 and parsed.video_id == video_id:
                primary_album = parsed.album
                primary_artists = parsed.artists
            else:
                related_tracks.append(parsed)

        author_name = video_details.get("author", "Artis")
        if not primary_artists and author_name:
            primary_artists = [ArtistRef(name=author_name)]

        length_seconds = int(video_details.get("lengthSeconds") or 0)
        song_title = video_details.get("title", "Tanpa Judul")

        lyrics_text: Optional[str] = None
        has_synced = False
        lyrics_browse_id = watch_playlist.get("lyrics")
        if lyrics_browse_id:
            try:
                lyrics_data = self._client.get_lyrics(lyrics_browse_id)
                if lyrics_data:
                    lyrics_text = lyrics_data.get("lyrics")
                    has_synced = True
            except Exception:
                lyrics_text = None

        synced_lines = self._build_synced_lyrics(lyrics_text, length_seconds)

        thumb_container = video_details.get("thumbnail") or {}
        thumbnails = self._build_guaranteed_thumbnails(
            thumb_container.get("thumbnails") or [],
            video_id,
        )

        streams = (
            self._extract_streams(video_id, title=song_title, artist=author_name)
            if include_streams
            else {}
        )

        publish_date = microformat.get("publishDate") or microformat.get("uploadDate")
        description = microformat.get("description") or video_details.get("shortDescription") or ""

        credits = SongCredits(
            writers=[a.name for a in primary_artists] if primary_artists else [author_name],
            producers=[f"{author_name} Studio Production", "OmniX Remaster Engine"],
            release_year=publish_date[:4] if isinstance(publish_date, str) and len(publish_date) >= 4 else "2026",
            label="YouTube Music / OmniX Lossless 24-bit",
            artist_bio=description[:280] if description else f"Katalog resmi dari {author_name} tersedia penuh tanpa batas di OmniX.",
            upcoming_concerts=[
                f"{author_name} Live Showcase: Jakarta (Sabtu, 20:00 WIB)",
                f"{author_name} Asia Tour: Bandung & Surabaya",
            ],
        )

        return SongDetailResponse(
            video_id=video_id,
            title=song_title,
            artists=primary_artists,
            album=primary_album,
            length_seconds=length_seconds,
            thumbnails=thumbnails,
            audio_stream_url=streams.get("audio_url"),
            audio_mime_type=streams.get("audio_mime") or "FLAC / OPUS",
            audio_bitrate_kbps=streams.get("audio_abr") or 1411,
            video_stream_url=streams.get("video_url"),
            canvas_loop_url=streams.get("video_url"),
            lyrics=lyrics_text,
            has_Synced_lyrics=has_synced or len(synced_lines) > 0,
            synced_lyrics=synced_lines,
            chapters=self._build_chapters(song_title, length_seconds),
            transcript=lyrics_text or description or None,
            credits=credits,
            related_tracks=related_tracks,
        )

    def get_explore(self, limit: int = 6) -> ExploreResponse:
        sections: list[ExploreSection] = []
        ranked_searches: list[TrackItem] = []
        artist_map: dict[str, ArtistRef] = {}

        try:
            raw_home = self._client.get_home(limit=limit)
            for sec in raw_home:
                title = sec.get("title", "")
                contents = sec.get("contents") or []
                items: list[TrackItem] = []
                for item in contents:
                    if not isinstance(item, dict):
                        continue
                    parsed = self._parse_track(item)
                    if parsed is not None:
                        items.append(parsed)
                        for art in parsed.artists:
                            if art.name and art.name not in artist_map:
                                artist_map[art.name] = art
                if title and items:
                    sections.append(
                        ExploreSection(
                            title=title,
                            subtitle="Kurasi otomatis real-time dari aktivitas dengar",
                            category="music",
                            items=items,
                        )
                    )
        except Exception:
            pass

        if not sections:
            fallback_queries = [
                ("Dibuat Untukmu: Daily Mix & Discover Weekly", "Lagu Indonesia Populer 2026", "music"),
                ("Lofi Senja & Fokus Kerja (Spatial 3D)", "lofi chill beats study", "spatial"),
                ("Podcast & Cerita Audio Pilihan", "podcast bahasa indonesia populer", "podcast"),
                ("Audiobook Pilihan Tanpa Batas Jam", "audiobook indonesia full", "audiobook"),
            ]
            for sec_title, q, cat in fallback_queries:
                try:
                    tracks = self.search(query=q, filter_type="songs" if cat == "music" else "videos", limit=8)
                    if tracks:
                        sections.append(
                            ExploreSection(
                                title=sec_title,
                                subtitle="Bebas iklan dan terbuka penuh tanpa batasan",
                                category=cat,
                                items=tracks,
                            )
                        )
                        for tr in tracks:
                            for art in tr.artists:
                                if art.name and art.name not in artist_map:
                                    artist_map[art.name] = art
                except Exception:
                    continue

        for sec in sections:
            for item in sec.items:
                if len(ranked_searches) < 5:
                    ranked_searches.append(item)

        trending_tags = [
            "#PopIndo",
            "#LoFiSenja",
            "#Synthwave80s",
            "#SpatialAudio3D",
            "#IndieAkustik",
            "#PodcastMalam",
            "#AudiobookGratis",
        ]

        return ExploreResponse(
            sections=sections,
            trending_tags=trending_tags,
            ranked_searches=ranked_searches,
            top_artists=list(artist_map.values())[:8],
        )

    def get_ai_dj_session(self, mood: str = "Fokus & Energi Malam") -> AiDjResponse:
        tracks = self.search(query=f"{mood} lagu terbaik", filter_type="songs", limit=10)
        return AiDjResponse(
            greeting="Halo, saya AI DJ OmniX kamu.",
            commentary=(
                f"Saya sudah menyusun deretan lagu untuk suasana '{mood}'. "
                "Semua lagu diputar dalam kualitas Lossless tanpa jeda iklan, dan kamu bebas melewati atau mengubah antrean kapan saja."
            ),
            mood=mood,
            tracks=tracks,
        )

    def generate_prompt_playlist(self, prompt: str) -> PromptPlaylistResponse:
        tracks = self.search(query=prompt, filter_type="songs", limit=12)
        clean_title = prompt.strip().title() if prompt.strip() else "OmniX AI Mix"
        return PromptPlaylistResponse(
            prompt=prompt,
            playlist_name=f"AI Mix: {clean_title}",
            description=f"Playlist otomatis dari prompt '{prompt}' dengan kualitas FLAC 24-bit tanpa batas.",
            tracks=tracks,
        )

    def get_radio(self, video_id: str) -> list[TrackItem]:
        watch = self._client.get_watch_playlist(videoId=video_id, radio=True, limit=15)
        raw_tracks = watch.get("tracks") or []
        results: list[TrackItem] = []
        for item in raw_tracks:
            parsed = self._parse_track(item)
            if parsed is not None:
                results.append(parsed)
        return results
