import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/transmission_client.dart';
import '../services/jackett_client.dart';
import '../services/omdb_client.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_watch_history.dart';
import '../services/download_mapping.dart';
import '../tmdb_client.dart';
import '../providers.dart';

class ApiRoutes {
  final TmdbClient tmdb;
  final TransmissionClient transmission;
  final JackettClient? jackett;
  final OmdbClient? omdb;
  final FirebaseAuthService firebaseAuth;
  final FirestoreWatchHistory watchHistory;
  final DownloadMapping downloadMapping;

  ApiRoutes({
    required this.tmdb,
    required this.transmission,
    this.jackett,
    this.omdb,
    required this.firebaseAuth,
    required this.watchHistory,
    required this.downloadMapping,
  });

  Router get router {
    final router = Router();

    // Auth routes (Firebase handles registration/login, we just validate tokens)
    router.get('/auth/me', _withAuth(_me));

    // Content routes
    router.get('/new', _withAuth(_getNew));
    router.get('/trending', _withAuth(_getTrending));
    router.get('/search', _withAuth(_search));
    router.get('/where', _withAuth(_where));
    router.get('/providers', _getProviders);
    router.get('/ratings/<mediaType>/<id>', _withAuth(_getRatings));

    // Watch history routes
    router.get('/watched', _withAuth(_getWatched));
    router.post('/watched/<mediaType>/<id>', _withAuth(_markWatched));
    router.delete('/watched/<mediaType>/<id>', _withAuth(_unmarkWatched));

    // Torrent routes
    router.get('/torrents/search', _withAuth(_searchTorrents));
    router.post('/torrents/download', _withAuth(_downloadTorrent));
    router.get('/torrents/active', _withAuth(_getActiveTorrents));
    router.delete('/torrents/<id>', _withAuth(_removeTorrent));

    return router;
  }

  // Auth middleware - validates Firebase ID tokens
  Handler _withAuth(Future<Response> Function(Request, FirebaseUser) handler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return _jsonError(401, 'Unauthorized');
      }

