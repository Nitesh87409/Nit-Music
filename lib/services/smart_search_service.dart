import 'dart:convert';
import 'package:http/http.dart' as http;

class SmartSearchService {
  /// Fetches smart autocomplete suggestions from YouTube for natural language processing.
  static Future<List<String>> getSmartSuggestions(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final String encodedQuery = Uri.encodeComponent(query);
      final Uri url = Uri.parse(
          'https://suggestqueries-clients6.youtube.com/complete/search?client=youtube&hl=en&gl=in&q=$encodedQuery&ds=yt');
      
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0'
      }).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final String body = response.body;
        // The response format is: window.google.ac.h(["query",[["sugg1", ...], ["sugg2", ...]]])
        // We need to extract the JSON array part
        final int startIndex = body.indexOf('[');
        final int endIndex = body.lastIndexOf(']');
        
        if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
          final String jsonStr = body.substring(startIndex, endIndex + 1);
          final List<dynamic> parsed = jsonDecode(jsonStr);
          
          if (parsed.length > 1 && parsed[1] is List) {
            final List<dynamic> suggestionsList = parsed[1];
            final List<String> results = [];
            
            for (var item in suggestionsList) {
              if (item is List && item.isNotEmpty && item[0] is String) {
                results.add(item[0].toString());
              }
            }
            return results;
          }
        }
      }
    } catch (e) {
      print('Error fetching smart suggestions: $e');
    }
    
    return [];
  }

  /// Automatically picks the best optimized query for vague searches.
  static Future<String> getOptimizedQuery(String originalQuery) async {
    final suggestions = await getSmartSuggestions(originalQuery);
    if (suggestions.isEmpty) return originalQuery;

    // Pick a suggestion that might expand abbreviations
    // E.g., original: "kd hr song", suggestions: ["kd hr song", "kd haryanvi song", ...]
    // We try to find the first suggestion that is longer than the original query,
    // indicating it expanded something (like "hr" -> "haryanvi").
    for (String suggestion in suggestions) {
      if (suggestion.toLowerCase() != originalQuery.toLowerCase() && suggestion.length > originalQuery.length) {
        // If the suggestion adds meaningful context or expansion
        return suggestion;
      }
    }
    
    // Fallback to the first suggestion or original query
    return suggestions.first;
  }
}
