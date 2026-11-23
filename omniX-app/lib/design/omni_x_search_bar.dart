import 'package:flutter/material.dart';
import '../theme/omnix_theme.dart';
import '../views/widgets/liquid_glass_box.dart';

/// Search bar (components.md §8): pil Glass 3 saat tidak fokus (tinggi
/// 48 px, ikon 24 px, teks base); fokus = border [border-input] 2 px
/// (token, bukan warna bebas) + cincin fokus 2 px aksen. Tombol tutup
/// muncul saat terisi, berlabel "Hapus pencarian".
class OmniXSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  const OmniXSearchBar({
    super.key,
    this.hintText = 'Cari lagu, artis, album',
    this.onChanged,
    this.controller,
  });

  @override
  State<OmniXSearchBar> createState() => _OmniXSearchBarState();
}

class _OmniXSearchBarState extends State<OmniXSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    if (widget.controller == null) _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasText = _controller.text.isNotEmpty;

    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: TextStyle(
        color: scheme.onSurface,
        fontSize: OmniXTokens.typeBase,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 24,
          color: scheme.onSurfaceVariant,
        ),
        suffixIcon: hasText
            ? IconButton(
                tooltip: 'Hapus pencarian',
                onPressed: () {
                  _controller.clear();
                  widget.onChanged?.call('');
                },
                icon: const Icon(Icons.close_rounded, size: 20),
              )
            : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );

    final pill = _focused
        ? Container(
            height: 48,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius:
                  BorderRadius.circular(OmniXTokens.radiusPill),
              border: Border.all(color: scheme.tertiary, width: 2),
            ),
            child: field,
          )
        : LiquidGlassBox(
            tier: GlassTier.glass3,
            borderRadius: OmniXTokens.radiusPill,
            child: SizedBox(height: 48, child: field),
          );

    // Saat fokus, border 2 px warna border-input (scheme.tertiary =
    // accent-bright gelap / accent terang = token border-input di kedua
    // mode) sekaligus berfungsi sebagai cincin focus-visible.
    return pill;
  }
}
