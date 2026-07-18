import 'package:flutter/material.dart';
import 'package:musify/models/position_data.dart';
import 'package:musify/services/lyrics_service.dart';

class LyricsSheet extends StatefulWidget {
  final Stream<PositionData> positionDataStream;
  final String trackName;
  final String? artistName;
  final Duration? duration;
  final void Function(Duration) onSeek;
  final Color dominantColor;

  const LyricsSheet({
    super.key,
    required this.positionDataStream,
    required this.trackName,
    this.artistName,
    this.duration,
    required this.onSeek,
    required this.dominantColor,
  });

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
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

  Future<void> _fetchLyrics() async {
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
          // Fake LRC with just plain text for display if no synced lyrics
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

    // Estimate item height = 60
    final targetOffset = (index * 60.0) - (MediaQuery.sizeOf(context).height * 0.3);
    
    _scrollController.animateTo(
      targetOffset > 0 ? targetOffset : 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.dominantColor.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                      )
                    : StreamBuilder<PositionData>(
                        stream: widget.positionDataStream,
                        builder: (context, snapshot) {
                          final currentPosition = snapshot.data?.position ?? Duration.zero;

                          // Find current line index (for synced lyrics)
                          int newIndex = -1;
                          if (_lyrics != null && _lyrics!.isNotEmpty && _lyrics!.first.time != Duration.zero) {
                            for (int i = 0; i < _lyrics!.length; i++) {
                              if (_lyrics![i].time > currentPosition) {
                                break;
                              }
                              newIndex = i;
                            }
                            
                            // Auto scroll if index changed
                            if (newIndex != _currentIndex && newIndex != -1) {
                              _currentIndex = newIndex;
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _scrollToCurrentLine(newIndex);
                              });
                            }
                          }

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
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
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    line.text,
                                    style: TextStyle(
                                      fontSize: isCurrent ? 28 : 24,
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                      color: isCurrent 
                                          ? Colors.white 
                                          : Colors.white.withValues(alpha: 0.4),
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
