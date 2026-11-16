# OmniX Flutter Client (`omniX-app`)

Aplikasi pemutar musik dan video klip lintas platform berbasis Flutter, `flutter_riverpod`, `just_audio`, `audio_service`, serta `video_player` dan `chewie` yang terhubung ke backend FastAPI (`omnixt-backend`).

## Struktur Direktori

- `lib/models/track_model.dart`: Model data lagu, artis, album, thumbnail, detail stream audio/video, dan lirik.
- `lib/services/api_service.dart`: Klien HTTP menuju endpoint `/api/explore`, `/api/search`, dan `/api/song/{video_id}`.
- `lib/services/audio_handler_service.dart`: Integrasi `just_audio` dan `audio_service` (`BaseAudioHandler`) untuk pemutaran latar belakang dan kontrol layar kunci.
- `lib/providers/app_providers.dart`: Manajemen state Riverpod untuk tema (Dark/Light), transparansi kaca (`reducedTransparencyProvider`), pencarian, koleksi, antrean, dan kontrol pemutar.
- `lib/theme/omnix_theme.dart`: Sistem desain Dark (`#0D0D0D` / `#16161A` + `#FF1E42`) dan Light (`#F7F7F9` / `#FFFFFF` + `#C80028`) yang telah diverifikasi terhadap standar kontras WCAG AA.
- `lib/views/widgets/liquid_glass_box.dart`: Komponen `BackdropFilter` (`sigmaX: 16, sigmaY: 16`) dengan batas dosis maksimal 2 elemen melayang (`StickyMiniPlayer` dan toggle `[ Song ] / [ Video ]`) serta fallback solid saat mode kurangi transparansi aktif.
- `lib/views/explore_view.dart`, `lib/views/search_view.dart`, `lib/views/library_view.dart`, `lib/views/fullscreen_player_view.dart`, `lib/views/app_shell.dart`: Tampilan utama responsif untuk Mobile (`< 640px`), Tablet (`640-1023px`), dan Desktop (`>= 1024px`).

## Menjalankan Aplikasi

1. Pastikan server backend di `../omnixt-backend` sudah berjalan pada `http://127.0.0.1:8000`.
2. Di dalam direktori `omniX-app/`, unduh paket dan jalankan aplikasi:
   ```bash
   flutter pub get
   flutter run
   ```
