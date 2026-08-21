import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/extensions/l10n.dart';

class PlaylistHeader extends StatelessWidget {
  const PlaylistHeader(
    this.image,
    this.title,
    this.songsLength, {
    super.key,
    this.isAlbum,
    this.isArtist = false,
    this.accentColor,
  });

  final Widget image;
  final String title;
  final int songsLength;
  final bool? isAlbum;
  final bool isArtist;
  final Color? accentColor;

  /// Static helper to build just the chips row (used by parallax header).
  static Widget buildChipsOnly({
    required BuildContext context,
    required int songsLength,
    required bool isArtist,
    bool? isAlbum,
    Color? accentColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final chipBg = accentColor?.withValues(alpha: 0.25) ?? colorScheme.primaryContainer;
    final chipFg = accentColor != null
        ? Colors.white.withValues(alpha: 0.9)
        : colorScheme.onPrimaryContainer;
    final countBg = accentColor?.withValues(alpha: 0.15) ?? colorScheme.secondaryContainer;
    final countFg = accentColor != null
        ? Colors.white.withValues(alpha: 0.8)
        : colorScheme.onSecondaryContainer;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      children: [
        if (isArtist)
          _Chip(
            icon: FluentIcons.person_16_regular,
            label: context.l10n!.artist,
            color: chipBg,
            onColor: chipFg,
            theme: theme,
          )
        else if (isAlbum != null)
          _Chip(
            icon: isAlbum!
                ? FluentIcons.cd_16_regular
                : FluentIcons.apps_list_24_regular,
            label: isAlbum!
                ? context.l10n!.album
                : context.l10n!.playlist,
            color: chipBg,
            onColor: chipFg,
            theme: theme,
          ),
        _Chip(
          icon: FluentIcons.text_bullet_list_24_filled,
          label: '$songsLength ${context.l10n!.songs}',
          color: countBg,
          onColor: countFg,
          theme: theme,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          if (isArtist)
            ClipOval(child: image)
          else
            ClipPath(
              clipper: const ShapeBorderClipper(
                shape: StarBorder(
                  points: 8,
                  pointRounding: 0.8,
                  valleyRounding: 0.2,
                  innerRadiusRatio: 0.6,
                ),
              ),
              child: image,
            ),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              letterSpacing: 0,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          buildChipsOnly(
            context: context,
            songsLength: songsLength,
            isAlbum: isAlbum,
            isArtist: isArtist,
            accentColor: accentColor,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onColor,
    required this.theme,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color onColor;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
