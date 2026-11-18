import 'package:flutter/material.dart';
import '../../models/track_model.dart';

class TrackArtwork extends StatelessWidget {
  final TrackModel track;
  final double size;
  final double borderRadius;

  const TrackArtwork({
    super.key,
    required this.track,
    this.size = 50,
    // Radius artwork 4px sesuai preview UI v2.
    this.borderRadius = 4,
  });

  static const List<List<Color>> _discPalettes = [
    [Color(0xFF5E35B1), Color(0xFF1E88E5)],
    [Color(0xFF00897B), Color(0xFF3949AB)],
    [Color(0xFFD81B60), Color(0xFF8E24AA)],
    [Color(0xFFFB8C00), Color(0xFFE53935)],
    [Color(0xFF43A047), Color(0xFF00ACC1)],
    [Color(0xFF3949AB), Color(0xFF7C5CFF)],
  ];

  @override
  Widget build(BuildContext context) {
    final primaryUrl = track.bestThumbnailUrl;

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: primaryUrl.isNotEmpty
            ? Image.network(
                primaryUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                semanticLabel: 'Sampul album ${track.title}',
                // Gagal dimuat -> placeholder gradien + ikon not musik.
                errorBuilder: (_, __, ___) => _VinylDiscArtwork(
                  track: track,
                  size: size,
                  palette: _pickPalette(track.title),
                ),
              )
            : _VinylDiscArtwork(
                track: track,
                size: size,
                palette: _pickPalette(track.title),
              ),
      ),
    );
  }

  List<Color> _pickPalette(String seed) {
    final hash = seed.codeUnits.fold<int>(0, (a, b) => a + b);
    return _discPalettes[hash % _discPalettes.length];
  }
}

class _VinylDiscArtwork extends StatelessWidget {
  final TrackModel track;
  final double size;
  final List<Color> palette;

  const _VinylDiscArtwork({
    required this.track,
    required this.size,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final isLarge = size >= 120;
    final initial = track.title.trim().isNotEmpty
        ? track.title.trim()[0].toUpperCase()
        : 'A';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.76,
            height: size * 0.76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.35),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: isLarge ? 3 : 1.5,
              ),
            ),
          ),
          if (isLarge)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Placeholder gradien + ikon not musik seperti preview v2.
                  const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.artistLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.34,
              ),
            ),
        ],
      ),
    );
  }
}
