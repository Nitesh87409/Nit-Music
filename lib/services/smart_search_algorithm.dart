import 'dart:math';
import 'package:musify/main.dart' show logger;

class SmartSearchAlgorithm {
  static final SmartSearchAlgorithm _instance = SmartSearchAlgorithm._internal();
  factory SmartSearchAlgorithm() => _instance;
  SmartSearchAlgorithm._internal();

  // ─────────────────────────────────────────────
  // STEP 1: Words to ignore during scoring/ranking
  // ─────────────────────────────────────────────
  static const Set<String> _scoringStopWords = {
    'song', 'songs', 'mp3', 'video', 'audio', 'full', 'official',
    'new', 'latest', 'best', 'top', 'dj', 'remix', 'hd', '4k',
    'lyrics', 'download', 'free', 'play', 'listen', 'music',
    'gana', 'gane', 'gaane', 'gaana',
  };

  // ─────────────────────────────────────────────
  // STEP 1: Keyword shortcut dictionary
  // ─────────────────────────────────────────────
  static const Map<String, String> _keywordMap = {
    // ── Hindi (हिंदी) ──
    'hi': 'hindi',
    'hin': 'hindi',
    'hnd': 'hindi',
    'hindi': 'hindi',
    'hndi': 'hindi',
    'hidi': 'hindi',
    'hinid': 'hindi',
    
    // ── English (अंग्रेज़ी) ──
    'en': 'english',
    'eng': 'english',
    'engl': 'english',
    'inglish': 'english',
    'angrezi': 'english',
    'angrez': 'english',
    'engish': 'english',
    'englsh': 'english',
    
    // ── Punjabi (पंजाबी) ──
    'pb': 'punjabi',
    'pbi': 'punjabi',
    'pnj': 'punjabi',
    'punj': 'punjabi',
    'pnjabi': 'punjabi',
    'panjabi': 'punjabi',
    'punjbi': 'punjabi',
    'pujabi': 'punjabi',
    'pubjabi': 'punjabi',
    'panjbi': 'punjabi',
    
    // ── Haryanvi (हरियाणवी) ──
    'hr': 'haryanvi',
    'hry': 'haryanvi',
    'hrynvi': 'haryanvi',
    'haryanavi': 'haryanvi',
    'haryani': 'haryanvi',
    'hariyani': 'haryanvi',
    'haryanbi': 'haryanvi',
    'hariyanvi': 'haryanvi',
    'hariyaanvi': 'haryanvi',
    'desi': 'haryanvi',
    
    // ── Bhojpuri (भोजपुरी) ──
    'bp': 'bhojpuri',
    'bhoj': 'bhojpuri',
    'bhojpri': 'bhojpuri',
    'bhojpuria': 'bhojpuri',
    'bhojpure': 'bhojpuri',
    'bhojpuree': 'bhojpuri',
    'bhojpui': 'bhojpuri',
    'bhoj puri': 'bhojpuri',
    
    // ── Bengali (बंगाली) ──
    'bg': 'bengali',
    'bn': 'bengali',
    'bng': 'bengali',
    'bngla': 'bengali',
    'bangla': 'bengali',
    'bangali': 'bengali',
    'bengli': 'bengali',
    'bengla': 'bengali',
    'bengoli': 'bengali',
    
    // ── Tamil (तमिल) ──
    'tm': 'tamil',
    'tam': 'tamil',
    'tml': 'tamil',
    'taml': 'tamil',
    'tamli': 'tamil',
    'tmil': 'tamil',
    
    // ── Telugu (तेलुगु) ──
    'tl': 'telugu',
    'tel': 'telugu',
    'tlg': 'telugu',
    'telgu': 'telugu',
    'telguu': 'telugu',
    'tlugu': 'telugu',
    'telegue': 'telugu',
    
    // ── Marathi (मराठी) ──
    'mr': 'marathi',
    'mrt': 'marathi',
    'mrathi': 'marathi',
    'marthi': 'marathi',
    'marthy': 'marathi',
    'marati': 'marathi',
    'mrth': 'marathi',
    
    // ── Malayalam (मलयालम) ──
    'ml': 'malayalam',
    'mal': 'malayalam',
    'mlm': 'malayalam',
    'mallu': 'malayalam',
    'malyalam': 'malayalam',
    'malyalm': 'malayalam',
    'malayalm': 'malayalam',
    'mlylm': 'malayalam',
    'malaylam': 'malayalam',
    
    // ── Kannada (कन्नड़) ──
    'kn': 'kannada',
    'kan': 'kannada',
    'knd': 'kannada',
    'kannad': 'kannada',
    'kannda': 'kannada',
    'kanada': 'kannada',
    'kanda': 'kannada',
    'kannd': 'kannada',
    
    // ── Gujarati (गुजराती) ──
    'gj': 'gujarati',
    'guj': 'gujarati',
    'gujrati': 'gujarati',
    'gujju': 'gujarati',
    'gujarti': 'gujarati',
    'gujrat': 'gujarati',
    
    // ── Rajasthani (राजस्थानी) ──
    'rj': 'rajasthani',
    'raj': 'rajasthani',
    'rjsthani': 'rajasthani',
    'rajsthani': 'rajasthani',
    'rajesthani': 'rajasthani',
    'rajstani': 'rajasthani',
    'marwadi': 'rajasthani',
    'marwari': 'rajasthani',
    
    // ── Urdu (उर्दू) ──
    'ur': 'urdu',
    'urd': 'urdu',
    'urdo': 'urdu',
    
    // ── Odia (ओड़िया) ──
    'od': 'odia',
    'odi': 'odia',
    'oriya': 'odia',
    'odiya': 'odia',
    'odisa': 'odia',
    'orisa': 'odia',
    
    // ── Assamese (असमिया) ──
    'as': 'assamese',
    'asm': 'assamese',
    'assami': 'assamese',
    'asmese': 'assamese',
    'axomiya': 'assamese',
    'asami': 'assamese',
    
    // ── Bollywood / Genre shortcuts ──
    'bolly': 'bollywood',
    'bolywood': 'bollywood',
    'bwood': 'bollywood',
    'bw': 'bollywood',
    'tolly': 'tollywood',
    'twood': 'tollywood',
    'kolly': 'kollywood',
    'kwood': 'kollywood',
    'polly': 'pollywood',
    'pwood': 'pollywood',
  };

