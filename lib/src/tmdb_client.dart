import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'providers.dart';

class TmdbClient {
  final String apiKey;
  final String baseUrl = 'https://api.themoviedb.org/3';
  final String region = 'US';

  TmdbClient(this.apiKey);

  Future<Map<String, dynamic>> _get(String endpoint,
      [Map<String, String>? params]) async {
    final queryParams = {
      'api_key': apiKey,
      ...?params,
    };
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('TMDB API error: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<MediaItem>> discoverMovies({
    List<int>? providerIds,
    String? releaseDateGte,
    String? releaseDateLte,
    int page = 1,
  }) async {
    final params = <String, String>{
      'sort_by': 'release_date.desc',
      'page': page.toString(),
    };
    // Only filter by provider if specified
    if (providerIds != null && providerIds.isNotEmpty) {
      params['watch_region'] = region;
      params['with_watch_providers'] = providerIds.join('|');
    }
    if (releaseDateGte != null) params['release_date.gte'] = releaseDateGte;
    if (releaseDateLte != null) params['release_date.lte'] = releaseDateLte;

    final data = await _get('/discover/movie', params);
    final results = data['results'] as List<dynamic>;
    return results
        .map((r) => MediaItem.fromJson(r as Map<String, dynamic>, 'movie'))
        .toList();
  }

  Future<List<MediaItem>> discoverTv({
    List<int>? providerIds,
    String? airDateGte,
    String? airDateLte,
    int page = 1,
  }) async {
    final params = <String, String>{
      'sort_by': 'first_air_date.desc',
      'page': page.toString(),
    };
    // Only filter by provider if specified
    if (providerIds != null && providerIds.isNotEmpty) {
      params['watch_region'] = region;
      params['with_watch_providers'] = providerIds.join('|');
    }
    if (airDateGte != null) params['first_air_date.gte'] = airDateGte;
    if (airDateLte != null) params['first_air_date.lte'] = airDateLte;

    final data = await _get('/discover/tv', params);
    final results = data['results'] as List<dynamic>;
    return results
        .map((r) => MediaItem.fromJson(r as Map<String, dynamic>, 'tv'))
        .toList();
  }

  Future<List<MediaItem>> getTrendingMovies({String window = 'week'}) async {
    final data = await _get('/trending/movie/$window');
    final results = data['results'] as List<dynamic>;
    return results
        .map((r) => MediaItem.fromJson(r as Map<String, dynamic>, 'movie'))
        .toList();
  }

  Future<List<MediaItem>> getTrendingTv({String window = 'week'}) async {
    final data = await _get('/trending/tv/$window');
    final results = data['results'] as List<dynamic>;
    return results
        .map((r) => MediaItem.fromJson(r as Map<String, dynamic>, 'tv'))
        .toList();
  }

  Future<List<MediaItem>> searchMulti(String query) async {
    final data = await _get('/search/multi', {'query': query});
    final results = data['results'] as List<dynamic>;
    return results
        .where((r) => r['media_type'] == 'movie' || r['media_type'] == 'tv')
        .map((r) => MediaItem.fromJson(
            r as Map<String, dynamic>, r['media_type'] as String))
        .toList();
  }

  Future<List<String>> getWatchProviders(int id, String mediaType) async {
    final endpoint = '/$mediaType/$id/watch/providers';
    final data = await _get(endpoint);
    final results = data['results'] as Map<String, dynamic>?;
    if (results == null) return [];

    final usData = results['US'] as Map<String, dynamic>?;
    if (usData == null) return [];

    final flatrate = usData['flatrate'] as List<dynamic>?;
    if (flatrate == null) return [];

    return flatrate
        .map((p) {
          final id = p['provider_id'] as int;
          return Providers.nameById(id);
        })
        .whereType<String>()
        .toList();
  }

  Future<MediaItem> enrichWithProviders(MediaItem item) async {
    final providers = await getWatchProviders(item.id, item.mediaType);
    return item.copyWith(providers: providers);
  }

  Future<List<MediaItem>> enrichAllWithProviders(List<MediaItem> items) async {
    final enriched = <MediaItem>[];
    for (final item in items) {
      enriched.add(await enrichWithProviders(item));
    }
    return enriched;
  }

  /// Get external IDs (IMDB, etc.) for a movie or TV show
  Future<String?> getImdbId(int id, String mediaType) async {
    try {
      final endpoint = '/$mediaType/$id/external_ids';
      final data = await _get(endpoint);
      return data['imdb_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Get detailed info for a movie (includes IMDB ID)
  Future<Map<String, dynamic>?> getMovieDetails(int id) async {
    try {
      final data = await _get('/movie/$id');
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Get detailed info for a TV show
  Future<Map<String, dynamic>?> getTvDetails(int id) async {
    try {
      final data = await _get('/tv/$id');
      return data;
    } catch (_) {
      return null;
    }
  }
}
