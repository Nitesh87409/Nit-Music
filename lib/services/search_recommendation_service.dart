import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:musify/main.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/data_manager.dart';

// ──────────────────────────────────────────────
//  Search Frequency Tracking
// ──────────────────────────────────────────────

/// Returns the stored search frequency map: { "query": count, ... }
Map<String, int> getSearchFrequency() {
  final raw = Hive.box('user').get('searchFrequency', defaultValue: {});
  if (raw is Map) {
    return Map<String, int>.from(
      raw.map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 1)),
    );
  }
  return {};
}

/// Increments the search count for [query] by 1.
Future<void> updateSearchFrequency(String query) async {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) return;

  final freq = getSearchFrequency();
  freq[trimmed] = (freq[trimmed] ?? 0) + 1;

  await addOrUpdateData<Map>('user', 'searchFrequency', freq);
}

/// Returns search terms sorted by frequency (highest first).
List<MapEntry<String, int>> getSortedSearchTerms() {
  final freq = getSearchFrequency();
  final entries = freq.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}

// ──────────────────────────────────────────────
//  Time-Based Mood Tags
// ──────────────────────────────────────────────

/// Returns mood keywords based on current time of day.
List<String> getTimeBasedMoodTags() {
  final hour = DateTime.now().hour;

  if (hour >= 5 && hour < 11) {
    // Morning
    return ['morning motivation songs', 'workout songs', 'bhakti songs hindi'];
  } else if (hour >= 11 && hour < 17) {
    // Afternoon
    return ['bollywood hits', 'trending songs', 'pop music'];
  } else if (hour >= 17 && hour < 21) {
    // Evening
    return ['drive songs', 'party songs', 'dance songs'];
  } else {
    // Night (9PM - 5AM)
    return ['sad songs', 'lofi songs', 'relaxing music'];
  }
}

// ──────────────────────────────────────────────
//  Listening Weightage — Top Listened Songs
// ──────────────────────────────────────────────

/// Returns recently played songs sorted by listeningCount (descending).
/// Songs that user has listened to more get higher weight.
List<Map<String, dynamic>> getTopListenedSongs({int limit = 10}) {
  final songs = List<Map<String, dynamic>>.from(
    userRecentlyPlayed.value
        .whereType<Map>()
        .map(Map<String, dynamic>.from),
  )
    ..sort((a, b) {
      final countA = (a['listeningCount'] as num?)?.toInt() ?? 0;
      final countB = (b['listeningCount'] as num?)?.toInt() ?? 0;
      return countB.compareTo(countA);
    });

  return songs.take(limit).toList();
}

// ──────────────────────────────────────────────
//  Smart Recommendation Algorithm
// ──────────────────────────────────────────────

/// Fetches smart recommendations based on:
/// 1. Search frequency (most searched terms first)
/// 2. Listening count (most listened songs' artists/titles)
/// 3. Time-based mood tags
///
/// Returns a deduplicated list of song maps.
Future<List<dynamic>> getSmartSearchRecommendations() async {
  try {
    final allResults = <dynamic>[];
    final seenIds = <String>{};

    // 1) Get weighted search keywords from frequency
    final sortedTerms = getSortedSearchTerms();

    // 2) Get top listened songs — extract artist names as bonus keywords
    final topListened = getTopListenedSongs(limit: 5);
    final listenedKeywords = <String>[];
    for (final song in topListened) {
      final artist = song['artist']?.toString().trim();
      if (artist != null && artist.isNotEmpty && artist != 'Unknown') {
        if (!listenedKeywords.contains(artist.toLowerCase())) {
          listenedKeywords.add(artist.toLowerCase());
        }
      }
    }

    // 3) Get time-based mood tags
    final moodTags = getTimeBasedMoodTags();

    // Build a priority queue of keywords to fetch
    // Format: (keyword, maxSongs)
    final fetchQueue = <MapEntry<String, int>>[];

    // Add listened artists with high priority (they actually listened)
    for (var i = 0; i < listenedKeywords.length && i < 3; i++) {
      final songsToFetch = i == 0 ? 4 : 2;
      fetchQueue.add(MapEntry('${listenedKeywords[i]} songs', songsToFetch));
    }

    // Add top searched terms
    for (var i = 0; i < sortedTerms.length && i < 5; i++) {
      final songsToFetch = i == 0 ? 5 : (i == 1 ? 3 : 2);
      fetchQueue.add(MapEntry(sortedTerms[i].key, songsToFetch));
    }

    // Add 1 mood-based tag
    if (moodTags.isNotEmpty) {
      fetchQueue.add(MapEntry(moodTags[0], 3));
    }

    // Fetch songs for each keyword (parallel with timeouts)
    final futures = <Future<List<dynamic>>>[];
    for (final entry in fetchQueue) {
      futures.add(
        fetchSongsList(entry.key)
            .timeout(const Duration(seconds: 5), onTimeout: () => []),
      );
    }

    final results = await Future.wait(futures);

    // Merge results respecting per-keyword limits and deduplication
    for (var i = 0; i < results.length; i++) {
      final maxForThis = fetchQueue[i].value;
      var added = 0;
      for (final song in results[i]) {
        if (added >= maxForThis) break;
        final id = song['ytid']?.toString() ?? '';
        if (id.isNotEmpty && seenIds.add(id)) {
          allResults.add(song);
          added++;
        }
      }
    }

    return allResults;
  } catch (e, stackTrace) {
    logger.log(
      'Error in getSmartSearchRecommendations',
      error: e,
      stackTrace: stackTrace,
    );
    return [];
  }
}
