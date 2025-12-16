import 'package:args/command_runner.dart';
import '../tmdb_client.dart';
import '../providers.dart';
import '../models.dart';
import '../watch_history.dart';
import 'utils.dart';

class NewReleasesCommand extends Command<void> {
  @override
  final name = 'new';
  @override
  final description = 'Show new releases from streaming services';

  final TmdbClient tmdb;
  final SingleUserWatchHistory watchHistory;

  NewReleasesCommand(this.tmdb, this.watchHistory) {
    argParser
      ..addMultiOption(
        'provider',
        abbr: 'p',
        help: 'Filter by provider (netflix, disney, apple, paramount, prime, hbo, hulu, peacock)',
      )
      ..addFlag(
        'movies',
        abbr: 'm',
        help: 'Show only movies',
        negatable: false,
      )
      ..addFlag(
        'tv',
        abbr: 't',
        help: 'Show only TV shows',
        negatable: false,
      )
      ..addOption(
        'days',
        abbr: 'd',
        help: 'Number of days to look back',
        defaultsTo: '30',
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
    final providerKeys = argResults!['provider'] as List<String>;
    final moviesOnly = argResults!['movies'] as bool;
    final tvOnly = argResults!['tv'] as bool;
    final days = int.tryParse(argResults!['days'] as String) ?? 30;
    final includeWatched = argResults!['all'] as bool;

    final providerIds = Providers.parseProviderKeys(providerKeys);
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final startStr = formatDate(startDate);
    final endStr = formatDate(now);

    final providerNames = providerIds
        .map((id) => Providers.nameById(id))
        .whereType<String>()
        .join(', ');
    print('New releases from $providerNames (last $days days)\n');

    var items = <MediaItem>[];

    if (!tvOnly) {
      print('Fetching movies...');
      final movies = await tmdb.discoverMovies(
        providerIds: providerIds,
        releaseDateGte: startStr,
        releaseDateLte: endStr,
      );
      items.addAll(movies);
    }

    if (!moviesOnly) {
      print('Fetching TV shows...');
      final tv = await tmdb.discoverTv(
        providerIds: providerIds,
        airDateGte: startStr,
        airDateLte: endStr,
      );
      items.addAll(tv);
    }

    if (!includeWatched) {
      items = watchHistory.filterUnwatched(items);
    }

    // Sort by release date descending
    items.sort((a, b) {
      final aDate = a.releaseDate ?? '';
      final bDate = b.releaseDate ?? '';
      return bDate.compareTo(aDate);
    });

    print('');
    if (items.isEmpty) {
      print('No new releases found.');
    } else {
      print('Found ${items.length} new releases:\n');
      for (final item in items.take(20)) {
        final type = item.mediaType == 'movie' ? 'MOVIE' : 'TV';
        final watched = watchHistory.isWatched(item) ? ' [watched]' : '';
        print('[$type] ${item.title} (${item.year}) - ${item.rating}/10$watched');
        if (item.overview != null && item.overview!.isNotEmpty) {
          final desc = truncate(item.overview!, 100);
          print('       $desc');
        }
        print('');
      }
    }
  }
}
