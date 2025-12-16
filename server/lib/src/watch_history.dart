import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'models.dart';

/// Multi-user watch history - stores watched items per user ID
class WatchHistory {
  final Map<String, Set<String>> _userWatched = {};
  late final String _filePath;

  WatchHistory() {
    final home = Platform.environment['HOME'] ?? '.';
    _filePath = path.join(home, '.downstream_watched.json');
  }

  Future<void> load() async {
    final file = File(_filePath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;

        // Support both old format (single user) and new format (multi-user)
        if (data.containsKey('users')) {
          // New multi-user format
          final users = data['users'] as Map<String, dynamic>;
          for (final entry in users.entries) {
            final items = entry.value as List<dynamic>;
            _userWatched[entry.key] = items.cast<String>().toSet();
          }
        } else if (data.containsKey('watched')) {
          // Old single-user format - migrate to default user
          final items = data['watched'] as List<dynamic>;
          _userWatched['default'] = items.cast<String>().toSet();
        }
      } catch (_) {
        // Ignore corrupt file
      }
    }
  }

  Future<void> save() async {
    final file = File(_filePath);
    final data = {
      'users': _userWatched.map((k, v) => MapEntry(k, v.toList())),
    };
    await file.writeAsString(jsonEncode(data));
  }

  Set<String> _getOrCreate(String userId) {
    return _userWatched.putIfAbsent(userId, () => {});
  }

  bool isWatched(String userId, MediaItem item) {
    return _getOrCreate(userId).contains(item.uniqueKey);
  }

  bool isWatchedByKey(String userId, String key) {
    return _getOrCreate(userId).contains(key);
  }

  Future<void> markWatched(String userId, MediaItem item) async {
    _getOrCreate(userId).add(item.uniqueKey);
    await save();
  }

  Future<void> markUnwatched(String userId, MediaItem item) async {
    _getOrCreate(userId).remove(item.uniqueKey);
    await save();
  }

  Future<void> markWatchedByKey(String userId, String key) async {
    _getOrCreate(userId).add(key);
    await save();
  }

  Future<void> markUnwatchedByKey(String userId, String key) async {
    _getOrCreate(userId).remove(key);
    await save();
  }

  List<MediaItem> filterUnwatched(String userId, List<MediaItem> items) {
    final watched = _getOrCreate(userId);
    return items.where((item) => !watched.contains(item.uniqueKey)).toList();
  }

  int count(String userId) => _getOrCreate(userId).length;

  List<String> all(String userId) => _getOrCreate(userId).toList();
}

/// Single-user watch history for CLI compatibility
class SingleUserWatchHistory {
  final WatchHistory _history;
  final String _userId;

  SingleUserWatchHistory(this._history, [this._userId = 'default']);

  bool isWatched(MediaItem item) => _history.isWatched(_userId, item);

  Future<void> markWatched(MediaItem item) => _history.markWatched(_userId, item);

  Future<void> markUnwatched(MediaItem item) => _history.markUnwatched(_userId, item);

  Future<void> markWatchedByKey(String key) => _history.markWatchedByKey(_userId, key);

  Future<void> markUnwatchedByKey(String key) => _history.markUnwatchedByKey(_userId, key);

  List<MediaItem> filterUnwatched(List<MediaItem> items) =>
      _history.filterUnwatched(_userId, items);

  int get count => _history.count(_userId);

  List<String> get all => _history.all(_userId);
}
