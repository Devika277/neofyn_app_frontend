// lib/services/mpin_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MpinService {
  static const String _baseUrl = 'https://neofyn-app-backend.onrender.com';
  // ✅ Use the SAME key as LoginScreen
  static const String _tokenKey = 'jwt_token';
  // static const String _mpinSetKey = 'mpin_set_local';

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ✅ Optional: store token after login (already done in LoginScreen, but kept for completeness)
  static Future<void> storeToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> _getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Set MPIN (first time)
  static Future<void> setMpin(String mpin) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/set-mpin'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'mpin': mpin}),
    );

    if (response.statusCode != 200) {
      final dynamic error = jsonDecode(response.body)['error'];
      throw Exception(error ?? 'Failed to set MPIN');
    }

    // Cache locally that MPIN is set
    // await _storage.write(key: _mpinSetKey, value: 'true');
  }

  // Verify MPIN
  static Future<bool> verifyMpin(String mpin) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/verify-mpin'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'mpin': mpin}),
    );

    if (response.statusCode == 200) return true;
    if (response.statusCode == 401) return false;
    throw Exception('Verification failed');
  }

  // Change MPIN
  static Future<void> changeMpin(String currentMpin, String newMpin) async {
    final token = await _getToken();
    if (token == null) throw Exception('User not authenticated');

    final response = await http.post(
      Uri.parse('$_baseUrl/api/auth/change-mpin'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'currentMpin': currentMpin,
        'newMpin': newMpin,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body)['error'] ?? 'Failed to change MPIN';
      throw Exception(error);
    }
  }

  // Check if MPIN is already set (uses local cache + optionally backend)
  static Future<bool> isMpinSet() async {
  final token = await _getToken();
  if (token == null) return false;
  final response = await http.get(
    Uri.parse('$_baseUrl/api/auth/mpin-status'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['mpinSet'] == true;
  }
  return false;
}

  // Clear local MPIN flags (call on logout)
  static Future<void> clearMpinStatus() async {
    // await _storage.delete(key: _mpinSetKey);
  }
}