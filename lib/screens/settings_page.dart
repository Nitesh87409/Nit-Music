import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/listening_stats_service.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/update_manager.dart';
import 'package:musify/theme/app_colors.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/bottom_sheet_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/section_header.dart';
import 'package:musify/widgets/settings_components.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final activatedColor = Theme.of(context).colorScheme.secondaryContainer;
    final inactivatedColor = Theme.of(context).colorScheme.surfaceContainerHigh;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.settings)),
      body: SingleChildScrollView(
        padding: commonSingleChildScrollViewPadding,
        child: Column(
          children: <Widget>[
            _buildPreferencesSection(
              context,
              primaryColor,
              activatedColor,
              inactivatedColor,
            ),
            if (!offlineMode.value) _buildOnlineFeaturesSection(context),
            _buildOthersSection(context),
            const SizedBox(height: 20),
            const MiniPlayerBottomSpace(),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesSection(
    BuildContext context,
    Color primaryColor,
    Color activatedColor,
    Color inactivatedColor,
  ) {
    return Column(
      children: [
        SettingsCardGroup(
          title: context.l10n!.preferences,
          icon: FluentIcons.options_24_filled,
          children: [
            ModernSettingsTile(
              title: context.l10n!.accentColor,
              icon: FluentIcons.color_24_regular,
              onTap: () => _showAccentColorPicker(context),
            ),
            ModernSettingsTile(
              title: context.l10n!.themeMode,
              icon: FluentIcons.weather_sunny_28_regular,
              onTap: () => _showThemeModePicker(context),
            ),

            ModernSettingsTile(
              title: context.l10n!.audioQuality,
              icon: FluentIcons.music_note_1_24_regular,
              onTap: () => _showAudioQualityPicker(context),
            ),
            ModernSettingsTile(
              title: context.l10n!.equalizer,
              icon: FluentIcons.data_histogram_24_regular,
              onTap: () => context.push('/settings/equalizer'),
            ),
            ModernSettingsTile(
              title: context.l10n!.dynamicColor,
              icon: FluentIcons.toggle_left_24_regular,
              trailing: ModernSwitch(
                value: useSystemColor.value,
                onChanged: (value) => _toggleSystemColor(context, value),
              ),
            ),
            if (themeMode == ThemeMode.dark)
              ModernSettingsTile(
                title: context.l10n!.pureBlackTheme,
                icon: FluentIcons.color_background_24_regular,
                trailing: ModernSwitch(
                  value: usePureBlackColor.value,
                  onChanged: (value) => _togglePureBlack(context, value),
                ),
              ),
            ValueListenableBuilder<bool>(
              valueListenable: predictiveBack,
              builder: (_, value, __) {
                return ModernSettingsTile(
                  title: context.l10n!.predictiveBack,
                  icon: FluentIcons.position_backward_24_regular,
                  trailing: ModernSwitch(
                    value: value,
                    onChanged: (value) => _togglePredictiveBack(context, value),
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: useProxy,
              builder: (_, value, __) {
                return ModernSettingsTile(
                  title: context.l10n!.useProxy,
                  icon: FluentIcons.shield_24_regular,
                  subtitle: context.l10n!.useProxyDescription,
                  trailing: ModernSwitch(
                    value: value,
                    onChanged: (value) {
                      useProxy.value = value;
                      addOrUpdateData<bool>('settings', 'useProxy', value);
                      showToast(context, context.l10n!.settingChangedMsg);
                    },
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: wrappedEnabled,
              builder: (_, value, __) {
                return ModernSettingsTile(
                  title: context.l10n!.listeningStats,
                  icon: FluentIcons.clock_24_regular,
                  subtitle: context.l10n!.listeningStatsDescription,
                  trailing: ModernSwitch(
                    value: value,
                    onChanged: (value) => _toggleWrapped(context, value),
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: offlineMode,
              builder: (_, value, __) {
                return ModernSettingsTile(
                  title: context.l10n!.offlineMode,
                  icon: FluentIcons.cloud_off_24_regular,
                  subtitle: context.l10n!.offlineModeDescription,
                  trailing: ModernSwitch(
                    value: value,
                    onChanged: (value) => _toggleOfflineMode(context, value),
                  ),
                );
              },
            ),
            ValueListenableBuilder<bool>(
              valueListenable: shakeToSkipEnabled,
              builder: (_, enabled, __) {
                return Column(
                  children: [
                    ModernSettingsTile(
                      title: 'Shake to Skip',
                      icon: FluentIcons.phone_shake_24_regular,
                      subtitle: 'Shake phone to skip to next/previous song',
                      trailing: ModernSwitch(
                        value: enabled,
                        onChanged: (value) =>
                            _toggleShakeToSkip(context, value),
                      ),
                    ),
                    if (enabled)
                      ValueListenableBuilder<String>(
                        valueListenable: shakeToSkipSensitivity,
                        builder: (_, sensitivity, __) {
                          String displaySens = 'Medium';
                          if (sensitivity == 'low')
                            displaySens = 'Low (Hard Shake)';
                          if (sensitivity == 'high')
                            displaySens = 'High (Light Shake)';
                          return ModernSettingsTile(
                            title: 'Shake Sensitivity',
                            icon: FluentIcons.settings_24_regular,
                            subtitle: 'Current: $displaySens',
                            onTap: () => _showShakeSensitivityPicker(context),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
            if (!isFdroidBuild)
              ValueListenableBuilder<bool>(
                valueListenable: shouldWeCheckUpdates,
                builder: (_, value, __) {
                  return Column(
                    children: [
                      ModernSettingsTile(
                        title: context.l10n!.automaticUpdateChecks,
                        icon: FluentIcons.arrow_sync_24_regular,
                        subtitle:
                            context.l10n!.automaticUpdateChecksDescription,
                        trailing: ModernSwitch(
                          value: value,
                          onChanged: (value) =>
                              _toggleAutomaticUpdateChecks(context, value),
                        ),
                      ),
                      ModernSettingsTile(
                        title: context.l10n!.checkForUpdates,
                        icon: FluentIcons.arrow_sync_circle_24_regular,
                        onTap: () {
                          if (kReleaseMode && !offlineMode.value) {
                            checkAppUpdates(manual: true);
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildOnlineFeaturesSection(BuildContext context) {
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: playNextSongAutomatically,
          builder: (_, value, __) {
            return ModernSettingsTile(
              title: context.l10n!.automaticSongPicker,
              icon: FluentIcons.music_note_2_play_20_regular,
              subtitle: context.l10n!.automaticSongPickerDescription,
              trailing: ModernSwitch(
                value: value,
                onChanged: (value) {
                  _toggleAutoPlayNext(context, value);
                  showToast(context, context.l10n!.settingChangedMsg);
                },
              ),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: externalRecommendations,
          builder: (_, value, __) {
            return ModernSettingsTile(
              title: context.l10n!.externalRecommendations,
              icon: FluentIcons.channel_share_24_regular,
              subtitle: context.l10n!.externalRecommendationsDescription,
              trailing: ModernSwitch(
                value: value,
                onChanged: (value) =>
                    _toggleExternalRecommendations(context, value),
              ),
            );
          },
        ),

        _buildToolsSection(context),
      ],
    );
  }

  Widget _buildToolsSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: context.l10n!.tools,
          icon: FluentIcons.toolbox_24_filled,
        ),
        ModernSettingsTile(
          title: context.l10n!.clearCache,
          icon: FluentIcons.broom_24_regular,
          onTap: () async {
            final cleared = await clearCache();
            showToast(
              context,
              cleared ? '${context.l10n!.cacheMsg}!' : context.l10n!.error,
            );
          },
        ),
        ModernSettingsTile(
          title: context.l10n!.clearSearchHistory,
          icon: FluentIcons.history_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearSearchHistoryQuestion,
            onSubmit: () {
              searchHistoryNotifier.value = [];
              deleteData('user', 'searchHistory');
              showToast(context, '${context.l10n!.searchHistoryMsg}!');
            },
          ),
        ),
        ModernSettingsTile(
          title: context.l10n!.clearRecentlyPlayed,
          icon: FluentIcons.receipt_play_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearRecentlyPlayedQuestion,
            onSubmit: () {
              userRecentlyPlayed.value = [];
              deleteData('user', 'recentlyPlayedSongs');
              showToast(context, '${context.l10n!.recentlyPlayedMsg}!');
            },
          ),
        ),
        ModernSettingsTile(
          title: context.l10n!.clearListeningStats,
          icon: FluentIcons.clock_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.clearListeningStatsQuestion,
            submitMessage: context.l10n!.delete,
            isDangerous: true,
            onSubmit: () async {
              audioHandler.resetListeningStatsSession(flushStats: false);
              await listeningStatsService.clearStats();
              audioHandler.startListeningStatsSessionIfNeeded();
              if (context.mounted) {
                showToast(context, '${context.l10n!.listeningStatsCleared}!');
              }
            },
          ),
        ),
        ModernSettingsTile(
          title: context.l10n!.deleteDownloads,
          icon: FluentIcons.delete_24_regular,
          onTap: () => _showConfirmationDialog(
            context: context,
            confirmationMessage: context.l10n!.deleteDownloadsQuestion,
            submitMessage: context.l10n!.delete,
            isDangerous: true,
            onSubmit: () async {
              try {
                await offlinePlaylistService.deleteAllDownloads();
                if (context.mounted) {
                  showToast(context, context.l10n!.downloadsDeleted);
                }
              } catch (e) {
                if (context.mounted) {
                  showToast(context, context.l10n!.error);
                }
              }
            },
          ),
        ),
        ModernSettingsTile(
          title: context.l10n!.backupUserData,
          icon: FluentIcons.cloud_sync_24_regular,
          onTap: () => _backupUserData(context),
        ),
        ModernSettingsTile(
          title: context.l10n!.restoreUserData,
          icon: FluentIcons.cloud_add_24_regular,
          onTap: () async {
            try {
              final result = await restoreData(context);
              if (result.success) {
                reloadSongLibraryStateFromStorage();
                reloadPlaylistLibraryStateFromStorage();
                reloadSearchHistoryFromStorage();
                // The restored settings box may carry a different
                // wrappedEnabled value than the one already loaded into this
                // ValueNotifier; without resyncing it here, recording silently
                // keeps following the pre-restore value until the next cold
                // start, when it would suddenly flip without explanation.
                wrappedEnabled.value =
                    await getData(
                          'settings',
                          'wrappedEnabled',
                          defaultValue: true,
                        )
                        as bool;
                listeningStatsService.reload();
              }
              if (context.mounted) {
                showToast(
                  context,
                  result.message,
                  icon: result.success
                      ? null
                      : FluentIcons.error_circle_24_regular,
                );
              }
            } catch (e, str) {
              logger.log('Error restoring data', error: e, stackTrace: str);
              if (context.mounted) {
                showToast(
                  context,
                  context.l10n!.error,
                  icon: FluentIcons.error_circle_24_regular,
                );
              }
            }
          },
        ),
      ],
    );
  }

  Widget _buildOthersSection(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: context.l10n!.others,
          icon: FluentIcons.more_circle_24_filled,
        ),
        ModernSettingsTile(
          title: '${context.l10n!.copyLogs} (${logger.getLogCount()})',
          icon: FluentIcons.error_circle_24_regular,
          onTap: () async => showToast(context, await logger.copyLogs(context)),
        ),
        ModernSettingsTile(
          title: context.l10n!.about,
          icon: FluentIcons.book_information_24_regular,
          onTap: () => NavigationManager.router.go('/settings/about'),
        ),
      ],
    );
  }

  void _showAccentColorPicker(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showCustomBottomSheet(
      context,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          itemCount: availableColors.length,
          itemBuilder: (context, index) {
            final color = availableColors[index];
            final isSelected = color == primaryColorSetting;

            return GestureDetector(
              onTap: () {
                addOrUpdateData<int>(
                  'settings',
                  'accentColor',
                  color.toARGB32(),
                );
                Musify.updateAppState(
                  context,
                  newAccentColor: color,
                  useSystemColor: false,
                );
                showToast(context, context.l10n!.accentChangeMsg);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: colorScheme.onSurface, width: 3)
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        FluentIcons.checkmark_20_filled,
                        color: color.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showThemeModePicker(BuildContext context) {
    final availableModes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];
    const modeIcons = [
      FluentIcons.phone_24_regular,
      FluentIcons.weather_sunny_24_regular,
      FluentIcons.weather_moon_24_regular,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableModes.length,
        itemBuilder: (context, index) {
          final mode = availableModes[index];
          final modeNames = [
            context.l10n!.themeModeSystem,
            context.l10n!.themeModeLight,
            context.l10n!.themeModeDark,
          ];

          return BottomSheetBar(
            modeNames[mode.index],
            () {
              addOrUpdateData<int>('settings', 'themeIndex', mode.index);
              Musify.updateAppState(context, newThemeMode: mode);
              Navigator.pop(context);
            },
            themeMode == mode,
            icon: modeIcons[mode.index],
          );
        },
      ),
    );
  }

  void _showAudioQualityPicker(BuildContext context) {
    final availableQualities = ['low', 'medium', 'high'];
    final qualityNames = [
      context.l10n!.audioQualityLow,
      context.l10n!.audioQualityMedium,
      context.l10n!.audioQualityHigh,
    ];
    const qualityIcons = [
      FluentIcons.speaker_1_24_regular,
      FluentIcons.speaker_2_24_regular,
      FluentIcons.speaker_2_24_filled,
    ];

    showCustomBottomSheet(
      context,
      ListView.builder(
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        padding: commonListViewBottomPadding,
        itemCount: availableQualities.length,
        itemBuilder: (context, index) {
          final quality = availableQualities[index];

          return BottomSheetBar(
            qualityNames[index],
            () {
              addOrUpdateData<String>('settings', 'audioQuality', quality);
              audioQualitySetting.value = quality;
              showToast(context, context.l10n!.audioQualityMsg);
              Navigator.pop(context);
            },
            audioQualitySetting.value == quality,
            icon: qualityIcons[index],
          );
        },
      ),
    );
  }

  void _toggleSystemColor(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'useSystemColor', value);
    useSystemColor.value = value;
    Musify.updateAppState(
      context,
      newAccentColor: primaryColorSetting,
      useSystemColor: value,
    );
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePureBlack(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'usePureBlackColor', value);
    usePureBlackColor.value = value;
    Musify.updateAppState(context);
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _togglePredictiveBack(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'predictiveBack', value);
    predictiveBack.value = value;
    transitionsBuilder = value
        ? const PredictiveBackPageTransitionsBuilder()
        : const CupertinoPageTransitionsBuilder();
    Musify.updateAppState(context);
    showToast(context, context.l10n!.settingChangedMsg);
  }

  Future<void> _toggleWrapped(BuildContext context, bool value) async {
    if (!value) {
      audioHandler.resetListeningStatsSession(
        countCurrentTick: true,
        flushStats: false,
      );
      await listeningStatsService.flush();
    }

    await addOrUpdateData<bool>('settings', 'wrappedEnabled', value);
    wrappedEnabled.value = value;
    listeningStatsService.reload();
    if (value) {
      audioHandler.startListeningStatsSessionIfNeeded();
    }
    if (context.mounted) {
      showToast(context, context.l10n!.settingChangedMsg);
    }
  }

  void _toggleOfflineMode(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'offlineMode', value);
    offlineMode.value = value;

    // Trigger router refresh and notify about the change
    NavigationManager.refreshRouter();

    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleAutoPlayNext(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'playNextSongAutomatically', value);
    playNextSongAutomatically.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleShakeToSkip(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'shakeToSkipEnabled', value);
    shakeToSkipEnabled.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _showShakeSensitivityPicker(BuildContext context) {
    showCustomBottomSheet(
      context,
      ListView(
        shrinkWrap: true,
        children: [
          RadioListTile<String>(
            title: const Text('Low (Hard Shake)'),
            value: 'low',
            groupValue: shakeToSkipSensitivity.value,
            onChanged: (value) {
              addOrUpdateData<String>(
                'settings',
                'shakeToSkipSensitivity',
                value!,
              );
              shakeToSkipSensitivity.value = value;
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            title: const Text('Medium (Normal)'),
            value: 'medium',
            groupValue: shakeToSkipSensitivity.value,
            onChanged: (value) {
              addOrUpdateData<String>(
                'settings',
                'shakeToSkipSensitivity',
                value!,
              );
              shakeToSkipSensitivity.value = value;
              Navigator.pop(context);
            },
          ),
          RadioListTile<String>(
            title: const Text('High (Light Shake)'),
            value: 'high',
            groupValue: shakeToSkipSensitivity.value,
            onChanged: (value) {
              addOrUpdateData<String>(
                'settings',
                'shakeToSkipSensitivity',
                value!,
              );
              shakeToSkipSensitivity.value = value;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _toggleAutomaticUpdateChecks(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', value);
    shouldWeCheckUpdates.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _toggleExternalRecommendations(BuildContext context, bool value) {
    addOrUpdateData<bool>('settings', 'externalRecommendations', value);
    externalRecommendations.value = value;
    showToast(context, context.l10n!.settingChangedMsg);
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String confirmationMessage,
    required VoidCallback onSubmit,
    String? submitMessage,
    bool isDangerous = false,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          submitMessage: submitMessage ?? context.l10n!.clear,
          confirmationMessage: confirmationMessage,
          isDangerous: isDangerous,
          onCancel: () => Navigator.of(context).pop(),
          onSubmit: () {
            Navigator.of(context).pop();
            onSubmit();
          },
        );
      },
    );
  }

  Future<void> _backupUserData(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    try {
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            icon: Icon(
              FluentIcons.info_24_regular,
              color: colorScheme.primary,
              size: 32,
            ),
            content: Text(
              context.l10n!.folderRestrictions,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n!.understand),
              ),
            ],
          );
        },
      );
      final result = await backupData(context);
      if (context.mounted) {
        showToast(
          context,
          result.message,
          icon: result.success ? null : FluentIcons.error_circle_24_regular,
        );
      }
    } catch (e, stackTrace) {
      logger.log('Error backing up data', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        showToast(
          context,
          context.l10n!.error,
          icon: FluentIcons.error_circle_24_regular,
        );
      }
    }
  }
}
