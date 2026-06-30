import 'dart:convert';
import 'dart:io';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:musify/constants/version.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/url_launcher.dart';
import 'package:musify/widgets/auto_format_text.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:musify/widgets/auto_format_text.dart';

const String checkUrl = 'https://api.github.com/repos/Nitesh87409/Nit-Music/releases/latest';

Future<void> checkAppUpdates() async {
  try {
    final response = await http.get(Uri.parse(checkUrl));

    if (response.statusCode != 200) {
      logger.log(
        'Fetch update API (checkUrl) call returned status code ${response.statusCode}',
      );
      return;
    }

    final map = json.decode(response.body) as Map<String, dynamic>;
    final tagName = map['tag_name'] as String?;
    if (tagName == null) return;
    final latestVersion = tagName.replaceAll('v', '');
    announcementURL.value = null; // Removed custom announcement feature

    if (!isLatestVersionHigher(appVersion, latestVersion)) {
      return;
    }

    final releasesResponse = map;



    await showDialog(
      context: NavigationManager().context,
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;

        return _UpdateDialog(
          latestVersion: latestVersion,
          releasesResponse: releasesResponse,
          map: map,
        );
      },
    );
  } catch (e, stackTrace) {
    logger.log('Error in checkAppUpdates', error: e, stackTrace: stackTrace);
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.latestVersion,
    required this.releasesResponse,
    required this.map,
  });

  final String latestVersion;
  final Map<String, dynamic> releasesResponse;
  final Map<String, dynamic> map;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = '';

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _status = 'Getting download URL...';
    });

    try {
      final url = await getDownloadUrl(widget.map);
      if (url.isEmpty) {
        setState(() {
          _status = 'No APK found in release.';
          _isDownloading = false;
        });
        return;
      }

      setState(() {
        _status = 'Downloading...';
      });

      final dir = await getExternalStorageDirectory();
      final savePath = '${dir?.path}/musify_update_${widget.latestVersion}.apk';
      final file = File(savePath);

      if (await file.exists()) {
        await file.delete();
      }

      final request = http.Request('GET', Uri.parse(url));
      final response = await http.Client().send(request);
      final contentLength = response.contentLength;

      int bytes = 0;
      final sink = file.openWrite();

      await response.stream.forEach((chunk) {
        sink.add(chunk);
        bytes += chunk.length;
        if (contentLength != null) {
          setState(() {
            _progress = bytes / contentLength;
            _status = 'Downloading... ${(_progress * 100).toStringAsFixed(1)}%';
          });
        }
      });

      await sink.flush();
      await sink.close();

      setState(() {
        _status = 'Opening installer...';
      });

      final result = await OpenFile.open(savePath);
      if (result.type != ResultType.done) {
        setState(() {
          _status = 'Error opening APK: ${result.message}';
          _isDownloading = false;
        });
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.arrow_download_24_regular,
              color: colorScheme.onPrimaryContainer,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n!.appUpdateIsAvailable,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'V${widget.latestVersion}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_isDownloading)
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height / 2.5,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: AutoFormatText(text: widget.releasesResponse['body']),
              ),
            )
          else
            Column(
              children: [
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: <Widget>[
        if (!_isDownloading) ...[
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n!.cancel),
          ),
          FilledButton.icon(
            onPressed: _startDownload,
            icon: const Icon(FluentIcons.arrow_download_20_regular),
            label: Text(context.l10n!.download),
          ),
        ],
      ],
    );
  }
}

void showUpdateCheckDialog(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        icon: Icon(
          FluentIcons.arrow_sync_circle_24_regular,
          color: colorScheme.primary,
          size: 40,
        ),
        title: Text(
          context.l10n!.checkForUpdates,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        content: Text(
          context.l10n!.enableUpdateChecksDescription,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () {
              shouldWeCheckUpdates.value = false;
              addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', false);
              Navigator.of(context).pop();
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colorScheme.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(context.l10n!.no),
          ),
          FilledButton(
            onPressed: () {
              shouldWeCheckUpdates.value = true;
              addOrUpdateData<bool>('settings', 'shouldWeCheckUpdates', true);
              if (!isFdroidBuild && kReleaseMode && !offlineMode.value) {
                checkAppUpdates();
                isUpdateChecked = true;
              }
              Navigator.of(context).pop();
            },
            child: Text(context.l10n!.yes),
          ),
        ],
      );
    },
  );
}

bool isLatestVersionHigher(String appVersion, String latestVersion) {
  final cleanAppVersion = appVersion.split('+').first;
  final cleanLatestVersion = latestVersion.split('+').first;
  final parsedAppVersion = cleanAppVersion.split('.');
  final parsedAppLatestVersion = cleanLatestVersion.split('.');
  final length = parsedAppVersion.length > parsedAppLatestVersion.length
      ? parsedAppVersion.length
      : parsedAppLatestVersion.length;
  for (var i = 0; i < length; i++) {
    final value1 = i < parsedAppVersion.length
        ? int.parse(parsedAppVersion[i])
        : 0;
    final value2 = i < parsedAppLatestVersion.length
        ? int.parse(parsedAppLatestVersion[i])
        : 0;
    if (value2 > value1) {
      return true;
    } else if (value2 < value1) {
      return false;
    }
  }

  return false;
}

Future<String> getCPUArchitecture() async {
  final info = await Process.run('uname', ['-m']);
  final cpu = info.stdout.toString().replaceAll('\n', '');

  return cpu;
}

Future<String> getDownloadUrl(Map<String, dynamic> map) async {
  final assets = map['assets'] as List<dynamic>?;
  if (assets != null && assets.isNotEmpty) {
    for (var asset in assets) {
      if (asset['name'].toString().endsWith('.apk')) {
        return asset['browser_download_url'].toString();
      }
    }
  }
  return '';
}

/// Fetch only the announcement URL from the `check.json` file and set the
/// global `announcementURL` ValueNotifier. This does not trigger releases
/// fetching or any update dialogs/downloads and is safe to call for F‑Droid
/// builds where update prompts are not allowed.
Future<void> fetchAnnouncementOnly() async {
  try {
    final response = await http.get(Uri.parse(checkUrl));

    if (response.statusCode != 200) {
      logger.log(
        'Fetch announcement (checkUrl) call returned status code ${response.statusCode}',
      );
      return;
    }

    final map = json.decode(response.body) as Map<String, dynamic>;
    final ann = map['announcementurl'];
    if (ann != null) {
      announcementURL.value = ann.toString();
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error in fetchAnnouncementOnly',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
