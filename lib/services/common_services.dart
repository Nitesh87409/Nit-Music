/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:musify/constants/clients.dart';
import 'package:musify/main.dart' show logger;
import 'package:musify/services/artist_service.dart';
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/io_service.dart';
import 'package:musify/services/lyrics_manager.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/services/proxy_manager.dart';
import 'package:musify/services/settings_manager.dart';
import 'package:musify/utilities/app_utils.dart';
import 'package:musify/utilities/formatter.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

List globalSongs = [];

ValueNotifier<List> userLikedSongsList = ValueNotifier<List>(
  Hive.box('user').get('likedSongs', defaultValue: []),
);

ValueNotifier<List<String>> userLikedRadioStations =
    ValueNotifier<List<String>>(
      List<String>.from(
        Hive.box('user').get('likedRadioStations', defaultValue: []),
      ),
    );

ValueNotifier<List> userRecentlyPlayed = ValueNotifier<List>(
  Hive.box('user').get('recentlyPlayedSongs', defaultValue: []),
);
ValueNotifier<List> userOfflineSongs = ValueNotifier<List>(
  Hive.box('userNoBackup').get('offlineSongs', defaultValue: []),
);

Set<String> _createSongIdCache(ValueNotifier<List> source) {
  final cache = _songIds(source.value);

  source.addListener(() {
    cache
      ..clear()
      ..addAll(_songIds(source.value));
  });

  return cache;
}

Set<String> _songIds(Iterable songs) => songs
    .whereType<Map>()
    .map((song) => song['ytid']?.toString())
    .whereType<String>()
    .where((ytid) => ytid.isNotEmpty)
    .toSet();

final _cachedLikedSongIds = _createSongIdCache(userLikedSongsList);
final _cachedOfflineSongIds = _createSongIdCache(userOfflineSongs);

dynamic nextRecommendedSong;

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

// Timeouts and durations used across manifest fetching and cache validation.
const Duration _manifestTimeout = Duration(seconds: 30);
const Duration _cacheValidationDuration = Duration(hours: 1);

/// Fetches a stream manifest for a song, honoring proxy settings.
Future<StreamManifest?> _fetchStreamManifest(String songId) async {
  if (useProxy.value) {
    return ProxyManager().getSongManifest(songId).timeout(_manifestTimeout);
  }

  return ytClient.videos.streams
      .getManifest(songId, ytClients: customClients)
      .timeout(_manifestTimeout);
}

/// Returns a cached song URL if present and still valid.
Future<String?> _getCachedSongUrl(
  String cacheKey,
  Duration cacheDuration,
) async {
  final cachedUrl = await getData(
    'cache',
    cacheKey,
    cachingDuration: cacheDuration,
  );

  if (cachedUrl is! String || cachedUrl.isEmpty) {
    return null;
  }

  final cacheBox = await Hive.openBox('cache');
  final cacheDate = cacheBox.get('${cacheKey}_date') as DateTime?;
  final now = DateTime.now();
  final isOld =
      cacheDate != null && now.difference(cacheDate) > _cacheValidationDuration;

  if (!isOld) {
    return cachedUrl;
  }

  if (await _validateCachedUrl(cachedUrl)) {
    return cachedUrl;
  }

  await deleteData('cache', cacheKey);
  await deleteData('cache', '${cacheKey}_date');
  return null;
}

