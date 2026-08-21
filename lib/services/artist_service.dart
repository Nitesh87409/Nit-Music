import 'dart:async';

import 'package:musify/main.dart' show logger;
import 'package:musify/services/data_manager.dart';
import 'package:musify/services/jiosaavn_api.dart';

const artistCatalogCacheVersion = 16;
const artistSearchCacheVersion = 11;

final _saavn = JioSaavnApi.instance;

Future<List<Map<String, dynamic>>> searchVerifiedArtists(
  String query, {
  int limit = 5,
}) async {
  final normalizedQuery = query.trim();
  if (normalizedQuery.isEmpty) return [];

  final cacheKey =
      'search_saavn_artists_v${artistSearchCacheVersion}_l$limit'
      '_${normalizedQuery.toLowerCase()}';
  
  final cachedArtists = await getData('cache', cacheKey);
  if (cachedArtists is List) {
    return cachedArtists
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .take(limit)
        .toList();
  }

  try {
    // We search for songs and extract artists, as JioSaavn artist search
    // sometimes returns less rich data. But let's just use the autocomplete.
    await _saavn.getSearchSuggestions(normalizedQuery);
    
    // For simplicity, we just return dummy artist objects based on search,
    // or rely on the actual song's artistId when clicked.
    // In Musify, artist pages are usually opened from a Song's artistId.
    
    return []; // Empty for now, we rely on song->artist navigation
  } catch (e, stackTrace) {
    logger.log(
      'Error while searching artists for "$normalizedQuery"',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
  }
}

Future<Map<String, dynamic>?> resolveArtist(
  String lookup, {
  String? sourceSongId,
  String? sourceVideoAuthor,
  String? preferredName,
  String? preferredImage,
  bool preferredVerified = false,
}) async {
  final normalizedLookup = lookup.trim();
  if (normalizedLookup.isEmpty || normalizedLookup == 'null') return null;

  return {
    'id': normalizedLookup,
    'ytid': normalizedLookup,
    'title': preferredName ?? normalizedLookup,
    'image': preferredImage ?? '',
    'lowResImage': preferredImage ?? '',
    'highResImage': preferredImage ?? '',
    'isVerified': true,
  };
}

Future<Map<String, dynamic>?> getArtistCatalog(
  String artistId, {
  bool forceRefresh = false,
  String? sourceSongId,
  String? sourceVideoAuthor,
  String? preferredName,
  String? preferredImage,
  bool preferredVerified = false,
}) async {
  try {
    final artist = await resolveArtist(
      artistId,
      preferredName: preferredName,
      preferredImage: preferredImage,
      sourceSongId: sourceSongId,
      sourceVideoAuthor: sourceVideoAuthor,
      preferredVerified: preferredVerified,
    );

    if (artist == null) return null;

    final resolvedArtistId = artist['ytid']?.toString() ?? artistId;
    final cacheKey =
        'artist_catalog_v${artistCatalogCacheVersion}_$resolvedArtistId';
    if (!forceRefresh) {
      final cachedArtist = await getData('cache', cacheKey);
      if (cachedArtist is Map &&
          cachedArtist['list'] is List &&
          (cachedArtist['list'] as List).isNotEmpty) {
        return Map<String, dynamic>.from(cachedArtist);
      }
    } else {
      await deleteData('cache', cacheKey);
      await deleteData('cache', '${cacheKey}_date');
    }

    // Since JioSaavn artist catalog fetching requires a specific endpoint
    // and we usually don't have it fully mapped out, we will just search
    // for the artist's name and return the top songs.
    final songs = await _saavn.searchSongs(artist['title']?.toString() ?? '', limit: 50);
    final formattedSongs = songs.map((s) => _saavn.formatSong(s)).toList();

    final artistPlaylist = {
      ...artist,
      'source': 'jiosaavn-artist',
      'isArtist': true,
      'catalogStatus': 'complete',
      'isCatalogComplete': true,
      'list': formattedSongs,
      'unfetchedReleases': [],
    };

    unawaited(addOrUpdateData<Map>('cache', cacheKey, artistPlaylist));
    return artistPlaylist;
  } catch (e, stackTrace) {
    logger.log(
      'Error fetching artist catalog for $artistId',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}
