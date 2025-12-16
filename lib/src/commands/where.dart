import 'package:args/command_runner.dart';
import '../tmdb_client.dart';

class WhereCommand extends Command<void> {
  @override
  final name = 'where';
  @override
  final description = 'Find where a title is streaming';

  final TmdbClient tmdb;

  WhereCommand(this.tmdb);

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('Usage: upstream where <title>');
      return;
    }

    final query = argResults!.rest.join(' ');
    print('Searching for "$query"...\n');

    final results = await tmdb.searchMulti(query);

    if (results.isEmpty) {
      print('No results found.');
      return;
    }

    // Get top 5 results and enrich with providers
    final topResults = results.take(5).toList();

    for (final item in topResults) {
      final type = item.mediaType == 'movie' ? 'MOVIE' : 'TV';
      print('[$type] ${item.title} (${item.year})');

      final providers = await tmdb.getWatchProviders(item.id, item.mediaType);

      if (providers.isEmpty) {
        print('       Not available on tracked streaming services');
      } else {
        print('       Available on: ${providers.join(", ")}');
      }
      print('');
    }
  }
}