/// Checks if a cached URL still responds successfully.
Future<bool> _validateCachedUrl(String cachedUrl) async {
  try {
    final response = await http.head(Uri.parse(cachedUrl));
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}

Future<List> fetchSongsList(String searchQuery) async {
  try {
    // If not in cache, perform the search
    final List<Video> searchResults = await ytClient.search
        .search(searchQuery)
        .timeout(const Duration(seconds: 8));
    final songsList = searchResults
        .map((video) => returnSongLayout(0, video))
        .toList();

    return songsList;
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsList', error: e, stackTrace: stackTrace);
    return [];
  }
}

Future<List>? _recommendedSongsInFlight;
List _recommendedSongsCache = [];
DateTime? _recommendedSongsCacheTime;
bool? _recommendedCacheExternal;

Future<List> getRecommendedSongs() async {
  final isExternal = externalRecommendations.value;
  if (_recommendedSongsCache.isNotEmpty &&
      _recommendedCacheExternal == isExternal &&
      _recommendedSongsCacheTime != null &&
      DateTime.now().difference(_recommendedSongsCacheTime!).inMinutes < 15) {
    return _recommendedSongsCache;
  }
  if (_recommendedSongsInFlight != null) {
    return _recommendedSongsInFlight!;
  }

  final future = _fetchRecommendedSongs(isExternal);
  _recommendedSongsInFlight = future;
  try {
    final result = await future;
    if (result.isNotEmpty) {
      _recommendedSongsCache = result;
      _recommendedSongsCacheTime = DateTime.now();
      _recommendedCacheExternal = isExternal;
    }
    return result;
  } finally {
    if (identical(_recommendedSongsInFlight, future)) {
      _recommendedSongsInFlight = null;
    }
  }
}

Future<List> _fetchRecommendedSongs(bool isExternal) async {
  try {
    if (isExternal && userRecentlyPlayed.value.isNotEmpty) {
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
    return _recommendedSongsCache.isNotEmpty ? _recommendedSongsCache : [];
  }
}

Future<List> _getRecommendationsFromRecentlyPlayed() async {
  final recent = (List.from(
    userRecentlyPlayed.value,
  )..shuffle()).take(3).toList();

  return _getRecommendationsFromSeedSongs(recent);
}

/// Expands seed songs into related videos and ranks them for home and playlist recommendations.
Future<List> _getRecommendationsFromSeedSongs(List seedSongs) async {
  final seeds = seedSongs
      .whereType<Map>()
      .where((song) => (song['ytid']?.toString() ?? '').isNotEmpty)
      .toList();
  if (seeds.isEmpty) return [];

  final scores = <String, double>{};
  final songMap = <String, Map>{};

  final futures = seeds.asMap().entries.map((entry) async {
    final seedIndex = entry.key;
    final songData = entry.value;
    try {
      final song = await ytClient.videos
          .get(songData['ytid'])
          .timeout(const Duration(seconds: 6));
      final related =
          await ytClient.videos
              .getRelatedVideos(song)
              .timeout(const Duration(seconds: 6)) ??
          [];
      for (var i = 0; i < related.length && i < 8; i++) {
        final s = returnSongLayout(0, related[i]);
        final id = s['ytid'];
        final positionWeight = 1.0 - (i / 8);
        final recencyWeight = 1.0 - (seedIndex / seeds.length);
        scores[id] = (scores[id] ?? 0) + positionWeight * recencyWeight;
        songMap[id] = s;
      }
    } catch (e, st) {
      logger.log(
        'related videos error for ${songData['ytid']}',
        error: e,
        stackTrace: st,
      );
    }
  }).toList();

  await Future.wait(futures);

  final sorted = scores.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(15).map((e) => songMap[e.key]!).toList();
}

/// Number of playlist tracks used to seed recommendations while keeping network cost bounded.
const _playlistRecommendationSeedCount = 5;

/// In-memory recommendations cache keyed by playlist ytid and cleared on app restart.
final Map<String, List> _playlistRecommendationsCache = {};

/// Gets playlist-seeded recommendations, reusing cached results and returning an empty list on failure.
Future<List> getRecommendedSongsForPlaylist(
  String playlistId,
  List playlistSongs,
) async {
  try {
    final existingIds = playlistSongs
        .whereType<Map>()
        .map((song) => song['ytid']?.toString())
        .toSet();

    final cached = _playlistRecommendationsCache[playlistId];
    if (cached != null) {
      final stillFresh = cached
          .where((song) => !existingIds.contains(song['ytid']?.toString()))
          .toList();
      if (stillFresh.isNotEmpty) return stillFresh;
    }

    final seeds = _sampleSeedSongs(
      playlistSongs,
      _playlistRecommendationSeedCount,
    );
    final recommendations = await _getRecommendationsFromSeedSongs(seeds);
    final filtered = recommendations
        .where((song) => !existingIds.contains(song['ytid']?.toString()))
        .toList();

    _playlistRecommendationsCache[playlistId] = filtered;
    return filtered;
  } catch (e, stackTrace) {
    logger.log(
      'Error in getRecommendedSongsForPlaylist',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
  }
}

/// Uniformly samples up to [count] valid songs in one pass without copying or shuffling the playlist.
List<Map> _sampleSeedSongs(List songs, int count) {
  final random = Random();
  final reservoir = <Map>[];
  var seen = 0;

  for (final song in songs) {
    if (song is! Map || (song['ytid']?.toString() ?? '').isEmpty) continue;
    seen++;
    if (reservoir.length < count) {
      reservoir.add(song);
    } else {
      final slot = random.nextInt(seen);
      if (slot < count) reservoir[slot] = song;
    }
  }

  return reservoir;
}

Future<List> _getRecommendationsFromMixedSources() async {
  final playlistSongs = [
    ...userLikedSongsList.value,
    ...userRecentlyPlayed.value,
  ];

  if (globalSongs.isEmpty) {
    const playlistId = 'PLgzTt0k8mXzEk586ze4BjvDXR7c-TUSnx';
    globalSongs = await getSongsFromPlaylist(playlistId);
  }
  playlistSongs.addAll(globalSongs.take(10));

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
      // Early exit when we have enough songs
      if (uniqueSongs.length >= 15) break;
    }
  }

  return uniqueSongs;
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
  return songId != null && _cachedLikedSongIds.contains(songId);
}

bool isPlaylistAlreadyLiked(playlistIdToCheck) {
  final playlistId = playlistIdToCheck?.toString();
  if (playlistId == null || playlistId.isEmpty) return false;
  return userLikedPlaylists.value.any(
    (playlist) => playlist['ytid']?.toString() == playlistId,
  );
}

bool isRadioStationLiked(String radioStationId) {
  return userLikedRadioStations.value.contains(radioStationId);
}

Future<void> addRadioStationToLiked(String radioStationId) async {
  if (!userLikedRadioStations.value.contains(radioStationId)) {
    final updatedList = List<String>.from(userLikedRadioStations.value)
      ..add(radioStationId);
    userLikedRadioStations.value = updatedList;
    await addOrUpdateData<List<String>>(
      'user',
      'likedRadioStations',
      updatedList,
    );
  }
}

Future<void> removeRadioStationFromLiked(String radioStationId) async {
  if (userLikedRadioStations.value.contains(radioStationId)) {
    final updatedList = List<String>.from(userLikedRadioStations.value)
      ..remove(radioStationId);
    userLikedRadioStations.value = updatedList;
    unawaited(
      addOrUpdateData<List<String>>('user', 'likedRadioStations', updatedList),
    );
  }
}

bool isSongAlreadyOffline(songIdToCheck) {
  final songId = songIdToCheck?.toString();
  return songId != null && _cachedOfflineSongIds.contains(songId);
}

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

  // Built-in implementation:

  final suggestions = await ytClient.search.getQuerySuggestions(query);

  return suggestions;
}

