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
import 'package:musify/screens/bottom_navigation_page.dart';
import 'package:musify/widgets/skeleton_loader.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/widgets/artist_bar.dart';
import 'package:musify/widgets/confirmation_dialog.dart';
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
  {'label': 'Workout', 'query': 'workout songs'},
  {'label': 'Sad', 'query': 'sad songs hindi'},
  {'label': 'Drive', 'query': 'drive songs'},
  {'label': 'Trending', 'query': 'trending songs'},
  {'label': 'Lofi', 'query': 'lofi songs'},
  {'label': 'Party', 'query': 'party songs'},
  {'label': 'Bhakti', 'query': 'bhakti songs hindi'},
  {'label': 'Bollywood', 'query': 'bollywood hits'},
];

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchBar = TextEditingController();
  final FocusNode _inputNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _fetchingSongs = ValueNotifier(false);
  bool _isLoadingMoreSongs = false;
  dynamic _songsNextPage;
  int maxSongsInList = 15;
  List<dynamic> _songsSearchResult = [];
  List<Map<String, dynamic>> _artistsSearchResult = [];
  List<dynamic> _albumsSearchResult = [];
  List<dynamic> _playlistsSearchResult = [];
  List<String> _suggestionsList = [];
  Timer? _debounce;
  Timer? _liveSearchDebounce;
  int _latestSuggestionRequest = 0;
  int _latestLiveSearchRequest = 0;

  // Search Stack (Industry back navigation)
  final List<String> _searchStack = [];
  bool _isHandlingBack = false;

  // Search filters
  final List<Map<String, String>> _searchFilters = [
    {'label': 'All', 'value': 'All'},
    {'label': 'Songs', 'value': 'Songs'},
    {'label': 'Artists', 'value': 'Artists'},
    {'label': 'Albums', 'value': 'Albums'},
    {'label': 'Playlists', 'value': 'Playlists'},
  ];
  String _activeFilter = 'All';

  // Smart recommendations
  List<dynamic> _recommendations = [];
  bool _isLoadingRecommendations = true;

  // History visibility (Google-style: show only on focus)
  bool _isHistoryVisible = false;

  @override
  void initState() {
    super.initState();
    _inputNode.addListener(_onFocusChange);
    _scrollController.addListener(_onScroll);
    searchTabReselectNotifier.addListener(_onReselectTab);
    _loadRecommendations();
  }

  void _onReselectTab() {
    if (mounted) {
      _searchBar.clear();
      setState(() {
        _songsSearchResult.clear();
        _artistsSearchResult.clear();
        _albumsSearchResult.clear();
        _playlistsSearchResult.clear();
        _suggestionsList.clear();
        _activeFilter = 'All';
      });
      _inputNode.unfocus();
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMoreSongs();
    }
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMoreSongs || _songsNextPage == null || (_activeFilter != 'Songs' && _activeFilter != 'All')) return;
    
    setState(() {
      _isLoadingMoreSongs = true;
    });
    
    final results = await fetchNextSongsList(_songsNextPage);
    
    if (mounted) {
      setState(() {
        _songsSearchResult.addAll(results['songs'] ?? []);
        _songsNextPage = results['nextPage'];
        _isLoadingMoreSongs = false;
      });
    }
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
      final results = await getRecommendedSongs();
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
    searchTabReselectNotifier.removeListener(_onReselectTab);
    _inputNode.removeListener(_onFocusChange);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchBar.dispose();
    _inputNode.dispose();
    _fetchingSongs.dispose();
    _debounce?.cancel();
    _liveSearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> search({int? requestId}) async {
    final query = _searchBar.text;

    if (query.isEmpty) {
      _songsSearchResult = [];
      _artistsSearchResult = [];
      _albumsSearchResult = [];
      _playlistsSearchResult = [];
      _suggestionsList = [];
      _activeFilter = 'All'; // Reset filter when search is cleared
      if (mounted) setState(() {});
      return;
    }
    
    _fetchingSongs.value = true;
    final optimizedQuery = query;

    if (!_isHandlingBack && optimizedQuery.isNotEmpty) {
      if (_searchStack.isEmpty || _searchStack.last != optimizedQuery) {
        _searchStack.add(optimizedQuery);
      }
    }
    _isHandlingBack = false;

    if (!searchHistory.contains(optimizedQuery)) {
      final updatedHistory = List.from(searchHistory)..insert(0, optimizedQuery);
      searchHistoryNotifier.value = updatedHistory;
      unawaited(addOrUpdateData<List>('user', 'searchHistory', updatedHistory));
    }

    try {
      final results = await Future.wait<dynamic>([
        fetchSongsListWithPagination(optimizedQuery).timeout(const Duration(seconds: 8), onTimeout: () => {'songs': <dynamic>[], 'nextPage': null}),
        searchArtists(optimizedQuery, limit: 5).timeout(const Duration(seconds: 4), onTimeout: () => <Map<String, dynamic>>[]),
        Future.value(<dynamic>[]),
        getPlaylists(query: optimizedQuery).timeout(const Duration(seconds: 10), onTimeout: () => <dynamic>[]),
      ]);

      if (requestId != null && requestId != _latestLiveSearchRequest) {
        return; // Ignore results if a newer request was made
      }

      final songData = results[0] as Map<String, dynamic>;
      _songsSearchResult = List<dynamic>.from(songData['songs'] ?? []);
      _songsNextPage = songData['nextPage'];
      
      _artistsSearchResult = (results[1] as List)
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

    return PopScope(
      canPop: _searchStack.isEmpty && _suggestionsList.isEmpty && !_inputNode.hasFocus,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        if (_inputNode.hasFocus || _suggestionsList.isNotEmpty) {
          _inputNode.unfocus();
          setState(() {
            _suggestionsList.clear();
          });
          return;
        }

        if (_searchStack.isNotEmpty) {
          _searchStack.removeLast(); // Remove current search
          if (_searchStack.isNotEmpty) {
            _isHandlingBack = true;
            _searchBar.text = _searchStack.last;
            search();
          } else {
            _searchBar.clear();
            search();
          }
        }
      },
      child: Scaffold(
        body: SafeArea(
        child: GestureDetector(
          onTap: _inputNode.unfocus,
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            controller: _scrollController,
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
                              // Append 'song' to get music-related suggestions only
                              String searchQuery = query;
                              
                              searchQuery = searchQuery.toLowerCase().endsWith('song') 
                                  ? searchQuery 
                                  : '$searchQuery song';
                              
                              final searchSuggestions = await getSearchSuggestions(
                                searchQuery,
                              );

                              if (!mounted ||
                                  requestId != _latestSuggestionRequest ||
                                  _searchBar.text != query) {
                                return;
                              }

                              // Limit to 5 suggestions so it doesn't take up the whole screen
                              _suggestionsList = List<String>.from(
                                searchSuggestions,
                              ).take(5).toList();
                              
                              if (mounted) setState(() {});
                            },
                          );

                          // Phase 2: Live Search Debounce (700ms) for heavy API calls
                          _liveSearchDebounce?.cancel();
                          final liveRequestId = ++_latestLiveSearchRequest;
                          
                          _liveSearchDebounce = Timer(
                            const Duration(milliseconds: 700),
                            () async {
                              if (_searchBar.text.trim().length >= 2) {
                                await search(requestId: liveRequestId);
                              }
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
                  child: (_suggestionsList.isNotEmpty || _hasSearchResults)
                      ? Column(
                          key: ValueKey('search-active-${_searchBar.text}'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_hasSearchResults || _searchBar.text.isNotEmpty)
                              _buildSearchFilters(colorScheme),
                            if (_suggestionsList.isNotEmpty)
                              _buildSuggestionsList(colorScheme),
                            if (_hasSearchResults)
                              _buildSearchResults(context, primaryColor),
                          ],
                        )
                      : _buildHomeContent(context, primaryColor, colorScheme),
                ),
                const MiniPlayerBottomSpace(),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }

  // ─── Search Filters (Categories) ───
  Widget _buildSearchFilters(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _searchFilters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = _searchFilters[index];
            final isSelected = _activeFilter == filter['value'];
            
            return ActionChip(
              label: Text(
                filter['label']!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                ),
              ),
              backgroundColor: isSelected ? colorScheme.primary : colorScheme.surfaceContainerHigh,
              side: BorderSide(
                color: isSelected ? Colors.transparent : colorScheme.primary.withValues(alpha: 0.2),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () {
                setState(() {
                  _activeFilter = filter['value']!;
                });
                _inputNode.unfocus();
              },
            );
          },
        ),
      ),
    );
  }

  // ─── Suggestions List (while typing) ───
  Widget _buildSuggestionsList(ColorScheme colorScheme) {
    final currentText = _searchBar.text.toLowerCase();
    
    return Column(
      key: ValueKey('suggestions-${_suggestionsList.length}-$currentText'),
      children: [
        for (int index = 0; index < _suggestionsList.length; index++)
          Builder(
            builder: (context) {
              final query = _suggestionsList[index];
              final queryLower = query.toLowerCase();
              
              Widget titleWidget;
              if (queryLower.startsWith(currentText) && currentText.isNotEmpty) {
                final remaining = query.substring(currentText.length);
                titleWidget = RichText(
                  text: TextSpan(
                    text: query.substring(0, currentText.length),
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
                    children: [
                      TextSpan(
                        text: remaining,
                        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                );
              } else {
                titleWidget = Text(query, style: TextStyle(color: colorScheme.onSurface, fontSize: 16));
              }

              return ListTile(
                leading: Icon(FluentIcons.search_24_regular, color: colorScheme.onSurfaceVariant, size: 22),
                title: titleWidget,
                trailing: Icon(FluentIcons.arrow_up_left_24_regular, color: colorScheme.onSurfaceVariant, size: 22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                dense: true,
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

        // Show max 5 compact items
        final displayItems = history.take(5).toList();

        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < displayItems.length; i++)
                ListTile(
                  leading: Icon(
                    FluentIcons.history_24_regular,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  title: Text(
                    displayItems[i].toString(),
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: GestureDetector(
                    onTap: () {
                      // Insert text into search bar
                      _searchBar.text = displayItems[i].toString();
                      _searchBar.selection = TextSelection.fromPosition(
                        TextPosition(offset: _searchBar.text.length),
                      );
                    },
                    child: Icon(
                      FluentIcons.arrow_up_left_24_regular,
                      color: colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                  dense: true,
                  onTap: () async {
                    await _submitSearch(displayItems[i].toString());
                  },
                  onLongPress: () async {
                    final confirm = await _showConfirmationDialog(context) ?? false;
                    if (confirm && history.contains(displayItems[i])) {
                      final updatedHistory = List.from(history)..remove(displayItems[i]);
                      searchHistoryNotifier.value = updatedHistory;
                      unawaited(
                        addOrUpdateData<List>('user', 'searchHistory', updatedHistory),
                      );
                    }
                  },
                ),

              // Clear All button
              if (displayItems.length > 2)
                InkWell(
                  onTap: () async {
                    final confirm = await _showConfirmationDialog(context) ?? false;
                    if (confirm) {
                      searchHistoryNotifier.value = [];
                      unawaited(addOrUpdateData<List>('user', 'searchHistory', []));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.delete_24_regular,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Clear All',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
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
                color: const Color(0xFFE11D48).withValues(alpha: 0.3),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < 4; i++) const SongBarSkeleton(),
        ],
      );
    }

    if (_recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < _recommendations.length; index++)
          SongBar(
            _recommendations[index],
            true,
            key: ValueKey('rec_song_$index'),
            showMusicDuration: true,
            backgroundColor: Colors.transparent,
            borderRadius: BorderRadius.zero,
            barPadding: const EdgeInsetsDirectional.symmetric(
              vertical: 8,
              horizontal: 4,
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, Color primaryColor) {
    final widgets = <Widget>[];

    // Artists section
    if (_artistsSearchResult.isNotEmpty && (_activeFilter == 'All' || _activeFilter == 'Artists')) {
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
    if (_songsSearchResult.isNotEmpty && (_activeFilter == 'All' || _activeFilter == 'Songs')) {
      widgets.add(
        SectionTitle(
          context.l10n!.songs,
          primaryColor,
          icon: FluentIcons.music_note_1_24_filled,
        ),
      );

      final songsCount = _songsSearchResult.length;

      for (var index = 0; index < songsCount; index++) {
        final song = _songsSearchResult[index];
        widgets.add(
          SongBar(
            song,
            true,
            key: listItemKey('search_song', index, song),
            showMusicDuration: true,
            backgroundColor: Colors.transparent,
            borderRadius: BorderRadius.zero,
            barPadding: const EdgeInsetsDirectional.symmetric(
              vertical: 8,
              horizontal: 4,
            ),
          ),
        );
      }
      
      if ((_activeFilter == 'Songs' || _activeFilter == 'All') && _isLoadingMoreSongs) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                height: 30,
                width: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Albums section
    if (_albumsSearchResult.isNotEmpty && (_activeFilter == 'All' || _activeFilter == 'Albums')) {
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
    if (_playlistsSearchResult.isNotEmpty && (_activeFilter == 'All' || _activeFilter == 'Playlists')) {
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
