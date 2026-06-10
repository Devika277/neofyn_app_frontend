import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();
  static const _loginTimeKey = 'login_timestamp';
  static const _isLoggedInKey = 'is_logged_in';
  static const _tokenKey = 'jwt_token';
  static const _userIdKey = 'user_id';
  static const _lastActiveKey = 'last_active_time';

  // Save login session
  static Future<void> saveLoginSession(String token, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _storage.write(key: _tokenKey, value: token);
    await prefs.setString(_userIdKey, userId);
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setInt(_loginTimeKey, now);
    await prefs.setInt(_lastActiveKey, now);
  }

  // Update last active time (called when app resumes)
  static Future<void> updateLastActiveTime() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_lastActiveKey, now);
  }

  // Check if session is valid (within 24 hours)
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!isLoggedIn) return false;

    final loginTime = prefs.getInt(_loginTimeKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final twentyFourHours = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

    return (now - loginTime) < twentyFourHours;
  }

  // Check if user needs MPIN re-verification (after 5 minutes idle)
  static Future<bool> needsMpinVerification() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    if (!isLoggedIn) return false;

    final lastActive = prefs.getInt(_lastActiveKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final fiveMinutes = 5 * 60 * 1000; // 5 minutes in milliseconds

    return (now - lastActive) > fiveMinutes;
  }

  // Get saved token
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Get saved user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await _storage.delete(key: _tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_loginTimeKey);
    await prefs.remove(_lastActiveKey);
  }
}
