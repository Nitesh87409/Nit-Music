import 'package:audio_service/audio_service.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/mediaitem.dart';
import 'package:musify/utilities/playlist_dialogs.dart';

class NowPlayingOptionsMenu extends StatefulWidget {
  const NowPlayingOptionsMenu({
    super.key,
    required this.audioId,
    required this.metadata,
  });
  final dynamic audioId;
  final MediaItem metadata;

  @override
  State<NowPlayingOptionsMenu> createState() => _NowPlayingOptionsMenuState();
}

class _NowPlayingOptionsMenuState extends State<NowPlayingOptionsMenu> {
  late final ValueNotifier<bool> _songOfflineStatus;

  @override
  void initState() {
    super.initState();
    _songOfflineStatus = ValueNotifier<bool>(isSongAlreadyOffline(widget.audioId));
    userOfflineSongs.addListener(_syncOfflineStatus);
  }

  void _syncOfflineStatus() {
    final newStatus = isSongAlreadyOffline(widget.audioId);
    if (_songOfflineStatus.value != newStatus) {
      _songOfflineStatus.value = newStatus;
    }
  }

  @override
  void didUpdateWidget(NowPlayingOptionsMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioId != widget.audioId) {
      _songOfflineStatus.value = isSongAlreadyOffline(widget.audioId);
    }
  }

  @override
  void dispose() {
    userOfflineSongs.removeListener(_syncOfflineStatus);
    _songOfflineStatus.dispose();
    super.dispose();
  }

  Future<void> _toggleOffline() async {
    final originalValue = _songOfflineStatus.value;
    _songOfflineStatus.value = !originalValue;

    try {
      final bool success;
      if (originalValue) {
        success = await removeSongFromOffline(widget.audioId);
      } else {
        success = await makeSongOffline(mediaItemToMap(widget.metadata));
      }
      if (!success) {
        _songOfflineStatus.value = originalValue;
      }
    } catch (e) {
      _songOfflineStatus.value = originalValue;
      logger.log('Error toggling offline status', error: e);
    }
  }

  void _showSleepTimerDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        final duration = sleepTimerNotifier.value ?? Duration.zero;
        var hours = duration.inMinutes ~/ 60;
        var minutes = duration.inMinutes % 60;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.timer_24_regular, color: colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(
                    context.l10n!.sleepTimer,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n!.selectDuration,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildTimeSelector(
                    context: context,
                    label: context.l10n!.hours,
                    value: hours,
                    colorScheme: colorScheme,
                    onDecrement: () {
                      if (hours > 0) setState(() => hours--);
                    },
                    onIncrement: () => setState(() => hours++),
                  ),
                  const SizedBox(height: 16),
                  _buildTimeSelector(
                    context: context,
                    label: context.l10n!.minutes,
                    value: minutes,
                    colorScheme: colorScheme,
                    onDecrement: () {
                      if (minutes > 0) setState(() => minutes--);
                    },
                    onIncrement: () {
                      if (minutes < 59) setState(() => minutes++);
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ...[15, 30, 45, 60].map((mins) {
                        return ActionChip(
                          label: Text('$mins min'),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onPressed: () {
                            setState(() {
                              hours = mins ~/ 60;
                              minutes = mins % 60;
                            });
                          },
                        );
                      }),
                      ActionChip(
                        label: Text(context.l10n!.endOfSong),
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onPressed: () {
                          audioHandler.setSleepTimerEndOfSong();
                          showToast(
                            context,
                            context.l10n!.sleepTimerSet,
                            duration: const Duration(seconds: 1, milliseconds: 500),
                          );
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(context.l10n!.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    final duration = Duration(hours: hours, minutes: minutes);
                    if (duration.inSeconds > 0) {
                      audioHandler.setSleepTimer(duration);
                      showToast(
                        context,
                        context.l10n!.sleepTimerSet,
                        duration: const Duration(seconds: 1, milliseconds: 500),
                      );
                    }
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(context.l10n!.setTimer),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTimeSelector({
    required BuildContext context,
    required String label,
    required int value,
    required ColorScheme colorScheme,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  FluentIcons.line_horizontal_1_24_regular,
                  color: colorScheme.onSurfaceVariant,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onDecrement,
              ),
              Container(
                width: 48,
                alignment: Alignment.center,
                child: Text(
                  '$value',
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  FluentIcons.add_24_regular,
                  color: colorScheme.onSurfaceVariant,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onIncrement,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n!;
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<int>(
      icon: Icon(
        FluentIcons.more_vertical_24_regular,
        color: colorScheme.onSurface,
      ),
      iconSize: 24,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.75),
      elevation: 0,
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(12),
      ),
      onSelected: (value) {
        if (value == 0) {
          if (widget.audioId != null) {
            _toggleOffline();
          }
        } else if (value == 1) {
          final isActive = sleepTimerNotifier.value != null;
          if (isActive) {
            audioHandler.cancelSleepTimer();
            sleepTimerNotifier.value = null;
            showToast(
              context,
              context.l10n!.sleepTimerCancelled,
              duration: const Duration(seconds: 1, milliseconds: 500),
            );
          } else {
            _showSleepTimerDialog(context);
          }
        } else if (value == 2) {
          showAddToPlaylistDialog(
            context,
            song: mediaItemToMap(widget.metadata),
          );
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 0,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ValueListenableBuilder<bool>(
            valueListenable: _songOfflineStatus,
            builder: (_, isOffline, __) {
              return Row(
                children: [
                  Icon(
                    isOffline
                        ? FluentIcons.cloud_off_24_filled
                        : FluentIcons.cloud_arrow_down_24_regular,
                    size: 20,
                    color: isOffline
                        ? Theme.of(context).colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.makeOffline,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
        PopupMenuItem(
          value: 1,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ValueListenableBuilder<Duration?>(
            valueListenable: sleepTimerNotifier,
            builder: (_, value, __) {
              final isActive = value != null;
              return Row(
                children: [
                  Icon(
                    isActive
                        ? FluentIcons.timer_24_filled
                        : FluentIcons.timer_24_regular,
                    size: 20,
                    color: isActive
                        ? Theme.of(context).colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.sleepTimer,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
        if (!offlineMode.value)
          PopupMenuItem(
            value: 2,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  FluentIcons.album_add_24_regular,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.addToPlaylist,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
