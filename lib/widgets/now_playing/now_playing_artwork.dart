import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_flip_card/flutter_flip_card.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/widgets/song_artwork.dart';
import 'package:musify/widgets/synced_lyrics_widget.dart';
import 'package:musify/main.dart';

class NowPlayingArtwork extends StatelessWidget {
  const NowPlayingArtwork({
    super.key,
    required this.size,
    required this.metadata,
    required this.lyricsController,
  });
  final Size size;
  final MediaItem metadata;
  final FlipCardController lyricsController;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = size.width;
    final screenHeight = size.height;
    final isLandscape = screenWidth > screenHeight;
    final isDesktop = screenWidth > 800;
    final imageSize = isDesktop
        ? screenHeight * 0.38
        : isLandscape
        ? screenHeight * 0.45
        : screenWidth < 360
        ? screenWidth * 0.75
        : screenWidth < 600
        ? screenWidth * 0.80
        : screenWidth * 0.65;

    const borderRadius = 24.0;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! < 0) {
            audioHandler.skipToNext();
          } else if (details.primaryVelocity! > 0) {
            audioHandler.skipToPrevious();
          }
        }
      },
      child: FlipCard(
        rotateSide: RotateSide.right,
        onTapFlipping: !offlineMode.value,
        controller: lyricsController,
        frontWidget: Hero(
          tag: 'now_playing_artwork',
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                  blurRadius: 40,
                  offset: const Offset(0, 4),
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: SongArtworkWidget(
                metadata: metadata,
                size: imageSize,
                errorWidgetIconSize: size.width / 8,
                borderRadius: borderRadius,
              ),
            ),
          ),
        ),
      backWidget: Container(
        width: imageSize,
        height: imageSize,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 4),
              spreadRadius: 4,
            ),
          ],
        ),
        child: SyncedLyricsWidget(
          positionDataStream: audioHandler.positionDataStream,
          trackName: metadata.title,
          artistName: metadata.artist,
          duration: metadata.duration,
          width: imageSize,
          height: imageSize,
          onSeek: (position) {
            audioHandler.seek(position);
          },
        ),
        ),
      ),
    );
  }
}
