import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

class UserService {
  final Map<String, User> _users = {};
  late final String _filePath;

  UserService() {
    final home = Platform.environment['HOME'] ?? '.';
    _filePath = path.join(home, '.upstream_users.json');
  }

  Future<void> load() async {
    final file = File(_filePath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final users = data['users'] as Map<String, dynamic>? ?? {};
        for (final entry in users.entries) {
          _users[entry.key] = User.fromJson(entry.value as Map<String, dynamic>);
        }
      } catch (_) {
        // Ignore corrupt file
      }
    }
  }

  Future<void> save() async {
    final file = File(_filePath);
    final data = {
      'users': _users.map((k, v) => MapEntry(k, v.toJson())),
    };
    await file.writeAsString(jsonEncode(data));
  }

  User? getUser(String username) => _users[username.toLowerCase()];

  User? getUserById(String id) {
    for (final user in _users.values) {
      if (user.id == id) return user;
    }
    return null;
  }

  Future<User> createUser(String username, String password) async {
    final key = username.toLowerCase();
    if (_users.containsKey(key)) {
      throw UserException('Username already exists');
    }

    final user = User(
      id: _generateId(),
      username: username,
      passwordHash: _hashPassword(password),
      createdAt: DateTime.now(),
    );

    _users[key] = user;
    await save();
    return user;
  }

  User? authenticate(String username, String password) {
    final user = getUser(username);
    if (user == null) return null;

    final hash = _hashPassword(password);
    if (hash != user.passwordHash) return null;

    return user;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = now.hashCode.toRadixString(36);
    return 'u_$random';
  }

  int get userCount => _users.length;
}

class User {
  final String id;
  final String username;
  final String passwordHash;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      username: json['username'] as String,
      passwordHash: json['passwordHash'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'passwordHash': passwordHash,
        'createdAt': createdAt.toIso8601String(),
      };

  Map<String, dynamic> toPublicJson() => {
        'id': id,
        'username': username,
        'createdAt': createdAt.toIso8601String(),
      };
}

class UserException implements Exception {
  final String message;

  UserException(this.message);

  @override
  String toString() => message;
}
