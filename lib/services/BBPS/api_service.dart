import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://api.myneofyn.com';
  
  static const _storage = FlutterSecureStorage();

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
  // Generic GET request
  static Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl$endpoint').replace(queryParameters: queryParams);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.get(uri, headers: headers);
    return _handleResponse(response);
  }

  // Generic POST request
  static Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.post(uri, headers: headers, body: jsonEncode(body));
    return _handleResponse(response);
  }

  // Handle HTTP response
  static dynamic _handleResponse(http.Response response) {
    final decoded = jsonDecode(response.body);
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
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final List<String>? errors;

  ApiException({required this.statusCode, required this.message, this.errors});

  @override
  String toString() => 'ApiException($statusCode): $message ${errors ?? ''}';
}