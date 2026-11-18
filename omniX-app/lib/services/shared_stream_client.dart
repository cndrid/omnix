import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Satu instance [YoutubeExplode] bersama untuk seluruh aplikasi
/// (fast start, 18 Nov 2026).
///
/// Sebelumnya `YoutubeExplode()` baru dibuat di tiap panggilan (8 tempat di
/// yt_client.dart + stream_extractor.dart): tiap panggilan handshake/TLS
/// ulang tanpa connection reuse, dan instance langsung di-close.
/// Instance ini sengaja TIDAK pernah di-close selama aplikasi jalan —
/// client HTTP di dalamnya dipakai ulang untuk semua pencarian, metadata,
/// dan ekstraksi stream.
class SharedStreamClient {
  SharedStreamClient._();

  static final YoutubeExplode instance = YoutubeExplode();
}
