import 'dart:convert';

import 'package:musify/main.dart';
import 'package:musify/services/jiosaavn_api.dart';

class PlaylistSharingService {
  static Map createCompactPlaylist(Map fullPlaylist) {
    return {
      'title': fullPlaylist['title'],
      if (fullPlaylist['image'] != null) 'image': fullPlaylist['image'],
      'source': 'user-created',
      'list': fullPlaylist['list'].map((song) => song['ytid']).toList(),
    };
  }

  static Future<Map> expandCompactPlaylist(Map compactPlaylist) async {
    final List<dynamic> songIds = compactPlaylist['list'];
    try {
      final saavn = JioSaavnApi.instance;

      final expandedSongs = await Future.wait(
        songIds.map((ytid) async {
          try {
            final songData = await saavn.getSongDetails(ytid.toString());
            if (songData != null) {
              return saavn.formatSong(songData, index: songIds.indexOf(ytid));
            }
            return null;
          } catch (e, stackTrace) {
            logger.log(
              'Error expanding song: $ytid',
              error: e,
              stackTrace: stackTrace,
            );
            return null;
          }
        }),
      );

      return {
        ...compactPlaylist,
        'list': expandedSongs.where((song) => song != null).toList(),
      };
    } finally {
      // Nothing to close
    }
  }

  static String encodePlaylist(Map playlist) {
    final compactPlaylist = createCompactPlaylist(playlist);
    return base64Url.encode(utf8.encode(json.encode(compactPlaylist)));
  }

  static Future<Map?> decodeAndExpandPlaylist(String encodedPlaylist) async {
    try {
      final jsonString = utf8.decode(base64Url.decode(encodedPlaylist));
      final compactPlaylist = json.decode(jsonString) as Map;
      return await expandCompactPlaylist(compactPlaylist);
    } catch (e, stackTrace) {
      logger.log('Failed to decode playlist', error: e, stackTrace: stackTrace);
      return null;
    }
  }
}
