import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:musify/main.dart';

class LyricsService {
  static const String _baseUrl = 'https://lrclib.net/api/get';

  /// Fetches synced lyrics from LRCLIB.
  /// Returns a Map containing 'syncedLyrics' and 'plainLyrics' if found, else null.
  static Future<Map<String, dynamic>?> fetchLyrics({
    required String trackName,
    String? artistName,
    Duration? duration,
  }) async {
    try {
      // Clean up track name (remove (Official Video), [Audio], etc.)
      final cleanTrackName = _cleanString(trackName);
      final cleanArtistName = artistName != null ? _cleanString(artistName) : '';

      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'track_name': cleanTrackName,
        if (cleanArtistName.isNotEmpty) 'artist_name': cleanArtistName,
        if (duration != null) 'duration': duration.inSeconds.toString(),
      });

      final response = await http.get(
        uri,
        headers: {'User-Agent': 'MusifyFlutterApp (https://github.com/Nitesh87409/Nit-Music)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data as Map<String, dynamic>;
      } else {
        // Fallback: try searching without duration and without artist if first fails
        if (duration != null || cleanArtistName.isNotEmpty) {
           return await _fallbackSearch(cleanTrackName, cleanArtistName);
        }
      }
    } catch (e, stackTrace) {
      logger.log('Error fetching lyrics', error: e, stackTrace: stackTrace);
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _fallbackSearch(String trackName, String artistName) async {
    try {
      final searchUri = Uri.parse('https://lrclib.net/api/search').replace(queryParameters: {
        'q': '$trackName $artistName'.trim(),
      });
      
      final response = await http.get(
        searchUri,
        headers: {'User-Agent': 'MusifyFlutterApp (https://github.com/Nitesh87409/Nit-Music)'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          // Return the first match that has synced lyrics if possible, otherwise just the first
          final syncedMatch = data.firstWhere(
            (item) => item['syncedLyrics'] != null,
            orElse: () => data.first,
          );
          return syncedMatch as Map<String, dynamic>;
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  static String _cleanString(String input) {
    return input
        .replaceAll(RegExp(r'\(.*?\)'), '') // Remove anything in parentheses
        .replaceAll(RegExp(r'\[.*?\]'), '') // Remove anything in brackets
        .replaceAll(RegExp(r'(?i)official video'), '')
        .replaceAll(RegExp(r'(?i)official audio'), '')
        .replaceAll(RegExp(r'(?i)lyric video'), '')
        .replaceAll(RegExp(r'(?i)music video'), '')
        .split('|')[0] // Sometimes titles have |
        .split('-')[0] // Handle "Artist - Track" slightly, though mostly we just want to remove noise
        .trim();
  }
}

/// Helper to parse LRC time format
class LrcLine {
  final Duration time;
  final String text;

  LrcLine(this.time, this.text);
}

List<LrcLine> parseLrc(String lrcContent) {
  final lines = lrcContent.split('\n');
  final result = <LrcLine>[];
  
  final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');

  for (final line in lines) {
    final match = regex.firstMatch(line);
    if (match != null) {
      final minutes = int.parse(match.group(1)!);
      final seconds = int.parse(match.group(2)!);
      
      String msString = match.group(3)!;
      // If 2 digits, it's 10s of milliseconds (e.g. 50 = 500ms). If 3 digits, it's milliseconds.
      if (msString.length == 2) msString += '0';
      final milliseconds = int.parse(msString);

      final text = match.group(4)?.trim() ?? '';
      
      final time = Duration(
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      );
      
      if (text.isNotEmpty) {
        result.add(LrcLine(time, text));
      }
    }
  }
  
  // LRCLIB sometimes includes lines like [00:15.00] (Instrumental)
  return result;
}
