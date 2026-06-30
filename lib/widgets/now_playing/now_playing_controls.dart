import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/widgets/now_playing/marquee_text_widget.dart';
import 'package:musify/widgets/playback_icon_button.dart';
import 'package:musify/widgets/position_slider.dart';

class NowPlayingControls extends StatelessWidget {
  const NowPlayingControls({
    super.key,
    required this.size,
    required this.audioId,
    required this.adjustedIconSize,
    required this.adjustedMiniIconSize,
    required this.metadata,
  });

  final Size size;
  final dynamic audioId;
  final double adjustedIconSize;
  final double adjustedMiniIconSize;
  final MediaItem metadata;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = size.width > 800;

    final titleFontSize = getResponsiveTitleFontSize(size);
    final artistFontSize = getResponsiveArtistFontSize(size);
    final canOpenArtist = _canOpenArtist(metadata);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 280;
        final isVeryCompact = availableHeight < 200;

        final spacing = isVeryCompact
            ? 2.0
            : isCompact
            ? 4.0
            : 8.0;
        final iconScale = isVeryCompact
            ? 0.65
            : isCompact
            ? 0.75
            : 1.0;
        final fontScale = isCompact ? 0.9 : 1.0;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCompact) const Spacer(),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 24,
                vertical: spacing,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        MarqueeTextWidget(
                          text: metadata.title,
                          fontColor: Colors.white,
                          fontSize: titleFontSize * fontScale,
                          fontWeight: FontWeight.bold,
                        ),
                        SizedBox(height: spacing),
                        if (metadata.artist != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: canOpenArtist
                                ? () => _openArtistPage(context, metadata)
                                : null,
                            child: MarqueeTextWidget(
                              text: metadata.artist!,
                              fontColor: const Color(0xFF8B5CF6),
                              fontSize: artistFontSize * fontScale,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _LikeButton(audioId: audioId, metadata: metadata),
                ],
              ),
            ),
            if (!isCompact) const Spacer(),
            if (!isCompact) const _StaticWaveform(),
            if (!isCompact) const SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 400 : constraints.maxWidth,
              ),
              child: const PositionSlider(),
            ),
            SizedBox(height: spacing),
            PlayerControlButtons(
              metadata: metadata,
              iconSize: adjustedIconSize * iconScale,
              miniIconSize: adjustedMiniIconSize * iconScale,
            ),
            if (!isCompact) const Spacer(),
          ],
        );
      },
    );
  }

  bool _canOpenArtist(MediaItem metadata) {
    final artist = metadata.artist?.trim() ?? '';
    final artistId = metadata.extras?['artistId']?.toString().trim() ?? '';
    final sourceSongId = metadata.extras?['ytid']?.toString().trim() ?? '';

    return !offlineMode.value &&
        (artist.isNotEmpty || artistId.isNotEmpty || sourceSongId.isNotEmpty);
  }

  void _openArtistPage(BuildContext context, MediaItem metadata) {
    final artist = metadata.artist?.trim() ?? '';
    final artistId = metadata.extras?['artistId']?.toString().trim() ?? '';
    final sourceSongId = metadata.extras?['ytid']?.toString().trim() ?? '';
    final videoAuthor =
        metadata.extras?['videoAuthor']?.toString().trim() ?? '';
    final lookup = artistId.isNotEmpty
        ? artistId
        : artist.isNotEmpty
        ? artist
        : sourceSongId;

    if (lookup.isEmpty) return;

    final router = GoRouter.of(context);
    final basePath = _artistRouteBasePath(context);
    final artistData = {
      'ytid': artistId.isNotEmpty ? artistId : lookup,
      if (artist.isNotEmpty) 'title': artist,
      if (sourceSongId.isNotEmpty) 'sourceSongId': sourceSongId,
      if (videoAuthor.isNotEmpty) 'videoAuthor': videoAuthor,
      'source': 'youtube-artist',
      'isArtist': true,
      'list': [],
    };

    Navigator.of(context).pop();
    unawaited(
      router.push(
        '$basePath/artist/${Uri.encodeComponent(lookup)}',
        extra: artistData,
      ),
    );
  }

  String _artistRouteBasePath(BuildContext context) {
    try {
      final currentPath = GoRouterState.of(context).uri.path;
      if (currentPath.startsWith(NavigationManager.searchPath)) {
        return NavigationManager.searchPath;
      }
      if (currentPath.startsWith(NavigationManager.libraryPath)) {
        return NavigationManager.libraryPath;
      }
    } catch (_) {}

    return NavigationManager.homePath;
  }
}

