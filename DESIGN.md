# Aura Audio / OmniX Design Direction (`DESIGN.md`)

## Design Read & Liveliness Dials

Reading this as: multi-platform Liquid Glass music, podcast, and audiobook streaming client (Aura Audio / OmniX) with all Spotify features unlocked for free without limits, dial `ENERGY 2 / RHYTHM 2 / MOTION 2`.

- **R-37 Owner Override Record:** Owner explicitly instructed ("untuk UI ubah mengikuti PRD brief yang saya berikan") to adopt the Aura Audio Liquid Glass PRD tokens (`#0B0B10` canvas, `#16161D` surface, `#7C5CFF` dynamic violet accent, `#3DDC84` success, `#FF5C5C` danger) and the 3-tier Liquid Glass system (`Glass 1` 24px blur floating pill nav & mini player, `Glass 2` 24px blur sheets/lyrics, `Glass 3` 16px blur chips/badges) across the 4-tab + Now Playing IA. All Hard Gate rules (`R-02` no em dashes, `R-03` mobile responsiveness & 48px touch targets, `R-24` no dead links, `R-25` WCAG AA >= 4.5:1 contrast, `R-26` functional completeness, `R-27` empty/loading/error states, `R-32` keyboard focus, `R-34` working theme toggle, `R-39` pointer cursors & semantics) remain strictly enforced.

## Palette & Contrast Verification (`R-01`, `R-25`, `R-29`, `R-34`)

### Dark Theme (Aura Audio Liquid Glass Default)
- **Canvas (`#0B0B10`)**: Universal deep midnight background.
- **Surface (`#16161D`)**: Content cards, track rows, and solid fallback containers.
- **Text Primary (`#FFFFFF`)**: `19.6:1` contrast ratio on `#0B0B10` and `17.2:1` on `#16161D` (passes WCAG AAA/AA).
- **Text Secondary (`#A7A7B3`)**: `8.2:1` contrast ratio on `#0B0B10` and `7.2:1` on `#16161D` (passes WCAG AA 4.5:1).
- **Accent (`#7C5CFF` / `#9E86FF`)**: Neon violet accent. Text over `#7C5CFF` uses `#FFFFFF` (`4.65:1` contrast when paired with `#6340F5` button fill or bold large text, and `#A992FF` on `#16161D` achieves `7.1:1`).
- **Success (`#3DDC84`)**: Offline sync verified & bit-perfect status (`11.4:1` contrast on `#0B0B10`).
- **Danger (`#FF5C5C`)**: Delete playlist, disconnect stream, alert state (`6.2:1` contrast on `#0B0B10`).

### Light Theme (Working Theme Toggle per `R-21`, `R-34`)
- **Canvas (`#F6F6FB`)**: Soft daylight background.
- **Surface (`#FFFFFF`)**: Elevated card surface with `#D6D6E5` border.
- **Text Primary (`#111118`)**: `17.5:1` contrast on `#F6F6FB`.
- **Text Secondary (`#48485A`)**: `8.1:1` contrast on `#FFFFFF`.
- **Accent (`#522ED3`)**: Deep violet with `7.4:1` contrast against `#FFFFFF` text.

## Material Tiers (Liquid Glass Formula)
1. **Glass 1 (Floating Pill Navigation & Stacked Mini Player)**:
   - Backdrop blur: `sigmaX: 24, sigmaY: 24`
   - Fill: `rgba(255, 255, 255, 0.12)` (Dark) / `rgba(255, 255, 255, 0.85)` (Light)
   - Border: `1px solid rgba(255, 255, 255, 0.25)`
   - Elevation Shadow: `0 8px 24px rgba(0, 0, 0, 0.25)`
2. **Glass 2 (Panels, Bottom Sheets & Synced Lyrics)**:
   - Backdrop blur: `sigmaX: 24, sigmaY: 24`
   - Fill: `rgba(255, 255, 255, 0.16)`
   - Border: `1px solid rgba(255, 255, 255, 0.20)`
3. **Glass 3 (Filter Chips, Small Icon Buttons & Interactive Badges)**:
   - Backdrop blur: `sigmaX: 16, sigmaY: 16`
   - Fill: `rgba(255, 255, 255, 0.18)`
   - Border: `1px solid rgba(255, 255, 255, 0.30)`

## One-Line Reasons for Major Decisions (`R-31`)

- **Why this color palette:** Midnight `#0B0B10` and `#16161D` ground the 3-tier Liquid Glass surfaces while `#7C5CFF` violet and `#3DDC84` emerald distinguish active playback and lossless/offline states.
- **Why this 4-tab + Now Playing layout:** Matches the Aura Audio IA (`Beranda`, `Cari`, `Koleksi`, `Profil & Pengaturan`, plus `Sedang Diputar` modal) with floating pill navigation on mobile and sidebar + floating dock on desktop.
- **Why all Spotify Premium features are unlocked for free:** Per owner product requirement, ad-free lossless streaming, unlimited skips, full queue reordering, offline downloads, AI DJ, Prompted Playlists, Jam, Blend, and Audiobooks ship without paywalls or hour caps.
- **Why this typography:** Geometric sans-serif with tabular numerals (`FontFeature.tabularFigures()`) aligns ranked charts (`01` to `05`), timestamps, and synced karaoke lyrics cleanly.
