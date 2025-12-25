import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../services/omdb_client.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_watch_history.dart';
import '../tmdb_client.dart';
import '../providers.dart';

class ApiRoutes {
  final TmdbClient tmdb;
  final OmdbClient? omdb;
  final FirebaseAuthService firebaseAuth;
  final FirestoreWatchHistory watchHistory;

  ApiRoutes({
    required this.tmdb,
    this.omdb,
    required this.firebaseAuth,
    required this.watchHistory,
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
    router.get('/providers/<mediaType>/<id>', _withAuth(_getWatchProviders));
    router.get('/ratings/<mediaType>/<id>', _withAuth(_getRatings));

    // Watch history routes
    router.get('/watched', _withAuth(_getWatched));
    router.post('/watched/<mediaType>/<id>', _withAuth(_markWatched));
    router.delete('/watched/<mediaType>/<id>', _withAuth(_unmarkWatched));

    // Request routes (more specific routes first)
    router.get('/requests', _withAuth(_getRequests));
    router.post('/requests/<mediaType>/<id>/reset', _withAuth(_resetRequest));
    router.post('/requests/<mediaType>/<id>', _withAuth(_createRequest));
    router.delete('/requests/<mediaType>/<id>', _withAuth(_deleteRequest));

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
    final genreId = int.tryParse(params['genre'] ?? '');

    // Only filter by provider if explicitly specified - otherwise get all releases
    final providerIds = providerKeys.isNotEmpty
        ? Providers.parseProviderKeys(providerKeys)
        : null;
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(now);

    // Fetch watched and requested keys once for efficiency
    final watchedKeys = await watchHistory.getWatchedKeys(user.uid);
    final requestedKeys = await watchHistory.getRequestedKeys();

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
          genreId: genreId,
          page: page,
        );
        if (movies.isEmpty) break; // No more results
        for (final m in movies) {
          items.add({
            ...m.toJson(),
            'watched': watchedKeys.contains(m.uniqueKey),
            'requested': requestedKeys.contains(m.uniqueKey),
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
          genreId: genreId,
          page: page,
        );
        if (tv.isEmpty) break; // No more results
        for (final t in tv) {
          items.add({
            ...t.toJson(),
            'watched': watchedKeys.contains(t.uniqueKey),
            'requested': requestedKeys.contains(t.uniqueKey),
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

    return _jsonOk({'items': items});
  }

  Future<Response> _getTrending(Request request, FirebaseUser user) async {
    final params = request.url.queryParameters;
    final window = params['window'] ?? 'week';
    final type = params['type']; // 'movie', 'tv', or null for both

    // Fetch watched and requested keys once for efficiency
    final watchedKeys = await watchHistory.getWatchedKeys(user.uid);
    final requestedKeys = await watchHistory.getRequestedKeys();

    final items = <Map<String, dynamic>>[];

    if (type == null || type == 'movie') {
      final movies = await tmdb.getTrendingMovies(window: window);
      for (final m in movies) {
        items.add({
          ...m.toJson(),
          'watched': watchedKeys.contains(m.uniqueKey),
          'requested': requestedKeys.contains(m.uniqueKey),
        });
      }
    }

    if (type == null || type == 'tv') {
      final tv = await tmdb.getTrendingTv(window: window);
      for (final t in tv) {
        items.add({
          ...t.toJson(),
          'watched': watchedKeys.contains(t.uniqueKey),
          'requested': requestedKeys.contains(t.uniqueKey),
        });
      }
    }

    return _jsonOk({'items': items});
  }

  Future<Response> _search(Request request, FirebaseUser user) async {
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return _jsonError(400, 'Query parameter q required');
    }

    // Fetch watched and requested keys once for efficiency
    final watchedKeys = await watchHistory.getWatchedKeys(user.uid);
    final requestedKeys = await watchHistory.getRequestedKeys();

    final results = await tmdb.searchMulti(query);
    final items = results
        .map((r) => {
              ...r.toJson(),
              'watched': watchedKeys.contains(r.uniqueKey),
              'requested': requestedKeys.contains(r.uniqueKey),
            })
        .toList();

    return _jsonOk({'items': items});
  }

  Future<Response> _where(Request request, FirebaseUser user) async {
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return _jsonError(400, 'Query parameter q required');
    }

    // Fetch watched and requested keys once for efficiency
    final watchedKeys = await watchHistory.getWatchedKeys(user.uid);
    final requestedKeys = await watchHistory.getRequestedKeys();

    final results = await tmdb.searchMulti(query);
    final items = <Map<String, dynamic>>[];

    for (final result in results.take(5)) {
      final providers =
          await tmdb.getWatchProviders(result.id, result.mediaType);
      items.add({
        ...result.toJson(),
        'providers': providers,
        'watched': watchedKeys.contains(result.uniqueKey),
        'requested': requestedKeys.contains(result.uniqueKey),
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

  /// Get streaming providers for a specific movie or TV show
  Future<Response> _getWatchProviders(Request request, FirebaseUser user) async {
    final mediaType = request.params['mediaType'];
    final idStr = request.params['id'];
    if (mediaType == null || idStr == null) {
      return _jsonError(400, 'Invalid parameters');
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      return _jsonError(400, 'Invalid ID');
    }

    final providers = await tmdb.getWatchProviders(id, mediaType);
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

  // === Request Routes ===

  Future<Response> _getRequests(Request request, FirebaseUser user) async {
    final requests = await watchHistory.getRequests();
    return _jsonOk({'requests': requests});
  }

  Future<Response> _createRequest(Request request, FirebaseUser user) async {
    final mediaType = request.params['mediaType'];
    final idStr = request.params['id'];
    if (mediaType == null || idStr == null) {
      return _jsonError(400, 'Invalid parameters');
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      return _jsonError(400, 'Invalid ID');
    }

    // Get title and poster from request body
    final body = await _parseJson(request);
    final title = body?['title'] as String? ?? 'Unknown';
    final posterPath = body?['posterPath'] as String?;

    // Check if already requested
    final alreadyRequested = await watchHistory.isRequested(mediaType, id);
    if (alreadyRequested) {
      return _jsonError(409, 'Already requested');
    }

    await watchHistory.createRequest(
      userId: user.uid,
      mediaType: mediaType,
      tmdbId: id,
      title: title,
      posterPath: posterPath,
    );

    return _jsonOk({'success': true, 'key': '${mediaType}_$id'});
  }

  Future<Response> _deleteRequest(Request request, FirebaseUser user) async {
    final mediaType = request.params['mediaType'];
    final idStr = request.params['id'];
    if (mediaType == null || idStr == null) {
      return _jsonError(400, 'Invalid parameters');
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      return _jsonError(400, 'Invalid ID');
    }

    await watchHistory.deleteRequest(mediaType, id);
    return _jsonOk({'success': true});
  }

  Future<Response> _resetRequest(Request request, FirebaseUser user) async {
    final mediaType = request.params['mediaType'];
    final idStr = request.params['id'];
    if (mediaType == null || idStr == null) {
      return _jsonError(400, 'Invalid parameters');
    }

    final id = int.tryParse(idStr);
    if (id == null) {
      return _jsonError(400, 'Invalid ID');
    }

    await watchHistory.resetRequest(mediaType, id);
    return _jsonOk({'success': true});
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
}
