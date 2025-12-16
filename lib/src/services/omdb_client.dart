import 'dart:convert';
import 'package:http/http.dart' as http;

/// OMDB API client for fetching IMDB, Rotten Tomatoes, and Metacritic ratings
class OmdbClient {
  final String apiKey;
  final String baseUrl = 'https://www.omdbapi.com';

  OmdbClient(this.apiKey);

  /// Get ratings by IMDB ID (e.g., "tt1234567")
  Future<Ratings?> getRatingsByImdbId(String imdbId) async {
    if (imdbId.isEmpty) return null;

    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'apikey': apiKey,
        'i': imdbId,
      });

      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['Response'] == 'False') return null;

      return Ratings.fromOmdb(data);
    } catch (_) {
      return null;
    }
  }

  /// Get ratings by title and year
  Future<Ratings?> getRatingsByTitle(String title, {String? year, String? type}) async {
    try {
      final params = {
        'apikey': apiKey,
        't': title,
        if (year != null) 'y': year,
        if (type != null) 'type': type, // 'movie' or 'series'
      };

      final uri = Uri.parse(baseUrl).replace(queryParameters: params);
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['Response'] == 'False') return null;

      return Ratings.fromOmdb(data);
    } catch (_) {
      return null;
    }
  }
}

class Ratings {
  final String? imdbId;
  final double? imdbRating;
  final String? imdbVotes;
  final int? rottenTomatoesCritics; // Tomatometer (0-100)
  final int? rottenTomatoesAudience; // Audience score (0-100) - not always available
  final int? metacritic; // Metascore (0-100)

  Ratings({
    this.imdbId,
    this.imdbRating,
    this.imdbVotes,
    this.rottenTomatoesCritics,
    this.rottenTomatoesAudience,
    this.metacritic,
  });

  factory Ratings.fromOmdb(Map<String, dynamic> json) {
    // Parse IMDB rating (comes as "8.5" string)
    double? imdbRating;
    final imdbStr = json['imdbRating'] as String?;
    if (imdbStr != null && imdbStr != 'N/A') {
      imdbRating = double.tryParse(imdbStr);
    }

    // Parse Metacritic (comes as "85" string)
    int? metacritic;
    final metaStr = json['Metascore'] as String?;
    if (metaStr != null && metaStr != 'N/A') {
      metacritic = int.tryParse(metaStr);
    }

    // Parse Rotten Tomatoes from Ratings array
    int? rtCritics;
    int? rtAudience;
    final ratings = json['Ratings'] as List<dynamic>?;
    if (ratings != null) {
      for (final r in ratings) {
        final source = r['Source'] as String?;
        final value = r['Value'] as String?;
        if (source == 'Rotten Tomatoes' && value != null) {
          // Value is like "85%"
          rtCritics = int.tryParse(value.replaceAll('%', ''));
        }
      }
    }

    return Ratings(
      imdbId: json['imdbID'] as String?,
      imdbRating: imdbRating,
      imdbVotes: json['imdbVotes'] as String?,
      rottenTomatoesCritics: rtCritics,
      rottenTomatoesAudience: rtAudience,
      metacritic: metacritic,
    );
  }

  Map<String, dynamic> toJson() => {
        'imdbId': imdbId,
        'imdbRating': imdbRating,
        'imdbVotes': imdbVotes,
        'rottenTomatoesCritics': rottenTomatoesCritics,
        'rottenTomatoesAudience': rottenTomatoesAudience,
        'metacritic': metacritic,
      };

  bool get hasRatings =>
      imdbRating != null ||
      rottenTomatoesCritics != null ||
      metacritic != null;
}