      final token = authHeader.substring(7);
      final user = await firebaseAuth.verifyIdToken(token);
      if (user == null) {
        return _jsonError(401, 'Invalid token');
      }
      return handler(request, user);
    };
  }

  // === Auth Routes ===

  Future<Response> _me(Request request, FirebaseUser user) async {
    return _jsonOk(user.toJson());
  }

  // === Content Routes ===

  Future<Response> _getNew(Request request, FirebaseUser user) async {
    final params = request.url.queryParameters;
    final providerKeys = params['providers']?.split(',').where((k) => k.isNotEmpty).toList() ?? [];
    final type = params['type']; // 'movie', 'tv', or null for both
    final days = int.tryParse(params['days'] ?? '30') ?? 30;
    // Rating filters - defaults filter out low quality content
    final minRating = double.tryParse(params['minRating'] ?? '6.0');
    final minVotes = int.tryParse(params['minVotes'] ?? '50');

    // Only filter by provider if explicitly specified - otherwise get all releases
    final providerIds = providerKeys.isNotEmpty
        ? Providers.parseProviderKeys(providerKeys)
        : null;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(now);

    // Fetch watched keys once for efficiency
    final watchedKeys = await watchHistory.getWatchedKeys(user.uid);

    final items = <Map<String, dynamic>>[];

    // Fetch multiple pages for more results (TMDB returns 20 per page)
    const pagesToFetch = 5;

    if (type == null || type == 'movie') {
      for (var page = 1; page <= pagesToFetch; page++) {
        final movies = await tmdb.discoverMovies(
          providerIds: providerIds,
          releaseDateGte: startStr,
          releaseDateLte: endStr,
          minRating: minRating,
          minVotes: minVotes,
          page: page,
        );
        if (movies.isEmpty) break; // No more results
        for (final m in movies) {
          items.add({
            ...m.toJson(),
            'watched': watchedKeys.contains(m.uniqueKey),
          });
        }
      }
    }

    if (type == null || type == 'tv') {
      for (var page = 1; page <= pagesToFetch; page++) {
        final tv = await tmdb.discoverTv(
          providerIds: providerIds,
          airDateGte: startStr,
          airDateLte: endStr,
          minRating: minRating,
          minVotes: minVotes,
          page: page,
        );
        if (tv.isEmpty) break; // No more results
        for (final t in tv) {
          items.add({
            ...t.toJson(),
            'watched': watchedKeys.contains(t.uniqueKey),
          });
        }
      }
    }

    // Sort by release date descending
    items.sort((a, b) {
      final aDate = a['releaseDate'] as String? ?? '';
      final bDate = b['releaseDate'] as String? ?? '';
      return bDate.compareTo(aDate);
    });

    // Add download progress for active torrents
    await _addDownloadProgress(items);

    return _jsonOk({'items': items});
  }

  Future<Response> _getTrending(Request request, FirebaseUser user) async {
    final params = request.url.queryParameters;
    final window = params['window'] ?? 'week';
    final type = params['type']; // 'movie', 'tv', or null for both

    // Fetch watched keys once for efficiency
    final watchedKeys = await watchHistory.getWatchedKeys(user.uid);

    final items = <Map<String, dynamic>>[];

    if (type == null || type == 'movie') {
      final movies = await tmdb.getTrendingMovies(window: window);
      for (final m in movies) {
        items.add({
          ...m.toJson(),
          'watched': watchedKeys.contains(m.uniqueKey),
        });
      }
    }

    if (type == null || type == 'tv') {
      final tv = await tmdb.getTrendingTv(window: window);
      for (final t in tv) {
        items.add({
          ...t.toJson(),
          'watched': watchedKeys.contains(t.uniqueKey),
        });
      }
    }

    // Add download progress for active torrents
    await _addDownloadProgress(items);

    return _jsonOk({'items': items});
  }

  Future<Response> _search(Request request, FirebaseUser user) async {
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return _jsonError(400, 'Query parameter q required');
    }

    // Fetch watched keys once for efficiency
    final watchedKeys = await watchHistory.getWatchedKeys(user.uid);

    final results = await tmdb.searchMulti(query);
    final items = results
        .map((r) => {
              ...r.toJson(),
              'watched': watchedKeys.contains(r.uniqueKey),
            })
        .toList();

    // Add download progress for active torrents
    await _addDownloadProgress(items);

    return _jsonOk({'items': items});
  }

  Future<Response> _where(Request request, FirebaseUser user) async {
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return _jsonError(400, 'Query parameter q required');
    }

    // Fetch watched keys once for efficiency
    final watchedKeys = await watchHistory.getWatchedKeys(user.uid);

    final results = await tmdb.searchMulti(query);
    final items = <Map<String, dynamic>>[];

    for (final result in results.take(5)) {
      final providers =
          await tmdb.getWatchProviders(result.id, result.mediaType);
      items.add({
        ...result.toJson(),
        'providers': providers,
        'watched': watchedKeys.contains(result.uniqueKey),
      });
    }

    return _jsonOk({'items': items});
  }

  Future<Response> _getProviders(Request request) async {
    final providers = Providers.all
        .map((p) => {
              'id': p.id,
              'name': p.name,
              'key': p.key,
            })
        .toList();
    return _jsonOk({'providers': providers});
  }

  /// Get IMDB, Rotten Tomatoes, and Metacritic ratings
  Future<Response> _getRatings(Request request, FirebaseUser user) async {
    if (omdb == null) {
      return _jsonError(503, 'OMDB not configured (ratings unavailable)');
    }

    final mediaType = request.params['mediaType'];
    final idStr = request.params['id'];
    if (mediaType == null || idStr == null) {
      return _jsonError(400, 'Invalid parameters');
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      return _jsonError(400, 'Invalid ID');
    }

    // Get IMDB ID from TMDB
    final imdbId = await tmdb.getImdbId(id, mediaType);
    if (imdbId == null || imdbId.isEmpty) {
      return _jsonError(404, 'IMDB ID not found');
    }

    // Fetch ratings from OMDB
    final ratings = await omdb!.getRatingsByImdbId(imdbId);
    if (ratings == null) {
      return _jsonError(404, 'Ratings not found');
    }

    return _jsonOk({
      'imdbId': ratings.imdbId,
      'imdbRating': ratings.imdbRating,
      'imdbVotes': ratings.imdbVotes,
      'rottenTomatoes': ratings.rottenTomatoesCritics,
      'metacritic': ratings.metacritic,
    });
  }

  // === Watch History Routes ===

  Future<Response> _getWatched(Request request, FirebaseUser user) async {
    final items = await watchHistory.getWatchedKeys(user.uid);
    return _jsonOk({'items': items.toList()});
  }

  Future<Response> _markWatched(Request request, FirebaseUser user) async {
    final mediaType = request.params['mediaType'];
    final idStr = request.params['id'];
    if (mediaType == null || idStr == null) {
      return _jsonError(400, 'Invalid parameters');
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      return _jsonError(400, 'Invalid ID');
    }

    await watchHistory.markWatched(user.uid, mediaType, id);
    return _jsonOk({'success': true, 'key': '${mediaType}_$id'});
  }

  Future<Response> _unmarkWatched(Request request, FirebaseUser user) async {
    final mediaType = request.params['mediaType'];
    final idStr = request.params['id'];
    if (mediaType == null || idStr == null) {
      return _jsonError(400, 'Invalid parameters');
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      return _jsonError(400, 'Invalid ID');
    }

    await watchHistory.markUnwatched(user.uid, mediaType, id);
    return _jsonOk({'success': true, 'key': '${mediaType}_$id'});
  }

  // === Torrent Routes ===

  Future<Response> _searchTorrents(Request request, FirebaseUser user) async {
    if (jackett == null) {
      return _jsonError(503, 'Jackett not configured');
    }

    final query = request.url.queryParameters['q'];
    // Category parameter no longer used - many indexers don't categorize
    // properly, which causes relevant results to be missed

    if (query == null || query.isEmpty) {
      return _jsonError(400, 'Query parameter q required');
    }

    // Search without category restriction to get maximum results
    final results = await jackett!.search(query);

    // Sort by seeders descending
    results.sort((a, b) => b.seeders.compareTo(a.seeders));

    return _jsonOk({
      'results': results.take(100).map((r) => r.toJson()).toList(),
    });
  }

  Future<Response> _downloadTorrent(Request request, FirebaseUser user) async {
    final body = await _parseJson(request);
    if (body == null) return _jsonError(400, 'Invalid JSON');

    final magnetOrUrl = body['url'] as String?;
    if (magnetOrUrl == null || magnetOrUrl.isEmpty) {
      return _jsonError(400, 'URL or magnet link required');
    }

    // Optional TMDB reference for tracking
    final tmdbId = body['tmdbId'] as int?;
    final mediaType = body['mediaType'] as String?;

    try {
      final torrent = await transmission.addTorrent(magnetOrUrl);

      // Store mapping if TMDB info provided
      if (tmdbId != null && mediaType != null) {
        await downloadMapping.addMapping(torrent.hashString, tmdbId, mediaType);
        print('Mapped torrent ${torrent.hashString} -> $mediaType/$tmdbId');
      }

      return _jsonOk({'torrent': torrent.toJson()});
    } on TransmissionException catch (e) {
      return _jsonError(500, e.message);
    }
  }

  Future<Response> _getActiveTorrents(Request request, FirebaseUser user) async {
    try {
      final torrents = await transmission.getTorrents();
      return _jsonOk({
        'torrents': torrents.map((t) => t.toJson()).toList(),
      });
    } on TransmissionException {
      // Return empty list if Transmission isn't available (it's optional)
      return _jsonOk({'torrents': []});
    }
  }

  Future<Response> _removeTorrent(Request request, FirebaseUser user) async {
    final idStr = request.params['id'];
    if (idStr == null) {
      return _jsonError(400, 'Torrent ID required');
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      return _jsonError(400, 'Invalid torrent ID');
    }

    final deleteData = request.url.queryParameters['deleteData'] == 'true';

    try {
      await transmission.removeTorrent(id, deleteLocalData: deleteData);
      return _jsonOk({'success': true});
    } on TransmissionException catch (e) {
      return _jsonError(500, e.message);
    }
  }

  // === Helpers ===

  Future<Map<String, dynamic>?> _parseJson(Request request) async {
    try {
      final body = await request.readAsString();
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Response _jsonOk(Map<String, dynamic> data) {
    return Response.ok(
      jsonEncode(data),
      headers: {'content-type': 'application/json'},
    );
  }

  Response _jsonError(int status, String message) {
    return Response(
      status,
      body: jsonEncode({'error': message}),
      headers: {'content-type': 'application/json'},
    );
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Match active torrents with media items and add progress info
  Future<void> _addDownloadProgress(List<Map<String, dynamic>> items) async {
    try {
      final torrents = await transmission.getTorrents();
      if (torrents.isEmpty) return;

      // Build hash -> torrent lookup for exact matching
      final torrentByHash = {for (final t in torrents) t.hashString: t};

      for (final item in items) {
        final tmdbId = item['id'] as int?;
        final mediaType = item['mediaType'] as String?;
        final title = (item['title'] as String? ?? '');

        // First try exact match via stored mapping
        if (tmdbId != null && mediaType != null) {
          final hash = downloadMapping.getTorrentHash(tmdbId, mediaType);
          if (hash != null && torrentByHash.containsKey(hash)) {
            final torrent = torrentByHash[hash]!;
            item['percentDone'] = torrent.percentDone;
            item['downloadStatus'] = torrent.statusText;
            continue;
          }
        }

        // Fall back to fuzzy title matching
        final year = item['year'] as String? ?? '';
        final normalizedTitle = _normalizeForMatch(title);

        for (final torrent in torrents) {
          final normalizedTorrent = _normalizeForMatch(torrent.name);
          final titleMatch = normalizedTorrent.contains(normalizedTitle);
          final yearMatch = year.isEmpty || normalizedTorrent.contains(year);

          if (titleMatch && yearMatch) {
            item['percentDone'] = torrent.percentDone;
            item['downloadStatus'] = torrent.statusText;
            break;
          }
        }
      }
    } catch (e) {
      // Transmission not available, skip progress info
      print('Transmission error: $e');
    }
  }

  /// Normalize a string for fuzzy matching (lowercase, remove punctuation, collapse spaces)
  String _normalizeForMatch(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[._\-:]+'), ' ')  // Replace dots, underscores, dashes, colons with spaces
        .replaceAll(RegExp(r'[^\w\s]'), '')     // Remove other punctuation
        .replaceAll(RegExp(r'\s+'), ' ')        // Collapse multiple spaces
        .trim();
  }
}
