import 'package:flutter/material.dart';
import 'package:musify/widgets/mini_player.dart';
import 'package:musify/screens/now_playing_page.dart';

class SlidingPlayerOverlay extends StatefulWidget {
  final AnimationController animationController;
  final bool isVisible;
  final double bottomMargin;

  const SlidingPlayerOverlay({
    required this.animationController,
    required this.isVisible,
    this.bottomMargin = 0.0,
    super.key,
  });

  @override
  State<SlidingPlayerOverlay> createState() => _SlidingPlayerOverlayState();
}

class _SlidingPlayerOverlayState extends State<SlidingPlayerOverlay> {
  final double _miniPlayerHeight = 72.0 + 8.0; // Height + Bottom Margin

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!widget.isVisible) return;

    final double screenHeight = MediaQuery.of(context).size.height;
    widget.animationController.value -= details.primaryDelta! / screenHeight;
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!widget.isVisible) return;

    final double velocity = details.primaryVelocity ?? 0.0;

    if (velocity < -500) {
      widget.animationController.animateTo(1.0, curve: Curves.easeOutCubic);
    } else if (velocity > 500) {
      widget.animationController.animateTo(0.0, curve: Curves.easeOutCubic);
    } else {
      if (widget.animationController.value > 0.5) {
        widget.animationController.animateTo(1.0, curve: Curves.easeOutCubic);
      } else {
        widget.animationController.animateTo(0.0, curve: Curves.easeOutCubic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible && widget.animationController.isDismissed) {
      return const SizedBox.shrink();
    }

    final screenHeight = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: widget.animationController,
      builder: (context, child) {
        final progress = widget.animationController.value;

        return PopScope(
          canPop: progress == 0.0,
          onPopInvoked: (didPop) {
            if (didPop) return;
            if (progress > 0.0) {
              widget.animationController.animateTo(
                0.0,
                curve: Curves.easeOutCubic,
              );
            }
          },
          child: SizedBox(
            width: double.infinity,
            height: screenHeight,
            child: GestureDetector(
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              child: Stack(
                children: [
                  // Collapsed Mini Player (Stays at the bottom, fades out quickly as we slide up)
                  if (progress < 1.0)
                    Positioned(
                      left: 8.0,
                      right: 8.0,
                      bottom: widget.bottomMargin + 8.0, // A slight margin
                      child: Opacity(
                        opacity: (1.0 - (progress * 2)).clamp(0.0, 1.0),
                        child: MiniPlayer(
                          onTap: () {
                            widget.animationController.animateTo(
                              1.0,
                              curve: Curves.easeOutCubic,
                            );
                          },
                        ),
                      ),
                    ),

                  // Expanded Player (Now Playing Page)
                  // Slides up gracefully from the bottom
                  if (progress > 0.0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: screenHeight,
                      child: Transform.translate(
                        offset: Offset(0, (1.0 - progress) * screenHeight),
                        child: Container(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: NowPlayingPage(
                            isOverlay: true,
                            onClose: () {
                              widget.animationController.animateTo(
                                0.0,
                                curve: Curves.easeOutCubic,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}