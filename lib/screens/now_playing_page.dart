import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:musify/main.dart';
import 'package:musify/utilities/palette_cache.dart';

import 'package:musify/widgets/now_playing/now_playing_options_menu.dart';
import 'package:musify/widgets/now_playing/now_playing_artwork.dart';
import 'package:musify/widgets/now_playing/now_playing_controls.dart';
import 'package:musify/widgets/queue_list_view.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';

import 'dart:async';
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
  StreamSubscription? _mediaItemSub;
  Color? _dominantColor;
  Color? _vibrantColor;

  @override
  void initState() {
    super.initState();
    _dominantColor = widget.initialDominantColor;
    _vibrantColor = widget.initialVibrantColor;

    final currentItem = audioHandler.mediaItem.value;
    if (currentItem != null && PaletteCache.hasColorsFor(currentItem.id)) {
      _dominantColor ??= PaletteCache.dominantColor;
      _vibrantColor ??= PaletteCache.vibrantColor;
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
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _updatePalette(item);
        });
      }
    });
  }

  @override
  void dispose() {
    _mediaItemSub?.cancel();
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
                    final backgroundColor = _vibrantColor ?? _dominantColor ?? colorScheme.surface;
                    final isDark = ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;
                    
                    final dynamicPrimaryColor = _vibrantColor ?? _dominantColor ?? colorScheme.primary;
                    
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
                            showCustomBottomSheet(
                              context,
                              Theme(
                                data: theme.copyWith(colorScheme: dynamicColorScheme),
                                child: const QueueWidget(isBottomSheet: true),
                              ),
                              backgroundColor: dynamicPrimaryColor.withValues(alpha: 0.15),
                              useScrollView: false,
                            );
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
    this.dominantColor,
  });
  final MediaItem metadata;
  final Size size;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final bool isLargeScreen;
  final FlipCardController lyricsController;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 8),
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