// Throws on network, HTTP and parsing failure instead of swallowing it, so
// callers that need to tell "confirmed no segments" apart from "failed to
// fetch" (e.g. the offline cache, which must not persist a false negative)
// can do so.
Future<List<Map<String, int>>> _fetchSkipSegments(String id) async {
  final res = await ProxyManager().getProxiedResponse(
    Uri(
      scheme: 'https',
      host: 'sponsor.ajay.app',
      path: '/api/skipSegments',
      queryParameters: {
        'videoID': id,
        'category': [
          'sponsor',
          'selfpromo',
          'interaction',
          'intro',
          'outro',
          'music_offtopic',
        ],
        'actionType': 'skip',
      },
    ),
  );
  // 404 is how the API answers "this video has no segments", so it is a real
  // empty result and safe to remember. Any other non-200 is a failure, and
  // throwing keeps it from being stored as a confirmed "no segments".
  if (res.statusCode == 404 || res.body == 'Not Found') return [];
  if (res.statusCode != 200) {
    throw HttpException('SponsorBlock responded ${res.statusCode} for $id');
  }

  final data = jsonDecode(res.body);
  final segments = data.map((obj) {
    return Map.castFrom<String, dynamic, String, int>({
      'start': obj['segment'].first.toInt(),
      'end': obj['segment'].last.toInt(),
    });
  }).toList();
  return List.castFrom<dynamic, Map<String, int>>(segments);
}

Future<List<Map<String, int>>> getSkipSegments(String id) async {
  try {
    return await _fetchSkipSegments(id);
  } catch (e, stackTrace) {
    logger.log('Error in getSkipSegments', error: e, stackTrace: stackTrace);
    return [];
  }
}

