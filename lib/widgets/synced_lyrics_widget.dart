import 'package:flutter/material.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/lyrics_service.dart';

class SyncedLyricsWidget extends StatefulWidget {
  final Stream<PositionData> positionDataStream;
  final String trackName;
  final String? artistName;
  final Duration? duration;
  final void Function(Duration) onSeek;
  final double width;
  final double height;

  const SyncedLyricsWidget({
    super.key,
    required this.positionDataStream,
    required this.trackName,
    this.artistName,
    this.duration,
    required this.onSeek,
    required this.width,
    required this.height,
  });

  @override
  State<SyncedLyricsWidget> createState() => _SyncedLyricsWidgetState();
}

class _SyncedLyricsWidgetState extends State<SyncedLyricsWidget> {
  bool _isLoading = true;
  String? _error;
  List<LrcLine>? _lyrics;
  final ScrollController _scrollController = ScrollController();
  int _currentIndex = -1;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  @override
  void didUpdateWidget(covariant SyncedLyricsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackName != widget.trackName) {
      _fetchLyrics();
    }
  }

  Future<void> _fetchLyrics() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _lyrics = null;
      _currentIndex = -1;
    });
    
    final result = await LyricsService.fetchLyrics(
      trackName: widget.trackName,
      artistName: widget.artistName,
      duration: widget.duration,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result != null && result['syncedLyrics'] != null) {
          _lyrics = parseLrc(result['syncedLyrics'] as String);
        } else if (result != null && result['plainLyrics'] != null) {
          _lyrics = (result['plainLyrics'] as String)
              .split('\n')
              .map((e) => LrcLine(Duration.zero, e))
              .toList();
        } else {
          _error = "Lyrics not found";
        }
      });
    }
  }

  void _scrollToCurrentLine(int index) {
    if (index < 0 || index >= (_lyrics?.length ?? 0)) return;
    if (!_scrollController.hasClients) return;

    // Center the current line
    final targetOffset = (index * 40.0) - (widget.height / 2) + 20;
    
    _scrollController.animateTo(
      targetOffset > 0 ? targetOffset : 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(fontSize: 16),
        ),
      );
    }
    
    if (_lyrics == null || _lyrics!.isEmpty) {
      return const Center(child: Text("No lyrics"));
    }

    return StreamBuilder<PositionData>(
      stream: widget.positionDataStream,
      builder: (context, snapshot) {
        final currentPosition = snapshot.data?.position ?? Duration.zero;

        int newIndex = -1;
        if (_lyrics!.first.time != Duration.zero) {
          for (int i = 0; i < _lyrics!.length; i++) {
            if (_lyrics![i].time > currentPosition) {
              break;
            }
            newIndex = i;
          }
          
          if (newIndex != _currentIndex && newIndex != -1) {
            _currentIndex = newIndex;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToCurrentLine(newIndex);
            });
          }
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          itemCount: _lyrics!.length,
          itemBuilder: (context, index) {
            final line = _lyrics![index];
            final isCurrent = index == _currentIndex;
            final isSynced = _lyrics!.first.time != Duration.zero;
            
            return GestureDetector(
              onTap: () {
                if (isSynced) {
                  widget.onSeek(line.time);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  line.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isCurrent ? 20 : 16,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    color: isCurrent 
                        ? Theme.of(context).colorScheme.primary 
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
