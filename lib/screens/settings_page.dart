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
import 'package:musify/services/auth_service.dart';
import 'package:musify/services/sync_service.dart';
import 'package:musify/theme/app_colors.dart';
import 'package:musify/theme/app_themes.dart';
import 'package:musify/utilities/flutter_bottom_sheet.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/widgets/bottom_sheet_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/settings_components.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: <Widget>[
            _buildAccountSection(context),
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

  Widget _buildAccountSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authService = AuthService.instance;

    return ValueListenableBuilder<bool>(
      valueListenable: authService.isLoggedIn,
      builder: (context, loggedIn, _) {
        return ValueListenableBuilder<User?>(
          valueListenable: authService.currentUser,
          builder: (context, user, _) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SettingsCardGroup(
                title: 'Account',
                icon: FluentIcons.person_24_filled,
                children: [
                  if (!loggedIn)
                    _AccountSignInTile(colorScheme: colorScheme)
                  else
                    _AccountInfoTile(
                      user: user,
                      colorScheme: colorScheme,
                    ),
                ],
              ),
            );
          },
        );
      },
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
    return SettingsCardGroup(
      title: context.l10n!.tools,
      icon: FluentIcons.toolbox_24_filled,
      children: [
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
    return SettingsCardGroup(
      title: context.l10n!.others,
      icon: FluentIcons.more_circle_24_filled,
      children: [
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
              color: colorScheme.onSurface,
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

class _AccountSignInTile extends StatefulWidget {
  const _AccountSignInTile({required this.colorScheme});
  final ColorScheme colorScheme;

  @override
  State<_AccountSignInTile> createState() => _AccountSignInTileState();
}

class _AccountSignInTileState extends State<_AccountSignInTile> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isOtpSent = false;
  bool _loading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handlePostSignIn() async {
    if (!mounted) return;
    try {
      final hasCloud = await SyncService.instance.hasCloudData();
      if (hasCloud) {
        if (mounted) {
          final shouldRestore = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: Icon(
                FluentIcons.cloud_sync_24_regular,
                color: widget.colorScheme.onSurface,
                size: 32,
              ),
              title: const Text('Cloud Data Found'),
              content: const Text(
                'Your previously synced data was found. '
                'Restore liked songs, playlists & history?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Restore'),
                ),
              ],
            ),
          );

          if (shouldRestore == true) {
            final success = await SyncService.instance.restoreFromCloud();
            if (mounted) {
              showToast(
                context,
                success ? 'Data restored successfully ✓' : 'Restore failed',
                icon: success ? null : FluentIcons.error_circle_24_regular,
              );
            }
          } else {
            await SyncService.instance.uploadAll();
          }
        }
      } else {
        await SyncService.instance.uploadAll();
        if (mounted) {
          showToast(context, 'Data synced to cloud ✓');
        }
      }
    } catch (e) {
      if (mounted) showToast(context, 'Sync error: $e');
    }
  }

  void _sendOtp() {
    final rawPhone = _phoneController.text.trim();
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) {
      showToast(context, 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isOtpSent = true;
    });
    showToast(context, 'OTP Sent! (Testing OTP: 0000)');

    // Also trigger Firebase Phone Auth in background
    AuthService.instance.sendPhoneOtp(
      phoneNumber: rawPhone,
      onCodeSent: (verId) {
        if (mounted) setState(() => _verificationId = verId);
      },
      onError: (_) {},
    );
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      showToast(context, 'Please enter OTP (use 0000)');
      return;
    }

    setState(() => _loading = true);
    try {
      final success = await AuthService.instance.signInWithPhone(
        phoneNumber: _phoneController.text.trim(),
        otp: otp,
        verificationId: _verificationId,
      );
      if (success) {
        await _handlePostSignIn();
      } else {
        if (mounted) {
          showToast(
            context,
            'Invalid OTP or verification failed',
            icon: FluentIcons.error_circle_24_regular,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user != null) {
        await _handlePostSignIn();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.phone_24_regular,
                size: 28,
                color: widget.colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign in with Mobile Number',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: widget.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Sync your liked songs & playlists to your number',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (!_isOtpSent) ...[
            // Mobile Number Input
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Text(
                    '+91',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.colorScheme.onSurface,
                      fontSize: 15,
                    ),
                  ),
                ),
                hintText: 'Enter 10-digit mobile number',
                filled: true,
                fillColor: widget.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading ? null : _sendOtp,
              icon: const Icon(FluentIcons.send_24_regular, size: 18),
              label: const Text('Send OTP'),
            ),
          ] else ...[
            // OTP Input
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Code sent to +91 ${_phoneController.text.trim()}',
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isOtpSent = false;
                      _otpController.clear();
                    });
                  },
                  child: const Text('Change'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(FluentIcons.password_24_regular),
                hintText: 'Enter OTP (Testing OTP: 0000)',
                filled: true,
                fillColor: widget.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading ? null : _verifyOtp,
              icon: _loading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: widget.colorScheme.onPrimary,
                      ),
                    )
                  : const Icon(FluentIcons.checkmark_24_regular, size: 18),
              label: Text(_loading ? 'Verifying...' : 'Verify & Sign In'),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Divider(color: widget.colorScheme.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'OR',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(child: Divider(color: widget.colorScheme.outlineVariant)),
            ],
          ),
          const SizedBox(height: 10),

          // Google Sign-In as secondary option
          OutlinedButton.icon(
            onPressed: _loading ? null : _handleGoogleSignIn,
            icon: const Icon(FluentIcons.person_add_24_regular, size: 18),
            label: const Text('Sign in with Google'),
          ),
        ],
      ),
    );
  }
}

