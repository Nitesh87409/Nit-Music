import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:musify/main.dart';
import 'package:musify/utilities/formatter.dart';
import 'package:musify/utilities/palette_cache.dart';

import 'package:musify/widgets/now_playing/now_playing_options_menu.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
import 'package:musify/widgets/queue_list_view.dart';

import 'package:palette_generator/palette_generator.dart';

class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({
    super.key,
    this.initialDominantColor,
    this.initialVibrantColor,
    this.isOverlay = false,
    this.onClose,
  });

  final Color? initialDominantColor;
  final Color? initialVibrantColor;
  final bool isOverlay;
  final VoidCallback? onClose;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  final _lyricsController = FlipCardController();
  final _upNextController = DraggableScrollableController();
  StreamSubscription? _mediaItemSub;
  Color? _dominantColor;
  Color? _vibrantColor;

  @override
  void initState() {
    super.initState();
    _dominantColor = widget.initialDominantColor;
    _vibrantColor = widget.initialVibrantColor;

    final currentItem = audioHandler.mediaItem.value;
    if (currentItem != null) {
      if (PaletteCache.hasColorsFor(currentItem.id)) {
        _dominantColor ??= PaletteCache.dominantColor;
        _vibrantColor ??= PaletteCache.vibrantColor;
      } else {
        _updatePalette(currentItem);
      }
    }

    _mediaItemSub = audioHandler.mediaItem.listen((item) {
      if (item == null) return;

      if (PaletteCache.hasColorsFor(item.id)) {
        if (mounted) {
          setState(() {
            _dominantColor = PaletteCache.dominantColor;
            _vibrantColor = PaletteCache.vibrantColor;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _dominantColor = null;
            _vibrantColor = null;
          });
        }
        _updatePalette(item);
      }
    });
  }

  @override
  void dispose() {
    _mediaItemSub?.cancel();
    _upNextController.dispose();
    super.dispose();
  }

  Future<void> _updatePalette(MediaItem? item) async {
    if (item?.artUri == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        ResizeImage(
          NetworkImage(item!.artUri!.toString()),
          width: 50,
          height: 50,
        ),
        maximumColorCount: 3,
        timeout: const Duration(seconds: 3),
      );
      if (mounted) {
        setState(() {
          _dominantColor = palette.dominantColor?.color;
          _vibrantColor = palette.vibrantColor?.color ?? palette.dominantColor?.color;
        });
        PaletteCache.update(item.id, _dominantColor, _vibrantColor);
      }
    } catch (e) {
      // ignore
    }
  }

  void _expandUpNextSheet() {
    if (!_upNextController.isAttached) return;
    _upNextController.animateTo(
      0.96,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLargeScreen = size.width > 800 && size.height > 600;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final screenWidth = size.width;
    final baseIconSize = screenWidth < 360
        ? 36.0
        : screenWidth < 400
        ? 40.0
        : 44.0;
    final miniIconSize = screenWidth < 360 ? 18.0 : 22.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _vibrantColor?.withValues(alpha: 0.3) ?? colorScheme.surface,
                    _dominantColor?.withValues(alpha: 0.5) ?? colorScheme.surface,
                    colorScheme.surface,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: StreamBuilder<MediaItem?>(
                initialData: audioHandler.mediaItem.value,
                stream: audioHandler.mediaItem,
                builder: (context, snapshot) {
                  if (snapshot.data == null || !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final metadata = snapshot.data!;
                    final blendedTop = _vibrantColor != null
                        ? Color.alphaBlend(
                            _vibrantColor!.withValues(alpha: 0.3),
                            colorScheme.surface,
                          )
                        : colorScheme.surface;
                    final blendedMid = _dominantColor != null
                        ? Color.alphaBlend(
                            _dominantColor!.withValues(alpha: 0.25),
                            colorScheme.surface,
                          )
                        : blendedTop;
                    final isDark =
                        ThemeData.estimateBrightnessForColor(blendedMid) ==
                            Brightness.dark;

                    final dynamicPrimaryColor =
                        _vibrantColor ?? _dominantColor ?? colorScheme.primary;
                    
                    // Create a completely new color scheme based on the background's brightness
                    // so text colors (onSurface) automatically contrast properly with the background!
                    final dynamicColorScheme = ColorScheme.fromSeed(
                      seedColor: dynamicPrimaryColor,
                      brightness: isDark ? Brightness.dark : Brightness.light,
                    );

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragEnd: (details) {
                        if (details.primaryVelocity != null) {
                          if (details.primaryVelocity! > 300) {
                            if (widget.onClose != null) {
                              widget.onClose!();
                            } else {
                              Navigator.pop(context);
                            }
                          } else if (details.primaryVelocity! < -300) {
                            _expandUpNextSheet();
                          }
                        }
                      },
                      child: Theme(
                        data: theme.copyWith(colorScheme: dynamicColorScheme),
                        child: Column(
                          children: [
                            _buildAppBar(context, dynamicColorScheme, metadata),
                            Expanded(
                              child: isLargeScreen
                                  ? _DesktopLayout(
                                      metadata: metadata,
                                      size: size,
                                      adjustedIconSize: baseIconSize,
                                      adjustedMiniIconSize: miniIconSize,
                                      lyricsController: _lyricsController,
                                      dominantColor: _dominantColor,
                                    )
                                  : _MobileLayout(
                                      metadata: metadata,
                                      size: size,
                                      adjustedIconSize: baseIconSize,
                                      adjustedMiniIconSize: miniIconSize,
                                      isLargeScreen: isLargeScreen,
                                      lyricsController: _lyricsController,
                                      dominantColor: _dominantColor,
                                      upNextController: _upNextController,
                                    ),
                            ),
                          ],
                        ),
                      ),
                    );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, ColorScheme colorScheme, MediaItem metadata) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            iconSize: 24,
            icon: const Icon(FluentIcons.chevron_down_24_regular),
            style: IconButton.styleFrom(
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(12),
            ),
            onPressed: widget.onClose ?? () => Navigator.pop(context),
          ),
          NowPlayingOptionsMenu(
            audioId: metadata.extras?['ytid'],
            metadata: metadata,
          ),
        ],
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.lyricsController,
    this.dominantColor,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final FlipCardController lyricsController;
  final Color? dominantColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Expanded(
                  flex: 5,
                  child: Center(
                    child: NowPlayingArtwork(
                      size: size,
                      metadata: metadata,
                      lyricsController: lyricsController,
                      dominantColor: dominantColor,
                    ),
                  ),
                ),
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    flex: 4,
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        const Expanded(child: QueueWidget()),
      ],
    );
  }
}

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.metadata,
    required this.size,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.isLargeScreen,
    required this.lyricsController,
    required this.upNextController,
    this.dominantColor,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final FlipCardController lyricsController;
  final DraggableScrollableController upNextController;
  final Color? dominantColor;

  @override
  Widget build(BuildContext context) {
    final isLandscape = size.width > size.height;

    if (isLandscape) {
      return _buildLandscapeLayout(context);
    }
    return _buildPortraitLayout(context);
  }

  Widget _buildPortraitLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const collapsedHeight = 176.0;
        final minSize = constraints.maxHeight > 0
            ? (collapsedHeight / constraints.maxHeight).clamp(0.20, 0.35)
            : 0.26;

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  NowPlayingArtwork(
                    size: size,
                    metadata: metadata,
                    lyricsController: lyricsController,
                    dominantColor: dominantColor,
                  ),
                  const SizedBox(height: 8),
                  if (!(metadata.extras?['isLive'] ?? false))
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: NowPlayingControls(
                        size: size,
                        audioId: metadata.extras?['ytid'],
                        adjustedIconSize: adjustedIconSize,
                        adjustedMiniIconSize: adjustedMiniIconSize,
                        metadata: metadata,
                      ),
                    ),
                  const Spacer(),
                ],
              ),
            ),
            _ExpandableUpNextSheet(
              controller: upNextController,
              minChildSize: minSize,
              metadata: metadata,
              dominantColor: dominantColor,
            ),
          ],
        );
      },
    );
  }

  Widget _buildLandscapeLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: NowPlayingArtwork(
                size: size,
                metadata: metadata,
                lyricsController: lyricsController,
                dominantColor: dominantColor,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 5,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!(metadata.extras?['isLive'] ?? false))
                  Expanded(
                    child: NowPlayingControls(
                      size: size,
                      audioId: metadata.extras?['ytid'],
                      adjustedIconSize: adjustedIconSize,
                      adjustedMiniIconSize: adjustedMiniIconSize,
                      metadata: metadata,
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandableUpNextSheet extends StatefulWidget {
  const _ExpandableUpNextSheet({
    required this.controller,
    required this.minChildSize,
    required this.metadata,
    this.dominantColor,
  });

  final DraggableScrollableController controller;
  final double minChildSize;
  final MediaItem metadata;
  final Color? dominantColor;

  @override
  State<_ExpandableUpNextSheet> createState() => _ExpandableUpNextSheetState();
}

class _ExpandableUpNextSheetState extends State<_ExpandableUpNextSheet> {
  static const double _maxChildSize = 0.96;
  late final ValueNotifier<double> _progressNotifier;
  final ValueNotifier<bool> _expandedNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _progressNotifier = ValueNotifier<double>(0.0);
  }

  @override
  void dispose() {
    _progressNotifier.dispose();
    _expandedNotifier.dispose();
    super.dispose();
  }

  void _toggleSheet() {
    if (!widget.controller.isAttached) return;
    final target = _expandedNotifier.value ? widget.minChildSize : _maxChildSize;
    widget.controller.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  String _formatItemSubtitle(MediaItem item) {
    final artist = (item.artist ?? '').trim();
    final seconds = item.duration?.inSeconds ?? 0;
    if (seconds > 0) {
      final durationText = formatDuration(seconds);
      return artist.isNotEmpty ? '$artist • $durationText' : durationText;
    }
    return artist;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sheetBg = Color.alphaBlend(
      (widget.dominantColor ?? colorScheme.primary).withValues(alpha: 0.16),
      colorScheme.surface,
    );

    return StreamBuilder<List<MediaItem>>(
      initialData: audioHandler.queue.value,
      stream: audioHandler.queue,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? const <MediaItem>[];
        final currentIndex = audioHandler.currentQueueIndex;
        final startIndex = currentIndex >= 0 ? currentIndex + 1 : 0;
        if (startIndex >= queue.length) return const SizedBox.shrink();

        final upcomingCount = queue.length - startIndex;

        return RepaintBoundary(
          child: NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              final progress = ((notification.extent - widget.minChildSize) / 0.25)
                  .clamp(0.0, 1.0);
              if ((_progressNotifier.value - progress).abs() > 0.005) {
                _progressNotifier.value = progress;
              }
              final expanded = notification.extent > widget.minChildSize + 0.08;
              if (_expandedNotifier.value != expanded) {
                _expandedNotifier.value = expanded;
              }
              return false;
            },
            child: DraggableScrollableSheet(
              controller: widget.controller,
              initialChildSize: widget.minChildSize,
              minChildSize: widget.minChildSize,
              maxChildSize: _maxChildSize,
              snap: true,
              snapSizes: [widget.minChildSize, _maxChildSize],
              builder: (context, scrollController) {
                final scrollable = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification ||
                          notification is ScrollEndNotification) {
                        final metrics = notification.metrics;
                        if (metrics.axis == Axis.vertical &&
                            metrics.maxScrollExtent > 0 &&
                            metrics.pixels >= metrics.maxScrollExtent - 180) {
                          unawaited(
                            audioHandler.loadMoreUpNextSongs(forceAppend: true),
                          );
                        }
                      }
                      return false;
                    },
                    child: CustomScrollView(
                      controller: scrollController,
                      physics: const ClampingScrollPhysics(),
                      slivers: [
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: _UpNextHeaderDelegate(
                            progressNotifier: _progressNotifier,
                            expandedNotifier: _expandedNotifier,
                            sheetBg: sheetBg,
                            metadata: widget.metadata,
                            onTap: _toggleSheet,
                            colorScheme: colorScheme,
                          ),
                        ),
                        SliverReorderableList(
                          itemCount: upcomingCount,
                          proxyDecorator: (child, index, animation) => Material(
                            elevation: 6,
                            color: colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            shadowColor: colorScheme.shadow.withValues(
                              alpha: 0.3,
                            ),
                            child: child,
                          ),
                          onReorder: (oldIndex, newIndex) {
                            if (oldIndex < 0 || oldIndex >= upcomingCount) {
                              return;
                            }
                            var adjustedNew = newIndex;
                            if (adjustedNew > oldIndex) adjustedNew -= 1;
                            if (adjustedNew < 0 ||
                                adjustedNew >= upcomingCount) {
                              return;
                            }
                            final movingItem = queue[startIndex + oldIndex];
                            final targetQueueIndex = startIndex + adjustedNew;
                            audioHandler.reorderQueueById(
                              movingItem.id,
                              targetQueueIndex,
                            );
                          },
                          itemBuilder: (context, index) {
                            final queueIndex = startIndex + index;
                            return _buildUpcomingTile(
                              context,
                              queue[queueIndex],
                              index,
                              queueIndex,
                              colorScheme,
                            );
                          },
                        ),
                        SliverToBoxAdapter(
                          child: ValueListenableBuilder<bool>(
                            valueListenable: audioHandler.isLoadingMoreUpNext,
                            builder: (context, isLoading, _) {
                              if (!isLoading) {
                                return const SizedBox(height: 16);
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );

                return ValueListenableBuilder<double>(
                  valueListenable: _progressNotifier,
                  child: scrollable,
                  builder: (context, progress, child) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          Colors.transparent,
                          sheetBg,
                          progress,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24 * progress),
                        ),
                      ),
                      child: child,
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpcomingTile(
    BuildContext context,
    MediaItem item,
    int localIndex,
    int queueIndex,
    ColorScheme colorScheme,
  ) {
    final artworkPath = item.extras?['artWorkPath']?.toString();
    final isLocal =
        item.artUri?.scheme == 'file' &&
        artworkPath != null &&
        artworkPath.isNotEmpty;
    final imageUrl =
        item.extras?['highResImage']?.toString() ??
        item.artUri?.toString() ??
        '';
    final subtitle = _formatItemSubtitle(item);

    return Material(
      key: ValueKey(item.id),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => audioHandler.skipToSong(queueIndex),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: isLocal
                    ? Image.file(
                        File(artworkPath),
                        width: 56,
                        height: 32,
                        fit: BoxFit.cover,
                      )
                    : imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 56,
                        height: 32,
                        fit: BoxFit.cover,
                        memCacheWidth: 168,
                      )
                    : Container(
                        width: 56,
                        height: 32,
                        color: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          FluentIcons.music_note_1_24_regular,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              ReorderableDragStartListener(
                index: localIndex,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Icon(
                    FluentIcons.re_order_24_regular,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpNextHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _UpNextHeaderDelegate({
    required this.progressNotifier,
    required this.expandedNotifier,
    required this.sheetBg,
    required this.metadata,
    required this.onTap,
    required this.colorScheme,
  });

  final ValueNotifier<double> progressNotifier;
  final ValueNotifier<bool> expandedNotifier;
  final Color sheetBg;
  final MediaItem metadata;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  @override
  double get minExtent => 40;

  @override
  double get maxExtent => 40;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final seconds = metadata.duration?.inSeconds ?? 0;
    final playingLabel = seconds > 0
        ? '${metadata.title} • ${formatDuration(seconds)}'
        : metadata.title;

    final headerBody = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Text(
              'UP NEXT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: expandedNotifier,
                builder: (context, isExpanded, _) {
                  return AnimatedOpacity(
                    opacity: isExpanded ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 150),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FluentIcons.music_note_2_24_regular,
                              size: 12,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                playingLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            ValueListenableBuilder<bool>(
              valueListenable: expandedNotifier,
              builder: (context, isExpanded, child) {
                return AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: child,
                );
              },
              child: Icon(
                FluentIcons.chevron_up_24_regular,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );

    return ValueListenableBuilder<double>(
      valueListenable: progressNotifier,
      child: headerBody,
      builder: (context, progress, child) {
        return Material(
          color: progress > 0.04
              ? Color.lerp(Colors.transparent, sheetBg, progress)
              : Colors.transparent,
          child: child,
        );
      },
    );
  }

  @override
  bool shouldRebuild(_UpNextHeaderDelegate oldDelegate) {
    return sheetBg != oldDelegate.sheetBg ||
        metadata.id != oldDelegate.metadata.id ||
        metadata.duration != oldDelegate.metadata.duration ||
        colorScheme != oldDelegate.colorScheme;
  }
}
