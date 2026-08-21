import 'dart:math' as math;
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/main.dart';
import 'package:musify/utilities/palette_cache.dart';

import 'package:musify/models/full_player_state.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/screens/now_playing_page.dart';
import 'package:musify/widgets/marquee.dart';
import 'package:musify/widgets/song_artwork.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:rxdart/rxdart.dart';

final Stream<FullPlayerState> _fullPlayerStateStream =
    Rx.combineLatest3(
          audioHandler.playbackStateStream,
          audioHandler.queue.distinct(),
          audioHandler.positionDataStream,
          (PlaybackState state, List<MediaItem> queue, PositionData pos) =>
              FullPlayerState(
                playbackState: state,
                queue: queue,
                position: pos,
              ),
        )
        .throttleTime(const Duration(milliseconds: 120), trailing: true)
        .asBroadcastStream();

class MiniPlayer extends StatelessWidget {
  final VoidCallback? onTap;

  const MiniPlayer({this.onTap, super.key});

  static const double playerHeight = 72;
  static const double _borderRadius = 16;
  static const double _artworkSize = 52;
  static const double _artworkRadius = 14;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: StreamBuilder<MediaItem?>(
        stream: audioHandler.mediaItem,
        builder: (context, mediaSnapshot) {
          final metadata = mediaSnapshot.data;
          if (metadata == null) return const SizedBox.shrink();

          return StreamBuilder<FullPlayerState>(
            stream: _fullPlayerStateStream,
            builder: (context, stateSnapshot) {
              final state = stateSnapshot.data;
              if (state == null) return const SizedBox.shrink();

              final hasNext =
                  state.queue.length > 1 &&
                  (state.playbackState.queueIndex ?? 0) <
                      state.queue.length - 1;

                final hasPrevious = (state.playbackState.queueIndex ?? 0) > 0;

              return _MiniPlayerBody(
                onTap: onTap,
                colorScheme: colorScheme,
                metadata: metadata,
                state: state,
                hasPrevious: hasPrevious,
                hasNext: hasNext,
              );
            },
          );
        },
      ),
    );
  }
}

class _MiniPlayerBody extends StatefulWidget {
  const _MiniPlayerBody({
    this.onTap,
    required this.colorScheme,
    required this.metadata,
    required this.state,
    required this.hasPrevious,
    required this.hasNext,
  });

  final VoidCallback? onTap;
  final ColorScheme colorScheme;
  final MediaItem metadata;
  final FullPlayerState state;
  final bool hasPrevious;
  final bool hasNext;

  @override
  State<_MiniPlayerBody> createState() => _MiniPlayerBodyState();
}

class _MiniPlayerBodyState extends State<_MiniPlayerBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _updatePaletteIfNeeded();
  }

  Color? _dominantColor;
  Color? _vibrantColor;
  bool _isDismissed = false;
  Offset _slideOffset = Offset.zero;

  @override
  void didUpdateWidget(covariant _MiniPlayerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.metadata.id != oldWidget.metadata.id) {
      _updatePaletteIfNeeded();
      _isDismissed = false;
      _slideOffset = Offset.zero;
    }
    if (widget.state.playbackState.playing && !oldWidget.state.playbackState.playing) {
      _isDismissed = false;
      _slideOffset = Offset.zero;
    }
  }

  Future<void> _updatePaletteIfNeeded() async {
    final item = widget.metadata;
    if (item.artUri == null) return;
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        ResizeImage(
          NetworkImage(item.artUri!.toString()),
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  static const double _dragThresholdForNavigation = 10;

  void _handleVerticalDrag(DragUpdateDetails details) {
    if ((details.primaryDelta ?? 0) < -_dragThresholdForNavigation) {
      if (widget.onTap != null) {
        widget.onTap!();
      } else {
        _navigateToNowPlaying();
      }
    } else if ((details.primaryDelta ?? 0) > _dragThresholdForNavigation) {
      setState(() => _slideOffset = const Offset(0, 1.5));
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _isDismissed = true);
        audioHandler.stop();
      });
    }
  }

  void _navigateToNowPlaying() {
    Navigator.of(context).push(_createSlideTransition());
  }

  PageRoute<void> _createSlideTransition() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, _) => const NowPlayingPage(),
      transitionDuration: const Duration(milliseconds: 400),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ));
        return SlideTransition(position: slideAnimation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed) return const SizedBox.shrink();

    final defaultColorScheme = widget.colorScheme;
    final metadata = widget.metadata;
    final state = widget.state;

    final backgroundColor = _vibrantColor ?? _dominantColor ?? defaultColorScheme.surfaceContainerHighest;
    final isDark = ThemeData.estimateBrightnessForColor(backgroundColor) == Brightness.dark;
    
    final colorScheme = defaultColorScheme.copyWith(
      secondary: Colors.white,
      onSurfaceVariant: Colors.white70,
      onSurface: Colors.white,
      primary: _vibrantColor ?? _dominantColor ?? defaultColorScheme.primary,
    );

    final totalDuration = state.position.duration > Duration.zero
        ? state.position.duration
        : (metadata.duration ?? Duration.zero);
    final progress = totalDuration.inMilliseconds == 0
        ? 0.0
        : (state.position.position.inMilliseconds /
                  totalDuration.inMilliseconds)
              .clamp(0.0, 1.0);

    return AnimatedSlide(
      offset: _slideOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInCubic,
      child: Dismissible(
        key: const Key('mini_player_dismiss'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) {
          setState(() => _isDismissed = true);
          audioHandler.stop();
        },
        child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: (_) => _animationController.forward(),
            onTapUp: (_) => _animationController.reverse(),
            onTapCancel: () => _animationController.reverse(),
            onVerticalDragUpdate: _handleVerticalDrag,
            onTap: () {
              if (widget.onTap != null) {
                widget.onTap!();
              } else {
                _navigateToNowPlaying();
              }
            },
            child: SizedBox(
              height: MiniPlayer.playerHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: backgroundColor, // Use dynamic color
                  borderRadius: BorderRadius.circular(MiniPlayer._borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      _ArtworkWidget(metadata: metadata),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: KeyedSubtree(
                            key: ValueKey(metadata.id),
                            child: Hero(
                              tag: 'now_playing_title',
                              child: Material(
                                type: MaterialType.transparency,
                                child: _MetadataAndProgressWidget(
                                  title: metadata.title,
                                  artist: metadata.artist,
                                  colorScheme: colorScheme,
                                  position: state.position.position,
                                  duration: totalDuration,
                                  progress: progress,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _ControlsWidget(
                        colorScheme: colorScheme,
                        playbackState: state.playbackState,
                        hasPrevious: widget.hasPrevious,
                        hasNext: widget.hasNext,
                        progress: progress,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    )));
  }
}

class _ArtworkWidget extends StatelessWidget {
  const _ArtworkWidget({required this.metadata});
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Hero(
        tag: 'now_playing_artwork',
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MiniPlayer._artworkRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(MiniPlayer._artworkRadius),
            child: SongArtworkWidget(
              metadata: metadata,
              size: MiniPlayer._artworkSize,
              errorWidgetIconSize: 24,
              borderRadius: MiniPlayer._artworkRadius,
            ),
          ),
        ),
      ),
    );
  }
}

