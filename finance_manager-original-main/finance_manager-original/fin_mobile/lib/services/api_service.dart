// lib/services/api_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String resolveBackendUrl([Map<String, String>? env]) {
  Map<String, String> source;
  if (env != null) {
    source = env;
  } else {
    try {
      source = dotenv.env;
    } catch (_) {
      source = const {};
    }
  }

  final normalized = (source['BACKEND_URL'] ??
          source['API_BASE_URL'] ??
          'http://10.0.2.2:5000')
      .replaceAll(RegExp(r'/+$'), '');

  final runningOnAndroid =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  if (runningOnAndroid) {
    final parsed = Uri.tryParse(normalized);
    final host = parsed?.host.toLowerCase();
    if (parsed != null && (host == 'localhost' || host == '127.0.0.1')) {
      return parsed
          .replace(host: '10.0.2.2')
          .toString()
          .replaceAll(RegExp(r'/+$'), '');
    }
  }

  return normalized;
}

class ApiService {
  // Load URL from .env file
  final String baseUrl = resolveBackendUrl();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  ApiService() {
    debugPrint('[ApiService] baseUrl=$baseUrl');
  }

  Future<String?> getToken() async => await storage.read(key: 'jwt_token');

  String _requestId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = Random().nextInt(1 << 32).toRadixString(16);
    return 'flutter-$now-$rand';
  }

  Future<void> saveToken(String token) async =>
      await storage.write(key: 'jwt_token', value: token);
  Future<void> deleteToken() async => await storage.delete(key: 'jwt_token');

  Map<String, String> _headers([bool auth = false]) {
    return {
      'Content-Type': 'application/json',
      'X-Request-ID': _requestId(),
    };
  }

  Future<http.Response> post(String path, Map body, {bool auth = false}) async {
    final url = Uri.parse('$baseUrl$path');
    if (!auth)
      return await http
          .post(url, body: jsonEncode(body), headers: _headers(false))
          .timeout(
            Duration(seconds: 10),
            onTimeout: () =>
                http.Response('{"error": "Connection timeout"}', 408),
          );

    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Request-ID': _requestId(),
    };
    return await http
        .post(url, body: jsonEncode(body), headers: headers)
        .timeout(
          Duration(seconds: 10),
          onTimeout: () =>
              http.Response('{"error": "Connection timeout"}', 408),
        );
  }

  Future<http.Response> get(String path,
      {Map<String, String>? queryParams, bool auth = false}) async {
    var url = Uri.parse('$baseUrl$path');
    if (queryParams != null) url = url.replace(queryParameters: queryParams);
    if (!auth)
      return await http.get(url, headers: _headers(false)).timeout(
            Duration(seconds: 10),
            onTimeout: () =>
                http.Response('{"error": "Connection timeout"}', 408),
          );
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Request-ID': _requestId(),
    };
    return await http.get(url, headers: headers).timeout(
          Duration(seconds: 10),
          onTimeout: () =>
              http.Response('{"error": "Connection timeout"}', 408),
        );
  }

  Future<http.Response> put(String path, Map body, {bool auth = false}) async {
    final url = Uri.parse('$baseUrl$path');
    if (!auth)
      return await http
          .put(url, body: jsonEncode(body), headers: _headers(false))
          .timeout(
            Duration(seconds: 10),
            onTimeout: () =>
                http.Response('{"error": "Connection timeout"}', 408),
          );

    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Request-ID': _requestId(),
    };
    return await http
        .put(url, body: jsonEncode(body), headers: headers)
        .timeout(
          Duration(seconds: 10),
          onTimeout: () =>
              http.Response('{"error": "Connection timeout"}', 408),
        );
  }

  Future<http.Response> delete(String path, {bool auth = false}) async {
    final url = Uri.parse('$baseUrl$path');
    if (!auth)
      return await http.delete(url, headers: _headers(false)).timeout(
            Duration(seconds: 10),
            onTimeout: () =>
                http.Response('{"error": "Connection timeout"}', 408),
          );

    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'X-Request-ID': _requestId(),
    };
    return await http.delete(url, headers: headers).timeout(
          Duration(seconds: 10),
          onTimeout: () =>
              http.Response('{"error": "Connection timeout"}', 408),
        );
  }

  // Analytics endpoints
  Future<Map<String, dynamic>> getHealthScore() async {
    final response = await get('/api/analytics/health-score', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 400) {
      // Return default when monthly income not set
      return {
        'score': 0,
        'grade': 'Set Income',
        'error': 'Please set monthly income'
      };
    }
    throw Exception('Failed to get health score');
  }

  Future<Map<String, dynamic>> getRiskAssessment() async {
    final response = await get('/api/analytics/risk-assessment', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get risk assessment');
  }

  Future<Map<String, dynamic>> getInsights() async {
    final response = await get('/api/analytics/insights', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get insights');
  }

  Future<Map<String, dynamic>> getDashboardSummary() async {
    final response = await get('/api/analytics/summary', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get dashboard summary');
  }

  Future<Map<String, dynamic>> getGamification() async {
    final response = await get('/api/analytics/gamification', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get gamification');
  }

  Future<Map<String, dynamic>> getAiWidgets({String? text}) async {
    final queryParams =
        (text != null && text.trim().isNotEmpty) ? {'text': text.trim()} : null;
    final response = await get('/api/analytics/ai-widgets',
        queryParams: queryParams, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get AI widgets');
  }

  // Coach endpoints
  Future<Map<String, dynamic>> getPersonalizedAdvice() async {
    final response = await post('/api/coach/get-advice', {}, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 400) {
      // Return default when monthly income not set
      return {
        'error': 'Please set monthly income',
        'recommendations': [
          'Set your monthly income in profile to get personalized financial advice'
        ],
        'health_score': 0,
        'grade': 'Unknown'
      };
    }
    throw Exception('Failed to get advice');
  }

  Future<List<dynamic>> getCoachNotifications() async {
    final response = await get('/api/coach/notifications', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['notifications'];
    }
    throw Exception('Failed to get notifications');
  }

  Future<String> getDailyTip() async {
    final response = await get('/api/coach/daily-tip', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['tip'];
    }
    throw Exception('Failed to get daily tip');
  }

  // Transactions
  Future<List<dynamic>> getTransactions({int limit = 100}) async {
    final response = await get('/api/transactions/',
        queryParams: {'limit': limit.toString()}, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get transactions');
  }

  Future<String> exportTransactionsCsv(
      {String? month, String? category, String? type}) async {
    final queryParams = <String, String>{};
    if (month != null) queryParams['month'] = month;
    if (category != null) queryParams['category'] = category;
    if (type != null) queryParams['type'] = type;

    final response = await get('/api/transactions/export/csv',
        queryParams: queryParams.isEmpty ? null : queryParams, auth: true);
    if (response.statusCode == 200) {
      return response.body;
    }
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};
    throw Exception((body as Map<String, dynamic>)['error'] ??
        'Failed to export transactions');
  }

  Future<void> deleteTransaction(int id) async {
    final response = await delete('/api/transactions/$id', auth: true);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(body['error'] ?? 'Failed to delete transaction');
    }
  }

  /// Updates a single transaction. Returns the updated transaction map.
  Future<Map<String, dynamic>> updateTransaction(
      int id, Map<String, dynamic> data) async {
    final response = await put('/api/transactions/$id', data, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};
    throw Exception((body as Map<String, dynamic>)['error'] ??
        'Failed to update transaction');
  }

  // Budget endpoints
  Future<List<dynamic>> getBudgets({String? month}) async {
    final queryParams = month != null ? {'month': month} : null;
    final response =
        await get('/api/budgets/', queryParams: queryParams, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['budgets'];
    }
    throw Exception('Failed to get budgets');
  }

  Future<Map<String, dynamic>> createBudget(
      String category, double limit, String month) async {
    final response = await post('/api/budgets/',
        {'category': category, 'limit_amount': limit, 'month': month},
        auth: true);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create budget');
  }

  Future<Map<String, dynamic>> updateBudget(
      int id, Map<String, dynamic> data) async {
    final response = await put('/api/budgets/$id', data, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};
    throw Exception(
        (body as Map<String, dynamic>)['error'] ?? 'Failed to update budget');
  }

  Future<Map<String, dynamic>> getBudgetSummary({String? month}) async {
    final queryParams = month != null ? {'month': month} : null;
    final response =
        await get('/api/budgets/summary', queryParams: queryParams, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};
    throw Exception((body as Map<String, dynamic>)['error'] ??
        'Failed to get budget summary');
  }

  Future<void> deleteBudget(int id) async {
    final response = await delete('/api/budgets/$id', auth: true);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      throw Exception(body['error'] ?? 'Failed to delete budget');
    }
  }

  // Credit endpoints
  Future<Map<String, dynamic>> getCreditSummary() async {
    final response = await get('/api/credit/summary', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get credit summary');
  }

  Future<List<dynamic>> getLoans() async {
    final response = await get('/api/credit/loans', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['loans'];
    }
    throw Exception('Failed to get loans');
  }

  // User profile endpoints
  Future<Map<String, dynamic>> getProfile() async {
    final response = await get('/api/user/profile', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to get profile');
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await put('/api/user/profile', data, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to update profile');
  }

  Future<Map<String, dynamic>> exportBackup() async {
    final response = await get('/api/user/backup', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final body = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : <String, dynamic>{};
    throw Exception(
        (body as Map<String, dynamic>)['error'] ?? 'Failed to export backup');
  }

  Future<void> restoreBackup(Map<String, dynamic> backup) async {
    final response = await post('/api/user/backup', backup, auth: true);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      throw Exception((body as Map<String, dynamic>)['error'] ??
          'Failed to restore backup');
    }
  }

  Future<List<String>> getCategories() async {
    final response = await get('/api/user/categories', auth: true);
    if (response.statusCode == 200) {
      return List<String>.from(jsonDecode(response.body)['categories']);
    }
    throw Exception('Failed to get categories');
  }

  Future<List<dynamic>> getNotifications() async {
    final response = await get('/api/user/notifications', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['notifications'];
    }
    throw Exception('Failed to get notifications');
  }

  Future<void> markNotificationsRead({int? notificationId}) async {
    final response = await post(
        '/api/user/notifications/mark-read',
        {
          if (notificationId != null) 'notification_id': notificationId,
        },
        auth: true);
    if (response.statusCode != 200) {
      final body = response.body.isNotEmpty
          ? jsonDecode(response.body)
          : <String, dynamic>{};
      throw Exception((body as Map<String, dynamic>)['error'] ??
          'Failed to mark notifications read');
    }
  }

  Future<Map<String, dynamic>> initiatePanConsent(
      String pan, String name, String dob, String mobile) async {
    final response = await post('/api/credit/kyc/initiate-pan-consent',
        {'pan': pan, 'name': name, 'dob': dob, 'mobile': mobile},
        auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to initiate PAN consent');
  }

  Future<Map<String, dynamic>> verifyOtp(String consentId, String otp) async {
    final response = await post('/api/credit/kyc/verify-otp',
        {'consent_request_id': consentId, 'otp': otp},
        auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to verify OTP');
  }

  Future<Map<String, dynamic>> fetchCreditReport(String pan) async {
    final response =
        await post('/api/credit/fetch-report', {'pan': pan}, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to fetch credit report');
  }

  Future<Map<String, dynamic>> parseSms(String text) async {
    final response = await post('/api/sms/parse', {'text': text}, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to parse SMS');
  }

  Future<Map<String, dynamic>> chat(String query) async {
    final response = await post('/api/chatbot/', {'query': query}, auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Chatbot request failed');
  }

  Future<List<dynamic>> getSubscriptions() async {
    final response = await get('/api/subscriptions/', auth: true);
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['subscriptions'];
    }
    throw Exception('Failed to get subscriptions');
  }

  Future<Map<String, dynamic>> createSubscription(
      String name, double amount, String frequency,
      {String? merchant, String? nextDate}) async {
    final body = {
      'name': name,
      'amount': amount,
      'frequency': frequency,
      if (merchant != null) 'merchant': merchant,
      if (nextDate != null) 'next_date': nextDate,
    };
    final response = await post('/api/subscriptions/', body, auth: true);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to create subscription');
  }
}