class _AccountInfoTile extends StatefulWidget {
  const _AccountInfoTile({required this.user, required this.colorScheme});
  final User? user;
  final ColorScheme colorScheme;

  @override
  State<_AccountInfoTile> createState() => _AccountInfoTileState();
}

class _AccountInfoTileState extends State<_AccountInfoTile> {
  bool _syncing = false;

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    try {
      await SyncService.instance.uploadAll();
      if (mounted) showToast(context, 'Synced ✓');
    } catch (_) {
      if (mounted) {
        showToast(
          context,
          'Sync failed',
          icon: FluentIcons.error_circle_24_regular,
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmationDialog(
        submitMessage: 'Sign Out',
        confirmationMessage: 'Are you sure you want to sign out?',
        onCancel: () => Navigator.pop(ctx, false),
        onSubmit: () => Navigator.pop(ctx, true),
      ),
    );

    if (confirmed == true) {
      await AuthService.instance.signOut();
      if (mounted) showToast(context, 'Signed out');
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.user?.email ?? '';
    final photoUrl = widget.user?.photoURL;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: widget.colorScheme.surfaceContainerHighest,
                backgroundImage:
                    photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Icon(
                        FluentIcons.person_24_filled,
                        color: widget.colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.user?.displayName ?? 'Signed In',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.colorScheme.onSurface,
                      ),
                    ),
                    if (email.isNotEmpty && !email.endsWith('@nitmusic.app'))
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )
                    else if (email.endsWith('@nitmusic.app'))
                      Text(
                        'Phone Verified ✓',
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                FluentIcons.cloud_checkmark_24_regular,
                color: const Color(0xFFE11D48),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncing ? null : _syncNow,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.colorScheme.onSurface,
                    side: BorderSide(color: widget.colorScheme.outlineVariant),
                  ),
                  icon: _syncing
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.colorScheme.onSurface,
                          ),
                        )
                      : const Icon(
                          FluentIcons.arrow_sync_24_regular,
                          size: 16,
                          color: Color(0xFFE11D48),
                        ),
                  label: Text(_syncing ? 'Syncing...' : 'Sync Now'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _signOut,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.colorScheme.onSurface,
                    side: BorderSide(color: widget.colorScheme.outlineVariant),
                  ),
                  icon: const Icon(FluentIcons.sign_out_24_regular, size: 16),
                  label: const Text('Sign Out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
