import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/artist_service.dart' show fetchMoreArtistSongs;
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/formatter.dart';
import 'package:musify/utilities/flutter_toast.dart';
import 'package:musify/utilities/playlist_utils.dart';
import 'package:musify/utilities/song_filtering.dart';
import 'package:musify/utilities/sort_utils.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_page/empty_playlist_state.dart';
import 'package:musify/widgets/song_bar.dart';
import 'package:musify/widgets/spinner.dart';
import 'package:palette_generator/palette_generator.dart';

enum PlaylistSortType { default_, title, artist }

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({
    super.key,
    this.playlistId,
    this.playlistData,
    this.cubeIcon = FluentIcons.text_bullet_list_24_filled,
    this.isArtist = false,
  });

  final String? playlistId;
  final dynamic playlistData;
  final IconData cubeIcon;
  final bool isArtist;

  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  dynamic _playlist;
  late List<dynamic> _originalPlaylistList; // Keep original order separately

  late final playlistLikeStatus = ValueNotifier<bool>(
    isPlaylistAlreadyLiked(_resolvedPlaylistId),
  );
  bool playlistOfflineStatus = false;
  bool _isInitializingPlaylist = true;

  // Dynamic colors extracted from artwork
  Color? _dominantColor;
  Color? _vibrantColor;
  bool _isLoadingMoreArtistSongs = false;

  String? get _resolvedPlaylistId =>
      _playlist?['ytid']?.toString() ??
      widget.playlistData?['ytid']?.toString() ??
      widget.playlistId;

  // Sorting
  late PlaylistSortType _sortType = PlaylistSortType.values.firstWhere(
    (e) => e.name == playlistSortSetting,
    orElse: () => PlaylistSortType.default_,
  );

  // Search
  final ValueNotifier<String> _searchQueryNotifier = ValueNotifier('');
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _getSourceList(String searchQuery) {
    final list = _playlist?['list'] as List<dynamic>? ?? [];
    return filterSongsByQuery(list, searchQuery);
  }

  bool get _isArtistCatalogLoading =>
      widget.isArtist && _playlist?['catalogStatus'] == 'loading';

  bool get _isArtistCatalogFailed =>
      widget.isArtist && _playlist?['catalogStatus'] == 'failed';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _scrollController.addListener(_onScroll);
    userLikedPlaylists.addListener(_syncPlaylistLikeStatus);
    _initializePlaylist();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      if (widget.isArtist && !_isLoadingMoreArtistSongs) {
        _loadMoreArtistSongs();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    userLikedPlaylists.removeListener(_syncPlaylistLikeStatus);
    playlistLikeStatus.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchQueryNotifier.dispose();
    super.dispose();
  }

  void _syncPlaylistLikeStatus() {
    final newStatus = isPlaylistAlreadyLiked(_resolvedPlaylistId);
    if (playlistLikeStatus.value != newStatus) {
      playlistLikeStatus.value = newStatus;
    }
  }

  Future<void> _initializePlaylist() async {
    try {
      final initialPlaylist = widget.playlistData;
      final resolvedId =
          initialPlaylist?['ytid']?.toString() ?? widget.playlistId;

      if (initialPlaylist != null) {
        _playlist = initialPlaylist;
        final playlistList = _playlist?['list'] as List?;
        final shouldFetchInitialPlaylist =
            playlistList == null || (!widget.isArtist && playlistList.isEmpty);
        if (shouldFetchInitialPlaylist && resolvedId != null) {
          _playlist =
              await getPlaylistInfoForWidget(
                resolvedId,
                isArtist: widget.isArtist,
                isAlbum: initialPlaylist?['isAlbum'] == true,
                artistName: initialPlaylist?['title']?.toString(),
                artistImage: initialPlaylist?['image']?.toString(),
                sourceSongId: initialPlaylist?['sourceSongId']?.toString(),
                sourceVideoAuthor: initialPlaylist?['videoAuthor']?.toString(),
                preferredVerified: initialPlaylist?['isVerifiedArtist'] == true,
              ) ??
              initialPlaylist;
        }
      } else {
        _playlist = await getPlaylistInfoForWidget(
          resolvedId,
          isArtist: widget.isArtist,
          isAlbum: widget.playlistData?['isAlbum'] == true,
          artistName: initialPlaylist?['title']?.toString(),
          artistImage: initialPlaylist?['image']?.toString(),
          sourceSongId: initialPlaylist?['sourceSongId']?.toString(),
          sourceVideoAuthor: initialPlaylist?['videoAuthor']?.toString(),
          preferredVerified: initialPlaylist?['isVerifiedArtist'] == true,
        );
      }

      if (_playlist != null && _playlist['list'] != null) {
        _originalPlaylistList = List<dynamic>.from(_playlist['list'] as List);
        _sortPlaylist(_sortType);
        _syncPlaylistLikeStatus();
      }

      // Extract colors from artwork
      _extractPaletteFromPlaylist();
    } catch (e, stackTrace) {
      logger.log(
        'Error initializing playlist:',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        showToast(context, context.l10n!.error);
      }
    } finally {
      _isInitializingPlaylist = false;
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _extractPaletteFromPlaylist() {
    if (_playlist == null) return;
    String? imageUrl = _playlist['image']?.toString();
    if (widget.isArtist) {
      imageUrl = normalizeArtistThumbnailUrl(imageUrl);
    }
    if (imageUrl == null || imageUrl.isEmpty) return;

    PaletteGenerator.fromImageProvider(
      ResizeImage(NetworkImage(imageUrl), width: 80, height: 80),
      maximumColorCount: 6,
      timeout: const Duration(seconds: 5),
    ).then((palette) {
      if (mounted) {
        setState(() {
          _dominantColor = palette.dominantColor?.color;
          _vibrantColor = palette.vibrantColor?.color ??
              palette.mutedColor?.color ??
              palette.dominantColor?.color;
        });
      }
    }).catchError((_) {});
  }

  Future<void> _loadMoreArtistSongs() async {
    if (_isLoadingMoreArtistSongs || !widget.isArtist) return;

    final unfetchedReleases = _playlist['unfetchedReleases'] as List<dynamic>?;
    if (unfetchedReleases == null || unfetchedReleases.isEmpty) {
      setState(() {
        _playlist['isCatalogComplete'] = true;
      });
      return;
    }

    setState(() {
      _isLoadingMoreArtistSongs = true;
    });

    try {
      final result = await fetchMoreArtistSongs(
        artistId: _playlist['ytid']?.toString() ?? '',
        artistName: _playlist['title']?.toString() ?? '',
        unfetchedReleases: unfetchedReleases,
      );

      if (mounted) {
        setState(() {
          final currentList = _playlist['list'] as List<dynamic>? ?? [];
          _playlist['list'] = [...currentList, ...result.newSongs];
          _playlist['unfetchedReleases'] = result.remainingReleases;
          if (result.remainingReleases.isEmpty) {
            _playlist['isCatalogComplete'] = true;
          }
          _originalPlaylistList = List<dynamic>.from(_playlist['list']);
        });

        // Update cache so subsequent opens have this data
        final cacheKey = 'artist_$_resolvedPlaylistId';
        await addOrUpdateData<Map>('cache', cacheKey, _playlist);
      }
    } catch (e, stack) {
      logger.log('Error loading more artist songs', error: e, stackTrace: stack);
      if (mounted) {
        showToast(context, context.l10n!.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMoreArtistSongs = false;
        });
      }
    }
  }

  Widget _buildLoadMoreButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: _isLoadingMoreArtistSongs
            ? const Spinner()
            : FilledButton.tonal(
                onPressed: _loadMoreArtistSongs,
                child: const Text('Load More'),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = _vibrantColor ?? _dominantColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Dynamic gradient background
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _vibrantColor?.withValues(alpha: 0.4) ?? colorScheme.surface,
                    _dominantColor?.withValues(alpha: 0.25) ?? colorScheme.surface,
                    colorScheme.surface,
                  ],
                  stops: const [0.0, 0.3, 0.7],
                ),
              ),
            ),
          ),
          // Content
          _isInitializingPlaylist
              ? Column(
                  children: [
                    AppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(FluentIcons.arrow_left_24_regular),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Expanded(child: Spinner()),
                  ],
                )
              : _playlist != null
              ? CustomScrollView(
                  controller: _scrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // AppBar
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        icon: const Icon(FluentIcons.arrow_left_24_regular),
                        onPressed: () =>
                            Navigator.pop(context, widget.playlistData == _playlist),
                        tooltip: context.l10n!.back,
                      ),
                      actions: [
                        IconButton(
                          icon: const Icon(FluentIcons.more_vertical_24_regular),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    // Header section
                    SliverToBoxAdapter(
                      child: _buildHeader(accentColor),
                    ),
                    // Buttons
                    SliverToBoxAdapter(
                      child: _buildButtons(accentColor),
                    ),
                    // Tabs + Sort (for artists: Songs/Albums/About)
                    SliverToBoxAdapter(
                      child: _buildTabsAndSort(accentColor),
                    ),
                    // Song list
                    if ((_playlist['list'] as List? ?? const []).isNotEmpty) ...[
                      ValueListenableBuilder<String>(
                        valueListenable: _searchQueryNotifier,
                        builder: (context, searchQuery, _) {
                          final sourceList = _getSourceList(searchQuery);
                          final showLoadMore = widget.isArtist &&
                             (_playlist['unfetchedReleases'] as List<dynamic>? ?? []).isNotEmpty &&
                             searchQuery.isEmpty;

                          return SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 10).add(commonListViewBottomPadding),
                            sliver: SliverList.builder(
                              itemCount: sourceList.length + (showLoadMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (showLoadMore && index == sourceList.length) {
                                  return _buildLoadMoreButton();
                                }

                                final isRemovable =
                                    _playlist['source'] == 'user-created';
                                return _buildSongListItem(
                                  sourceList[index],
                                  index,
                                  isRemovable,
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ] else if (_isArtistCatalogLoading)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: SizedBox(
                            height: MediaQuery.sizeOf(context).height * 0.3,
                            child: const Spinner(),
                          ),
                        ),
                      )
                    else if (_isArtistCatalogFailed)
                      EmptyPlaylistState(message: context.l10n!.error)
                    else
                      EmptyPlaylistState(
                        message: context.l10n!.noSongsInPlaylist,
                      ),
                    const SliverMiniPlayerBottomSpace(),
                  ],
                )
              : CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                    EmptyPlaylistState(message: context.l10n!.error),
                    const SliverMiniPlayerBottomSpace(),
                  ],
                ),
        ],
      ),
    );
  }

  // ──────────────────── HEADER: Image LEFT, Info RIGHT ────────────────────

  Widget _buildHeader(Color? accentColor) {
    final theme = Theme.of(context);
    final songsLength = (_playlist['list'] as List? ?? const []).length;
    final playlistTitle = widget.isArtist
        ? normalizeArtistDisplayTitle(_playlist['title']?.toString() ?? '')
        : _playlist['title']?.toString() ?? '';

    final imageSize = 120.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Circular image with gradient ring ──
          _buildRingedImage(imageSize, accentColor),
          const SizedBox(width: 20),
          // ── Info column ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  playlistTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Type label
                Text(
                  widget.isArtist
                      ? context.l10n!.artist
                      : (_playlist['isAlbum'] == true
                          ? context.l10n!.album
                          : context.l10n!.playlist),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                // Stats row
                Row(
                  children: [
                    _buildStat(
                      '$songsLength',
                      context.l10n!.songs,
                      accentColor,
                    ),
                    const SizedBox(width: 16),
                    if (_playlist['fan_count'] != null || _playlist['listeners'] != null)
                      _buildStat(
                        _formatCount(
                          _playlist['fan_count']?.toString() ??
                          _playlist['listeners']?.toString() ?? '0',
                        ),
                        'Listeners',
                        accentColor,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Tagline / description chip
                if (_playlist['subtitle'] != null &&
                    _playlist['subtitle'].toString().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _playlist['subtitle'].toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingedImage(double size, Color? accentColor) {
    final ringColor = accentColor ?? Theme.of(context).colorScheme.primary;
    final imageUrl = widget.isArtist
        ? normalizeArtistThumbnailUrl(_playlist['image']?.toString())
        : _playlist['image']?.toString();
    final isCircle = widget.isArtist;
    final thumbWidth = isCircle ? size : 160.0;
    final thumbHeight = isCircle ? size : 90.0;
    final borderWidth = 3.0;

    return Container(
      width: thumbWidth,
      height: thumbHeight,
      decoration: BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ringColor,
            ringColor.withValues(alpha: 0.5),
            ringColor.withValues(alpha: 0.8),
          ],
        ),
      ),
      padding: EdgeInsets.all(borderWidth),
      child: ClipRRect(
        borderRadius: isCircle
            ? BorderRadius.circular(size / 2)
            : BorderRadius.circular(11),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                width: thumbWidth - borderWidth * 2,
                height: thumbHeight - borderWidth * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholderImage(
                  thumbWidth - borderWidth * 2,
                  thumbHeight - borderWidth * 2,
                ),
              )
            : _buildPlaceholderImage(
                thumbWidth - borderWidth * 2,
                thumbHeight - borderWidth * 2,
              ),
      ),
    );
  }

  Widget _buildPlaceholderImage(double width, double height) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHigh,
      child: Icon(
        widget.cubeIcon,
        size: height * 0.4,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildStat(String value, String label, Color? accentColor) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: accentColor ?? theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatCount(String count) {
    final n = int.tryParse(count) ?? 0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return count;
  }

  // ──────────────────── BUTTONS: Play All | Shuffle ────────────────────

  Widget _buildButtons(Color? accentColor) {
    final songsLength = (_playlist['list'] as List? ?? const []).length;
    if (songsLength == 0) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final playBg = accentColor ?? colorScheme.primary;
    final playFg = ThemeData.estimateBrightnessForColor(playBg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: playBg,
                foregroundColor: playFg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(FluentIcons.play_24_filled, size: 20),
              label: Text(
                context.l10n!.play,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () => audioHandler.playPlaylistSong(
                playlist: _playlist,
                songIndex: 0,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                foregroundColor: colorScheme.onSurface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(FluentIcons.arrow_shuffle_24_regular, size: 20),
              label: Text(
                context.l10n!.shuffle,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: () async {
                final songs = _playlist['list'] as List? ?? [];
                if (songs.isEmpty) return;
                final shuffled = List<Map>.from(songs.whereType<Map>())
                  ..shuffle();
                await audioHandler.addPlaylistToQueue(
                  shuffled,
                  replace: true,
                  startIndex: 0,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────── TABS: Songs | Albums | About + Sort ────────────────────

  Widget _buildTab(String title, bool isSelected, Color? accentColor) {
    final theme = Theme.of(context);
    final color = isSelected
        ? (accentColor ?? theme.colorScheme.primary)
        : theme.colorScheme.onSurfaceVariant;
    
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isSelected ? (accentColor ?? theme.colorScheme.primary) : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildTabsAndSort(Color? accentColor) {
    final songsLength = (_playlist['list'] as List? ?? const []).length;
    final isUserCreated = _playlist['source'] == 'user-created';

        (widget.playlistId != null && !isUserCreated && !offlineMode.value) ||
        !offlineMode.value ||
        isUserCreated;

    return Column(
      children: [
        // Tab row with sort
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // "Songs" tab (always active for now)
              _buildTab(context.l10n!.songs, true, accentColor),
              if (widget.isArtist) ...[
                const SizedBox(width: 24),
                _buildTab(context.l10n!.album, false, accentColor),
                const SizedBox(width: 24),
                _buildTab('About', false, accentColor),
              ],
              const Spacer(),
              // Sort dropdown
              if (songsLength > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PopupMenuButton<PlaylistSortType>(
                    initialValue: _sortType,
                    onSelected: (type) {
                      setState(() {
                        _sortType = type;
                        addOrUpdateData<String>(
                          'settings',
                          'playlistSortType',
                          type.name,
                        );
                        playlistSortSetting = type.name;
                        _sortPlaylist(type);
                      });
                    },
                    itemBuilder: (context) => PlaylistSortType.values.map((type) {
                      return PopupMenuItem(
                        value: type,
                        child: Text(_getSortTypeDisplayText(type)),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FluentIcons.filter_24_regular,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getSortTypeDisplayText(_sortType),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _updateSongsListOnRemove(int indexOfRemovedSong, dynamic songToRemove) {
    _originalPlaylistList.removeWhere((s) => s['ytid'] == songToRemove['ytid']);
    final playlistId = _playlist['ytid'];
    if (mounted) {
      setState(() {});
      showToastWithButton(
        context,
        context.l10n!.songRemoved,
        context.l10n!.undo.toUpperCase(),
        () {
          addSongInCustomPlaylist(
            context,
            playlistId,
            songToRemove,
            indexToInsert: indexOfRemovedSong,
          );
          if (mounted) setState(() {});
        },
      );
    } else {
      logger.log(
        '(_updateSongsListOnRemove): Widget not mounted, cannot show undo toast.',
      );
    }
  }

  String _getSortTypeDisplayText(PlaylistSortType type) {
    switch (type) {
      case PlaylistSortType.default_:
        return context.l10n!.default_;
      case PlaylistSortType.title:
        return context.l10n!.name;
      case PlaylistSortType.artist:
        return context.l10n!.artist;
    }
  }

  void _sortPlaylist(PlaylistSortType type) {
    if (_playlist == null || _playlist['list'] == null) return;

    switch (type) {
      case PlaylistSortType.default_:
        // Restore original order from backup
        _playlist['list'] = List<dynamic>.from(_originalPlaylistList);
        break;
      case PlaylistSortType.title:
        final playlist = List<dynamic>.from(_playlist['list']);
        sortSongsByKey(playlist, 'title');
        _playlist['list'] = playlist;
        break;
      case PlaylistSortType.artist:
        final playlist = List<dynamic>.from(_playlist['list']);
        sortSongsByKey(playlist, 'artist');
        _playlist['list'] = playlist;
        break;
    }
  }

  Widget _buildSongListItem(dynamic song, int index, bool isRemovable) {
    final sourceList = _getSourceList(_searchQueryNotifier.value);
    final totalItems = sourceList.length;
    final borderRadius = getItemBorderRadius(index, totalItems);
    final isUserCreatedPlaylist = _playlist?['source'] == 'user-created';
    final playlistId = isUserCreatedPlaylist ? _playlist!['ytid'] : null;
    final isSearching = _searchQueryNotifier.value.isNotEmpty;
    final fullIndex = isSearching
        ? PlaylistUtils.findSongIndexByYtid(_playlist, song['ytid'])
        : index;

    if (isSearching && fullIndex == -1) {
      logger.log('Warning: Song ${song['ytid']} not found in full playlist');
    }

    return SongBar(
      song,
      true,
      key: listItemKey('playlist_song', index, song),
      onRemove: (isRemovable && !isSearching)
          ? () {
              if (removeSongFromPlaylist(
                _playlist,
                song,
                removeOneAtIndex: index,
              )) {
                _updateSongsListOnRemove(index, song);
              }
            }
          : null,
      onPlay: () {
        audioHandler.playPlaylistSong(
          playlist: _playlist,
          songIndex: fullIndex != -1 ? fullIndex : index,
        );
      },
      borderRadius: borderRadius,
      playlistId: playlistId,
      onRenamed: () => setState(() {}),
    );
  }
}