  // ─────────────────────────────────────────────
  // STEP 1: Clean and expand user query
  // ─────────────────────────────────────────────
  
  /// Public method so common_services can use the cleaned query for API calls
  String getCleanedQuery(String rawQuery) => _cleanQuery(rawQuery);

  String _cleanQuery(String rawQuery) {
    // Lowercase and trim
    var query = rawQuery.toLowerCase().trim();

    // Split into words
    var words = query.split(RegExp(r'\s+'));

    // Expand keyword shortcuts
    words = words.map((word) {
      return _keywordMap[word] ?? word;
    }).toList();

    // Return the expanded string keeping all words (no stop-word deletion)
    return words.join(' ');
  }

  // ─────────────────────────────────────────────
  // STEP 2 + 4: Levenshtein Distance (Fuzzy Match)
  // ─────────────────────────────────────────────
  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    // Use two-row optimization to save memory
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      curr[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        curr[j] = [
          curr[j - 1] + 1,      // insertion
          prev[j] + 1,          // deletion
          prev[j - 1] + cost,   // substitution
        ].reduce(min);
      }
      // Swap rows
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[b.length];
  }

  /// Check if queryWord fuzzy-matches targetWord (distance <= 2)
  bool _fuzzyMatch(String queryWord, String targetWord) {
    // Exact substring match first (fastest path)
    if (targetWord.contains(queryWord) || queryWord.contains(targetWord)) {
      return true;
    }
    // Only do Levenshtein on short words to keep it fast
    if (queryWord.length >= 3 && targetWord.length >= 3) {
      return _levenshtein(queryWord, targetWord) <= 2;
    }
    return false;
  }

  // ─────────────────────────────────────────────
  // STEP 2: Calculate match score for a single song
  // ─────────────────────────────────────────────
  double _calculateScore(String cleanedQuery, Map<String, dynamic> song) {
    double score = 0;

    final queryWords = cleanedQuery
        .split(RegExp(r'\s+'))
        .where((w) => !_scoringStopWords.contains(w))
        .toList();

    // If query was ONLY stop words (unlikely), fallback to original words
    if (queryWords.isEmpty) {
      queryWords.addAll(cleanedQuery.split(RegExp(r'\s+')));
    }

    // Extract fields from API response (all lowercase for comparison)
    final title = (song['song']?.toString() ?? song['title']?.toString() ?? '').toLowerCase();
    final language = (song['language']?.toString() ?? '').toLowerCase();
    final primaryArtists = (song['primary_artists']?.toString() ?? '').toLowerCase();
    final singers = (song['singers']?.toString() ?? '').toLowerCase();
    final album = (song['album']?.toString() ?? '').toLowerCase();
    final starring = (song['starring']?.toString() ?? '').toLowerCase();
    final music = (song['music']?.toString() ?? '').toLowerCase();

    // Split title and artist into individual words for word-level matching
    final titleWords = title.split(RegExp(r'[\s,\-\(\)&]+'));
    final artistWords = (primaryArtists + ' ' + singers).split(RegExp(r'[\s,\-\(\)&]+'));

    for (final qWord in queryWords) {
      if (qWord.isEmpty) continue;

      // ── Title Match ──
      // Exact word match in title
      if (titleWords.any((tw) => tw == qWord)) {
        score += 100;
      }
      // Title contains query as substring
      else if (title.contains(qWord)) {
        score += 80;
      }
      // Fuzzy match on title words
      else if (titleWords.any((tw) => tw.length >= 3 && _fuzzyMatch(qWord, tw))) {
        score += 50;
      }

      // ── Language Match ──
      if (language == qWord || language.contains(qWord)) {
        score += 80;
      }

      // ── Artist Match ──
      if (artistWords.any((aw) => aw == qWord)) {
        score += 70;
      } else if (primaryArtists.contains(qWord) || singers.contains(qWord)) {
        score += 60;
      } else if (artistWords.any((aw) => aw.length >= 3 && _fuzzyMatch(qWord, aw))) {
        score += 35;
      }

      // ── Album / Starring Match ──
      if (album.contains(qWord)) {
        score += 40;
      }
      if (starring.contains(qWord)) {
        score += 40;
      }

      // ── Music Director Match ──
      if (music.contains(qWord)) {
        score += 30;
      }
    }

    // ─────────────────────────────────────────────
    // STEP 3: Popularity Booster
    // ─────────────────────────────────────────────
    final playCount = int.tryParse(song['play_count']?.toString() ?? '0') ?? 0;
    final popularityBonus = playCount / 500000;
    score += popularityBonus;

    return score;
  }

  // ─────────────────────────────────────────────
  // MAIN: Process search results
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> processSearch(
    String query,
    List<Map<String, dynamic>> rawResults,
  ) async {
    try {
      if (rawResults.isEmpty) return rawResults;

      // Step 1: Clean the query
      final cleanedQuery = _cleanQuery(query);
      logger.log('SmartSearch: raw="$query" → cleaned="$cleanedQuery"');

      // Step 2 + 3: Score each song
      final scoredResults = rawResults.map((song) {
        final score = _calculateScore(cleanedQuery, song);
        return MapEntry(score, song);
      }).toList();

      // Step 4: Sort by score descending (highest first)
      scoredResults.sort((a, b) => b.key.compareTo(a.key));

      logger.log('SmartSearch: Top score=${scoredResults.first.key.toStringAsFixed(1)}, '
          'Bottom score=${scoredResults.last.key.toStringAsFixed(1)}');

      // Return sorted songs (without the score wrapper)
      return scoredResults.map((e) => e.value).toList();
    } catch (e, stackTrace) {
      logger.log('Error in SmartSearchAlgorithm', error: e, stackTrace: stackTrace);
      return rawResults;
    }
  }
}
