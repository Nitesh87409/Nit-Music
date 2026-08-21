
// --------------------------------------------------------------------------
// Noise-term dictionary (case-insensitive, used inside bracket & trailing
// patterns). Organised by category for maintainability.
// --------------------------------------------------------------------------

const _noiseTerms =
    // official * variants
    'official music video|official lyric video|official lyrics video|'
    'official video|official 4k video|official audio|official hd video|'
    'official visualizer|official vizualizer|official visualiser|'
    'official vizualiser|official song clip|official'
    // lyric / lyrics variants
    '|lyric video|lyrics video|lyric visualizer|lyric vizualizer|'
    'lyrics|lyric|lyrical'
    // karaoke
    '|karaoke'
    // full / video / audio song combos
    '|full video song|full song|video song|full audio|full video'
    // resolution & quality tags
    '|4k video|hd video|4k|hd|1080p|720p|480p'
    // jukebox variants
    '|audio jukebox|video jukebox|jukebox'
    // trending / new / latest tags
    '|new song \d{4}|latest hindi song|trending song|new song|latest song'
    // audio standalone
    '|audio';

// (From "Movie Name") or [From "Movie Name"] - Bollywood-style movie credits.
final _fromMoviePattern = RegExp(
  r'[\(\[]\s*from\s+["' + "'" + r'\u201C\u201D].+?["' + "'" + r'\u201C\u201D]\s*[\)\]]',
  caseSensitive: false,
);

// Bracket groups that contain a noise term anywhere inside: (Official Video)
final _bracketedNoisePattern = RegExp(
  r'[\(\[][^\)\]]*(?:' + _noiseTerms + r')[^\)\]]*[\)\]]',
  caseSensitive: false,
);

// Bracketed year-only tags like (2024) or [2025].
final _bracketedYearPattern = RegExp(
  r'[\(\[]\s*\d{4}\s*[\)\]]',
);

// feat. / ft. / featuring / composed by / singer: credits (with everything
// after them until end-of-string or a bracket/pipe boundary).
final _creditsPattern = RegExp(
  r'\s*[-\u2013\u2014]?\s*\b(?:feat\.?|ft\.?|featuring|composed by|singer\s*:)\s*.+$',
  caseSensitive: false,
);

// Same noise phrases unbracketed at the end of a title.
final _trailingNoisePattern = RegExp(
  r'\s*[-\u2013\u2014]?\s*\b(?:' + _noiseTerms + r')\b\s*$',
  caseSensitive: false,
);

// Emoji unicode ranges (covers most common emoji blocks).
final _emojiPattern = RegExp(
  r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{27BF}\u{FE00}-\u{FE0F}'
  r'\u{1FA00}-\u{1FA6F}\u{1FA70}-\u{1FAFF}\u{200D}\u{20E3}'
  r'\u{E0020}-\u{E007F}\u{2702}-\u{27B0}\u{1F600}-\u{1F64F}'
  r'\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}]',
  unicode: true,
);

// --------------------------------------------------------------------------
// formatSongTitle - cleans a raw YouTube title to just the song name.
// Pure function, no side effects. If everything gets stripped the caller
// (returnSongLayout) falls back to the original rawTitle.
// --------------------------------------------------------------------------

String formatSongTitle(String title, [String? author]) {
  // 1. Strip emojis and hashtags first so junk segments become empty.
  var t = title.replaceAll(_emojiPattern, '').replaceAll(RegExp(r'#\w+'), '');

  // 2. Strip artist prefix if present (e.g. "KD DESIROCK : Bhola Inside")
  if (author != null && author.isNotEmpty) {
    final lowerT = t.toLowerCase();
    final lowerAuth = author.toLowerCase();
    if (lowerT.startsWith(lowerAuth)) {
      t = t.substring(author.length).trimLeft();
      if (t.startsWith(':') || t.startsWith('-')) {
        t = t.substring(1).trimLeft();
      }
    }
  }

  // 3. Split by pipe and take the first non-empty segment.
  if (t.contains('|')) {
    final segments = t.split('|').map((s) => s.trim()).toList();
    t = segments.firstWhere((s) => s.isNotEmpty, orElse: () => t);
  }

  // 4. Remove (From "Movie Name") brackets before general bracket matching.
  t = t.replaceAll(_fromMoviePattern, '');

  // 3. Remove bracketed groups that contain any noise term.
  t = t.replaceAll(_bracketedNoisePattern, '');

  // 4. Remove bracketed year-only tags like (2024) or [2025].
  t = t.replaceAll(_bracketedYearPattern, '');

  // 7. Remove feat./ft./featuring/composed by/singer: credits.
  t = t.replaceAll(_creditsPattern, '');

  // 8. Strip lone brackets, pipes, and decode HTML entities.
  t = t
      .replaceAll(RegExp(r'[\[\]()|]'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&#039;', "'")
      .replaceAll('&quot;', '"')
      .trimLeft();

  // 9. Strip trailing unbracketed noise; loop to handle stacked suffixes.
  String prev;
  do {
    prev = t;
    t = t.replaceAll(_trailingNoisePattern, '');
  } while (t != prev);

  // 10. Collapse multiple spaces and trim.
  return t.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}



String? getSongId(String url) {
  final ytRegex = RegExp(r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})');
  final match = ytRegex.firstMatch(url);
  return match?.group(1);
}

String formatDuration(int audioDurationInSeconds) {
  final duration = Duration(seconds: audioDurationInSeconds);

  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  return [
    if (hours > 0) hours.toString().padLeft(2, '0'),
    minutes.toString().padLeft(2, '0'),
    seconds.toString().padLeft(2, '0'),
  ].join(':');
}

String normalizeArtistDisplayTitle(String title) {
  return title.trim();
}

String normalizeArtistThumbnailUrl(String? url) {
  return url ?? '';
}

