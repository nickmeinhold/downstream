import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = true;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String get username => _user?['username'] ?? '';

  String get baseUrl {
    // In web, use relative URLs (same origin)
    // For development, you might need to change this
    if (kIsWeb) {
      return '';
    }
    return 'http://localhost:8080';
  }

  Future<void> tryRestoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      _user = jsonDecode(userJson);
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_token != null) {
      await prefs.setString(_tokenKey, _token!);
    } else {
      await prefs.remove(_tokenKey);
    }
    if (_user != null) {
      await prefs.setString(_userKey, jsonEncode(_user));
    } else {
      await prefs.remove(_userKey);
    }
  }

  Future<String?> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _user = data['user'];
        await _saveSession();
        notifyListeners();
        return null;
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? 'Login failed';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<String?> register(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _user = data['user'];
        await _saveSession();
        notifyListeners();
        return null;
      } else {
        final data = jsonDecode(response.body);
        return data['error'] ?? 'Registration failed';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _saveSession();
    notifyListeners();
  }
}
