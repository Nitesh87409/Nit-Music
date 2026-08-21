import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:musify/main.dart' show logger;
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/jiosaavn_api.dart';
import 'package:musify/services/lyrics_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/screens/search_page.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/services/smart_search_algorithm.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/formatter.dart';

List globalSongs = [];

ValueNotifier<List> userLikedSongsList = ValueNotifier<List>(
  Hive.box('user').get('likedSongs', defaultValue: []),
);

ValueNotifier<List> userRecentlyPlayed = ValueNotifier<List>(
  Hive.box('user').get('recentlyPlayedSongs', defaultValue: []),
);
ValueNotifier<List> userOfflineSongs = ValueNotifier<List>(
  Hive.box('userNoBackup').get('offlineSongs', defaultValue: []),
);



var _songLikeUpdateToken = 0;
final _latestSongLikeUpdateTokens = <String, int>{};

final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;

void reloadSongLibraryStateFromStorage() {
  final userBox = Hive.box('user');
  userLikedSongsList.value = List.from(
    userBox.get('likedSongs', defaultValue: []),
  );
  userRecentlyPlayed.value = List.from(
    userBox.get('recentlyPlayedSongs', defaultValue: []),
  );
}

// JioSaavn API instance for all music operations.
final _saavn = JioSaavnApi.instance;





Future<List> getTrendingSongs() async {
  try {
    final results = await _saavn.getTrendingSongs();
    return results.map((song) => _saavn.formatSong(song)).toList();
  } catch (e, stackTrace) {
    logger.log('Error in getTrendingSongs', error: e, stackTrace: stackTrace);
    return [];
  }
}

Future<List> fetchSongsList(String searchQuery) async {
  try {
    final results = await _saavn.searchSongs(searchQuery);
    return results.map((song) => _saavn.formatSong(song)).toList();
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsList', error: e, stackTrace: stackTrace);
    return [];
  }
}

/// Tracks the current page number for paginated search.
int _currentSearchPage = 1;
String _lastSearchQuery = '';

Future<Map<String, dynamic>> fetchSongsListWithPagination(String searchQuery) async {
  try {
    _currentSearchPage = 1;
    _lastSearchQuery = searchQuery;
    
    final smartSearch = SmartSearchAlgorithm();
    
    // Always clean the query BEFORE calling API
    String apiQuery = smartSearch.getCleanedQuery(searchQuery);
    
    final regularResults = await _saavn.searchSongs(apiQuery, page: 1);
    
    // Always apply Smart Search scoring & sorting
    List<Map<String, dynamic>> finalResults = await smartSearch.processSearch(apiQuery, regularResults);
    
    final formattedSongs = finalResults.map((song) => _saavn.formatSong(song)).toList();

    return {
      'songs': formattedSongs,
      'nextPage': formattedSongs.length >= 20 ? (_currentSearchPage + 1) : null,
    };
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsListWithPagination', error: e, stackTrace: stackTrace);
    return {'songs': [], 'nextPage': null};
  }
}

Future<Map<String, dynamic>> fetchNextSongsList(dynamic currentList) async {
  if (currentList == null) {
    return {'songs': [], 'nextPage': null};
  }

  try {
    _currentSearchPage = (currentList is int) ? currentList : _currentSearchPage + 1;
    final results = await _saavn.searchSongs(_lastSearchQuery, page: _currentSearchPage);
    if (results.isEmpty) return {'songs': [], 'nextPage': null};

    final songsList = results.map((song) => _saavn.formatSong(song)).toList();

    return {
      'songs': songsList,
      'nextPage': results.length >= 20 ? (_currentSearchPage + 1) : null,
    };
  } catch (e, stackTrace) {
    logger.log('Error in fetchNextSongsList', error: e, stackTrace: stackTrace);
    return {'songs': [], 'nextPage': null};
  }
}

