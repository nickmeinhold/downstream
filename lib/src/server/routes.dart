import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

import '../services/transmission_client.dart';
import '../services/jackett_client.dart';
import '../services/omdb_client.dart';
import '../services/user_service.dart';
import '../watch_history.dart';
import '../tmdb_client.dart';
import '../providers.dart';

class ApiRoutes {
  final TmdbClient tmdb;
  final TransmissionClient transmission;
  final JackettClient? jackett;
  final OmdbClient? omdb;
  final UserService userService;
  final WatchHistory watchHistory;
  final String jwtSecret;

  ApiRoutes({
    required this.tmdb,
    required this.transmission,
    this.jackett,
    this.omdb,
    required this.userService,
    required this.watchHistory,
    required this.jwtSecret,
  });

  Router get router {
    final router = Router();

    // Auth routes
    router.post('/auth/register', _register);
    router.post('/auth/login', _login);
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

  // Auth middleware
  Handler _withAuth(Future<Response> Function(Request, User) handler) {
    return (Request request) async {
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return _jsonError(401, 'Unauthorized');
      }

      final token = authHeader.substring(7);
      try {
        final jwt = JWT.verify(token, SecretKey(jwtSecret));
        final userId = jwt.payload['sub'] as String;
        final user = userService.getUserById(userId);
        if (user == null) {
          return _jsonError(401, 'User not found');
        }
        return handler(request, user);
      } catch (e) {
        return _jsonError(401, 'Invalid token');
      }
    };
  }

  // === Auth Routes ===

  Future<Response> _register(Request request) async {
    final body = await _parseJson(request);
    if (body == null) return _jsonError(400, 'Invalid JSON');

    final username = body['username'] as String?;
    final password = body['password'] as String?;

    if (username == null || username.isEmpty) {
      return _jsonError(400, 'Username required');
    }
    if (password == null || password.length < 4) {
      return _jsonError(400, 'Password must be at least 4 characters');
    }

    try {
      final user = await userService.createUser(username, password);
      final token = _createToken(user);
      return _jsonOk({'token': token, 'user': user.toPublicJson()});
    } on UserException catch (e) {
      return _jsonError(400, e.message);
    }
  }

  Future<Response> _login(Request request) async {
    final body = await _parseJson(request);
    if (body == null) return _jsonError(400, 'Invalid JSON');

    final username = body['username'] as String?;
    final password = body['password'] as String?;

    if (username == null || password == null) {
      return _jsonError(400, 'Username and password required');
    }

    final user = userService.authenticate(username, password);
    if (user == null) {
      return _jsonError(401, 'Invalid credentials');
    }

    final token = _createToken(user);
    return _jsonOk({'token': token, 'user': user.toPublicJson()});
  }

  Future<Response> _me(Request request, User user) async {
    return _jsonOk(user.toPublicJson());
  }

  String _createToken(User user) {
    final jwt = JWT({
      'sub': user.id,
      'username': user.username,
    });
    return jwt.sign(SecretKey(jwtSecret), expiresIn: Duration(days: 30));
  }

  // === Content Routes ===

