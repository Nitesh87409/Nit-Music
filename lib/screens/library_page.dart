import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart' show logger;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlist_download_service.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/async_loader.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/offline_playlist_dialogs.dart';
import 'package:musify/utilities/playlist_dialogs.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/section_header.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  _LibraryPageState createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  @override
  Widget build(BuildContext context) {
    // Show offline mode message if there is no content
    if (offlineMode.value) {
      final hasUserContent =
          userPlaylistFolders.value.isNotEmpty ||
          userPlaylists.value.isNotEmpty ||
          userCustomPlaylists.value.isNotEmpty;
      final hasOfflinePlaylists = offlinePlaylistService.offlinePlaylists.value
          .any((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p));
      final hasOfflineArtists = getLikedArtistItems(
        offlineOnly: true,
      ).isNotEmpty;
      final hasOfflineSongs = userOfflineSongs.value.isNotEmpty;

      if (!hasUserContent &&
          !hasOfflinePlaylists &&
          !hasOfflineArtists &&
          !hasOfflineSongs) {
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Library', style: TextStyle(color: Colors.white)),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FluentIcons.cloud_off_24_regular,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n!.offlineMode,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n!.noOfflineLibraryContent,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            pinnedPlaylistIds,
            offlineMode,
            userCustomPlaylists,
            userPlaylistFolders,
            offlinePlaylistService.offlinePlaylists,
            userLikedPlaylists,
            onlinePlaylists,
            userPlaylists,
          ]),
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        _buildSubHeader(context),
                        const SizedBox(height: 24),
                        _buildBanner(context),
                        const SizedBox(height: 24),
                        _buildActionGroup(context),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                ..._buildPinnedSlivers(),
                ..._buildUserPlaylistsSlivers(),
                if (!offlineMode.value)
                  ..._buildLikedPlaylistsSlivers(),
                ..._buildLikedArtistsSlivers(),
                const SliverMiniPlayerBottomSpace(),
              ],
            );
          },
        ),
      ),
    );
  }



  Widget _buildSubHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(FluentIcons.library_24_filled, color: Color(0xFFA67CFF), size: 28),
            const SizedBox(width: 8),
            const Text(
              'My Library',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: _showCreateFolderDialog,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FluentIcons.folder_add_24_regular,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => showCreatePlaylistDialog(context),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF8B5CF6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  FluentIcons.add_24_filled,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            flex: 3,
            child: Text(
              'Good music is collected,\nnot just found.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(
                FluentIcons.headphones_24_filled,
                size: 64,
                color: const Color(0xFFA67CFF).withValues(alpha: 0.8),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionGroup(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildActionTile(
            title: 'Recently played',
            listNotifier: userRecentlyPlayed,
            icon: FluentIcons.history_24_regular,
            iconColor: const Color(0xFFA67CFF),
            backgroundColor: const Color(0xFF2C2442),
            onTap: () => NavigationManager.router.go('/library/userSongs/recents'),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 72, endIndent: 16),
          _buildActionTile(
            title: 'Liked songs',
            listNotifier: userLikedSongsList,
            icon: FluentIcons.heart_24_regular,
            iconColor: const Color(0xFFFF71A9),
            backgroundColor: const Color(0xFF421C2F),
            onTap: () => NavigationManager.router.go('/library/userSongs/liked'),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.05), height: 1, indent: 72, endIndent: 16),
          _buildActionTile(
            title: 'Offline songs',
            listNotifier: userOfflineSongs,
            icon: FluentIcons.cloud_off_24_regular,
            iconColor: const Color(0xFF00E5FF),
            backgroundColor: const Color(0xFF123440),
            onTap: () => NavigationManager.router.go('/library/userSongs/offline'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required ValueNotifier<List> listNotifier,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ValueListenableBuilder<List>(
                    valueListenable: listNotifier,
                    builder: (context, list, _) {
                      return Text(
                        '${list.length} songs',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(FluentIcons.chevron_right_20_regular, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPinnedSlivers() {
    final ids = pinnedPlaylistIds.value;
    if (ids.isEmpty) return [];

    final isOff = offlineMode.value;
    final items = resolvePinnedPlaylists(ids).where((p) {
      return !isOff ||
          offlinePlaylistService.isPlaylistDownloaded(
            p['ytid']?.toString() ?? '',
          );
    }).toList();

    if (items.isEmpty) return [];

    return [
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('Pinned Playlists', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
      _buildSliverPlaylistList(items),
    ];
  }

  List<Widget> _buildUserPlaylistsSlivers() {
    final isOffline = offlineMode.value;
    final rawOfflinePlaylists = offlinePlaylistService.offlinePlaylists.value;
    final visibleOfflinePlaylists = rawOfflinePlaylists
        .where((p) => p is Map && !PlaylistUtils.isArtistPlaylist(p))
        .toList();
    final folders = isOffline
        ? userPlaylistFolders.value
              .where(PlaylistUtils.folderHasOfflinePlaylists)
              .toList()
        : userPlaylistFolders.value;

    final offlinePlaylistsNotInFolders =
        PlaylistUtils.filterOfflinePlaylistsNotInFolders(
          visibleOfflinePlaylists,
          folders,
        );

    final offlineIdsNotInFolders = PlaylistUtils.offlinePlaylistIdsNotInFolders(
      visibleOfflinePlaylists,
      folders,
    );

    final allPlaylistsNotInFolders = getPlaylistsNotInFolders();
    final playlistsNotInFolders = PlaylistUtils.excludePlaylistsWithIds(
      allPlaylistsNotInFolders,
      offlineIdsNotInFolders,
    );

    final hasFolders = folders.isNotEmpty;
    final hasCustomPlaylists = playlistsNotInFolders.isNotEmpty;
    final slivers = <Widget>[];

    if (hasFolders || hasCustomPlaylists) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Custom Playlists', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      );

      if (hasFolders) {
        slivers.add(
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: _buildFolderSliverList(folders, hasCustomPlaylists),
          ),
        );
      }
      if (hasCustomPlaylists) {
        slivers.add(
          _buildSliverPlaylistList(playlistsNotInFolders),
        );
      }
    }

    final offlinePlaylists = offlinePlaylistsNotInFolders;

    if (offlinePlaylists.isNotEmpty) {
      slivers
        ..add(
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text('Offline Playlists', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        )
        ..add(
          _buildSliverPlaylistList(offlinePlaylists, isOfflinePlaylists: true),
        );
    }

    if (!offlineMode.value && userPlaylists.value.isNotEmpty) {
      slivers.add(
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Added Playlists', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ),
      );
      slivers.add(
        SliverToBoxAdapter(
          child: AsyncLoader<List<dynamic>>(
            future: getUserPlaylistsNotInFolders(),
            emptyWidget: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                context.l10n!.noPlaylistsAdded,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            builder: (ctx, playlists) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildPlaylistListView(ctx, playlists),
            ),
          ),
        ),
      );
    }

    return slivers;
  }

  List<Widget> _buildLikedPlaylistsSlivers() {
    final likedPlaylists = getLikedPlaylistItems();
    if (likedPlaylists.isEmpty) return [];
    return [
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('Liked Playlists', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
      _buildSliverPlaylistList(likedPlaylists),
    ];
  }

  List<Widget> _buildLikedArtistsSlivers() {
    final likedArtists = getLikedArtistItems(offlineOnly: offlineMode.value);
    if (likedArtists.isEmpty) return [];
    return [
      const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text('Artists', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
      _buildSliverPlaylistList(likedArtists),
    ];
  }

  Widget _buildSliverPlaylistList(
    List playlists, {
    bool isOfflinePlaylists = false,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      sliver: SliverList.builder(
        itemCount: playlists.length,
        itemBuilder: (BuildContext context, index) {
          final playlist = playlists[index];
          final isArtist = playlist['source']?.toString() == 'youtube-artist';
          final borderRadius = getItemBorderRadius(
            index,
            playlists.length,
          );
          return PlaylistBar(
            key: listItemKey('library_playlist', index, playlist),
            playlist['title'],
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['image'],
            cubeIcon: isArtist
                ? FluentIcons.person_24_filled
                : FluentIcons.text_bullet_list_24_filled,
            isAlbum: isArtist ? false : playlist['isAlbum'],
            playlistData:
                isArtist ||
                    playlist['source'] == 'user-created' ||
                    playlist['source'] == 'user-youtube' ||
                    isOfflinePlaylists
                ? playlist
                : null,
            onDelete:
                playlist['source'] == 'user-created' ||
                    playlist['source'] == 'user-youtube' ||
                    isOfflinePlaylists
                ? () => isOfflinePlaylists
                      ? _showRemoveOfflinePlaylistDialog(playlist)
                      : _showRemovePlaylistDialog(playlist)
                : null,
            borderRadius: borderRadius,
          );
        },
      ),
    );
  }

  Widget _buildFolderSliverList(List folders, bool hasPlaylistsAfter) {
    return SliverList.builder(
      itemCount: folders.length,
      itemBuilder: (BuildContext context, index) {
        final folder = folders[index];
        final isLastFolder = index == folders.length - 1;
        final borderRadius = isLastFolder && !hasPlaylistsAfter
            ? commonCustomBarRadiusLast
            : BorderRadius.zero;
        return PlaylistBar(
          folder['name'],
          playlistData: folder,
          borderRadius: borderRadius,
          onDelete: () => _showDeleteFolderDialog(folder),
        );
      },
    );
  }

  Widget _buildPlaylistListView(
    BuildContext context,
    List playlists, {
    bool isOfflinePlaylists = false,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: playlists.length,
      padding: EdgeInsets.zero,
      itemBuilder: (BuildContext context, index) {
        final playlist = playlists[index];
        final borderRadius = getItemBorderRadius(
          index,
          playlists.length,
        );
        return PlaylistBar(
          key: listItemKey('library_playlist', index, playlist),
          playlist['title'],
          playlistId: playlist['ytid'],
          playlistArtwork: playlist['image'],
          isAlbum: playlist['isAlbum'],
          playlistData:
              playlist['source'] == 'user-created' ||
                  playlist['source'] == 'user-youtube' ||
                  isOfflinePlaylists
              ? playlist
              : null,
          onDelete:
              playlist['source'] == 'user-created' ||
                  playlist['source'] == 'user-youtube' ||
                  isOfflinePlaylists
              ? () => isOfflinePlaylists
                    ? _showRemoveOfflinePlaylistDialog(playlist)
                    : _showRemovePlaylistDialog(playlist)
              : null,
          borderRadius: borderRadius,
        );
      },
    );
  }

  void _showRemoveOfflinePlaylistDialog(Map playlist) {
    final playlistId = playlist['ytid']?.toString() ?? '';
    if (playlistId.isEmpty) return;
    showRemoveOfflinePlaylistDialog(context, playlistId);
  }

  void _showRemovePlaylistDialog(Map playlist) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage: context.l10n!.removePlaylistQuestion,
        submitMessage: context.l10n!.remove,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSubmit: () {
          Navigator.of(context).pop();

          final playlistId = playlist['ytid']?.toString() ?? '';

          if (playlistId.isEmpty) {
            logger.log('Playlist ID is missing, cannot remove playlist.');
            showToast(context, context.l10n!.error);
            return;
          }

          removeUserPlaylistEntry(playlist);
          if (offlinePlaylistService.isPlaylistDownloaded(playlistId)) {
            unawaited(offlinePlaylistService.removeOfflinePlaylist(playlistId));
          }
        },
      );
    },
  );

  void _showCreateFolderDialog() => showDialog(
    context: context,
    builder: (BuildContext context) {
      var folderName = '';
      final colorScheme = Theme.of(context).colorScheme;

      return AlertDialog(
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            FluentIcons.folder_add_24_regular,
            color: colorScheme.primary,
            size: 32,
          ),
        ),
        title: Text(
          context.l10n!.createFolder,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: TextField(
          decoration: InputDecoration(
            labelText: context.l10n!.folderName,
            hintText: context.l10n!.newFolder,
            prefixIcon: Icon(
              FluentIcons.folder_20_regular,
              color: colorScheme.onSurfaceVariant,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
          ),
          onChanged: (value) {
            folderName = value;
          },
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: <Widget>[
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
            onPressed: () {
              if (folderName.trim().isNotEmpty) {
                final result = createPlaylistFolder(folderName.trim(), context);
                showToast(context, result);
              } else {
                showToast(context, context.l10n!.enterFolderName);
              }
              Navigator.pop(context);
            },
            icon: const Icon(FluentIcons.add_20_regular),
            label: Text(context.l10n!.create),
          ),
        ],
      );
    },
  );

  void _showDeleteFolderDialog(Map folder) => showDialog(
    context: context,
    builder: (BuildContext context) {
      return ConfirmationDialog(
        confirmationMessage: context.l10n!.deleteFolderQuestion,
        submitMessage: context.l10n!.delete,
        onCancel: () {
          Navigator.of(context).pop();
        },
        onSubmit: () {
          final result = deletePlaylistFolder(folder['id'], context);
          Navigator.of(context).pop();
          showToast(context, result);
        },
      );
    },
  );
}
