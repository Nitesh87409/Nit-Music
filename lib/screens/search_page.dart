import 'dart:async';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:musify/constants/app_constants.dart';
import 'package:musify/extensions/l10n.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/router_service.dart';
import 'package:musify/services/search_recommendation_service.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
import 'package:musify/widgets/custom_bar.dart';
import 'package:musify/widgets/custom_search_bar.dart';
import 'package:musify/widgets/mini_player_bottom_space.dart';
import 'package:musify/widgets/playlist_bar.dart';
import 'package:musify/widgets/section_title.dart';
import 'package:musify/widgets/song_bar.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  _SearchPageState createState() => _SearchPageState();
}

// Global ValueNotifier for search history to make it reactive
final ValueNotifier<List> searchHistoryNotifier = ValueNotifier<List>(
  Hive.box('user').get('searchHistory', defaultValue: []),
);

// Backward compatibility - keep the global variable for existing code
List get searchHistory => searchHistoryNotifier.value;
set searchHistory(List value) {
  searchHistoryNotifier.value = value;
}

void reloadSearchHistoryFromStorage() {
  searchHistoryNotifier.value = Hive.box(
    'user',
  ).get('searchHistory', defaultValue: []);
}

// ─── Mood Chip definitions ───
const List<Map<String, String>> _moodChips = [
  {'label': '🎧 Workout', 'query': 'workout songs'},
  {'label': '💔 Sad', 'query': 'sad songs hindi'},
  {'label': '🚗 Drive', 'query': 'drive songs'},
  {'label': '🔥 Trending', 'query': 'trending songs'},
  {'label': '🧘 Lofi', 'query': 'lofi songs'},
  {'label': '🎉 Party', 'query': 'party songs'},
  {'label': '🙏 Bhakti', 'query': 'bhakti songs hindi'},
  {'label': '🎵 Bollywood', 'query': 'bollywood hits'},
];

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  int _latestSuggestionRequest = 0;

  // Smart recommendations
  List<dynamic> _recommendations = [];
  bool _isLoadingRecommendations = true;

  // History visibility (Google-style: show only on focus)
  bool _isHistoryVisible = false;

  @override
  void initState() {
    super.initState();
    _inputNode.addListener(_onFocusChange);
    _loadRecommendations();
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isHistoryVisible = _inputNode.hasFocus;
      });
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final results = await getSmartSearchRecommendations();
      if (mounted) {
        setState(() {
          _recommendations = results;
          _isLoadingRecommendations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  Future<void> _submitSearch([String? query]) async {
    if (query != null) {
      _searchBar.text = query;
      _searchBar.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchBar.text.length),
      );
    }

    _latestSuggestionRequest++;
    _debounce?.cancel();
    _suggestionsList = [];
    if (mounted) setState(() {});

    await search();
    _inputNode.unfocus();
  }

  @override
  void dispose() {
    _inputNode.removeListener(_onFocusChange);
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingSongs.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> search() async {
    final query = _searchBar.text;

    if (query.isEmpty) {
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _suggestionsList = [];
      if (mounted) setState(() {});
      return;
    }
    _fetchingSongs.value = true;

    if (!searchHistory.contains(query)) {
      final updatedHistory = List.from(searchHistory)..insert(0, query);
      searchHistoryNotifier.value = updatedHistory;
      unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));
    }

    // Update search frequency for smart recommendations
    unawaited(updateSearchFrequency(query));

    try {
      final results = await Future.wait<List<dynamic>>([
        fetchSongsList(query).timeout(const Duration(seconds: 8), onTimeout: () => []),
        searchArtists(query).timeout(const Duration(seconds: 2), onTimeout: () => []),
        getPlaylists(query: query, type: 'album').timeout(const Duration(seconds: 2), onTimeout: () => []),
        getPlaylists(query: query, type: 'playlist').timeout(const Duration(seconds: 2), onTimeout: () => []),
      ]);

      _songsSearchResult = results[0];
      _artistsSearchResult = results[1]
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      if (_songsSearchResult.isEmpty && _artistsSearchResult.isNotEmpty) {
        _songsSearchResult = await _fetchSongsForResolvedArtist(query);
      }
      _albumsSearchResult = results[2];
      _playlistsSearchResult = results[3];
    } catch (e, stackTrace) {
      logger.log(
        'Error while searching online songs',
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      _fetchingSongs.value = false;
      if (mounted) setState(() {});
    }
  }

  Future<List<dynamic>> _fetchSongsForResolvedArtist(String query) async {
    final artistName = _artistsSearchResult.first['title']?.toString().trim();
    if (artistName == null || artistName.isEmpty) return [];

    final fallbackQueries = <String>{
      if (artistName.toLowerCase() != query.trim().toLowerCase()) artistName,
      '$artistName songs',
      '$artistName music',
    };

    for (final fallbackQuery in fallbackQueries) {
      final songs = await fetchSongsList(fallbackQuery);
      if (songs.isNotEmpty) return songs;
    }

    return [];
  }

  bool get _hasSearchResults =>
      _songsSearchResult.isNotEmpty ||
      _artistsSearchResult.isNotEmpty ||
      _albumsSearchResult.isNotEmpty ||
      _playlistsSearchResult.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n!.search)),
      body: GestureDetector(
        onTap: _inputNode.unfocus,
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          padding: commonSingleChildScrollViewPadding,
          child: Column(
            children: <Widget>[
              // ─── Search Bar ───
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  final bar = ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? 600 : double.infinity,
                    ),
                    child: CustomSearchBar(
                      loadingProgressNotifier: _fetchingSongs,
                      controller: _searchBar,
                      focusNode: _inputNode,
                      labelText: '${context.l10n!.search}...',
                      onChanged: (value) {
                        // debounce suggestions to avoid rapid API calls
                        _debounce?.cancel();
                        final query = value;
                        final requestId = ++_latestSuggestionRequest;

                        // Clear suggestions immediately if input is empty
                        if (query.isEmpty) {
                          _suggestionsList = [];
                          if (mounted) setState(() {});
                          return;
                        }

                        _debounce = Timer(
                          const Duration(milliseconds: 300),
                          () async {
                            final searchSuggestions = await getSearchSuggestions(
                              query,
                            );

                            if (!mounted ||
                                requestId != _latestSuggestionRequest ||
                                _searchBar.text != query) {
                              return;
                            }

                            _suggestionsList = List<String>.from(
                              searchSuggestions,
                            );
                            if (mounted) setState(() {});
                          },
                        );
                      },
                      onSubmitted: (String value) {
                        _submitSearch();
                      },
                    ),
                  );
                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [bar],
                    );
                  } else {
                    return bar;
                  }
                },
              ),

              // ─── Main Content Area ───
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _suggestionsList.isNotEmpty
                    // Show API suggestions when user is typing
                    ? _buildSuggestionsList(colorScheme)
                    : _hasSearchResults
                        // Show search results
                        ? _buildSearchResults(context, primaryColor)
                        // Show home screen (history dropdown + chips + recommendations)
                        : _buildHomeContent(context, primaryColor, colorScheme),
              ),
              const MiniPlayerBottomSpace(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Suggestions List (while typing) ───
  Widget _buildSuggestionsList(ColorScheme colorScheme) {
    return Column(
      key: ValueKey('suggestions-${_suggestionsList.length}-${_searchBar.text}'),
      children: [
        for (int index = 0; index < _suggestionsList.length; index++)
          Builder(
            builder: (context) {
              final query = _suggestionsList[index];
              final borderRadius = getItemBorderRadius(
                index,
                _suggestionsList.length,
              );
              return CustomBar(
                query,
                FluentIcons.search_24_regular,
                borderRadius: borderRadius,
                onTap: () async {
                  await _submitSearch(query);
                },
              );
            },
          ),
      ],
    );
  }

  // ─── Home Content (no search results, empty search bar) ───
  Widget _buildHomeContent(
    BuildContext context,
    Color primaryColor,
    ColorScheme colorScheme,
  ) {
    return Column(
      key: const ValueKey('home-content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Compact Google-style History Dropdown (only on focus) ───
        _buildCompactHistory(colorScheme),

        // ─── Mood & Genre Chips ───
        _buildMoodChips(colorScheme),

        // ─── Smart Recommendations ───
        _buildRecommendations(primaryColor),
      ],
    );
  }

  // ─── Compact Search History (Google-style) ───
  Widget _buildCompactHistory(ColorScheme colorScheme) {
    return ValueListenableBuilder<List>(
      valueListenable: searchHistoryNotifier,
      builder: (context, history, _) {
        if (!_isHistoryVisible || history.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show max 6 compact items
        final displayItems = history.take(6).toList();

        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < displayItems.length; i++)
                  InkWell(
                    onTap: () async {
                      await _submitSearch(displayItems[i].toString());
                    },
                    onLongPress: () async {
                      final confirm =
                          await _showConfirmationDialog(context) ?? false;
                      if (confirm && history.contains(displayItems[i])) {
                        final updatedHistory = List.from(history)
                          ..remove(displayItems[i]);
                        searchHistoryNotifier.value = updatedHistory;
                        unawaited(
                          addOrUpdateData<List>(
                            'user',
                            'searchHistory',
                            updatedHistory,
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            FluentIcons.history_24_regular,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              displayItems[i].toString(),
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Insert text into search bar
                              _searchBar.text = displayItems[i].toString();
                              _searchBar.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                  offset: _searchBar.text.length,
                                ),
                              );
                            },
                            child: Icon(
                              FluentIcons.arrow_upload_24_regular,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Clear All button
                if (displayItems.length > 2)
                  InkWell(
                    onTap: () async {
                      final confirm =
                          await _showConfirmationDialog(context) ?? false;
                      if (confirm) {
                        searchHistoryNotifier.value = [];
                        unawaited(
                          addOrUpdateData<List>(
                            'user',
                            'searchHistory',
                            [],
                          ),
                        );
                      }
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FluentIcons.delete_24_regular,
                            size: 16,
                            color: Color(0xFF8B5CF6),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Clear All',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Mood & Genre Chips ───
  Widget _buildMoodChips(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _moodChips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final chip = _moodChips[index];
            return ActionChip(
              label: Text(
                chip['label']!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              backgroundColor: colorScheme.surfaceContainerHigh,
              side: BorderSide(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () async {
                await _submitSearch(chip['query'] ?? '');
              },
            );
          },
        ),
      ),
    );
  }

  // ─── Smart Recommendations Section ───
  Widget _buildRecommendations(Color primaryColor) {
    if (_isLoadingRecommendations) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            children: [
              const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Loading recommendations...',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Recommended For You',
          primaryColor,
          icon: FluentIcons.star_24_filled,
        ),
        for (var index = 0; index < _recommendations.length; index++)
          SongBar(
            _recommendations[index],
            true,
            key: ValueKey('rec_song_$index'),
            showMusicDuration: true,
            borderRadius: getItemBorderRadius(index, _recommendations.length),
          ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, Color primaryColor) {
    final widgets = <Widget>[];

    // Artists section
    if (_artistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.artists,
          primaryColor,
          icon: FluentIcons.person_24_filled,
        ),
      );

      final artists = _artistsSearchResult.take(3).toList();
      for (var index = 0; index < artists.length; index++) {
        final artist = Map<String, dynamic>.from(artists[index]);
        final artistId =
            artist['ytid']?.toString() ?? artist['title']?.toString() ?? '';
        if (artistId.isEmpty) continue;

        final borderRadius = getItemBorderRadius(index, artists.length);
        widgets.add(
          ArtistBar(
            key: listItemKey('search_artist', index, artist),
            artist: artist,
            borderRadius: borderRadius,
            onTap: () {
              context.push(
                '${NavigationManager.searchPath}/artist/${Uri.encodeComponent(artistId)}',
                extra: artist,
              );
            },
          ),
        );
      }
    }

    // Songs section
    if (_songsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.songs,
          primaryColor,
          icon: FluentIcons.music_note_1_24_filled,
        ),
      );

      final songsCount = _songsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _songsSearchResult.length;

      for (var index = 0; index < songsCount; index++) {
        final song = _songsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, songsCount);
        widgets.add(
          SongBar(
            song,
            true,
            key: listItemKey('search_song', index, song),
            showMusicDuration: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Albums section
    if (_albumsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.albums,
          primaryColor,
          icon: FluentIcons.album_24_filled,
        ),
      );

      final albumsCount = _albumsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _albumsSearchResult.length;

      for (var index = 0; index < albumsCount; index++) {
        final playlist = _albumsSearchResult[index];
        final borderRadius = getItemBorderRadius(index, albumsCount);

        widgets.add(
          PlaylistBar(
            key: listItemKey('search_album', index, playlist),
            playlist['title'],
            playlistId: playlist['ytid'],
            playlistArtwork: playlist['image'],
            cubeIcon: FluentIcons.cd_16_filled,
            isAlbum: true,
            borderRadius: borderRadius,
          ),
        );
      }
    }

    // Playlists section
    if (_playlistsSearchResult.isNotEmpty) {
      widgets.add(
        SectionTitle(
          context.l10n!.playlists,
          primaryColor,
          icon: FluentIcons.text_bullet_list_24_filled,
        ),
      );

      final playlistsCount = _playlistsSearchResult.length > maxSongsInList
          ? maxSongsInList
          : _playlistsSearchResult.length;

      for (var index = 0; index < playlistsCount; index++) {
        final playlist = _playlistsSearchResult[index];
        final isLast = index == playlistsCount - 1;
        final borderRadius = getItemBorderRadius(index, playlistsCount);

        widgets.add(
          Padding(
            padding: isLast ? commonListViewBottomPadding : EdgeInsets.zero,
            child: PlaylistBar(
              key: listItemKey('search_playlist', index, playlist),
              playlist['title'],
              playlistId: playlist['ytid'],
              playlistArtwork: playlist['image'],
              cubeIcon: FluentIcons.apps_list_24_filled,
              borderRadius: borderRadius,
            ),
          ),
        );
      }
    }

    return Column(
      key: ValueKey(
        'results-${_songsSearchResult.length}-${_artistsSearchResult.length}-${_albumsSearchResult.length}-${_playlistsSearchResult.length}',
      ),
      children: widgets,
    );
  }

  Future<bool?> _showConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return ConfirmationDialog(
          confirmationMessage: context.l10n!.removeSearchQueryQuestion,
          submitMessage: context.l10n!.confirm,
          onCancel: () {
            Navigator.of(context).pop(false);
          },
          onSubmit: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );
  }
}
