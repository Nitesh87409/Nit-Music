import 'package:flutter/material.dart';

class MarqueeWidget extends StatefulWidget {
  const MarqueeWidget({
    super.key,
    required this.child,
    this.direction = Axis.horizontal,
    this.animationDuration = const Duration(seconds: 9),
    this.backDuration = const Duration(seconds: 6),
    this.pauseDuration = const Duration(milliseconds: 1500),
    this.manualScrollEnabled = true,
  });

  final Widget child;
  final Axis direction;
  final Duration animationDuration, backDuration, pauseDuration;
  final bool manualScrollEnabled;

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  bool _isAnimating = false;
  bool _isDisposed = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: widget.direction,
        controller: _scrollController,
        physics: widget.manualScrollEnabled
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: widget.child,
      ),
    );
  }

  Future<void> _startAnimation() async {
    if (_isDisposed || _isAnimating) return;

    _isAnimating = true;

    while (_scrollController.hasClients && !_isDisposed) {
      try {
        final extent = _scrollController.position.maxScrollExtent;
        if (extent <= 0) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        final forwardMs = ((extent / 26.0) * 1000).round().clamp(
          widget.animationDuration.inMilliseconds,
          20000,
        );
        final backMs = ((extent / 35.0) * 1000).round().clamp(
          widget.backDuration.inMilliseconds,
          14000,
        );

        await Future.delayed(widget.pauseDuration);
        if (_isDisposed || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: forwardMs),
          curve: Curves.easeInOut,
        );

        await Future.delayed(widget.pauseDuration);
        if (_isDisposed || !_scrollController.hasClients) break;

        await _scrollController.animateTo(
          0,
          duration: Duration(milliseconds: backMs),
          curve: Curves.easeInOut,
        );
      } catch (e) {
        // Handle animation interruptions gracefully
        break;
      }
    }

    _isAnimating = false;
  }
}