class PlayerControlButtons extends StatelessWidget {
  const PlayerControlButtons({
    super.key,
    required this.metadata,
    required this.iconSize,
    required this.miniIconSize,
  });
  final MediaItem metadata;
  final double iconSize;
  final double miniIconSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final responsiveIconSize = screenWidth < 360 ? iconSize * 0.85 : iconSize;
    final responsiveMiniIconSize = screenWidth < 360
        ? miniIconSize * 0.85
        : miniIconSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final isTight = maxWidth < 360;
        final isUltraTight = maxWidth < 320;

        final horizontalPadding = isUltraTight
            ? 10.0
            : isTight
            ? 14.0
            : 20.0;
        final buttonSpacing = isUltraTight
            ? 6.0
            : isTight
            ? 10.0
            : screenWidth < 360
            ? 8.0
            : 16.0;
        final minButtonSize = isUltraTight
            ? 38.0
            : isTight
            ? 42.0
            : 46.0;
        final buttonPadding = EdgeInsets.all(
          isUltraTight
              ? 6.0
              : isTight
              ? 8.0
              : 10.0,
        );

        final buttonConstraints = BoxConstraints(
          minWidth: minButtonSize,
          minHeight: minButtonSize,
        );

        final controlIconSize =
            responsiveIconSize *
            (isUltraTight
                ? 0.75
                : isTight
                ? 0.85
                : 0.92);
        final miniControlSize =
            responsiveMiniIconSize *
            (isUltraTight
                ? 0.8
                : isTight
                ? 0.9
                : 1.0);
        final playPadding = EdgeInsets.all(
          responsiveIconSize *
              (isUltraTight
                  ? 0.30
                  : isTight
                  ? 0.36
                  : 0.45),
        );

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Row(
            children: <Widget>[
              _buildShuffleButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
              SizedBox(width: buttonSpacing),
              Expanded(
                child: Center(
                  child: StreamBuilder<List<MediaItem>>(
                    stream: audioHandler.queue,
                    builder: (context, snapshot) {
                      return ValueListenableBuilder<AudioServiceRepeatMode>(
                        valueListenable: repeatNotifier,
                        builder: (_, repeatMode, __) {
                          return FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    FluentIcons.previous_24_regular,
                                    color: audioHandler.hasPrevious
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface.withValues(
                                            alpha: 0.3,
                                          ),
                                  ),
                                  tooltip: context.l10n!.skipToPrevious,
                                  constraints: buttonConstraints,
                                  iconSize: controlIconSize * 0.65,
                                  onPressed: audioHandler.hasPrevious
                                      ? () => audioHandler.skipToPrevious()
                                      : null,
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E1E2A),
                                    disabledBackgroundColor: const Color(0xFF1E1E2A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: buttonPadding,
                                    minimumSize: Size(
                                      minButtonSize,
                                      minButtonSize,
                                    ),
                                  ),
                                ),
                                SizedBox(width: buttonSpacing),
                                PlaybackIconButton(
                                  iconColor: colorScheme.onPrimary,
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  iconSize: controlIconSize,
                                  padding: playPadding,
                                ),
                                SizedBox(width: buttonSpacing),
                                IconButton(
                                  icon: Icon(
                                    FluentIcons.next_24_regular,
                                    color: audioHandler.hasNext
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurface.withValues(
                                            alpha: 0.3,
                                          ),
                                  ),
                                  tooltip: context.l10n!.skipToNext,
                                  constraints: buttonConstraints,
                                  iconSize: controlIconSize * 0.65,
                                  onPressed: () =>
                                      repeatNotifier.value ==
                                          AudioServiceRepeatMode.one
                                      ? audioHandler.playAgain()
                                      : audioHandler.skipToNext(),
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E1E2A),
                                    disabledBackgroundColor: const Color(0xFF1E1E2A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: buttonPadding,
                                    minimumSize: Size(
                                      minButtonSize,
                                      minButtonSize,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              SizedBox(width: buttonSpacing),
              _buildRepeatButton(
                context,
                colorScheme,
                miniControlSize,
                buttonConstraints,
                buttonPadding,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShuffleButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: shuffleNotifier,
      builder: (_, value, __) {
        return IconButton(
          icon: Icon(
            value
                ? FluentIcons.arrow_shuffle_24_filled
                : FluentIcons.arrow_shuffle_off_24_regular,
            color: value ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          ),
          tooltip: context.l10n!.shuffle,
          iconSize: size,
          constraints: buttonConstraints,
          padding: buttonPadding,
          style: IconButton.styleFrom(
            backgroundColor: value
                ? const Color(0xFF8B5CF6)
                : const Color(0xFF1E1E2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            audioHandler.setShuffleMode(
              value
                  ? AudioServiceShuffleMode.none
                  : AudioServiceShuffleMode.all,
            );
          },
        );
      },
    );
  }

  Widget _buildRepeatButton(
    BuildContext context,
    ColorScheme colorScheme,
    double size,
    BoxConstraints buttonConstraints,
    EdgeInsets buttonPadding,
  ) {
    return StreamBuilder<List<MediaItem>>(
      stream: audioHandler.queue,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? [];
        return ValueListenableBuilder<AudioServiceRepeatMode>(
          valueListenable: repeatNotifier,
          builder: (_, repeatMode, __) {
            final isActive = repeatMode != AudioServiceRepeatMode.none;

            return IconButton(
              icon: Icon(
                repeatMode == AudioServiceRepeatMode.one
                    ? FluentIcons.arrow_repeat_1_24_filled
                    : isActive
                    ? FluentIcons.arrow_repeat_all_24_filled
                    : FluentIcons.arrow_repeat_all_off_24_regular,
                color: isActive
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              tooltip: context.l10n!.repeat,
              iconSize: size,
              constraints: buttonConstraints,
              padding: buttonPadding,
              style: IconButton.styleFrom(
                backgroundColor: isActive
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF1E1E2A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                final AudioServiceRepeatMode newMode;
                if (repeatMode == AudioServiceRepeatMode.none) {
                  newMode = queue.length <= 1
                      ? AudioServiceRepeatMode.one
                      : AudioServiceRepeatMode.all;
                } else if (repeatMode == AudioServiceRepeatMode.all) {
                  newMode = AudioServiceRepeatMode.one;
                } else {
                  newMode = AudioServiceRepeatMode.none;
                }
                repeatNotifier.value = newMode;
                audioHandler.setRepeatMode(newMode);
              },
            );
          },
        );
      },
    );
  }
}

class _StaticWaveform extends StatelessWidget {
  const _StaticWaveform();

  @override
  Widget build(BuildContext context) {
    final heights = [5.0, 10.0, 15.0, 25.0, 15.0, 20.0, 35.0, 25.0, 45.0, 30.0, 20.0, 10.0, 15.0, 25.0, 35.0, 25.0, 15.0, 30.0, 20.0, 15.0, 10.0, 5.0];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: heights.map((h) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 3,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }).toList(),
    );
  }
}

class _LikeButton extends StatefulWidget {
  const _LikeButton({required this.audioId, required this.metadata});
  final dynamic audioId;
  final MediaItem metadata;

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton> {
  late final ValueNotifier<bool> _songLikeStatus;

  @override
  void initState() {
    super.initState();
    _songLikeStatus = ValueNotifier<bool>(isSongAlreadyLiked(widget.audioId));
    userLikedSongsList.addListener(_syncLikeStatus);
  }

  void _syncLikeStatus() {
    final newStatus = isSongAlreadyLiked(widget.audioId);
    if (_songLikeStatus.value != newStatus) {
      _songLikeStatus.value = newStatus;
    }
  }

  @override
  void didUpdateWidget(_LikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioId != widget.audioId) {
      _songLikeStatus.value = isSongAlreadyLiked(widget.audioId);
    }
  }

  @override
  void dispose() {
    userLikedSongsList.removeListener(_syncLikeStatus);
    _songLikeStatus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _songLikeStatus,
      builder: (_, isActive, __) {
        return IconButton(
          icon: Icon(
            isActive ? FluentIcons.heart_24_filled : FluentIcons.heart_24_regular,
            color: isActive ? const Color(0xFF8B5CF6) : Colors.white70,
          ),
          iconSize: 28,
          onPressed: () {
            updateSongLikeStatus(
              widget.audioId,
              !_songLikeStatus.value,
              songData: mediaItemToMap(widget.metadata),
            );
            _songLikeStatus.value = !_songLikeStatus.value;
          },
        );
      },
    );
  }
}