class _MetadataAndProgressWidget extends StatelessWidget {
  const _MetadataAndProgressWidget({
    required this.title,
    required this.artist,
    required this.colorScheme,
    required this.position,
    required this.duration,
    required this.progress,
  });

  final String title;
  final String? artist;
  final ColorScheme colorScheme;
  final Duration position;
  final Duration duration;
  final double progress;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarqueeWidget(
            manualScrollEnabled: false,
            animationDuration: const Duration(seconds: 8),
            backDuration: const Duration(seconds: 2),
            pauseDuration: const Duration(seconds: 2),
            child: Text(
              title,
              style: TextStyle(
                color: colorScheme.secondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (artist != null && artist!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              artist!,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _formatDuration(position),
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1.5),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _formatDuration(duration),
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlsWidget extends StatelessWidget {
  const _ControlsWidget({
    required this.colorScheme,
    required this.playbackState,
    required this.hasPrevious,
    required this.hasNext,
    required this.progress,
  });

  final ColorScheme colorScheme;
  final PlaybackState playbackState;
  final bool hasPrevious;
  final bool hasNext;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircularPlayButton(
          colorScheme: colorScheme,
          playbackState: playbackState,
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 24, color: Colors.white24),
        const SizedBox(width: 4),
        IconButton(
          onPressed: audioHandler.skipToNext,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          icon: Icon(
            FluentIcons.next_24_filled,
            color: colorScheme.secondary,
            size: 24,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _CircularPlayButton extends StatelessWidget {
  const _CircularPlayButton({
    required this.colorScheme,
    required this.playbackState,
  });

  final ColorScheme colorScheme;
  final PlaybackState playbackState;

  @override
  Widget build(BuildContext context) {
    final processingState = playbackState.processingState;
    final isPlaying = playbackState.playing;
    final isLoading =
        processingState == AudioProcessingState.loading ||
        processingState == AudioProcessingState.buffering;
    final isCompleted = processingState == AudioProcessingState.completed;

    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(48, 48),
            painter: _DashedCirclePainter(
              color: Colors.white30,
            ),
          ),
          if (isLoading)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.secondary),
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: IconButton(
                onPressed: isCompleted
                    ? () => audioHandler.playAgain()
                    : (isPlaying ? audioHandler.pause : audioHandler.play),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                icon: Icon(
                  isCompleted
                      ? FluentIcons.arrow_counterclockwise_24_filled
                      : (isPlaying
                            ? FluentIcons.pause_16_filled
                            : FluentIcons.play_16_filled),
                  color: Colors.white,
                  size: 16,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = (size.width - 2) / 2;
    final dashCount = 36;
    final dashLength = 2.0;
    final gapLength = (2 * math.pi * radius) / dashCount - dashLength;

    double currentAngle = 0;
    for (int i = 0; i < dashCount; i++) {
      final startX = cx + radius * math.cos(currentAngle);
      final startY = cy + radius * math.sin(currentAngle);
      
      final endAngle = currentAngle + (dashLength / radius);
      final endX = cx + radius * math.cos(endAngle);
      final endY = cy + radius * math.sin(endAngle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
      
      currentAngle = endAngle + (gapLength / radius);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}
