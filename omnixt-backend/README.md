# OmniX Backend (`omnixt-backend`)

Layanan API berbasis FastAPI dan `ytmusicapi` untuk pencarian lagu, metadata, lirik, dan ekstraksi stream YouTube Music pada aplikasi OmniX.

## Menjalankan Server

1. Buat virtual environment dan pasang dependensi:
   ```bash
   python -m venv .venv
   .venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. Jalankan server pengembangan:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

## Endpoint Utama

- `GET /health`: Pemeriksaan status layanan.
- `GET /api/search?query=...&filter=songs&limit=20`: Pencarian lagu, video, album, atau artis dari YouTube Music.
- `GET /api/song/{video_id}?include_streams=true`: Detail metadata lagu, lirik, daftar lagu terkait, serta URL stream audio dan video.
- `GET /api/explore`: Daftar rekomendasi beranda langsung dari YouTube Music.
