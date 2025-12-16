import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:plex/plex.dart';

void main(List<String> arguments) async {
  final apiKey = Platform.environment['TMDB_API_KEY'];
  final watchHistoryStore = WatchHistory();
  await watchHistoryStore.load();
  final watchHistory = SingleUserWatchHistory(watchHistoryStore);

  final runner = CommandRunner<void>(
    'plex',
    'Streaming content discovery CLI - find what\'s new on your favorite services.',
  )
    ..addCommand(ProvidersCommand())
    ..addCommand(WatchedCommand(watchHistory))
    ..addCommand(UnwatchCommand(watchHistory));

  // Commands that require TMDB API key
  if (apiKey != null && apiKey.isNotEmpty) {
    final tmdb = TmdbClient(apiKey);
    runner
      ..addCommand(NewReleasesCommand(tmdb, watchHistory))
      ..addCommand(TrendingCommand(tmdb, watchHistory))
      ..addCommand(SearchCommand(tmdb))
      ..addCommand(WhereCommand(tmdb));
  } else {
    // Check if user is trying to use a command that needs API key
    final needsApiKey = arguments.isNotEmpty &&
        ['new', 'trending', 'search', 'where'].contains(arguments.first);
    if (needsApiKey) {
      stderr.writeln('Error: TMDB_API_KEY environment variable not set.');
      stderr.writeln('Get a free API key at https://www.themoviedb.org/settings/api');
      exit(1);
    }
  }

  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    print(e);
    exit(64);
  }
}
