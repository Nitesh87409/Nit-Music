import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:musify/main.dart' show logger;
import 'package:dart_des/dart_des.dart';

/// Service to interact with JioSaavn's unofficial API.
///
/// All methods hit `www.jiosaavn.com/api.php` directly — no third-party
/// wrapper needed. Stream URLs are DES-ECB encrypted; [decryptUrl] handles
/// that transparently.
class JioSaavnApi {
  JioSaavnApi._();
  static final JioSaavnApi instance = JioSaavnApi._();

  static const String _baseUrl = 'https://www.jiosaavn.com/api.php';
  static const String _desKey = '38346591';

  // ───────────────────────── helpers ─────────────────────────

  static final _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
  };

  Uri _buildUri(Map<String, String> params) {
    return Uri.parse(_baseUrl).replace(
      queryParameters: {
        '_format': 'json',
        '_marker': '0',
        'ctx': 'android',
        ...params,
      },
    );
  }

  Future<dynamic> _get(Map<String, String> params, {String? ctxOverride}) async {
    final Map<String, String> finalParams = Map.from(params);
    if (ctxOverride != null) {
      finalParams['ctx'] = ctxOverride;
    }
    final uri = _buildUri(finalParams);
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('JioSaavn API error: ${response.statusCode}');
    }
    return json.decode(response.body);
  }

  /// Decrypt a JioSaavn encrypted media URL using DES/ECB.
  String decryptUrl(String encryptedUrl) {
    try {
      final keyBytes = utf8.encode(_desKey);
      final encryptedBytes = base64.decode(encryptedUrl);

      final desECB = DES(key: keyBytes, mode: DESMode.ECB);
      final decryptedBytes = desECB.decrypt(encryptedBytes);

      var url = utf8.decode(decryptedBytes, allowMalformed: true);
      // Remove trailing padding characters (0x01-0x08)
      url = url.replaceAll(RegExp(r'[\x01-\x08]+$'), '');
      return url;
    } catch (e, st) {
      logger.log('JioSaavnApi.decryptUrl error', error: e, stackTrace: st);
      return '';
    }
  }

  // ───────────────────────── public API ─────────────────────────

  /// Search for songs. Returns a list of raw JioSaavn song maps.
  Future<List<Map<String, dynamic>>> searchSongs(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final data = await _get({
        '__call': 'search.getResults',
        'q': query,
        'p': page.toString(),
        'n': limit.toString(),
      });

      final results = data['results'];
      if (results == null || results is! List) return [];

      return List<Map<String, dynamic>>.from(
        results.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    } catch (e, st) {
      logger.log('JioSaavnApi.searchSongs error', error: e, stackTrace: st);
      return [];
    }
  }

  /// Get details for a single song by its JioSaavn ID (pids).
  Future<Map<String, dynamic>?> getSongDetails(String songId) async {
    try {
      final data = await _get({
        '__call': 'song.getDetails',
        'pids': songId,
      });

      // The response wraps the song inside a map keyed by song ID.
      if (data is Map && data.containsKey('songs')) {
        final songs = data['songs'] as List?;
        if (songs != null && songs.isNotEmpty) {
          return Map<String, dynamic>.from(songs.first as Map);
        }
      }
      // Alternatively the response is keyed by the song ID directly.
      if (data is Map && data.containsKey(songId)) {
        final song = data[songId];
        if (song is Map) return Map<String, dynamic>.from(song);
      }
      return null;
    } catch (e, st) {
      logger.log('JioSaavnApi.getSongDetails error', error: e, stackTrace: st);
      return null;
    }
  }

  /// Get the direct playable stream URL for a song.
  /// [encryptedMediaUrl] is the `encrypted_media_url` field from song data.
  /// Returns a high-quality (320kbps) direct MP4 link.
  String getSongStreamUrl(String encryptedMediaUrl, {bool highQuality = true}) {
    var url = decryptUrl(encryptedMediaUrl);
    if (highQuality) {
      url = url.replaceAll('_96.mp4', '_320.mp4');
    }
    return url;
  }

  /// Fetch trending / top songs (Hindi charts).
  Future<List<Map<String, dynamic>>> getTrendingSongs() async {
    try {
      // Use the top charts / new releases endpoint
      final data = await _get({
        '__call': 'content.getHomepageData',
      });

      final List<Map<String, dynamic>> songs = [];

      if (data is Map) {
        // Try to extract from 'new_trending' or 'charts' or 'trending' modules
        for (final key in [
          'new_trending',
          'trending',
          'charts',
          'top_playlists',
          'new_albums',
        ]) {
          if (data.containsKey(key)) {
            final module = data[key];
            List? items;
            if (module is List) {
              items = module;
            } else if (module is Map && module.containsKey('data')) {
              items = module['data'] as List?;
            }
            if (items != null) {
              for (final item in items) {
                if (item is Map &&
                    item.containsKey('id') &&
                    item.containsKey('song') &&
                    item.containsKey('encrypted_media_url')) {
                  songs.add(Map<String, dynamic>.from(item));
                }
              }
              if (songs.length >= 15) break;
            }
          }
        }
      }

      // Fallback: search for trending
      if (songs.isEmpty) {
        return searchSongs('trending Hindi songs 2026', limit: 15);
      }

      return songs.take(15).toList();
    } catch (e, st) {
      logger.log('JioSaavnApi.getTrendingSongs error',
          error: e, stackTrace: st);
      // Fallback to search
      return searchSongs('new Hindi songs', limit: 15);
    }
  }

  /// Get search autocomplete suggestions.
  Future<List<String>> getSearchSuggestions(String query) async {
    try {
      final data = await _get({
        '__call': 'autocomplete.get',
        'query': query,
      });

      final suggestions = <String>[];

      if (data is Map) {
        // Extract from 'topquery' and 'songs' sections
        for (final key in ['topquery', 'songs', 'albums', 'artists']) {
          final section = data[key];
          if (section is Map && section.containsKey('data')) {
            final items = section['data'];
            if (items is List) {
              for (final item in items) {
                if (item is Map) {
                  final title = item['title']?.toString();
                  if (title != null && title.isNotEmpty) {
                    suggestions.add(title);
                  }
                }
              }
            }
          }
        }
      }

      return suggestions.take(10).toList();
    } catch (e, st) {
      logger.log('JioSaavnApi.getSearchSuggestions error',
          error: e, stackTrace: st);
      return [];
    }
  }

  /// Get detailed autocomplete results from JioSaavn.
  /// Returns a map containing categories like 'topquery', 'songs', 'albums', 'artists', 'playlists'.
  Future<Map<String, dynamic>> getAutocompleteResults(String query) async {
    try {
      final data = await _get({
        '__call': 'autocomplete.get',
        'query': query,
      });

      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } catch (e, st) {
      logger.log('JioSaavnApi.getAutocompleteResults error',
          error: e, stackTrace: st);
      return {};
    }
  }

  /// Get songs from a JioSaavn playlist by playlist ID.
  Future<List<Map<String, dynamic>>> getPlaylistSongs(
      String playlistId) async {
    try {
      final data = await _get({
        '__call': 'playlist.getDetails',
        'listid': playlistId,
      }, ctxOverride: 'web6dot0');

      if (data is Map && data.containsKey('songs')) {
        final list = data['songs'];
        if (list is List) {
          return List<Map<String, dynamic>>.from(
            list.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      return [];
    } catch (e, st) {
      logger.log('JioSaavnApi.getPlaylistSongs error',
          error: e, stackTrace: st);
      return [];
    }
  }

  /// Get details of a JioSaavn playlist.
  Future<Map<String, dynamic>?> getPlaylist(String playlistId) async {
    try {
      final data = await _get({
        '__call': 'playlist.getDetails',
        'listid': playlistId,
      }, ctxOverride: 'web6dot0');

      if (data is Map && data.containsKey('listid')) {
        return {
          'id': data['listid'],
          'title': data['listname'] ?? data['title'],
          'image': data['image'],
          'isAlbum': false,
        };
      }
      return null;
    } catch (e, st) {
      logger.log('JioSaavnApi.getPlaylist error', error: e, stackTrace: st);
      return null;
    }
  }

  /// Get songs from a JioSaavn album by album ID.
  Future<List<Map<String, dynamic>>> getAlbumSongs(String albumId) async {
    try {
      final data = await _get({
        '__call': 'content.getAlbumDetails',
        'albumid': albumId,
      }, ctxOverride: 'web6dot0');

      if (data is Map && data.containsKey('songs')) {
        final list = data['songs'];
        if (list is List) {
          return List<Map<String, dynamic>>.from(
            list.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      return [];
    } catch (e, st) {
      logger.log('JioSaavnApi.getAlbumSongs error',
          error: e, stackTrace: st);
      return [];
    }
  }

  /// Get details of a JioSaavn album.
  Future<Map<String, dynamic>?> getAlbum(String albumId) async {
    try {
      final data = await _get({
        '__call': 'content.getAlbumDetails',
        'albumid': albumId,
      }, ctxOverride: 'web6dot0');

      if (data is Map && data.containsKey('albumid')) {
        return {
          'id': data['albumid'],
          'title': data['title'] ?? data['name'],
          'image': data['image'],
          'isAlbum': true,
        };
      }
      return null;
    } catch (e, st) {
      logger.log('JioSaavnApi.getAlbum error', error: e, stackTrace: st);
      return null;
    }
  }

  /// Search for playlists.
  Future<List<Map<String, dynamic>>> searchPlaylists(String query) async {
    try {
      final data = await _get({
        '__call': 'search.getPlaylistResults',
        'q': query,
        'p': '1',
        'n': '15',
      });

      final results = data['results'];
      if (results == null || results is! List) return [];

      return List<Map<String, dynamic>>.from(
        results.map((e) {
          final item = Map<String, dynamic>.from(e as Map);
          return {
            'ytid': item['listid']?.toString() ?? '',
            'title': _cleanHtml(item['listname']?.toString() ?? 'Unknown Playlist'),
            'image': _getBestImage({'image': item['image']}),
            'isAlbum': false,
            'source': 'jiosaavn-playlist',
          };
        }),
      );
    } catch (e, st) {
      logger.log('JioSaavnApi.searchPlaylists error', error: e, stackTrace: st);
      return [];
    }
  }

  /// Search for albums.
  Future<List<Map<String, dynamic>>> searchAlbums(String query) async {
    try {
      final data = await _get({
        '__call': 'search.getAlbumResults',
        'q': query,
        'p': '1',
        'n': '15',
      });

      final results = data['results'];
      if (results == null || results is! List) return [];

      return List<Map<String, dynamic>>.from(
        results.map((e) {
          final item = Map<String, dynamic>.from(e as Map);
          return {
            'ytid': item['albumid']?.toString() ?? '',
            'title': _cleanHtml(item['title']?.toString() ?? 'Unknown Album'),
            'image': _getBestImage({'image': item['image']}),
            'isAlbum': true,
            'source': 'jiosaavn-album',
          };
        }),
      );
    } catch (e, st) {
      logger.log('JioSaavnApi.searchAlbums error', error: e, stackTrace: st);
      return [];
    }
  }

  /// Search for artists.
  Future<List<Map<String, dynamic>>> searchArtists(String query) async {
    try {
      final data = await _get({
        '__call': 'search.getArtistResults',
        'q': query,
        'p': '1',
        'n': '15',
      });

      final results = data['results'];
      if (results == null || results is! List) return [];

      return List<Map<String, dynamic>>.from(
        results.map((e) {
          final item = Map<String, dynamic>.from(e as Map);
          return {
            'ytid': item['id']?.toString() ?? '',
            'title': _cleanHtml(item['name']?.toString() ?? 'Unknown Artist'),
            'image': _getBestImage({'image': item['image']}),
            'isArtist': true,
            'source': 'jiosaavn-artist',
          };
        }),
      );
    } catch (e, st) {
      logger.log('JioSaavnApi.searchArtists error', error: e, stackTrace: st);
      return [];
    }
  }

  /// Get related / recommended songs for a given song.
  /// Uses the song's station (radio) feature.
  Future<List<Map<String, dynamic>>> getRelatedSongs(String songId) async {
    try {
      // First get the station ID
      final stationData = await _get({
        '__call': 'webradio.createEntityStation',
        'entity_id': '["$songId"]',
        'entity_type': 'queue',
      });

      String? stationId;
      if (stationData is Map && stationData.containsKey('stationid')) {
        stationId = stationData['stationid']?.toString();
      }

      if (stationId == null || stationId.isEmpty) {
        // Fallback: search for similar content
        final details = await getSongDetails(songId);
        if (details != null) {
          final artistString = details['primary_artists']?.toString() ?? '';
          if (artistString.isNotEmpty) {
            // Split by comma and take the first prominent artist to ensure we get results
            final firstArtist = artistString.split(',').first.trim();
            if (firstArtist.isNotEmpty) {
              final results = await searchSongs(firstArtist, limit: 50);
              results.shuffle();
              return results;
            }
          }
        }
        return [];
      }

      // Get songs from the station
      final songsData = await _get({
        '__call': 'webradio.getSong',
        'stationid': stationId,
        'k': '20',
      });

      if (songsData is Map) {
        final songs = <Map<String, dynamic>>[];
        for (final value in songsData.values) {
          if (value is Map && value.containsKey('song')) {
            final song = value['song'];
            if (song is Map) {
              songs.add(Map<String, dynamic>.from(song));
            }
          }
        }
        return songs;
      }

      return [];
    } catch (e, st) {
      logger.log('JioSaavnApi.getRelatedSongs error',
          error: e, stackTrace: st);
      return [];
    }
  }

  // ───────────────────────── data formatting helpers ─────────────────────────

  /// Convert a raw JioSaavn song map to the app's standard song layout format.
  /// This produces the same `Map<String, dynamic>` structure that the rest of
  /// the app expects (title, artist, ytid, image, duration, etc.).
  Map<String, dynamic> formatSong(Map<String, dynamic> saavnSong,
      {int index = 0}) {
    if (saavnSong.containsKey('ytid') && saavnSong.containsKey('source')) {
      return saavnSong; // Already formatted
    }

    final title = _cleanHtml(saavnSong['song']?.toString() ??
        saavnSong['title']?.toString() ??
        'Unknown');
    final artist = _cleanHtml(
        saavnSong['primary_artists']?.toString() ??
            saavnSong['singers']?.toString() ??
            saavnSong['music']?.toString() ??
            'Unknown Artist');
    final songId = saavnSong['id']?.toString() ?? '';
    final duration = int.tryParse(saavnSong['duration']?.toString() ?? '0') ?? 0;

    // Get the best available image
    final imageUrl = _getBestImage(saavnSong);
    final lowResImage = _getLowResImage(saavnSong);

    return {
      'id': index,
      'ytid': songId,
      'title': title,
      'artist': artist,
      'artistId': saavnSong['primary_artists_id']?.toString() ?? '',
      'videoAuthor': artist,
      'image': imageUrl,
      'lowResImage': lowResImage,
      'highResImage': imageUrl,
      'duration': duration,
      'isLive': false,
      // JioSaavn-specific fields for stream resolution
      'encrypted_media_url':
          saavnSong['encrypted_media_url']?.toString() ?? '',
      'has_320kbps': saavnSong['320kbps']?.toString() == 'true',
      'source': 'jiosaavn',
    };
  }

  String _cleanHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  }

  String _getBestImage(Map<String, dynamic> song) {
    final image = song['image']?.toString() ?? '';
    if (image.isEmpty) return '';
    // JioSaavn images come in 50x50, 150x150, 500x500 sizes
    return image
        .replaceAll('50x50', '500x500')
        .replaceAll('150x150', '500x500');
  }

  String _getLowResImage(Map<String, dynamic> song) {
    final image = song['image']?.toString() ?? '';
    if (image.isEmpty) return '';
    return image
        .replaceAll('50x50', '150x150')
        .replaceAll('500x500', '150x150');
  }
}
