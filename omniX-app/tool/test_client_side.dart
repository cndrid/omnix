// Smoke test arsitektur client-side (sementara, bukan bagian build).
import 'package:omnix_app/services/lyrics_service.dart';
import 'package:omnix_app/services/skip_service.dart';
import 'package:omnix_app/services/yt_client.dart';

Future<void> main() async {
  final yt = YtClientService();
  final tracks = await yt.searchMusic('Tulus Hati-Hati di Jalan', limit: 3);
  print('SEARCH: ${tracks.length} hasil');
  for (final t in tracks) {
    print(' - ${t.title} | ${t.artistLine} | ${t.duration} | ${t.videoId}');
  }

  final lyrics = await LrclibService().fetchLyrics(
    artist: 'Tulus',
    track: 'Hati-Hati di Jalan',
    durationSeconds: 242,
  );
  print('LRCLIB: synced=${lyrics?.syncedLyrics.length ?? 0} '
      'plain=${lyrics?.plainLyrics?.length ?? 0} chars');

  final votes = await SkipService().fetchVotes('RgKAFK5djSk');
  print('RYD: likes=${votes?.likes} dislikes=${votes?.dislikes}');

  final segs = await SkipService().fetchSkipSegments('RgKAFK5djSk');
  print('SPONSORBLOCK: ${segs.length} segmen');

  final explore = await yt.getExploreData(limit: 3);
  print('EXPLORE: ${explore.sections.length} seksi');
  for (final s in explore.sections) {
    print(' - ${s.title}: ${s.items.length} lagu, pertama: '
        '${s.items.isNotEmpty ? s.items.first.title : '-'}');
  }
  print('DONE');
}
