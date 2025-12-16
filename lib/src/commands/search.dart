import 'package:args/command_runner.dart';
import '../tmdb_client.dart';
import 'utils.dart';

class SearchCommand extends Command<void> {
  @override
  final name = 'search';
  @override
  final description = 'Search for movies and TV shows';

  final TmdbClient tmdb;

  SearchCommand(this.tmdb) {
    argParser.addOption(
      'type',
      abbr: 't',
      help: 'Filter by type (movie, tv)',
      allowed: ['movie', 'tv'],
    );
  }

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('Usage: plex search <query>');
      return;
    }

    final query = argResults!.rest.join(' ');
    final typeFilter = argResults!['type'] as String?;

    print('Searching for "$query"...\n');

    var results = await tmdb.searchMulti(query);

    if (typeFilter != null) {
      results = results.where((r) => r.mediaType == typeFilter).toList();
    }

    if (results.isEmpty) {
      print('No results found.');
      return;
    }

    print('Found ${results.length} results:\n');
    for (final item in results.take(15)) {
      final type = item.mediaType == 'movie' ? 'MOVIE' : 'TV';
      print('[$type] ${item.title} (${item.year}) - ${item.rating}/10');
      if (item.overview != null && item.overview!.isNotEmpty) {
        final desc = truncate(item.overview!, 100);
        print('       $desc');
      }
      print('');
    }
  }
}
