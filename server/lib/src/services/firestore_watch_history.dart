import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';

import '../models.dart';

class FirestoreWatchHistory {
  final String projectId;
  final AutoRefreshingAuthClient _client;

  FirestoreWatchHistory._({
    required this.projectId,
    required AutoRefreshingAuthClient client,
  }) : _client = client;

  static Future<FirestoreWatchHistory> create({
    required String projectId,
    required String serviceAccountJson,
  }) async {
    final credentials = ServiceAccountCredentials.fromJson(serviceAccountJson);
    final client = await clientViaServiceAccount(
      credentials,
      ['https://www.googleapis.com/auth/datastore'],
    );
    return FirestoreWatchHistory._(projectId: projectId, client: client);
  }

  String get _baseUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// Check if item is watched by user
  Future<bool> isWatched(String userId, MediaItem item) async {
    final mediaKey = item.uniqueKey;
    final docPath = 'users/$userId/watched/$mediaKey';
    final response = await _client.get(Uri.parse('$_baseUrl/$docPath'));
    return response.statusCode == 200;
  }

  /// Get all watched media keys for a user
  Future<Set<String>> getWatchedKeys(String userId) async {
    final url = '$_baseUrl/users/$userId/watched';
    final response = await _client.get(Uri.parse(url));

    if (response.statusCode != 200) return {};

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = data['documents'] as List<dynamic>? ?? [];

    return documents.map((doc) {
      final name = doc['name'] as String;
      return name.split('/').last; // Extract document ID (the media key)
    }).toSet();
  }

  /// Get count of watched items for a user
  Future<int> count(String userId) async {
    final keys = await getWatchedKeys(userId);
    return keys.length;
  }

  /// Mark item as watched
  Future<void> markWatched(String userId, String mediaType, int id) async {
    final mediaKey = '${mediaType}_$id';
    final docPath = 'users/$userId/watched/$mediaKey';
    final url = '$_baseUrl/$docPath';

    await _client.patch(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fields': {
          'mediaType': {'stringValue': mediaType},
          'tmdbId': {'integerValue': id.toString()},
          'watchedAt': {
            'timestampValue': DateTime.now().toUtc().toIso8601String(),
          },
        },
      }),
    );
  }

  /// Unmark item as watched
  Future<void> markUnwatched(String userId, String mediaType, int id) async {
    final mediaKey = '${mediaType}_$id';
    final docPath = 'users/$userId/watched/$mediaKey';
    await _client.delete(Uri.parse('$_baseUrl/$docPath'));
  }

  /// Filter a list of items to only include unwatched ones
  Future<List<MediaItem>> filterUnwatched(
      String userId, List<MediaItem> items) async {
    final watchedKeys = await getWatchedKeys(userId);
    return items.where((item) => !watchedKeys.contains(item.uniqueKey)).toList();
  }

  // === Media Requests ===

  /// Create a new media request
  Future<void> createRequest({
    required String userId,
    required String mediaType,
    required int tmdbId,
    required String title,
    String? posterPath,
  }) async {
    final mediaKey = '${mediaType}_$tmdbId';
    final docPath = 'requests/$mediaKey';
    final url = '$_baseUrl/$docPath';

    await _client.patch(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'fields': {
          'tmdbId': {'integerValue': tmdbId.toString()},
          'mediaType': {'stringValue': mediaType},
          'title': {'stringValue': title},
          'posterPath': posterPath != null
              ? {'stringValue': posterPath}
              : {'nullValue': null},
          'requestedBy': {'stringValue': userId},
          'requestedAt': {
            'timestampValue': DateTime.now().toUtc().toIso8601String(),
          },
          'status': {'stringValue': 'pending'},
        },
      }),
    );
  }

  /// Get all media requests
  Future<List<Map<String, dynamic>>> getRequests() async {
    final url = '$_baseUrl/requests';
    final response = await _client.get(Uri.parse(url));

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = data['documents'] as List<dynamic>? ?? [];

    return documents.map((doc) {
      final fields = doc['fields'] as Map<String, dynamic>;
      final name = doc['name'] as String;
      final id = name.split('/').last;

      return {
        'id': id,
        'tmdbId': int.parse(fields['tmdbId']['integerValue'] as String),
        'mediaType': fields['mediaType']['stringValue'] as String,
        'title': fields['title']['stringValue'] as String,
        'posterPath': fields['posterPath']?['stringValue'] as String?,
        'requestedBy': fields['requestedBy']['stringValue'] as String,
        'requestedAt': fields['requestedAt']['timestampValue'] as String,
        'status': fields['status']['stringValue'] as String,
      };
    }).toList();
  }

  /// Get all requested media keys
  Future<Set<String>> getRequestedKeys() async {
    final url = '$_baseUrl/requests';
    final response = await _client.get(Uri.parse(url));

    if (response.statusCode != 200) return {};

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final documents = data['documents'] as List<dynamic>? ?? [];

    return documents.map((doc) {
      final name = doc['name'] as String;
      return name.split('/').last; // Extract document ID (the media key)
    }).toSet();
  }

  /// Check if a media item has already been requested
  Future<bool> isRequested(String mediaType, int tmdbId) async {
    final mediaKey = '${mediaType}_$tmdbId';
    final docPath = 'requests/$mediaKey';
    final response = await _client.get(Uri.parse('$_baseUrl/$docPath'));
    return response.statusCode == 200;
  }

  /// Delete a request
  Future<void> deleteRequest(String mediaType, int tmdbId) async {
    final mediaKey = '${mediaType}_$tmdbId';
    final docPath = 'requests/$mediaKey';
    await _client.delete(Uri.parse('$_baseUrl/$docPath'));
  }
}
