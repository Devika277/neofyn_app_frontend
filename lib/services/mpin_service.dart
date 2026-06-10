// lib/services/mpin_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MpinService {
  static const String _baseUrl = 'https://neofyn-app-backend.onrender.com'; // Replace with your backend URL
  static const String _tokenKey = 'access_token';
  static const String _mpinSetKey = 'mpin_set_local'; // optional local cache

  static final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Get stored JWT token
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
      final error = jsonDecode(response.body)['error'] ?? 'Failed to set MPIN';
      throw Exception(error);
    }

    // Optionally cache that MPIN is set locally
    await _storage.write(key: _mpinSetKey, value: 'true');
  }

  // Verify MPIN (e.g., during login or before sensitive action)
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

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 401) {
      return false; // invalid MPIN
    } else {
      throw Exception('Verification failed');
    }
  }

  // Change MPIN (requires current MPIN)
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

  // Check if MPIN is already set (calls backend or uses local cache)
  static Future<bool> isMpinSet() async {
    // First check local cache for speed
    final local = await _storage.read(key: _mpinSetKey);
    if (local == 'true') return true;

    // Otherwise verify with backend (if needed)
    final token = await _getToken();
    if (token == null) return false;

    // You could add a dedicated endpoint like /api/auth/mpin-status
    // For now, return false and let the user attempt setMpin
    return false;
  }

  // Clear local MPIN flags (call on logout)
  static Future<void> clearMpinStatus() async {
    await _storage.delete(key: _mpinSetKey);
  }
}