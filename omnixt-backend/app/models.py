from typing import Optional
from pydantic import BaseModel, Field


class Thumbnail(BaseModel):
    url: str
    width: int = 0
    height: int = 0


class ArtistRef(BaseModel):
    name: str
    id: Optional[str] = None


class AlbumRef(BaseModel):
    name: str
    id: Optional[str] = None


class ChapterItem(BaseModel):
    title: str
    start_seconds: int
    duration_seconds: int


class LyricLine(BaseModel):
    time_seconds: int
    text: str


class SongCredits(BaseModel):
    writers: list[str] = Field(default_factory=list)
    producers: list[str] = Field(default_factory=list)
    release_year: Optional[str] = None
    label: str = "YouTube Music / OmniX Lossless"
    artist_bio: Optional[str] = None
    upcoming_concerts: list[str] = Field(default_factory=list)


class TrackItem(BaseModel):
    video_id: str
    title: str
    artists: list[ArtistRef] = Field(default_factory=list)
    album: Optional[AlbumRef] = None
    duration: Optional[str] = None
    duration_seconds: Optional[int] = None
    thumbnails: list[Thumbnail] = Field(default_factory=list)
    is_explicit: bool = False
    result_type: str = "song"
    category: str = "music"
    audio_quality_badge: str = "FLAC 24-bit"


class SearchResponse(BaseModel):
    query: str
    filter: Optional[str] = None
    count: int
    top_result: Optional[TrackItem] = None
    results: list[TrackItem]


class SongDetailResponse(BaseModel):
    video_id: str
    title: str
    artists: list[ArtistRef] = Field(default_factory=list)
    album: Optional[AlbumRef] = None
    length_seconds: int = 0
    thumbnails: list[Thumbnail] = Field(default_factory=list)
    audio_stream_url: Optional[str] = None
    audio_mime_type: Optional[str] = None
    audio_bitrate_kbps: Optional[int] = None
    video_stream_url: Optional[str] = None
    canvas_loop_url: Optional[str] = None
    lyrics: Optional[str] = None
    has_Synced_lyrics: bool = False
    synced_lyrics: list[LyricLine] = Field(default_factory=list)
    chapters: list[ChapterItem] = Field(default_factory=list)
    transcript: Optional[str] = None
    credits: SongCredits = Field(default_factory=SongCredits)
    related_tracks: list[TrackItem] = Field(default_factory=list)


class ExploreSection(BaseModel):
    title: str
    subtitle: Optional[str] = None
    category: str = "all"
    items: list[TrackItem] = Field(default_factory=list)


class ExploreResponse(BaseModel):
    sections: list[ExploreSection] = Field(default_factory=list)
    trending_tags: list[str] = Field(default_factory=list)
    ranked_searches: list[TrackItem] = Field(default_factory=list)
    top_artists: list[ArtistRef] = Field(default_factory=list)


class AiDjResponse(BaseModel):
    greeting: str
    commentary: str
    mood: str
    tracks: list[TrackItem] = Field(default_factory=list)


class PromptPlaylistResponse(BaseModel):
    prompt: str
    playlist_name: str
    description: str
    tracks: list[TrackItem] = Field(default_factory=list)
