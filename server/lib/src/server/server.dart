import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

import '../services/omdb_client.dart';
import '../services/firebase_auth_service.dart';
import '../services/firestore_watch_history.dart';
import '../tmdb_client.dart';
import 'routes.dart';

class DownstreamServer {
  final int port;
  final String? staticPath;

  late final TmdbClient tmdb;
  late final OmdbClient? omdb;
  late final FirebaseAuthService firebaseAuth;
  late final FirestoreWatchHistory watchHistory;

  DownstreamServer({
    this.port = 8080,
    this.staticPath,
  });

  Future<void> start() async {
    // Load config from environment
    final tmdbKey = Platform.environment['TMDB_API_KEY'];
    if (tmdbKey == null || tmdbKey.isEmpty) {
      throw Exception('TMDB_API_KEY environment variable required');
    }

    final firebaseProjectId = Platform.environment['FIREBASE_PROJECT_ID'];
    if (firebaseProjectId == null || firebaseProjectId.isEmpty) {
      throw Exception('FIREBASE_PROJECT_ID environment variable required');
    }

    final firebaseServiceAccount = Platform.environment['FIREBASE_SERVICE_ACCOUNT'];
    if (firebaseServiceAccount == null || firebaseServiceAccount.isEmpty) {
      throw Exception('FIREBASE_SERVICE_ACCOUNT environment variable required');
    }

    final omdbKey = Platform.environment['OMDB_API_KEY'];

    // Initialize services
    tmdb = TmdbClient(tmdbKey);

    if (omdbKey != null && omdbKey.isNotEmpty) {
      omdb = OmdbClient(omdbKey);
      print('  OMDB: Configured (IMDB/RT/Metacritic ratings enabled)');
    } else {
      omdb = null;
      print('Warning: OMDB not configured (OMDB_API_KEY required for ratings)');
    }

    // Initialize Firebase services
    firebaseAuth = FirebaseAuthService(projectId: firebaseProjectId);
    watchHistory = await FirestoreWatchHistory.create(
      projectId: firebaseProjectId,
      serviceAccountJson: firebaseServiceAccount,
    );
    print('  Firebase: Configured (project: $firebaseProjectId)');

    // Build router
    final apiRoutes = ApiRoutes(
      tmdb: tmdb,
      omdb: omdb,
      firebaseAuth: firebaseAuth,
      watchHistory: watchHistory,
    );

    final router = Router();

    // Mount API routes
    router.mount('/api/', apiRoutes.router.call);

    // Health check
    router.get('/health', (Request request) {
      return Response.ok('OK');
    });

    // Build pipeline
    var handler = const Pipeline()
        .addMiddleware(logRequests())
        .addMiddleware(corsHeaders())
        .addHandler(router.call);

    // Add static file serving if path provided
    if (staticPath != null) {
      final staticHandler = createStaticHandler(
        staticPath!,
        defaultDocument: 'index.html',
      );

      handler = const Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(corsHeaders())
          .addHandler((Request request) async {
            // Try API first
            if (request.url.path.startsWith('api/') ||
                request.url.path == 'health') {
              return router.call(request);
            }
            // Fall back to static files
            return staticHandler(request);
          });
    }

    // Start server
    final server = await io.serve(handler, InternetAddress.anyIPv4, port);
    print('Downstream server running at http://${server.address.host}:${server.port}');
  }
}