Future<List> getRecommendedSongs() async {
    try {
      final List searchHistoryList = searchHistoryNotifier.value;
      if (searchHistoryList.isNotEmpty) {
        return await _getRecommendationsFromSearchHistory();
      } else if (userRecentlyPlayed.value.isNotEmpty) {
        return await _getRecommendationsFromRecentlyPlayed();
      } else {
        return await _getRecommendationsFromMixedSources();
      }
    } catch (e, stackTrace) {
    logger.log(
      'Error in getRecommendedSongs',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
    }
  }

  Future<List> _getRecommendationsFromSearchHistory() async {
    try {
      final List searchHistoryList = searchHistoryNotifier.value;
      
      // Get the 2 most recent unique searches
      final recentSearches = searchHistoryList.take(2).toList();
      
      final futures = recentSearches.map((query) async {
        try {
          final q = query.toString().trim();
          if (q.isEmpty) return <Map>[];
          
          final smartSearch = SmartSearchAlgorithm();
          final apiQuery = smartSearch.getCleanedQuery(q);
          
          final regularResults = await _saavn.searchSongs(apiQuery, page: 1);
          final finalResults = await smartSearch.processSearch(apiQuery, regularResults);
          
          return finalResults.take(10).map((s) => _saavn.formatSong(s)).toList();
        } catch (e) {
          return <Map>[];
        }
      }).toList();
      
      final results = await Future.wait(futures);
      final searchSongs = results.expand((list) => list).toList();
      
      // Blend with recently played to keep the mix healthy
      List recentlyPlayedSongs = [];
      if (userRecentlyPlayed.value.isNotEmpty) {
        recentlyPlayedSongs = (List.from(userRecentlyPlayed.value)..shuffle()).take(5).toList();
      }
      
      final allSongs = [...searchSongs, ...recentlyPlayedSongs];
      return _deduplicateAndShuffle(allSongs);
      
    } catch (e, stackTrace) {
      logger.log(
        'Error getting recommendations from search history',
        error: e,
        stackTrace: stackTrace,
      );
      if (userRecentlyPlayed.value.isNotEmpty) {
        return await _getRecommendationsFromRecentlyPlayed();
      } else {
        return await _getRecommendationsFromMixedSources();
      }
    }
  }
  
  Future<List> _getRecommendationsFromRecentlyPlayed() async {
  final recent = (List.from(
    userRecentlyPlayed.value,
  )..shuffle()).take(3).toList();

  final futures = recent.map((songData) async {
    try {
      final songId = songData['ytid']?.toString() ?? '';
      if (songId.isEmpty) return <Map>[];
      final related = await _saavn.getRelatedSongs(songId);
      return related.take(5).map((s) => _saavn.formatSong(s)).toList();
    } catch (e, stackTrace) {
      logger.log(
        'Error getting related songs for ${songData['ytid']}',
        error: e,
        stackTrace: stackTrace,
      );
      return <Map>[];
    }
  }).toList();

  final results = await Future.wait(futures);
  final playlistSongs = results.expand((list) => list).take(15).toList()
    ..shuffle();
  return playlistSongs;
}

Future<List> _getRecommendationsFromMixedSources() async {
  final playlistSongs = [
    ...userLikedSongsList.value,
    ...userRecentlyPlayed.value,
  ];

  if (userCustomPlaylists.value.isNotEmpty) {
    for (final userPlaylist in userCustomPlaylists.value) {
      final _list = List.from(userPlaylist['list'] as List)..shuffle();
      playlistSongs.addAll(_list.take(5));
    }
  }

  return _deduplicateAndShuffle(playlistSongs);
}

List _deduplicateAndShuffle(List playlistSongs) {
  final seenYtIds = <String>{};
  final uniqueSongs = <Map>[];

  playlistSongs.shuffle();

  for (final song in playlistSongs) {
    if (song['ytid'] != null && seenYtIds.add(song['ytid'])) {
      uniqueSongs.add(song);
      if (uniqueSongs.length >= 15) break;
    }
  }

  return uniqueSongs;
}

/// Fetches Quick Picks: related songs based on a random seed from recent history.
Future<List> getQuickPicks() async {
    try {
      List<Map> seedSongs = [];
      
      if (userRecentlyPlayed.value.isNotEmpty) {
        // Get top 50 most played
        final sortedByPlays = List.from(userRecentlyPlayed.value)
          ..sort((a, b) {
            final countA = (a['listeningCount'] ?? 0) as int;
            final countB = (b['listeningCount'] ?? 0) as int;
            return countB.compareTo(countA);
          });
        
        // Get top 50 most recent
        final topRecent = userRecentlyPlayed.value.take(50).toList();
        
        // Combine and shuffle, then take up to 4 distinct songs
        final combined = [...sortedByPlays.take(50), ...topRecent];
        combined.shuffle();
        
        final distinctYtids = <String>{};
        for (final song in combined) {
          if (song is Map && song['ytid'] != null) {
            if (distinctYtids.add(song['ytid'].toString())) {
              seedSongs.add(song);
              if (seedSongs.length >= 4) break;
            }
          }
        }
      }

      if (seedSongs.isNotEmpty) {
        List<dynamic> finalMix = [];
        
        // 1. Add the seed songs themselves to the mix
        finalMix.addAll(seedSongs);
        
        // 2. Fetch related songs for each seed concurrently
        final relatedFutures = seedSongs.map((song) => _saavn.getRelatedSongs(song['ytid'].toString()));
        final relatedResults = await Future.wait(relatedFutures);
        
        // 3. Add a few related songs from each seed
        for (final relatedList in relatedResults) {
          if (relatedList.isNotEmpty) {
            final formatted = relatedList.take(6).map((s) => _saavn.formatSong(s)).toList();
            finalMix.addAll(formatted);
          }
        }
        
        // 4. Shuffle the final mix and remove duplicates
        finalMix.shuffle();
        final distinctMix = <dynamic>[];
        final seenIds = <String>{};
        
        for (final song in finalMix) {
          final id = song['ytid']?.toString() ?? '';
          if (id.isNotEmpty && seenIds.add(id)) {
            distinctMix.add(song);
          }
          if (distinctMix.length >= 20) break;
        }
        
        if (distinctMix.isNotEmpty) {
          return distinctMix;
        }
      }

      // Fallback: return trending songs as quick picks
      return getTrendingSongs();
    } catch (e, stackTrace) {
      logger.log('Error in getQuickPicks', error: e, stackTrace: stackTrace);
      return [];
    }
  }

/// Returns the top 10 most-played songs from local history for Speed Dial.
/// No network call needed — purely local Hive data.
List getSpeedDial() {
  try {
    if (userRecentlyPlayed.value.isEmpty) return [];

    final sorted = List.from(userRecentlyPlayed.value)
      ..sort((a, b) {
        final countA = (a['listeningCount'] ?? 0) as int;
        final countB = (b['listeningCount'] ?? 0) as int;
        return countB.compareTo(countA);
      });

    return sorted.take(10).toList();
  } catch (e, stackTrace) {
    logger.log('Error in getSpeedDial', error: e, stackTrace: stackTrace);
    return [];
  }
}

Future<void> updateSongLikeStatus(
  dynamic songId,
  bool add, {
  Map? songData,
}) async {
  try {
    final normalizedSongId = songId?.toString().trim() ?? '';
    if (normalizedSongId.isEmpty) return;

    final updateToken = ++_songLikeUpdateToken;
    _latestSongLikeUpdateTokens[normalizedSongId] = updateToken;

    final songToAdd = add
        ? await _resolveSongForLikedStatus(normalizedSongId, songData)
        : null;

    if (_latestSongLikeUpdateTokens[normalizedSongId] != updateToken) {
      return;
    }

    final updatedLikedSongs = _deduplicateLikedSongs(userLikedSongsList.value);

    if (add) {
      if (songToAdd != null &&
          !updatedLikedSongs.any(
            (song) => song['ytid']?.toString() == normalizedSongId,
          )) {
        updatedLikedSongs.insert(0, songToAdd);
      }
    } else {
      updatedLikedSongs.removeWhere(
        (song) => song['ytid']?.toString() == normalizedSongId,
      );
    }

    if (_likedSongIdsAreEqual(userLikedSongsList.value, updatedLikedSongs))
      return;

    userLikedSongsList.value = updatedLikedSongs;
    unawaited(
      addOrUpdateData<List>('user', 'likedSongs', userLikedSongsList.value),
    );
  } catch (e, stackTrace) {
    logger.log(
      'Error updating song like status',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<Map?> _resolveSongForLikedStatus(String songId, Map? songData) async {
  if (songData?['ytid']?.toString() == songId) {
    return Map<String, dynamic>.from(songData!);
  }

  final cachedSong = _findSongById(userLikedSongsList.value, songId);
  if (cachedSong != null) return Map<String, dynamic>.from(cachedSong);

  return getSongDetails(userLikedSongsList.value.length, songId);
}

Map? _findSongById(Iterable<dynamic> songs, String songId) {
  for (final song in songs) {
    if (song is Map && song['ytid']?.toString() == songId) return song;
  }

  return null;
}

List _deduplicateLikedSongs(Iterable<dynamic> likedSongs) {
  final seenSongIds = <String>{};
  final deduplicatedSongs = [];

  for (final song in likedSongs) {
    if (song is! Map) {
      deduplicatedSongs.add(song);
      continue;
    }

    final songId = song['ytid']?.toString();
    if (songId == null || songId.isEmpty) {
      deduplicatedSongs.add(song);
      continue;
    }

    if (seenSongIds.add(songId)) {
      deduplicatedSongs.add(song);
    }
  }

  return deduplicatedSongs;
}

bool _likedSongIdsAreEqual(List previous, List updated) {
  if (previous.length != updated.length) return false;

  for (var i = 0; i < previous.length; i++) {
    final previousSong = previous[i];
    final updatedSong = updated[i];
    if (previousSong is! Map || updatedSong is! Map) {
      if (previousSong != updatedSong) return false;
      continue;
    }

    if (previousSong['ytid']?.toString() != updatedSong['ytid']?.toString()) {
      return false;
    }
  }

  return true;
}

Future<void> renameSongInLikedSongs(
  dynamic songId,
  String newTitle,
  String newArtist,
) async {
  try {
    final songIndex = userLikedSongsList.value.indexWhere(
      (song) => song['ytid'] == songId,
    );

    if (songIndex != -1) {
      final updatedList = List.from(userLikedSongsList.value);
      updatedList[songIndex] = Map.from(updatedList[songIndex] as Map)
        ..['title'] = newTitle
        ..['artist'] = newArtist;
      userLikedSongsList.value = updatedList;

      unawaited(
        addOrUpdateData<List>('user', 'likedSongs', userLikedSongsList.value),
      );
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error renaming song in liked songs',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

bool isSongAlreadyLiked(songIdToCheck) {
  final songId = songIdToCheck?.toString();
  return userLikedSongsList.value.any(
    (song) => song['ytid']?.toString() == songId,
  );
}

bool isPlaylistAlreadyLiked(playlistIdToCheck) {
  final playlistId = playlistIdToCheck?.toString();
  if (playlistId == null || playlistId.isEmpty) return false;
  return userLikedPlaylists.value.any(
    (playlist) => playlist['ytid']?.toString() == playlistId,
  );
}

bool isSongAlreadyOffline(songIdToCheck) =>
    userOfflineSongs.value.any((song) => song['ytid'] == songIdToCheck);

bool isPlaylistFullyOffline(List songs) {
  if (songs.isEmpty) return false;
  final offlineIds = userOfflineSongs.value.map((s) => s['ytid']).toSet();
  return songs.every((s) => offlineIds.contains(s['ytid']));
}

Map<String, dynamic> getOfflineSongByYtid(String ytid) {
  try {
    final song = userOfflineSongs.value.firstWhere(
      (s) => s['ytid'] == ytid,
      orElse: () => <String, dynamic>{},
    );
    return Map<String, dynamic>.from(song);
  } catch (_) {
    return <String, dynamic>{};
  }
}

Future<List<String>> getSearchSuggestions(String query) async {
  // Custom implementation:

  // const baseUrl = 'https://suggestqueries.google.com/complete/search';
  // final parameters = {
  //   'client': 'firefox',
  //   'ds': 'yt',
  //   'q': query,
  // };

  // final uri = Uri.parse(baseUrl).replace(queryParameters: parameters);

  // try {
  //   final response = await http.get(
  //     uri,
  //     headers: {
  //       'User-Agent':
  //           'Mozilla/5.0 (Windows NT 10.0; rv:96.0) Gecko/20100101 Firefox/96.0',
  //     },
  //   );

  //   if (response.statusCode == 200) {
  //     final suggestions = jsonDecode(response.body)[1] as List<dynamic>;
  //     final suggestionStrings = suggestions.cast<String>().toList();
  //     return suggestionStrings;
  //   }
  // } catch (e, stackTrace) {
  //   logger.log('Error in getSearchSuggestions:$e\n$stackTrace');
  // }

  // JioSaavn autocomplete:
  final suggestions = await _saavn.getSearchSuggestions(query);
  return suggestions;
}

Future<List<Map<String, int>>> getSkipSegments(String id) async {
  return [];
}

List<dynamic> nextRecommendedSongs = [];

Future<void> getSimilarSong(String songYtId) async {
  try {
    var related = await _saavn.getRelatedSongs(songYtId);
    
    if (related.isEmpty) {
      logger.log('No related songs found for $songYtId even after artist fallback.');
      // DO NOT fallback to generic trending songs to avoid polluting niche playlists
    }

    if (related.isNotEmpty) {
      nextRecommendedSongs = related
          .take(50)
          .map((s) => _saavn.formatSong(s))
          .toList();
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error while fetching next similar song:',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// Resolves a playable stream URL for a song from JioSaavn.
/// JioSaavn URLs are direct MP4 links — no proxy needed.
Future<String?> fetchSongStreamUrl(String songId, bool isLive) async {
  try {
    if (songId.isEmpty) {
      logger.log('fetchSongStreamUrl: songId is empty');
      return null;
    }

    // For JioSaavn songs, we return a marker that tells the audio service
    // to resolve the actual URL lazily (from the song's encrypted_media_url).
    return 'jiosaavn_lazy_resolve';
  } catch (e, stackTrace) {
    logger.log(
      'Error in fetchSongStreamUrl for $songId:',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Resolve the actual direct stream URL for a JioSaavn song.
/// Called lazily when playback actually starts.
String? resolveJioSaavnStreamUrl(Map song) {
  final encryptedUrl = song['encrypted_media_url']?.toString();
  if (encryptedUrl == null || encryptedUrl.isEmpty) {
    logger.log('resolveJioSaavnStreamUrl: no encrypted_media_url');
    return null;
  }
  return _saavn.getSongStreamUrl(encryptedUrl);
}

Future<Map<String, dynamic>> getSongDetails(
  int songIndex,
  String songId,
) async {
  try {
    final song = await _saavn.getSongDetails(songId);
    if (song != null) {
      return _saavn.formatSong(song, index: songIndex);
    }
    throw Exception('Song not found: $songId');
  } catch (e, stackTrace) {
    logger.log(
      'Error while getting song details',
      error: e,
      stackTrace: stackTrace,
    );
    rethrow;
  }
}

Future<String?> getSongLyrics(String? artist, String title) async {
  if (artist == null) return null;
  if (lastFetchedLyrics != '$artist - $title') {
    lyrics.value = null;
    var _lyrics = await LyricsManager().fetchLyrics(artist, title);
    if (_lyrics != null) {
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{4}'), '\n\n');
      _lyrics = _lyrics.replaceAll(RegExp(r'\n{2}'), '\n');
      lyrics.value = _lyrics;
    } else {
      return null;
    }

    lastFetchedLyrics = '$artist - $title';
    return _lyrics;
  }

  return lyrics.value;
}

Future<bool> makeSongOffline(dynamic song) async {
  try {
    final String? ytid = song['ytid'];

    if (ytid == null || ytid.isEmpty) {
      logger.log('makeSongOffline: song["ytid"] is null or empty');
      return false;
    }

    if (isSongAlreadyOffline(ytid)) {
      final existingPath = FilePaths.getAudioPath(ytid);
      if (await File(existingPath).exists()) {
        return true;
      }
    }

    final offlineSong = Map<String, dynamic>.from(song as Map);

    final audioPath = FilePaths.getAudioPath(ytid);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(ytid);

    await audioFile.parent.create(recursive: true);

    try {
      // Resolve the direct stream URL from JioSaavn
      final streamUrl = resolveJioSaavnStreamUrl(offlineSong);
      if (streamUrl == null || streamUrl.isEmpty) {
        logger.log('makeSongOffline: no stream URL for $ytid');
        return false;
      }

      // Download the MP4 audio file directly
      final response = await http.get(Uri.parse(streamUrl));
      if (response.statusCode != 200) {
        logger.log('makeSongOffline: download failed with ${response.statusCode}');
        return false;
      }
      await audioFile.writeAsBytes(response.bodyBytes);
    } catch (e, stackTrace) {
      logger.log(
        'Error downloading audio file',
        error: e,
        stackTrace: stackTrace,
      );
      // file stream is no longer used
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      return false;
    }

    try {
      if (offlineSong['highResImage'] != null &&
          offlineSong['highResImage'].toString().isNotEmpty) {
        final _artworkFile = await _downloadAndSaveArtworkFile(
          offlineSong['highResImage'],
          artworkPath,
        );

        if (_artworkFile != null && await _artworkFile.exists()) {
          offlineSong['artworkPath'] = artworkPath;
        } else {
          logger.log(
            'Artwork download failed or file does not exist for $ytid',
          );
          offlineSong['artworkPath'] = null;
        }
      }
    } catch (e, stackTrace) {
      logger.log('Error downloading artwork', error: e, stackTrace: stackTrace);
      offlineSong['artworkPath'] = null;
    }

    offlineSong['audioPath'] = audioFile.path;
    offlineSong['dateAdded'] = DateTime.now().millisecondsSinceEpoch;

    try {
      final existingIndex = userOfflineSongs.value.indexWhere(
        (s) => s['ytid'] == ytid,
      );

      final updatedOfflineSongs = List.from(userOfflineSongs.value);
      if (existingIndex != -1) {
        updatedOfflineSongs[existingIndex] = offlineSong;
      } else {
        updatedOfflineSongs.add(offlineSong);
      }
      userOfflineSongs.value = updatedOfflineSongs;

      unawaited(
        addOrUpdateData<List>(
          'userNoBackup',
          'offlineSongs',
          userOfflineSongs.value,
        ),
      );
    } catch (e, st) {
      logger.log(
        'Error updating global offline songs list',
        error: e,
        stackTrace: st,
      );
    }

    return true;
  } catch (e, stackTrace) {
    logger.log('Error making song offline', error: e, stackTrace: stackTrace);
    return false;
  }
}

Future<bool> removeSongFromOffline(dynamic songId) async {
  try {
    final audioPath = FilePaths.getAudioPath(songId);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(songId);
    final artworkFile = File(artworkPath);

    try {
      if (await audioFile.exists()) await audioFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log('Error deleting audio file', error: e, stackTrace: stackTrace);
    }

    try {
      if (await artworkFile.exists()) await artworkFile.delete(recursive: true);
    } catch (e, stackTrace) {
      logger.log(
        'Error deleting artwork file',
        error: e,
        stackTrace: stackTrace,
      );
    }

    try {
      userOfflineSongs.value = List.from(userOfflineSongs.value)
        ..removeWhere((song) => song['ytid'] == songId);
      unawaited(
        addOrUpdateData<List>(
          'userNoBackup',
          'offlineSongs',
          userOfflineSongs.value,
        ),
      );
    } catch (e, st) {
      logger.log(
        'Error updating offline songs registry after removal',
        error: e,
        stackTrace: st,
      );
    }

    return true;
  } catch (e, stackTrace) {
    logger.log(
      'Error removing song from offline storage',
      error: e,
      stackTrace: stackTrace,
    );
    return false;
  }
}

Future<File?> _downloadAndSaveArtworkFile(String url, String filePath) async {
  try {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(response.bodyBytes);

      // Validate that the file was actually written
      if (await file.exists() && await file.length() > 0) {
        return file;
      } else {
        logger.log('Artwork file was not written properly: $filePath');
        return null;
      }
    } else {
      logger.log(
        'Failed to download file. Status code: ${response.statusCode}',
      );
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error downloading and saving file',
      error: e,
      stackTrace: stackTrace,
    );
  }

  return null;
}

const recentlyPlayedSongsLimit = 100;

/// Updates the recently played list and listening count for [songId].
///
/// When [songFallback] is provided, its metadata is used to seed the history
/// entry if the song has never been played before. This avoids a network
/// request when registering offline songs whose metadata is already available
/// locally (e.g. from [userOfflineSongs]).
Future<void> updateRecentlyPlayed(dynamic songId, {Map? songFallback}) async {
  try {
    if (userRecentlyPlayed.value.isNotEmpty &&
        userRecentlyPlayed.value[0]['ytid'] == songId) {
      final updatedList = List.from(userRecentlyPlayed.value);
      final existing = Map.from(updatedList[0] as Map);
      existing['listeningCount'] = (existing['listeningCount'] ?? 0) + 1;
      existing['lastPlayed'] = DateTime.now();
      updatedList[0] = existing;
      userRecentlyPlayed.value = updatedList;
      unawaited(
        addOrUpdateData<List>(
          'user',
          'recentlyPlayedSongs',
          userRecentlyPlayed.value,
        ),
      );
      return;
    }

    final existingIndex = userRecentlyPlayed.value.indexWhere(
      (song) => song['ytid'] == songId,
    );

    final updatedList = List.from(userRecentlyPlayed.value);

    if (existingIndex == -1 && updatedList.length >= recentlyPlayedSongsLimit) {
      updatedList.removeLast();
    }

    if (existingIndex != -1) {
      final song = Map.from(updatedList.removeAt(existingIndex) as Map);
      song['listeningCount'] = (song['listeningCount'] ?? 0) + 1;
      song['lastPlayed'] = DateTime.now();
      updatedList.insert(0, song);
    } else {
      final newSongDetails = songFallback != null
          ? Map<String, dynamic>.from(songFallback)
          : await getSongDetails(0, songId);
      newSongDetails['listeningCount'] = 1;
      newSongDetails['lastPlayed'] = DateTime.now();
      updatedList.insert(0, newSongDetails);
    }

    userRecentlyPlayed.value = updatedList;
    unawaited(
      addOrUpdateData<List>(
        'user',
        'recentlyPlayedSongs',
        userRecentlyPlayed.value,
      ),
    );
  } catch (e, stackTrace) {
    logger.log(
      'Error updating recently played',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<void> removeFromRecentlyPlayed(dynamic songId) async {
  if (userRecentlyPlayed.value.any((song) => song['ytid'] == songId)) {
    userRecentlyPlayed.value = List.from(userRecentlyPlayed.value)
      ..removeWhere((song) => song['ytid'] == songId);
    unawaited(
      addOrUpdateData<List>(
        'user',
        'recentlyPlayedSongs',
        userRecentlyPlayed.value,
      ),
    );
  }
}


