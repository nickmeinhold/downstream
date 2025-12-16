import 'package:args/command_runner.dart';
import '../tmdb_client.dart';
import '../models.dart';
import '../watch_history.dart';
import 'utils.dart';

class TrendingCommand extends Command<void> {
  @override
  final name = 'trending';
  @override
  final description = 'Show trending movies and TV shows';

  final TmdbClient tmdb;
  final SingleUserWatchHistory watchHistory;

  TrendingCommand(this.tmdb, this.watchHistory) {
    argParser
      ..addOption(
        'window',
        abbr: 'w',
        help: 'Time window (day or week)',
        defaultsTo: 'week',
        allowed: ['day', 'week'],
      )
      ..addOption(
        'type',
        abbr: 't',
        help: 'Media type (movie, tv, or all)',
        defaultsTo: 'all',
        allowed: ['movie', 'tv', 'all'],
      )
      ..addFlag(
        'all',
        abbr: 'a',
        help: 'Include already watched items',
        negatable: false,
      );
  }

  @override
  Future<void> run() async {
    final window = argResults!['window'] as String;
    final type = argResults!['type'] as String;
    final includeWatched = argResults!['all'] as bool;

    final windowLabel = window == 'day' ? 'today' : 'this week';
    print('Trending $windowLabel\n');

    var items = <MediaItem>[];

    if (type == 'all' || type == 'movie') {
      print('Fetching trending movies...');
      final movies = await tmdb.getTrendingMovies(window: window);
      items.addAll(movies);
    }

    if (type == 'all' || type == 'tv') {
      print('Fetching trending TV shows...');
      final tv = await tmdb.getTrendingTv(window: window);
      items.addAll(tv);
    }

    if (!includeWatched) {
      items = watchHistory.filterUnwatched(items);
    }

    print('');
    if (items.isEmpty) {
      print('No trending items found.');
    } else {
      print('Found ${items.length} trending items:\n');
      for (final item in items.take(20)) {
        final typeLabel = item.mediaType == 'movie' ? 'MOVIE' : 'TV';
        final watched = watchHistory.isWatched(item) ? ' [watched]' : '';
        print('[$typeLabel] ${item.title} (${item.year}) - ${item.rating}/10$watched');
        if (item.overview != null && item.overview!.isNotEmpty) {
          final desc = truncate(item.overview!, 100);
          print('         $desc');
        }
        print('');
      }
    }
  }
}
