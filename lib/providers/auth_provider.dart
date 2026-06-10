// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';

class User {
  final bool tpinSet;
  User({required this.tpinSet});
}

class AuthProvider extends ChangeNotifier {
  User? _user;
  String? _accessToken;

  User? get user => _user;

  void setAccessToken(String token) {
    _accessToken = token;
    // store token securely (SharedPreferences / FlutterSecureStorage)
    notifyListeners();
  }

  Future<void> updateUser({required bool tpinSet}) async {
    _user = User(tpinSet: tpinSet);
    notifyListeners();
  }
}