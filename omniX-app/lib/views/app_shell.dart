import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/omnix_theme.dart';
import 'explore_view.dart';
import 'fullscreen_player_view.dart';
import 'library_view.dart';
import 'profile_view.dart';
import 'search_view.dart';
import 'widgets/liquid_glass_box.dart';
import 'widgets/queue_sheet.dart';
import 'widgets/sticky_mini_player.dart';

class OmniXAppShell extends ConsumerWidget {
  const OmniXAppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeTabProvider);
    final railCollapsed = ref.watch(railCollapsedProvider);
    final themeMode = ref.watch(themeModeProvider);
    final reducedTransparency = ref.watch(reducedTransparencyProvider);
    final playerState = ref.watch(playerControllerProvider);
    final engineState = ref.watch(audioEngineProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < OmniXTokens.breakpointTablet;
    final isDesktop = width >= OmniXTokens.breakpointDesktop;
    final hasActiveTrack = playerState.currentTrack != null;

    final bottomSafePadding = hasActiveTrack
        ? (isMobile ? 184.0 : 116.0)
        : (isMobile ? 104.0 : 32.0);

    final pages = [
      ExploreView(bottomSafePadding: bottomSafePadding),
      SearchView(bottomSafePadding: bottomSafePadding),
      LibraryView(bottomSafePadding: bottomSafePadding),
      ProfileView(bottomSafePadding: bottomSafePadding),
    ];

    final scheme = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (playerState.isFullscreenOpen) {
            controller.closeFullscreen();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                backgroundColor: scheme.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                titleSpacing: 16,
                leading: !isMobile
                    ? IconButton(
                        tooltip: railCollapsed
                            ? 'Perluas panel navigasi samping'
                            : 'Ciutkan panel navigasi samping',
                        onPressed: () {
                          ref.read(railCollapsedProvider.notifier).state =
                              !railCollapsed;
                        },
                        icon: Icon(
                          railCollapsed ? Icons.menu_open : Icons.menu,
                        ),
                      )
                    : null,
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.cover,
                        semanticLabel: 'Logo OmniX',
                        errorBuilder: (_, __, ___) => Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'OmniX',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton.icon(
                    onPressed: () => showQueueManagerSheet(context, ref),
                    icon: const Icon(Icons.queue_music_rounded, size: 19),
                    label: Text(
                      'Antrean (${playerState.queue.length})',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (engineState.jamSessionActive && !isMobile)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.secondary.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(OmniXTokens.radiusPill),
                          border: Border.all(color: scheme.secondary),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'JAM: ${engineState.jamCode}',
                          style: TextStyle(
                            color: scheme.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  IconButton(
                    tooltip: reducedTransparency
                        ? 'Aktifkan efek kaca transparan (Liquid Glass)'
                        : 'Nonaktifkan transparansi kaca (Kontras Solid)',
                    onPressed: () {
                      ref.read(reducedTransparencyProvider.notifier).state =
                          !reducedTransparency;
                    },
                    icon: Icon(
                      reducedTransparency
                          ? Icons.blur_off_rounded
                          : Icons.blur_on_rounded,
                    ),
                  ),
                  IconButton(
                    tooltip: themeMode == ThemeMode.dark
                        ? 'Beralih ke Mode Terang'
                        : 'Beralih ke Mode Gelap',
                    onPressed: () {
                      ref.read(themeModeProvider.notifier).state =
                          themeMode == ThemeMode.dark
                              ? ThemeMode.light
                              : ThemeMode.dark;
                    },
                    icon: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Divider(
                    height: 1,
                    color: scheme.outline,
                  ),
                ),
              ),
              body: Row(
                children: [
                  if (!isMobile) ...[
                    NavigationRail(
                      backgroundColor: scheme.surface,
                      extended: isDesktop && !railCollapsed,
                      selectedIndex: activeTab.index,
                      onDestinationSelected: (idx) {
                        ref.read(activeTabProvider.notifier).state =
                            AppTab.values[idx];
                      },
                      labelType: (isDesktop && !railCollapsed)
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      indicatorColor: scheme.primary.withValues(alpha: 0.22),
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.home_outlined),
                          selectedIcon: Icon(Icons.home_rounded),
                          label: Text('Beranda'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.search_outlined),
                          selectedIcon: Icon(Icons.search_rounded),
                          label: Text('Cari'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.library_music_outlined),
                          selectedIcon: Icon(Icons.library_music_rounded),
                          label: Text('Koleksi'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.person_outline_rounded),
                          selectedIcon: Icon(Icons.person_rounded),
                          label: Text('Profil'),
                        ),
                      ],
                    ),
                    VerticalDivider(
                      width: 1,
                      color: scheme.outline,
                    ),
                  ],
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 240),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              final slide = Tween<Offset>(
                                begin: const Offset(0.015, 0),
                                end: Offset.zero,
                              ).animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: slide,
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey('main_tab_${activeTab.name}'),
                              child: pages[activeTab.index],
                            ),
                          ),
                        ),
                        if (hasActiveTrack)
                          Positioned(
                            left: isMobile ? 12 : 24,
                            right: isMobile ? 12 : 24,
                            bottom: isMobile ? 88 : 16,
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 760),
                                child: const StickyMiniPlayer(),
                              ),
                            ),
                          ),
                        if (isMobile)
                          Positioned(
                            left: 16,
                            right: 16,
                            bottom: 16,
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 420),
                                child: _FloatingPillBottomNavbar(
                                  activeTab: activeTab,
                                  onSelectTab: (tab) {
                                    ref.read(activeTabProvider.notifier).state =
                                        tab;
                                  },
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !(playerState.isFullscreenOpen && hasActiveTrack),
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  offset: (playerState.isFullscreenOpen && hasActiveTrack)
                      ? Offset.zero
                      : const Offset(0, 1.0),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    opacity: (playerState.isFullscreenOpen && hasActiveTrack)
                        ? 1.0
                        : 0.0,
                    child: hasActiveTrack
                        ? const FullscreenPlayerView()
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingPillBottomNavbar extends StatelessWidget {
  final AppTab activeTab;
  final ValueChanged<AppTab> onSelectTab;

  const _FloatingPillBottomNavbar({
    required this.activeTab,
    required this.onSelectTab,
  });

  static const List<(AppTab, String, IconData)> _items = [
    (AppTab.beranda, 'Beranda', Icons.home_rounded),
    (AppTab.cari, 'Cari', Icons.search_rounded),
    (AppTab.koleksi, 'Koleksi', Icons.library_music_rounded),
    (AppTab.profil, 'Profil', Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return LiquidGlassBox(
      tier: GlassTier.glass1,
      borderRadius: OmniXTokens.radiusNavbar,
      elevatedShadow: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final (tab, label, icon) in _items)
            _PillNavDestination(
              label: label,
              icon: icon,
              selected: activeTab == tab,
              scheme: scheme,
              onTap: () => onSelectTab(tab),
            ),
        ],
      ),
    );
  }
}

class _PillNavDestination extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _PillNavDestination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tab $label',
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(
            minHeight: OmniXTokens.minTouchTarget,
            minWidth: 72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(OmniXTokens.radiusPill),
            border: selected ? Border.all(color: scheme.primary) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
