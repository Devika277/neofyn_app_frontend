// lib/services/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/services/api_logger.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Base URL – change to your actual backend URL
  static const String _baseUrl = 'https://api.myneofyn.com';

  // ========== EXISTING MERCHANT METHODS ==========

  Future<void> saveMerchantData({
    required String merchantId,
    required String merchantRefId,
    required String mobileNo,
    String? aadhaarNo, String? pipe,
  }) async {
    await _storage.write(key: 'merchant_id', value: merchantId);
    await _storage.write(key: 'merchant_ref_id', value: merchantRefId);
    await _storage.write(key: 'mobile_no', value: mobileNo);
    if (aadhaarNo != null) {
      await _storage.write(key: 'aadhaar_no', value: aadhaarNo);
    }
  }

  Future<Map<String, String?>> getMerchantData() async {
    return {
      'merchantId': await _storage.read(key: 'merchant_id'),
      'merchantRefId': await _storage.read(key: 'merchant_ref_id'),
      'mobileNo': await _storage.read(key: 'mobile_no'),
      'aadhaarNo': await _storage.read(key: 'aadhaar_no'),
    };
  }

  Future<void> clearMerchantData() async {
    await _storage.delete(key: 'merchant_id');
    await _storage.delete(key: 'merchant_ref_id');
    await _storage.delete(key: 'mobile_no');
    await _storage.delete(key: 'aadhaar_no');
    await clearAccessToken();
  }

  Future<bool> isMerchantRegistered() async {
    final merchantId = await _storage.read(key: 'merchant_id');
    return merchantId != null && merchantId.isNotEmpty;
  }

  // ========== ACCESS TOKEN MANAGEMENT (COMPATIBLE WITH LOGIN SCREEN) ==========

  /// Saves the access token under both keys for full compatibility.
  /// - 'access_token' is the preferred key (used by AuthService).
  /// - 'jwt_token' is the legacy key used by the old login screen.
  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: 'access_token', value: token);
    await _storage.write(key: 'jwt_token', value: token);   // legacy compatibility
  }

  /// Retrieves the access token.
  /// First tries 'access_token'; if missing, falls back to 'jwt_token'
  /// and automatically migrates it to 'access_token'.
  Future<String?> getAccessToken() async {
    String? token = await _storage.read(key: 'access_token');
    if (token == null) {
      token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        // Migrate legacy token to the new key
        await _storage.write(key: 'access_token', value: token);
      }
    }
    return token;
  }

  /// Clears the token from both storage keys.
  Future<void> clearAccessToken() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'jwt_token');
  }

  // Helper: get headers with Authorization
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await getAccessToken();
    print('🔑 AuthService - Token present: ${token != null}');
    if (token != null) {
      print('🔑 Token (first 10 chars): ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Helper: parse error response
  String _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['error'] ?? data['message'] ?? 'Something went wrong';
    } catch (_) {
      return 'Server error (${response.statusCode})';
    }
  }

  // ========== TPIN METHODS ==========

  /// Set TPIN for first time
  Future<String?> setTpin(String newTpin) async {
    final url = Uri.parse('$_baseUrl/api/auth/set-tpin');
    final headers = await _getAuthHeaders();

    final response = await LoggedHttpClient.post(
      url,
      headers: headers,
      body: jsonEncode({'newTpin': newTpin}),
    );

    if (response.statusCode != 200) {
      throw _parseError(response);
    }

    final data = jsonDecode(response.body);
    final newToken = data['accessToken'] as String?;
    if (newToken != null) {
      await saveAccessToken(newToken);
    }
    return newToken;
  }

  /// Change existing TPIN (requires current TPIN)
  Future<void> changeTpin(String currentTpin, String newTpin) async {
    final url = Uri.parse('$_baseUrl/api/auth/change-tpin');
    final headers = await _getAuthHeaders();

    final response = await LoggedHttpClient.post(
      url,
      headers: headers,
      body: jsonEncode({
        'currentTpin': currentTpin,
        'newTpin': newTpin,
      }),
    );

    if (response.statusCode != 200) {
      throw _parseError(response);
    }
    final data = jsonDecode(response.body);
    final newToken = data['accessToken'] as String?;
    if (newToken != null) {
      await saveAccessToken(newToken);
    }
  }

  /// Verify TPIN before sensitive transactions
  Future<bool> verifyTpin(String tpin) async {
    final url = Uri.parse('$_baseUrl/api/auth/verify-tpin');
    final headers = await _getAuthHeaders();

    final response = await LoggedHttpClient.post(
      url,
      headers: headers,
      body: jsonEncode({'tpin': tpin}),
    );

    if (response.statusCode != 200) {
      throw _parseError(response);
    }

    final data = jsonDecode(response.body);
    return data['valid'] == true;
  }
}