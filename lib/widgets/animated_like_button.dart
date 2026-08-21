import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/services/common_services.dart';

class AnimatedLikeButton extends StatefulWidget {
  final String audioId;
  final Map<String, dynamic> songData;
  final double size;

  const AnimatedLikeButton({
    super.key,
    required this.audioId,
    required this.songData,
    this.size = 28,
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton> with SingleTickerProviderStateMixin {
  late final ValueNotifier<bool> _songLikeStatus;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _songLikeStatus = ValueNotifier<bool>(isSongAlreadyLiked(widget.audioId));
    userLikedSongsList.addListener(_syncLikeStatus);
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOutBack)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 50),
    ]).animate(_controller);
  }

  void _syncLikeStatus() {
    final newStatus = isSongAlreadyLiked(widget.audioId);
    if (_songLikeStatus.value != newStatus) {
      _songLikeStatus.value = newStatus;
    }
  }

  @override
  void didUpdateWidget(AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioId != widget.audioId) {
      _songLikeStatus.value = isSongAlreadyLiked(widget.audioId);
    }
  }

  @override
  void dispose() {
    userLikedSongsList.removeListener(_syncLikeStatus);
    _songLikeStatus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _songLikeStatus,
      builder: (_, isActive, __) {
        return IconButton(
          icon: ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              isActive ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
              color: isActive ? Colors.redAccent : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          iconSize: widget.size,
          onPressed: () {
            if (!isActive) {
              _controller.forward(from: 0.0);
            }
            updateSongLikeStatus(
              widget.audioId,
              !_songLikeStatus.value,
              songData: widget.songData,
            );
            _songLikeStatus.value = !_songLikeStatus.value;
          },
        );
      },
    );
  }
}
