// lib/providers/auth_provider.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fin_mobile/services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService api = ApiService();
  bool _loggedIn = false;
  bool _restoring = true; // true until restoreSession() finishes
  String? _name;
  String? _email;
  String? _token;

  bool get isLoggedIn => _loggedIn;
  bool get isRestoring => _restoring;
  String? get name => _name;
  String? get email => _email;
  String? get token => _token;

  Future<Map> register(String name, String email, String password,
      {double? monthlyIncome}) async {
    try {
      final body = {
        "name": name,
        "email": email,
        "password": password,
        if (monthlyIncome != null) "monthly_income": monthlyIncome
      };
      final res = await api.post('/api/auth/register', body);
      final map = jsonDecode(res.body);
      if (res.statusCode == 201 && map['token'] != null) {
        await api.saveToken(map['token']);
        _loggedIn = true;
        _name = map['name'];
        _email = email;
        _token = map['token'];
        notifyListeners();
      }
      return map;
    } catch (e) {
      return {"error": "Cannot connect to server. Check WiFi and backend: $e"};
    }
  }

  Future<Map> login(String email, String password) async {
    try {
      final body = {"email": email, "password": password};
      final res = await api.post('/api/auth/login', body);
      final map = jsonDecode(res.body);
      if (res.statusCode == 200 && map['token'] != null) {
        await api.saveToken(map['token']);
        _loggedIn = true;
        _name = map['user']?['name'];
        _email = map['user']?['email'] ?? email;
        _token = map['token'];
        notifyListeners();
      }
      return map;
    } catch (e) {
      return {"error": "Cannot connect to server. Check WiFi and backend: $e"};
    }
  }

  Future<void> logout() async {
    await api.deleteToken();
    _loggedIn = false;
    _name = null;
    _email = null;
    _token = null;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    final startedAt = DateTime.now();
    debugPrint('[Auth] restoreSession start');
    try {
      final token = await api
          .getToken()
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
      if (token != null) {
        _token = token;
        try {
          final profile =
              await api.getProfile().timeout(const Duration(seconds: 5));
          _name = profile['name']?.toString();
          _email = profile['email']?.toString();
          debugPrint('[Auth] restoreSession token validated');
        } on TimeoutException {
          debugPrint(
              '[Auth] restoreSession profile timeout, continuing with cached token');
        }
        _loggedIn = true;
      } else {
        debugPrint('[Auth] restoreSession no token');
      }
    } catch (e) {
      debugPrint('[Auth] restoreSession error: $e');
      await api.deleteToken();
      _loggedIn = false;
      _name = null;
      _email = null;
      _token = null;
      // secure storage/api unavailable — treat as logged-out
    } finally {
      _restoring = false;
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      debugPrint(
          '[Auth] restoreSession end in ${elapsed}ms | isLoggedIn=$_loggedIn');
      notifyListeners();
    }
  }
}