  Future<Response> _getNew(Request request, User user) async {
    final params = request.url.queryParameters;
    final providerKeys = params['providers']?.split(',') ?? [];
    final type = params['type']; // 'movie', 'tv', or null for both
    final days = int.tryParse(params['days'] ?? '30') ?? 30;

    final providerIds = Providers.parseProviderKeys(providerKeys);
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final startStr = _formatDate(startDate);
    final endStr = _formatDate(now);

    final items = <Map<String, dynamic>>[];

    if (type == null || type == 'movie') {
      final movies = await tmdb.discoverMovies(
        providerIds: providerIds,
        releaseDateGte: startStr,
        releaseDateLte: endStr,
      );
      for (final m in movies) {
        items.add({
          ...m.toJson(),
          'watched': watchHistory.isWatched(user.id, m),
        });
      }
    }

    if (type == null || type == 'tv') {
      final tv = await tmdb.discoverTv(
        providerIds: providerIds,
        airDateGte: startStr,
        airDateLte: endStr,
      );
      for (final t in tv) {
        items.add({
          ...t.toJson(),
          'watched': watchHistory.isWatched(user.id, t),
        });
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

  Future<Response> _getTrending(Request request, User user) async {
    final params = request.url.queryParameters;
    final window = params['window'] ?? 'week';
    final type = params['type']; // 'movie', 'tv', or null for both

    final items = <Map<String, dynamic>>[];

    if (type == null || type == 'movie') {
      final movies = await tmdb.getTrendingMovies(window: window);
      for (final m in movies) {
        items.add({
          ...m.toJson(),
          'watched': watchHistory.isWatched(user.id, m),
        });
      }
    }

    if (type == null || type == 'tv') {
      final tv = await tmdb.getTrendingTv(window: window);
      for (final t in tv) {
        items.add({
          ...t.toJson(),
          'watched': watchHistory.isWatched(user.id, t),
        });
      }
    }

    return _jsonOk({'items': items});
  }

  Future<Response> _search(Request request, User user) async {
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return _jsonError(400, 'Query parameter q required');
    }

    final results = await tmdb.searchMulti(query);
    final items = results
        .map((r) => {
              ...r.toJson(),
              'watched': watchHistory.isWatched(user.id, r),
            })
        .toList();

    return _jsonOk({'items': items});
  }

  Future<Response> _where(Request request, User user) async {
    final query = request.url.queryParameters['q'];
    if (query == null || query.isEmpty) {
      return _jsonError(400, 'Query parameter q required');
    }

    final results = await tmdb.searchMulti(query);
    final items = <Map<String, dynamic>>[];

    for (final result in results.take(5)) {
      final providers =
          await tmdb.getWatchProviders(result.id, result.mediaType);
      items.add({
        ...result.toJson(),
        'providers': providers,
        'watched': watchHistory.isWatched(user.id, result),
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
  Future<Response> _getRatings(Request request, User user) async {
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

  Future<Response> _getWatched(Request request, User user) async {
    final items = watchHistory.all(user.id);
    return _jsonOk({'items': items});
  }

  Future<Response> _markWatched(Request request, User user) async {
    final mediaType = request.params['mediaType'];
    final id = request.params['id'];
    if (mediaType == null || id == null) {
      return _jsonError(400, 'Invalid parameters');
    }

    final key = '${mediaType}_$id';
    await watchHistory.markWatchedByKey(user.id, key);
    return _jsonOk({'success': true, 'key': key});
  }

  Future<Response> _unmarkWatched(Request request, User user) async {
    final mediaType = request.params['mediaType'];
    final id = request.params['id'];
    if (mediaType == null || id == null) {
      return _jsonError(400, 'Invalid parameters');
    }

    final key = '${mediaType}_$id';
    await watchHistory.markUnwatchedByKey(user.id, key);
    return _jsonOk({'success': true, 'key': key});
  }

  // === Torrent Routes ===

  Future<Response> _searchTorrents(Request request, User user) async {
    if (jackett == null) {
      return _jsonError(503, 'Jackett not configured');
    }

    final query = request.url.queryParameters['q'];
    final category = request.url.queryParameters['category']; // 'movie' or 'tv'

    if (query == null || query.isEmpty) {
      return _jsonError(400, 'Query parameter q required');
    }

    List<TorrentResult> results;
    if (category == 'movie') {
      results = await jackett!.searchMovies(query);
    } else if (category == 'tv') {
      results = await jackett!.searchTv(query);
    } else {
      results = await jackett!.search(query);
    }

    // Sort by seeders descending
    results.sort((a, b) => b.seeders.compareTo(a.seeders));

    return _jsonOk({
      'results': results.take(50).map((r) => r.toJson()).toList(),
    });
  }

  Future<Response> _downloadTorrent(Request request, User user) async {
    final body = await _parseJson(request);
    if (body == null) return _jsonError(400, 'Invalid JSON');

    final magnetOrUrl = body['url'] as String?;
    if (magnetOrUrl == null || magnetOrUrl.isEmpty) {
      return _jsonError(400, 'URL or magnet link required');
    }

    try {
      final torrent = await transmission.addTorrent(magnetOrUrl);
      return _jsonOk({'torrent': torrent.toJson()});
    } on TransmissionException catch (e) {
      return _jsonError(500, e.message);
    }
  }

  Future<Response> _getActiveTorrents(Request request, User user) async {
    try {
      final torrents = await transmission.getTorrents();
      return _jsonOk({
        'torrents': torrents.map((t) => t.toJson()).toList(),
      });
    } on TransmissionException catch (e) {
      return _jsonError(500, e.message);
    }
  }

  Future<Response> _removeTorrent(Request request, User user) async {
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
}