Future<void> getSimilarSong(String songYtId) async {
  try {
    final song = await ytClient.videos.get(songYtId);
    final relatedSongs = await ytClient.videos.getRelatedVideos(song) ?? [];

    if (relatedSongs.isNotEmpty) {
      nextRecommendedSongs = relatedSongs
          .where((s) => s.duration != null && s.duration!.inMinutes <= 15)
          .take(30)
          .map((s) => returnSongLayout(0, s))
          .toList();
    } else {
      logger.log('No related songs found for $songYtId');
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error while fetching next similar song:',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// In-memory cache of the audio stream picked for a song at the current
/// quality setting. The Hive cache only keeps the URL, so without this every
/// caller that needs the stream itself (bitrate, codec) would fetch the
/// manifest again right after playback already resolved it.
final Map<String, ({AudioOnlyStreamInfo stream, DateTime resolvedAt})>
_selectedAudioStreams = {};

const _maxSelectedAudioStreams = 50;

String _selectedAudioStreamKey(String songId) =>
    '${songId}_${audioQualitySetting.value}';

/// Returns the stream resolved earlier for a song, unless it is old enough
/// that its URL may have expired.
AudioOnlyStreamInfo? _getSelectedAudioStream(String songId) {
  final key = _selectedAudioStreamKey(songId);
  final entry = _selectedAudioStreams[key];
  if (entry == null) return null;

  if (DateTime.now().difference(entry.resolvedAt) > _cacheValidationDuration) {
    _selectedAudioStreams.remove(key);
    return null;
  }

  return entry.stream;
}

void _cacheSelectedAudioStream(String songId, AudioOnlyStreamInfo stream) {
  if (_selectedAudioStreams.length >= _maxSelectedAudioStreams) {
    _selectedAudioStreams.remove(_selectedAudioStreams.keys.first);
  }

  _selectedAudioStreams[_selectedAudioStreamKey(songId)] = (
    stream: stream,
    resolvedAt: DateTime.now(),
  );
}

/// Drops both cached forms of a song's stream, so the next request resolves
/// it again. Used when a cached URL turns out to be dead.
Future<void> invalidateSongStreamCache(String songId) async {
  _selectedAudioStreams.remove(_selectedAudioStreamKey(songId));
  await deleteData('cache', 'song_${songId}_${audioQualitySetting.value}_url');
}

/// Fetches the best available audio stream for a song.
Future<AudioOnlyStreamInfo?> fetchBestAudioStream(String? songId) async {
  try {
    if (songId == null || songId.isEmpty) {
      logger.log('fetchBestAudioStream: songId is null or empty');
      return null;
    }

    final cachedStream = _getSelectedAudioStream(songId);
    if (cachedStream != null) return cachedStream;

    final manifest = await _fetchStreamManifest(songId);
    final audioStream = manifest?.audioOnly;
    if (audioStream == null || audioStream.isEmpty) {
      logger.log('fetchBestAudioStream: no audio streams for $songId');
      return null;
    }

    final selectedStream = selectAudioOnlyStreamForQuality(audioStream);
    if (selectedStream == null) {
      logger.log(
        'fetchBestAudioStream: no compatible audio streams for $songId',
      );
      return null;
    }

    _cacheSelectedAudioStream(songId, selectedStream);
    return selectedStream;
  } on TimeoutException catch (_) {
    logger.log('fetchBestAudioStream request timed out for $songId');
    return null;
  } catch (e, stackTrace) {
    logger.log(
      'Error while fetching best audio stream',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Resolves a playable stream URL for a song (cached when possible).
Future<String?> fetchSongStreamUrl(String songId, bool isLive) async {
  try {
    if (songId.isEmpty) {
      logger.log('fetchSongStreamUrl: songId is empty');
      return null;
    }
    if (isLive) {
      final streamInfo = await ytClient.videos.streamsClient
          .getHttpLiveStreamUrl(VideoId(songId));
      return streamInfo;
    }

    const _cacheDuration = Duration(hours: 3);
    final cacheKey = 'song_${songId}_${audioQualitySetting.value}_url';

    // Try to get from cache
    final cachedUrl = await _getCachedSongUrl(cacheKey, _cacheDuration);
    if (cachedUrl != null) {
      return cachedUrl;
    }

    // Get fresh URL, reusing the stream already resolved for this song.
    final selectedStream = await fetchBestAudioStream(songId);
    if (selectedStream == null) {
      logger.log('fetchSongStreamUrl: no audio streams for $songId');
      return null;
    }

    final url = selectedStream.url.toString();

    unawaited(addOrUpdateData<String>('cache', cacheKey, url));

    return url;
  } on TimeoutException catch (_) {
    logger.log('fetchSongStreamUrl request timed out for $songId');
    return null;
  } catch (e, stackTrace) {
    logger.log(
      'Error in fetchSongStreamUrl for $songId:',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

Future<Map<String, dynamic>> getSongDetails(
  int songIndex,
  String songId,
) async {
  try {
    final song = await ytClient.videos.get(songId);
    return returnSongLayout(songIndex, song);
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
        unawaited(cacheSponsorBlockSegments(ytid));
        return true;
      }
    }

    final offlineSong = Map<String, dynamic>.from(song as Map);

    final audioPath = FilePaths.getAudioPath(ytid);
    final audioFile = File(audioPath);
    final artworkPath = FilePaths.getArtworkPath(ytid);

    await audioFile.parent.create(recursive: true);

    int? audioBitrateKbps;
    String? audioCodec;
    IOSink? fileStream;
    try {
      final audioManifest = await fetchBestAudioStream(ytid);
      if (audioManifest == null) {
        logger.log('makeSongOffline: audioManifest is null for $ytid');
        return false;
      }
      audioBitrateKbps = audioManifest.bitrate.kiloBitsPerSecond.round();
      audioCodec = audioManifest.audioCodec;

      final stream = ytClient.videos.streamsClient.get(audioManifest);
      fileStream = audioFile.openWrite();
      await stream.pipe(fileStream);
      await fileStream.flush();
      await fileStream.close();
      fileStream = null;
    } catch (e, stackTrace) {
      logger.log(
        'Error downloading audio file',
        error: e,
        stackTrace: stackTrace,
      );
      try {
        await fileStream?.close();
      } catch (_) {}
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
    offlineSong['audioBitrateKbps'] = audioBitrateKbps;
    offlineSong['audioCodec'] = audioCodec;
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

      unawaited(cacheSponsorBlockSegments(ytid));
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

const _sponsorCallSpacing = Duration(seconds: 1);
Future<void> _sponsorSerialChain = Future.value();

/// Runs SponsorBlock lookups one at a time, spaced out, so that a playlist
/// download finishing several songs at once does not fire them all together.
Future<T> _sponsorSerialCall<T>(Future<T> Function() action) {
  final result = _sponsorSerialChain.then((_) => action());
  _sponsorSerialChain = result
      .then((_) {}, onError: (_) {})
      .then((_) => Future<void>.delayed(_sponsorCallSpacing));
  return result;
}

/// Stores the SponsorBlock segments of a downloaded song next to the download
/// itself, so they last exactly as long as it does: they are not backed up,
/// they never expire, and removing the song removes them.
///
/// Looked up once per song: a stored result — including a confirmed empty one —
/// is never fetched again.
Future<void> cacheSponsorBlockSegments(String ytid) async {
  try {
    if (getOfflineSongByYtid(ytid)['sponsorSegments'] != null) return;

    // Two attempts, spaced out by the queue above; a failure stores nothing so
    // it is not mistaken for a confirmed "no segments", and is looked up again
    // the next time the song plays.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final segments = await _sponsorSerialCall(
          () => _fetchSkipSegments(ytid),
        );
        await _storeSponsorBlockSegments(ytid, segments);
        return;
      } catch (_) {
        continue;
      }
    }
  } catch (e, stackTrace) {
    logger.log(
      'Error caching sponsor block for $ytid',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

Future<void> _storeSponsorBlockSegments(
  String ytid,
  List<Map<String, int>> segments,
) async {
  final index = userOfflineSongs.value.indexWhere((s) => s['ytid'] == ytid);
  // The song was removed while the lookup was in flight.
  if (index == -1) return;

  final updatedOfflineSongs = List.from(userOfflineSongs.value);
  updatedOfflineSongs[index] = {
    ...Map<String, dynamic>.from(updatedOfflineSongs[index] as Map),
    'sponsorSegments': segments,
  };
  userOfflineSongs.value = updatedOfflineSongs;
  await addOrUpdateData<List>(
    'userNoBackup',
    'offlineSongs',
    userOfflineSongs.value,
  );
}

/// The stored segments of a downloaded song, or null when it has none stored
/// yet. An empty list means the song was looked up and has no segments.
List<Map<String, int>>? getCachedSponsorBlockSegments(String ytid) {
  final stored = getOfflineSongByYtid(ytid)['sponsorSegments'];
  if (stored is! List) return null;
  return [for (final segment in stored) Map<String, int>.from(segment as Map)];
}

Future<File?> _downloadAndSaveArtworkFile(String url, String filePath) async {
  try {
    final response = await ProxyManager().getProxiedResponse(Uri.parse(url));

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
    final now = DateTime.now();

    if (userRecentlyPlayed.value.isNotEmpty &&
        userRecentlyPlayed.value[0]['ytid'] == songId) {
      final updatedList = List.from(userRecentlyPlayed.value);
      final existing = Map.from(updatedList[0] as Map);
      existing['listeningCount'] = (existing['listeningCount'] ?? 0) + 1;
      existing['lastPlayed'] = now;
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
      song['lastPlayed'] = now;
      updatedList.insert(0, song);
    } else {
      final dynamic fetchedSongDetails = songFallback != null
          ? Map<String, dynamic>.from(songFallback)
          : await getSongDetails(0, songId);

      if (fetchedSongDetails is! Map) {
        logger.log('Failed to update recently played: invalid song details');
        return;
      }

      final newSongDetails = Map<String, dynamic>.from(fetchedSongDetails);
      newSongDetails['ytid'] ??= songId;
      newSongDetails['listeningCount'] = 1;
      newSongDetails['lastPlayed'] = now;
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

// ===== UI compatibility layer =====
List<dynamic> nextRecommendedSongs = [];

Future<Map<String, dynamic>> fetchSongsListWithPagination(String searchQuery) async {
  try {
    final searchResults = await ytClient.search
        .search(searchQuery)
        .timeout(const Duration(seconds: 8));
    final songsList = searchResults
        .map((video) => returnSongLayout(0, video))
        .toList();
    return {
      'songs': songsList,
      'nextPage': searchResults,
    };
  } catch (e, stackTrace) {
    logger.log('Error in fetchSongsListWithPagination', error: e, stackTrace: stackTrace);
    return {'songs': [], 'nextPage': null};
  }
}

Future<Map<String, dynamic>> fetchNextSongsList(dynamic currentList) async {
  if (currentList == null) return {'songs': [], 'nextPage': null};
  try {
    if (currentList is VideoSearchList) {
      final VideoSearchList? nextPage = await currentList.nextPage();
      if (nextPage == null) {
        return {'songs': [], 'nextPage': null};
      }
      final songsList = nextPage
          .map((video) => returnSongLayout(0, video))
          .toList();
      return {
        'songs': songsList,
        'nextPage': nextPage,
      };
    }
    return {'songs': [], 'nextPage': null};
  } catch (e, stackTrace) {
    logger.log('Error in fetchNextSongsList', error: e, stackTrace: stackTrace);
    return {'songs': [], 'nextPage': null};
  }
}

Future<List> getQuickPicks() async {
  try {
    return await getRecommendedSongs();
  } catch (e, stackTrace) {
    logger.log('Error in getQuickPicks', error: e, stackTrace: stackTrace);
    return [];
  }
}

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

/// Returns trending songs (uses YouTube recommendations as trending source).
List _trendingCache = [];
DateTime? _trendingCacheTime;

Future<List> getTrendingSongs() async {
  try {
    // Return cached result if less than 30 minutes old
    if (_trendingCache.isNotEmpty &&
        _trendingCacheTime != null &&
        DateTime.now().difference(_trendingCacheTime!).inMinutes < 30) {
      return _trendingCache;
    }
    final results = await ytClient.search
        .search('india trending songs')
        .timeout(const Duration(seconds: 8));
    final songs = results.map((video) => returnSongLayout(0, video)).toList();
    if (songs.isNotEmpty) {
      _trendingCache = songs;
      _trendingCacheTime = DateTime.now();
    }
    return songs;
  } catch (e, stackTrace) {
    logger.log('Error in getTrendingSongs', error: e, stackTrace: stackTrace);
    if (_trendingCache.isNotEmpty) return _trendingCache;
    return [];
  }
}

// ===== Popular Albums, Radio & Artists (YouTube API) =====

List _popularAlbumsCache = [];
DateTime? _popularAlbumsCacheTime;

Future<List> getPopularAlbumsAndSingles() async {
  try {
    if (_popularAlbumsCache.isNotEmpty &&
        _popularAlbumsCacheTime != null &&
        DateTime.now().difference(_popularAlbumsCacheTime!).inMinutes < 30) {
      return _popularAlbumsCache;
    }

    final albums = <Map<String, dynamic>>[];

    try {
      final searchResults = await ytClient.search.searchContent(
        'bollywood hit album playlist',
        filter: TypeFilters.playlist,
      );

      for (final item in searchResults) {
        if (item is SearchPlaylist) {
          final thumb = item.thumbnails.isNotEmpty
              ? item.thumbnails.first.url.toString()
              : '';
          albums.add({
            'ytid': item.id.toString(),
            'title': item.title.replaceAll(RegExp('playlist|full album|audio jukebox', caseSensitive: false), '').trim(),
            'rawTitle': item.title,
            'image': thumb,
            'subtitle': 'Album',
            'isAlbum': true,
          });
        }
        if (albums.length >= 12) break;
      }
    } catch (_) {}

    if (albums.length < 5) {
      final results = await ytClient.search.search('popular hindi hit album songs');
      for (final video in results.take(12)) {
        final song = returnSongLayout(0, video);
        albums.add({
          ...song,
          'subtitle': 'Single',
          'isAlbum': false,
        });
      }
    }

    if (albums.isNotEmpty) {
      _popularAlbumsCache = albums;
      _popularAlbumsCacheTime = DateTime.now();
    }
    return albums;
  } catch (e, stackTrace) {
    logger.log('Error in getPopularAlbumsAndSingles', error: e, stackTrace: stackTrace);
    if (_popularAlbumsCache.isNotEmpty) return _popularAlbumsCache;
    return [];
  }
}

List _popularRadioCache = [];
DateTime? _popularRadioCacheTime;

Future<List> getPopularRadioStations() async {
  try {
    if (_popularRadioCache.isNotEmpty &&
        _popularRadioCacheTime != null &&
        DateTime.now().difference(_popularRadioCacheTime!).inMinutes < 30) {
      return _popularRadioCache;
    }

    final radioItems = <Map<String, dynamic>>[];

    try {
      final searchResults = await ytClient.search.searchContent(
        'hindi artist radio mix playlist',
        filter: TypeFilters.playlist,
      );

      for (final item in searchResults) {
        if (item is SearchPlaylist) {
          final thumb = item.thumbnails.isNotEmpty
              ? item.thumbnails.first.url.toString()
              : '';
          final cleanTitle = item.title
              .replaceAll(RegExp('playlist|full album|songs?|jukebox|audio|official', caseSensitive: false), '')
              .trim();
          radioItems.add({
            'ytid': item.id.toString(),
            'title': cleanTitle.isNotEmpty ? cleanTitle : item.title,
            'rawTitle': item.title,
            'image': thumb,
            'subtitle': 'Popular Radio',
            'isRadio': true,
          });
        }
        if (radioItems.length >= 12) break;
      }
    } catch (_) {}

    if (radioItems.length < 4) {
      final popularArtists = [
        {'name': 'Arijit Singh', 'sub': 'Arijit Singh, Pritam, Atif Aslam...'},
        {'name': 'Sidhu Moose Wala', 'sub': 'Sidhu Moose Wala, Karan Aujla, AP Dhillon...'},
        {'name': 'Diljit Dosanjh', 'sub': 'Diljit Dosanjh, Badshah, Yo Yo Honey Singh...'},
        {'name': 'Shreya Ghoshal', 'sub': 'Shreya Ghoshal, Sunidhi Chauhan, Neha Kakkar...'},
        {'name': 'Pritam', 'sub': 'Pritam, Sachin-Jigar, Mithoon...'},
        {'name': 'Atif Aslam', 'sub': 'Atif Aslam, Rahat Fateh Ali Khan, KK...'},
      ];

      final results = await Future.wait(
        popularArtists.map((artist) async {
          try {
            final res = await ytClient.search.search('${artist['name']} mix playlist');
            if (res.isNotEmpty) {
              final video = res.first;
              return {
                'ytid': video.id.toString(),
                'title': '${artist['name']} Radio',
                'artist': artist['name'],
                'image': video.thumbnails.standardResUrl,
                'subtitle': artist['sub'],
                'isRadio': true,
              };
            }
          } catch (_) {}
          return null;
        }),
      );

      for (final r in results) {
        if (r != null) radioItems.add(r);
      }
    }

    if (radioItems.isNotEmpty) {
      _popularRadioCache = radioItems;
      _popularRadioCacheTime = DateTime.now();
    }
    return radioItems;
  } catch (e, stackTrace) {
    logger.log('Error in getPopularRadioStations', error: e, stackTrace: stackTrace);
    if (_popularRadioCache.isNotEmpty) return _popularRadioCache;
    return [];
  }
}

List _popularArtistsCache = [];
DateTime? _popularArtistsCacheTime;

Future<List> getPopularArtistsList() async {
  try {
    if (_popularArtistsCache.isNotEmpty &&
        _popularArtistsCacheTime != null &&
        DateTime.now().difference(_popularArtistsCacheTime!).inMinutes < 30) {
      return _popularArtistsCache;
    }

    final topArtists = [
      'Arijit Singh',
      'Sidhu Moose Wala',
      'Diljit Dosanjh',
      'Shreya Ghoshal',
      'Pritam',
      'Atif Aslam',
      'Karan Aujla',
      'Yo Yo Honey Singh',
      'Badshah',
      'Anirudh Ravichander',
      'A.R. Rahman',
      'Neha Kakkar',
    ];

    // Check if trending songs have more recent popular artists
    final dynamicArtists = <String>[];
    if (_trendingCache.isNotEmpty) {
      for (final song in _trendingCache) {
        final artist = song['artist']?.toString().trim();
        if (artist != null &&
            artist.isNotEmpty &&
            !artist.toLowerCase().contains('various') &&
            !dynamicArtists.contains(artist)) {
          dynamicArtists.add(artist);
        }
      }
    }

    final mergedArtistNames = {...dynamicArtists, ...topArtists}.take(12).toList();

    final artistResults = await Future.wait(
      mergedArtistNames.map((name) async {
        try {
          final res = await searchVerifiedArtists(name, limit: 1);
          if (res.isNotEmpty) {
            final artist = res.first;
            final image = artist['image']?.toString();
            if (image != null && image.isNotEmpty) {
              return artist;
            }
          }
          final fallback = await ytClient.search
              .search(name)
              .timeout(const Duration(seconds: 6));
          if (fallback.isNotEmpty) {
            final video = fallback.first;
            return {
              'ytid': name,
              'title': name,
              'image': video.thumbnails.standardResUrl,
              'videoAuthor': video.author,
              'isArtist': true,
            };
          }
        } catch (_) {}
        return null;
      }),
    );

    final validArtists = artistResults.whereType<Map<String, dynamic>>().toList();

    if (validArtists.isNotEmpty) {
      _popularArtistsCache = validArtists;
      _popularArtistsCacheTime = DateTime.now();
    }
    return validArtists;
  } catch (e, stackTrace) {
    logger.log('Error in getPopularArtistsList', error: e, stackTrace: stackTrace);
    if (_popularArtistsCache.isNotEmpty) return _popularArtistsCache;
    return [];
  }
}

final Map<String, List> _moodTracksCache = {};
final Map<String, List> _moodPlaylistsCache = {};

Future<List> getMoodTracks(String mood) async {
  if (_moodTracksCache.containsKey(mood) && _moodTracksCache[mood]!.isNotEmpty) {
    return _moodTracksCache[mood]!;
  }
  try {
    final query = '$mood songs hits';
    final searchList = await ytClient.search
        .search(query)
        .timeout(const Duration(seconds: 8));
    final songs = searchList.take(20).map((video) {
      return {
        'ytid': video.id.value,
        'title': video.title,
        'artist': video.author,
        'image': video.thumbnails.standardResUrl,
        'lowResImage': video.thumbnails.lowResUrl,
        'highResImage': video.thumbnails.maxResUrl,
        'duration': video.duration?.inSeconds ?? 0,
        'isLive': video.isLive,
      };
    }).toList();
    if (songs.isNotEmpty) {
      _moodTracksCache[mood] = songs;
    }
    return songs;
  } catch (e, stackTrace) {
    logger.log('Error in getMoodTracks($mood)', error: e, stackTrace: stackTrace);
    return _moodTracksCache[mood] ?? [];
  }
}

Future<List> getMoodPlaylists(String mood) async {
  if (_moodPlaylistsCache.containsKey(mood) && _moodPlaylistsCache[mood]!.isNotEmpty) {
    return _moodPlaylistsCache[mood]!;
  }
  try {
    final query = '$mood playlist';
    final searchList = await ytClient.search
        .searchContent(
          query,
          filter: TypeFilters.playlist,
        )
        .timeout(const Duration(seconds: 8));
    final playlists = <Map<String, dynamic>>[];
    for (final item in searchList) {
      if (item is SearchPlaylist) {
        final thumb = item.thumbnails.isNotEmpty
            ? item.thumbnails.first.url.toString()
            : '';
        playlists.add({
          'ytid': item.id.toString(),
          'title': item.title,
          'image': thumb,
          'artist': 'Playlist',
          'songCount': item.videoCount,
          'isPlaylist': true,
        });
      }
      if (playlists.length >= 10) break;
    }
    if (playlists.isNotEmpty) {
      _moodPlaylistsCache[mood] = playlists;
    }
    return playlists;
  } catch (e, stackTrace) {
    logger.log('Error in getMoodPlaylists($mood)', error: e, stackTrace: stackTrace);
    return _moodPlaylistsCache[mood] ?? [];
  }
}
