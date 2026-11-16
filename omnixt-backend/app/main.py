import os
from typing import Iterator, Optional
from urllib.request import Request, urlopen
from fastapi import FastAPI, HTTPException, Query, Request as FastAPIRequest, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse

from app.models import (
    AiDjResponse,
    ExploreResponse,
    PromptPlaylistResponse,
    SearchResponse,
    SongDetailResponse,
    TrackItem,
)
from app.services.ytmusic_service import YTMusicService

app = FastAPI(
    title="OmniX Backend API",
    version="1.2.0",
    description="FastAPI wrapper over ytmusicapi with CORS artwork & video proxy.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

ytmusic_service = YTMusicService(
    base_proxy_url=os.environ.get("OMNIX_PUBLIC_URL")
    or os.environ.get("RENDER_EXTERNAL_URL", "http://127.0.0.1:8001")
)


@app.get("/health")
def health_check() -> dict[str, str]:
    return {"status": "ok", "tier": "unlimited_free_master"}


@app.get("/api/proxy-image")
def proxy_image(
    url: Optional[str] = Query(None, description="URL gambar asli"),
    video_id: Optional[str] = Query(None, description="ID video YouTube untuk fallback sampul"),
) -> Response:
    candidates: list[str] = []
    if url:
        candidates.append(url)
    if video_id:
        candidates.append(f"https://i.ytimg.com/vi/{video_id}/hqdefault.jpg")
        candidates.append(f"https://i.ytimg.com/vi/{video_id}/mqdefault.jpg")

    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        )
    }

    for candidate in candidates:
        try:
            req = Request(candidate, headers=headers)
            with urlopen(req, timeout=8) as resp:
                data = resp.read()
                content_type = resp.headers.get("Content-Type", "image/jpeg")
                if data:
                    return Response(
                        content=data,
                        media_type=content_type,
                        headers={
                            "Access-Control-Allow-Origin": "*",
                            "Cache-Control": "public, max-age=86400",
                        },
                    )
        except Exception:
            continue

    raise HTTPException(status_code=404, detail="Sampul tidak ditemukan")


@app.get("/api/stream-video/{video_id}")
def stream_video(
    video_id: str,
    request: FastAPIRequest,
    title: str = Query("", description="Judul lagu untuk pencarian video klip"),
    artist: str = Query("", description="Nama artis untuk pencarian video klip"),
) -> StreamingResponse:
    direct_url = ytmusic_service.resolve_video_stream_url(
        video_id=video_id,
        title=title,
        artist=artist,
    )
    if not direct_url:
        raise HTTPException(status_code=404, detail="Stream video tidak ditemukan")

    req_headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        )
    }
    range_header = request.headers.get("range")
    if range_header:
        req_headers["Range"] = range_header

    try:
        upstream_req = Request(direct_url, headers=req_headers)
        upstream = urlopen(upstream_req, timeout=15)
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Gagal membuka stream video: {exc}") from exc

    status_code = getattr(upstream, "status", 200)
    content_type = upstream.headers.get("Content-Type", "video/mp4")
    resp_headers = {
        "Access-Control-Allow-Origin": "*",
        "Accept-Ranges": "bytes",
    }
    for header_name in ("Content-Length", "Content-Range"):
        val = upstream.headers.get(header_name)
        if val:
            resp_headers[header_name] = val

    def iter_chunks() -> Iterator[bytes]:
        try:
            while True:
                chunk = upstream.read(65536)
                if not chunk:
                    break
                yield chunk
        finally:
            upstream.close()

    return StreamingResponse(
        iter_chunks(),
        status_code=status_code,
        media_type=content_type,
        headers=resp_headers,
    )


@app.get("/api/search", response_model=SearchResponse)
def search_tracks(
    query: str = Query(..., min_length=1, description="Kata kunci pencarian lagu, podcast, audiobook, atau lirik"),
    filter: Optional[str] = Query(
        "songs",
        description="Filter: songs, videos, albums, artists, playlists, podcasts, episodes, audiobooks, lyrics, spatial, atau all",
    ),
    limit: int = Query(20, ge=1, le=50),
) -> SearchResponse:
    try:
        effective_filter = None if filter == "all" else filter
        results = ytmusic_service.search(query=query, filter_type=effective_filter, limit=limit)
        return SearchResponse(
            query=query,
            filter=effective_filter,
            count=len(results),
            top_result=results[0] if results else None,
            results=results,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Gagal mengambil hasil pencarian dari YouTube Music: {exc}",
        ) from exc


@app.get("/api/song/{video_id}", response_model=SongDetailResponse)
def get_song(
    video_id: str,
    include_streams: bool = Query(True, description="Sertakan URL stream audio dan video langsung"),
) -> SongDetailResponse:
    try:
        return ytmusic_service.get_song_detail(video_id=video_id, include_streams=include_streams)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Gagal memuat metadata lagu {video_id}: {exc}",
        ) from exc


@app.get("/api/explore", response_model=ExploreResponse)
def get_explore_feed(
    limit: int = Query(6, ge=1, le=12),
) -> ExploreResponse:
    try:
        return ytmusic_service.get_explore(limit=limit)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Gagal memuat feed eksplorasi: {exc}",
        ) from exc


@app.get("/api/ai-dj", response_model=AiDjResponse)
def get_ai_dj(
    mood: str = Query("Lofi Fokus & Energi Malam", description="Suasana atau permintaan ke AI DJ"),
) -> AiDjResponse:
    try:
        return ytmusic_service.get_ai_dj_session(mood=mood)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Gagal memuat sesi AI DJ: {exc}",
        ) from exc


@app.get("/api/prompt-playlist", response_model=PromptPlaylistResponse)
def create_prompt_playlist(
    prompt: str = Query(..., min_length=2, description="Prompt teks untuk membuat playlist otomatis"),
) -> PromptPlaylistResponse:
    try:
        return ytmusic_service.generate_prompt_playlist(prompt=prompt)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Gagal membuat playlist dari prompt: {exc}",
        ) from exc


@app.get("/api/radio/{video_id}", response_model=list[TrackItem])
def get_song_radio(video_id: str) -> list[TrackItem]:
    try:
        return ytmusic_service.get_radio(video_id=video_id)
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail=f"Gagal memuat stasiun radio untuk {video_id}: {exc}",
        ) from exc
