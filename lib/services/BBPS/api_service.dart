import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api_logger.dart';

class ApiService {
  static const String baseUrl = 'https://api.myneofyn.com';
  static const _storage = FlutterSecureStorage();

  // ────────────────────────────────────────────────────────────
  // Token Management
  // ────────────────────────────────────────────────────────────
  
  static Future<String?> getToken() async {
    // 1. Try secure storage (primary storage)
    try {
      String? token = await _storage.read(key: 'jwt_token');
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}

    // 2. Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: 'jwt_token', value: token);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> clearToken() async {
    try {
      await _storage.delete(key: 'jwt_token');
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  // ────────────────────────────────────────────────────────────
  // HTTP Methods
  // ────────────────────────────────────────────────────────────

  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    print('📤 GET $uri');
    final response = await http.get(uri, headers: headers);
    print('📥 Response [${response.statusCode}] from $endpoint');
    return _handleResponse(response);
  }

  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final jsonBody = jsonEncode(body);
    print('📤 POST $endpoint');
    print('📤 Body: $jsonBody');

    final response = await http.post(uri, headers: headers, body: jsonBody);
    print('📥 Response [${response.statusCode}] from $endpoint');
    return _handleResponse(response);
  }

  static Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final jsonBody = jsonEncode(body);
    print('📤 PUT $endpoint');
    final response = await http.put(uri, headers: headers, body: jsonBody);
    print('📥 Response [${response.statusCode}] from $endpoint');
    return _handleResponse(response);
  }

  static Future<dynamic> delete(String endpoint) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    print('📤 DELETE $endpoint');
    final response = await http.delete(uri, headers: headers);
    print('📥 Response [${response.statusCode}] from $endpoint');
    return _handleResponse(response);
  }

  // ────────────────────────────────────────────────────────────
  // Response Handling
  // ────────────────────────────────────────────────────────────
  static dynamic _handleResponse(http.Response response) {
    final decoded = jsonDecode(response.body);

    // ✅ Print full response for BBPS endpoints
    if (response.request?.url.toString().contains('bbps') == true) {
      print('┌──────────────────────────────────────────────────────');
      print('│ 📦 [BBPS] FULL RESPONSE BODY:');
      print('│');
      final prettyJson = const JsonEncoder.withIndent('  ').convert(decoded);
      print('│ $prettyJson');
      print('│');
      print('└──────────────────────────────────────────────────────');
    } else {
      print('📦 Response body: ${response.body.length > 200 ? response.body.substring(0, 200) + '...' : response.body}');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    } else {
      throw ApiException(
        statusCode: response.statusCode,
        message: decoded['message'] ?? decoded['error'] ?? 'Unknown error',
        errors: decoded['errors'] is List ? List<String>.from(decoded['errors']) : null,
      );
    }
  }
// ───────────────────────────────────────────────────────────────
//  BBPS - Get Transaction History
// ───────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getBbpsHistory({
    String? userId,
    int limit = 100,
    int offset = 0,
    String? category,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (userId != null) queryParams['userId'] = userId;
      if (category != null) queryParams['category'] = category;

      debugPrint('┌──────────────────────────────────────────');
      debugPrint('│ 🔍 [BBPS] Fetching History');
      debugPrint('│ 👤 UserID: $userId');
      debugPrint('└──────────────────────────────────────────');

      final data = await ApiService.get(
        '/api/bbps/history',
        queryParams: queryParams,
      );

      // ✅ Print full response
      debugPrint('┌──────────────────────────────────────────');
      debugPrint('│ 📦 [BBPS] FULL RESPONSE:');
      debugPrint('│ ${jsonEncode(data)}');
      debugPrint('└──────────────────────────────────────────');

      List<dynamic> list = [];

      if (data is List) {
        list = data;
      } else if (data is Map) {
        list = data['transactions'] ?? data['data'] ?? data['history'] ?? [];
      }

      debugPrint('✅ [BBPS] Found ${list.length} transactions');

      // ✅ Print first transaction keys for debugging
      if (list.isNotEmpty) {
        debugPrint('📋 [BBPS] First transaction keys: ${(list[0] as Map).keys.toList()}');
        debugPrint('📋 [BBPS] First transaction: ${jsonEncode(list[0])}');
      }

      return list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('❌ [BBPS] History error: $e');
      return [];
    }
  }
}

// ────────────────────────────────────────────────────────────
// Custom Exception
// ────────────────────────────────────────────────────────────

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final List<String>? errors;

  ApiException({
    required this.statusCode,
    required this.message,
    this.errors,
  });

  @override
  String toString() => 'ApiException($statusCode): $message ${errors ?? ''}';
}