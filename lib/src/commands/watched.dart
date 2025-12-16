import 'package:args/command_runner.dart';
import '../watch_history.dart';

class WatchedCommand extends Command<void> {
  @override
  final name = 'watched';
  @override
  final description = 'Mark a title as watched';

  final SingleUserWatchHistory watchHistory;

  WatchedCommand(this.watchHistory);

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      // List watched items
      final watched = watchHistory.all;
      if (watched.isEmpty) {
        print('No items marked as watched.');
      } else {
        print('Watched items (${watched.length}):');
        for (final key in watched) {
          print('  $key');
        }
      }
      return;
    }

    // Mark item as watched by key
    final key = argResults!.rest.join(' ');
    await watchHistory.markWatchedByKey(key);
    print('Marked as watched: $key');
  }
}

class UnwatchCommand extends Command<void> {
  @override
  final name = 'unwatch';
  @override
  final description = 'Remove a title from watched list';

  final SingleUserWatchHistory watchHistory;

  UnwatchCommand(this.watchHistory);

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      print('Usage: plex unwatch <key>');
      print('Use "plex watched" to see watched items and their keys.');
      return;
    }

    final key = argResults!.rest.join(' ');
    await watchHistory.markUnwatchedByKey(key);
    print('Removed from watched: $key');
  }
}
