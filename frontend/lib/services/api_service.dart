import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  final AuthService _auth;

  ApiService(this._auth);

  String get _baseUrl => _auth.baseUrl;

  Future<Map<String, String>> get _headers async {
    final token = await _auth.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _get(String path,
      [Map<String, String>? params]) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (params != null) {
      uri = uri.replace(queryParameters: params);
    }

    final response = await http.get(uri, headers: await _headers);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _post(String path,
      [Map<String, dynamic>? body]) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: await _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> _delete(String path,
      [Map<String, String>? params]) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (params != null) {
      uri = uri.replace(queryParameters: params);
    }

    final response = await http.delete(uri, headers: await _headers);
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(data['error'] ?? 'Request failed', response.statusCode);
    }
    return data;
  }

  // Content endpoints
  Future<List<dynamic>> getNewReleases({
    List<String>? providers,
    String? type,
    int days = 30,
    double? minRating,
    int? minVotes,
    int? genre,
  }) async {
    final params = <String, String>{
      'days': days.toString(),
      if (providers != null && providers.isNotEmpty)
        'providers': providers.join(','),
      if (type != null) 'type': type,
      if (minRating != null) 'minRating': minRating.toString(),
      if (minVotes != null) 'minVotes': minVotes.toString(),
      if (genre != null) 'genre': genre.toString(),
    };
    final data = await _get('/api/new', params);
    return data['items'] as List<dynamic>;
  }

  Future<List<dynamic>> getTrending({
    String window = 'week',
    String? type,
  }) async {
    final params = <String, String>{
      'window': window,
      if (type != null) 'type': type,
    };
    final data = await _get('/api/trending', params);
    return data['items'] as List<dynamic>;
  }

  Future<List<dynamic>> search(String query) async {
    final data = await _get('/api/search', {'q': query});
    return data['items'] as List<dynamic>;
  }

  Future<List<dynamic>> whereToWatch(String query) async {
    final data = await _get('/api/where', {'q': query});
    return data['items'] as List<dynamic>;
  }

  Future<List<dynamic>> getProviders() async {
    final data = await _get('/api/providers');
    return data['providers'] as List<dynamic>;
  }

  /// Get streaming providers (Netflix, Disney+, etc.) for a specific title
  Future<List<String>> getWatchProviders(String mediaType, int id) async {
    try {
      final data = await _get('/api/providers/$mediaType/$id');
      return (data['providers'] as List<dynamic>).cast<String>();
    } catch (e) {
      return [];
    }
  }

  // Ratings (IMDB, Rotten Tomatoes, Metacritic)
  Future<Map<String, dynamic>?> getRatings(String mediaType, int id) async {
    try {
      final data = await _get('/api/ratings/$mediaType/$id');
      return data;
    } catch (e) {
      // Ratings are optional - don't fail if unavailable
      return null;
    }
  }

  // Watch history
  Future<void> markWatched(String mediaType, int id) async {
    await _post('/api/watched/$mediaType/$id');
  }

  Future<void> unmarkWatched(String mediaType, int id) async {
    await _delete('/api/watched/$mediaType/$id');
  }

  // Request endpoints
  Future<List<dynamic>> getRequests() async {
    final data = await _get('/api/requests');
    return data['requests'] as List<dynamic>;
  }

  Future<void> createRequest({
    required String mediaType,
    required int id,
    required String title,
    String? posterPath,
  }) async {
    await _post('/api/requests/$mediaType/$id', {
      'title': title,
      if (posterPath != null) 'posterPath': posterPath,
    });
  }

  Future<void> deleteRequest(String mediaType, int id) async {
    await _delete('/api/requests/$mediaType/$id');
  }

  Future<void> resetRequest(String mediaType, int id) async {
    await _post('/api/requests/$mediaType/$id/reset');
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => message;
}
