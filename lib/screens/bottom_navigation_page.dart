import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/main.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart'
    show closeCurrentBottomSheet;
import 'package:musify/widgets/sliding_player_overlay.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart';

// Global notifier to detect when the Search tab is re-tapped while already active
final ValueNotifier<int> searchTabReselectNotifier = ValueNotifier(0);

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

class _BottomNavigationPageState extends State<BottomNavigationPage>
    with TickerProviderStateMixin {
  late final _miniPlayerVisibilityStream = Rx.combineLatest2(
    audioHandler.mediaItem,
    audioHandler.playbackStateStream,
    (mediaItem, playbackState) =>
        mediaItem != null &&
        (playbackState.processingState != AudioProcessingState.idle ||
            audioHandler.queue.value.isNotEmpty),
  ).distinct().asBroadcastStream();

  bool? _previousOfflineMode;

  /// Track the previously selected tab index to detect double-taps on the same tab.
  int? _previousTabIndex;
  int _targetIndex = 0;
  int _sourceIndex = 0;

  late final AnimationController _animationController;
  late final AnimationController _playerAnimController;
  late final AnimationController _pageSlideController;
  late final Animation<double> _pageSlideAnimation;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _targetIndex = widget.navigationShell.currentIndex;
    _sourceIndex = widget.navigationShell.currentIndex;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      upperBound: 10, // High enough to cover all tabs
      value: widget.navigationShell.currentIndex.toDouble(),
    );
    _animation = _animationController;

    _playerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _pageSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );
    _pageSlideAnimation = CurvedAnimation(
      parent: _pageSlideController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageSlideController.dispose();
    _playerAnimController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BottomNavigationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.navigationShell.currentIndex !=
        oldWidget.navigationShell.currentIndex) {
      final isOffline = offlineMode.value;
      final items = _getNavigationItems(isOffline);
      final newIndex = _getCurrentIndex(items, isOffline);
      _animationController.animateTo(
        newIndex.toDouble(),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      if (newIndex != _targetIndex) {
        _sourceIndex = _targetIndex;
        _targetIndex = newIndex;
        _pageSlideController.forward(from: 0.0);
      }
      _previousTabIndex = widget.navigationShell.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final currentIndex = widget.navigationShell.currentIndex;
        if (currentIndex != 0) {
          if (0 != _targetIndex) {
            _sourceIndex = _targetIndex;
            _targetIndex = 0;
            _pageSlideController.forward(from: 0.0);
          }
          widget.navigationShell.goBranch(0);
          _animationController.animateTo(
            0,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
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

              return Stack(
                children: [
                  Scaffold(
                    body: SafeArea(
                      top: false,
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
                              selectedIndex: _getCurrentIndex(
                                items,
                                isOfflineMode,
                              ),
                              onDestinationSelected: (index) =>
                                  _onTabTapped(index, items),
                            ),
                          Expanded(
                            child: StreamBuilder<bool>(
                              initialData: audioHandler.mediaItem.value != null,
                              stream: _miniPlayerVisibilityStream,
                              builder: (context, snapshot) {
                                final mediaQuery = MediaQuery.of(context);

                                return Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    MediaQuery(
                                      data: mediaQuery.copyWith(
                                        padding: mediaQuery.padding.copyWith(
                                          bottom: mediaQuery.padding.bottom,
                                        ),
                                      ),
                                      child: LayoutBuilder(
                                        builder: (context, pageConstraints) {
                                          final width = pageConstraints.maxWidth;
                                          return AnimatedBuilder(
                                            animation: _pageSlideAnimation,
                                            builder: (context, _) {
                                              final progress = _pageSlideAnimation.value;
                                              final isAnimating = _pageSlideController.isAnimating;
                                              final direction = (_targetIndex >= _sourceIndex) ? 1.0 : -1.0;

                                              return Stack(
                                                fit: StackFit.expand,
                                                children: List.generate(widget.children.length, (i) {
                                                  if (!isAnimating) {
                                                    final isCurrent = i == _targetIndex;
                                                    return Offstage(
                                                      offstage: !isCurrent,
                                                      child: TickerMode(
                                                        enabled: isCurrent,
                                                        child: widget.children[i],
                                                      ),
                                                    );
                                                  }

                                                  if (i == _targetIndex) {
                                                    final offset = Offset(direction * width * 0.25 * (1.0 - progress), 0);
                                                    return Offstage(
                                                      offstage: false,
                                                      child: TickerMode(
                                                        enabled: true,
                                                        child: Transform.translate(
                                                          offset: offset,
                                                          child: Opacity(
                                                            opacity: progress.clamp(0.0, 1.0),
                                                            child: widget.children[i],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  } else if (i == _sourceIndex) {
                                                    final offset = Offset(-direction * width * 0.25 * progress, 0);
                                                    return Offstage(
                                                      offstage: false,
                                                      child: TickerMode(
                                                        enabled: true,
                                                        child: Transform.translate(
                                                          offset: offset,
                                                          child: Opacity(
                                                            opacity: (1.0 - progress).clamp(0.0, 1.0),
                                                            child: widget.children[i],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }

                                                  return Offstage(
                                                    offstage: true,
                                                    child: TickerMode(
                                                      enabled: false,
                                                      child: widget.children[i],
                                                    ),
                                                  );
                                                }),
                                              );
                                            },
                                          );
                                        },
                                      ),
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
                            selectedIndex: _getCurrentIndex(
                              items,
                              isOfflineMode,
                            ),
                            animation: _animation,
                            onDestinationSelected: (index) =>
                                _onTabTapped(index, items),
                          )
                        : null,
                  ),
                  StreamBuilder<bool>(
                    initialData: audioHandler.mediaItem.value != null,
                    stream: _miniPlayerVisibilityStream,
                    builder: (context, snapshot) {
                      if (widget.navigationShell.currentIndex == 4) {
                        return const SizedBox.shrink();
                      }
                      final isVisible = snapshot.data == true;
                      return SlidingPlayerOverlay(
                        animationController: _playerAnimController,
                        isVisible: isVisible,
                        bottomMargin: isLargeScreen
                            ? 0.0
                            : 54.0 + MediaQuery.of(context).padding.bottom,
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<_NavigationItem> _getNavigationItems(bool isOfflineMode) {
    final items = <_NavigationItem>[
      const _NavigationItem(
        icon: FluentIcons.play_circle_24_regular,
        selectedIcon: FluentIcons.play_circle_24_filled,
        label: 'Listen',
        route: '/home',
        shellIndex: 0,
      ),
    ];

    // Only add search and radio tabs in online mode
    if (!isOfflineMode) {
      items.add(
        const _NavigationItem(
          icon: FluentIcons.search_24_regular,
          selectedIcon: FluentIcons.search_24_filled,
          label: 'Search',
          route: '/search',
          shellIndex: 1,
        ),
      );
      items.add(
        const _NavigationItem(
          icon: Icons.radio_rounded,
          selectedIcon: Icons.radio_rounded,
          label: 'Radio',
          route: '/radio',
          shellIndex: 2,
        ),
      );
    }

    items.addAll([
      const _NavigationItem(
        icon: FluentIcons.music_note_2_24_regular,
        selectedIcon: FluentIcons.music_note_2_24_filled,
        label: 'Library',
        route: '/library',
        shellIndex: 3,
      ),
      const _NavigationItem(
        icon: FluentIcons.settings_24_regular,
        selectedIcon: FluentIcons.settings_24_filled,
        label: 'Settings',
        route: '/settings',
        shellIndex: 4,
      ),
    ]);

    return items;
  }

  void _handleOfflineModeChange(bool isOfflineMode) {
    if (!mounted) return;

    final currentRoute = GoRouterState.of(context).matchedLocation;

    // If we're switching to offline mode and currently on search or radio tab
    if (isOfflineMode &&
        (currentRoute.startsWith('/search') ||
            currentRoute.startsWith('/radio'))) {
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

      // Animate the bottom bar sliding indicator to this tab (120fps glide)
      _animationController.animateTo(
        index.toDouble(),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );

      // Trigger smooth directional page transition
      if (item.shellIndex != _targetIndex) {
        _sourceIndex = _targetIndex;
        _targetIndex = item.shellIndex;
        _pageSlideController.forward(from: 0.0);
      }

      // If user taps the same tab again, reset it to initial state.
      // Otherwise, preserve the branch state.
      if (isReselect) {
        if (item.route == '/search') {
          searchTabReselectNotifier.value++;
        }
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
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    // Active color from user CSS: #e11d48
    const activeColor = Color(0xFFE11D48);
    // Inactive color from user CSS: #8c857b
    const inactiveColor = Color(0xFF8C857B);

    return Container(
      height: 54 + bottomPadding,
      padding: EdgeInsets.only(left: 6, right: 6, bottom: bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0x1FFFFFFF) : const Color(0xFFE7E2DA),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / items.length;
          const indicatorWidth = 28.0;

          return Stack(
            children: [
              // Single Smooth Gliding Top Red Indicator Bar (120 FPS continuous swipe)
              AnimatedBuilder(
                animation: animation,
                builder: (context, _) {
                  final left = (tabWidth * animation.value) +
                      (tabWidth - indicatorWidth) / 2;
                  return Positioned(
                    top: 0,
                    left: left.clamp(0.0, constraints.maxWidth - indicatorWidth),
                    child: Container(
                      width: indicatorWidth,
                      height: 2.5,
                      decoration: const BoxDecoration(
                        color: activeColor,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(4),
                          bottomRight: Radius.circular(4),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Navigation Tab Items Row
              Row(
                children: List.generate(items.length, (index) {
                  final item = items[index];
                  final isSelected = selectedIndex == index;

                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDestinationSelected(index),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                key: ValueKey(isSelected),
                                color: isSelected ? activeColor : inactiveColor,
                                size: 19,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                color: isSelected ? activeColor : inactiveColor,
                                fontSize: 9.5,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                letterSpacing: 0.1,
                                fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: Text(item.label),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}
