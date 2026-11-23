import 'dart:async';

import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import '../views/widgets/liquid_glass_box.dart';
import 'omni_x_button.dart';
import 'play_button.dart';

/// Kartu AI DJ (components.md §19, §30): kartu kaca Glass 2, radius
/// card, ikon gelombang suara 64 px, nama sesi lg/600, komentar base.
/// Komentar mengetik SATU KALI saat sesi mulai, lalu berhenti — bukan
/// loop. Screen reader membaca komentar sebagai teks biasa setelah
/// selesai mengetik, bukan per huruf.
class AiDjCard extends StatefulWidget {
  final String sessionName;
  final String comment;
  final VoidCallback? onOpen;

  const AiDjCard({
    super.key,
    this.sessionName = 'AI DJ',
    this.comment =
        'Sore ini enak didengar yang santai dulu — saya pilihkan lagu-lagu akustik untuk menemani perjalanan pulangmu.',
    this.onOpen,
  });

  @override
  State<AiDjCard> createState() => _AiDjCardState();
}

class _AiDjCardState extends State<AiDjCard> {
  bool _sessionRunning = false;
  bool _typingDone = false;
  int _typedChars = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSession() {
    if (_sessionRunning) {
      _timer?.cancel();
      setState(() {
        _sessionRunning = false;
        _typedChars = 0;
        _typingDone = false;
      });
      return;
    }
    setState(() {
      _sessionRunning = true;
      _typedChars = 0;
      _typingDone = false;
    });
    // Mengetik satu kali, ~45 ms per karakter; berhenti di akhir teks.
    _timer = Timer.periodic(const Duration(milliseconds: 45), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_typedChars >= widget.comment.length) {
        timer.cancel();
        setState(() => _typingDone = true);
        return;
      }
      setState(() => _typedChars++);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visibleComment = _sessionRunning
        ? widget.comment.substring(0, _typedChars)
        : (_typingDone ? widget.comment : 'Belum ada sesi DJ.');

    return Semantics(
      button: true,
      label: 'Buka AI DJ',
      child: LiquidGlassBox(
        tier: GlassTier.glass2,
        borderRadius: OmniXTokens.radiusCard,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius:
                    BorderRadius.circular(OmniXTokens.radiusCard),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.graphic_eq_rounded,
                size: 32,
                color: scheme.tertiary,
                semanticLabel: 'Ikon AI DJ',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.sessionName,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: OmniXTokens.typeLg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Selama mengetik, teks disembunyikan dari screen
                  // reader; setelah selesai, dibaca sebagai teks biasa.
                  if (_sessionRunning && !_typingDone)
                    ExcludeSemantics(
                      child: Text(
                        visibleComment,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: OmniXTokens.typeBase,
                        ),
                      ),
                    )
                  else
                    Text(
                      visibleComment,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: OmniXTokens.typeBase,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      PlayButton.small(
                        isPlaying: _sessionRunning,
                        trackTitle: widget.sessionName,
                        onPressed: _startSession,
                      ),
                      const SizedBox(width: 12),
                      OmniXButton(
                        label: _sessionRunning
                            ? 'Hentikan DJ'
                            : 'Putar AI DJ',
                        variant: OmniXButtonVariant.primary,
                        size: OmniXButtonSize.md,
                        onPressed: _startSession,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
