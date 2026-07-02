import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart'
    show closeCurrentBottomSheet;
import 'package:musify/widgets/mini_player.dart';

class BottomNavigationPage extends StatefulWidget {
  const BottomNavigationPage({
    required this.navigationShell,
    required this.children,
    super.key,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<BottomNavigationPage> createState() => _BottomNavigationPageState();
}

class _BottomNavigationPageState extends State<BottomNavigationPage> with TickerProviderStateMixin {
  late final _miniPlayerVisibilityStream = audioHandler.mediaItem
      .map((mediaItem) => mediaItem != null)
      .distinct();

  bool? _previousOfflineMode;

  /// Track the previously selected tab index to detect double-taps on the same tab.
  int? _previousTabIndex;

  late final AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.navigationShell.currentIndex.toDouble(),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    );
  }



  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final currentIndex = widget.navigationShell.currentIndex;
        if (currentIndex != 0) {
          widget.navigationShell.goBranch(0);
          _animationController.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: offlineMode,
        builder: (context, isOfflineMode, _) {
          if (_previousOfflineMode != null &&
              _previousOfflineMode != isOfflineMode) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              _handleOfflineModeChange(isOfflineMode);
            });
          }
          _previousOfflineMode = isOfflineMode;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isLargeScreen = MediaQuery.of(context).size.width >= 600;
              final items = _getNavigationItems(isOfflineMode);

              return Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      if (isLargeScreen)
                        NavigationRail(
                          labelType: NavigationRailLabelType.selected,
                          destinations: items
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: Icon(item.icon),
                                  selectedIcon: Icon(item.selectedIcon),
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                          selectedIndex: _getCurrentIndex(items, isOfflineMode),
                          onDestinationSelected: (index) =>
                              _onTabTapped(index, items),
                        ),
                      Expanded(
                        child: StreamBuilder<bool>(
                          initialData: audioHandler.mediaItem.value != null,
                          stream: _miniPlayerVisibilityStream,
                          builder: (context, snapshot) {
                            final mediaQuery = MediaQuery.of(context);
                            final isMiniPlayerVisible = snapshot.data ?? false;
                            final bottomPadding = !isMiniPlayerVisible
                                ? mediaQuery.padding.bottom
                                : mediaQuery.padding.bottom +
                                      miniPlayerTotalHeight;

                            return Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                MediaQuery(
                                  data: mediaQuery.copyWith(
                                    padding: mediaQuery.padding.copyWith(
                                      bottom: bottomPadding,
                                    ),
                                  ),
                                  child: IndexedStack(
                                    index: widget.navigationShell.currentIndex,
                                    children: widget.children,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(
                                    left: 16,
                                    right: 16,
                                    bottom: 16,
                                  ),
                                  child: MiniPlayer(),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                bottomNavigationBar: !isLargeScreen
                    ? CustomBottomNavigationBar(
                        items: items,
                        selectedIndex: _getCurrentIndex(items, isOfflineMode),
                        animation: _animation,
                        onDestinationSelected: (index) =>
                            _onTabTapped(index, items),
                      )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  List<_NavigationItem> _getNavigationItems(bool isOfflineMode) {
    final items = <_NavigationItem>[
      _NavigationItem(
        icon: FluentIcons.home_24_regular,
        selectedIcon: FluentIcons.home_24_filled,
        label: context.l10n?.home ?? 'Home',
        route: '/home',
        shellIndex: 0,
      ),
    ];

    // Only add search tab in online mode
    if (!isOfflineMode) {
      items.add(
        _NavigationItem(
          icon: FluentIcons.search_24_regular,
          selectedIcon: FluentIcons.search_24_filled,
          label: context.l10n?.search ?? 'Search',
          route: '/search',
          shellIndex: 1,
        ),
      );
    }

    items.addAll([
      _NavigationItem(
        icon: FluentIcons.book_24_regular,
        selectedIcon: FluentIcons.book_24_filled,
        label: context.l10n?.library ?? 'Library',
        route: '/library',
        shellIndex: 2,
      ),
      _NavigationItem(
        icon: FluentIcons.settings_24_regular,
        selectedIcon: FluentIcons.settings_24_filled,
        label: context.l10n?.settings ?? 'Settings',
        route: '/settings',
        shellIndex: 3,
      ),
    ]);

    return items;
  }

  void _handleOfflineModeChange(bool isOfflineMode) {
    if (!mounted) return;

    final currentRoute = GoRouterState.of(context).matchedLocation;

    // If we're switching to offline mode and currently on search tab
    if (isOfflineMode && currentRoute.startsWith('/search')) {
      // Navigate to home
      widget.navigationShell.goBranch(0);
    }
  }

  void _onTabTapped(int index, List<_NavigationItem> items) {
    if (index < items.length) {
      final item = items[index];
      final isReselect = _previousTabIndex == index;

      // Close any open bottom sheet before switching tabs
      closeCurrentBottomSheet();

      // Animate the bottom bar pill indicator to this tab
      _animationController.animateTo(
        index.toDouble(),
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
      );

      // If user taps the same tab again, reset it to initial state.
      // Otherwise, preserve the branch state.
      if (isReselect) {
        widget.navigationShell.goBranch(item.shellIndex, initialLocation: true);
      } else {
        widget.navigationShell.goBranch(item.shellIndex);
      }

      _previousTabIndex = index;
    }
  }

  int _getCurrentIndex(List<_NavigationItem> items, bool isOfflineMode) {
    final currentShellIndex = widget.navigationShell.currentIndex;

    if (items.isEmpty) return 0;

    // Try to find the current shell index in the available items
    final matchedIndex = items.indexWhere(
      (item) => item.shellIndex == currentShellIndex,
    );
    if (matchedIndex != -1) return matchedIndex;

    // If the Search branch (1) is active but Search is hidden in offline mode,
    // fall back to the Home tab.
    if (isOfflineMode && currentShellIndex == 1) return 0;

    // Final fallback: return the first tab to keep UI in a valid state.
    return 0;
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.route,
    required this.shellIndex,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String route;
  final int shellIndex;
}

class CustomBottomNavigationBar extends StatelessWidget {
  const CustomBottomNavigationBar({
    required this.items,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.animation,
    super.key,
  });

  final List<_NavigationItem> items;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      height: 70,
      color: theme.colorScheme.surface,
      child: Stack(
        children: [
          // The animated pill
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              // Calculate the alignment based on the continuous animation value
              // 0 -> -1.0, 1 -> x, items.length - 1 -> 1.0
              final t = items.length > 1 ? animation.value / (items.length - 1) : 0.0;
              final alignmentX = -1.0 + (t * 2.0);
              
              return Align(
                alignment: Alignment(alignmentX, 0),
                child: FractionallySizedBox(
                  widthFactor: 1.0 / items.length,
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          // The icons and labels
          Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onDestinationSelected(index),
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) {
                      // Distance from the current animating index to this item's index
                      // 0.0 means perfectly centered on this item.
                      // 1.0 or greater means the pill is completely on another item.
                      final distance = (animation.value - index).abs();
                      final isSelected = distance < 0.5;
                      final t = (1.0 - distance).clamp(0.0, 1.0); // 1.0 when active, 0.0 when inactive

                      final iconColor = Color.lerp(
                        colorScheme.onSurfaceVariant,
                        colorScheme.onPrimaryContainer,
                        t,
                      );
                      
                      final labelColor = Color.lerp(
                        colorScheme.onSurfaceVariant,
                        colorScheme.onSurface,
                        t,
                      );

                      final fontWeight = isSelected ? FontWeight.w600 : FontWeight.w500;

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            color: iconColor,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 12,
                              fontWeight: fontWeight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
