// lib/services/auth_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:convert' as convert;

class AuthService {
  static const String _tokenKey = 'accessToken'; // Match your existing key
  static const String _tokenKeyAlt = 'token'; // Alternative key
  static const String _userIdKey = 'userId';
  static const String _userNameKey = 'name';
  static const String _userPhoneKey = 'phone';
  static const String _userEmailKey = 'email';
  static const String _userDataKey = 'user_data';

  // ─── Token Management ───────────────────────────────────────

  /// Save token (matches your existing implementation)
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    // Also save as 'token' for backward compatibility
    await prefs.setString(_tokenKeyAlt, token);
  }

  /// Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Try 'accessToken' first, then fallback to 'token'
    String? token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      token = prefs.getString(_tokenKeyAlt);
    }
    return token;
  }

  /// Check if user has a valid token
  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Check if token is expired (if it's a JWT)
  static Future<bool> isTokenExpired() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return true;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      // Decode the payload
      String normalized = parts[1];
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }

      final payload = json.decode(
        convert.utf8.decode(base64.decode(normalized))
      );

      final exp = payload['exp'] as int?;
      if (exp == null) return true;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      // If we can't decode, assume it's valid (or handle as needed)
      return false;
    }
  }

  /// Check if token is valid (exists and not expired)
  static Future<bool> hasValidToken() async {
    if (!await hasToken()) return false;
    return !await isTokenExpired();
  }

  /// Clear token (logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenKeyAlt);
  }

  // ─── User Data Management ───────────────────────────────────

  /// Save user data
  static Future<void> saveUserData({
    required String userId,
    required String name,
    required String phone,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userNameKey, name);
    await prefs.setString(_userPhoneKey, phone);
    if (email != null) {
      await prefs.setString(_userEmailKey, email);
    }
    // Save full user data as JSON
    final userData = {
      'id': userId,
      'name': name,
      'phone': phone,
      'email': email,
    };
    await prefs.setString(_userDataKey, json.encode(userData));
  }

  /// Get user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Get user name
  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  /// Get user phone
  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userPhoneKey);
  }

  /// Get user email
  static Future<String?> getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  /// Get full user data
  static Future<Map<String, dynamic>?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString(_userDataKey);
    if (dataStr != null) {
      return json.decode(dataStr) as Map<String, dynamic>;
    }
    return null;
  }

  /// Clear all user data (logout)
  static Future<void> clearAllUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_tokenKeyAlt);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userDataKey);
  }

  // ─── Login Helper ───────────────────────────────────────────

  /// Complete login - saves token and user data
  static Future<void> completeLogin({
    required String token,
    required String userId,
    required String name,
    required String phone,
    String? email,
  }) async {
    await saveToken(token);
    await saveUserData(
      userId: userId,
      name: name,
      phone: phone,
      email: email,
    );
  }

  /// Check if user is fully logged in
  static Future<bool> isLoggedIn() async {
    final hasToken = await hasValidToken();
    final userId = await getUserId();
    return hasToken && userId != null && userId.isNotEmpty;
  }

  /// Get auth headers for API calls
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    final userId = await getUserId();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (userId != null && userId.isNotEmpty) 'userId': userId,
    };
  }
}