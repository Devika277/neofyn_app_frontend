// lib/providers/bank_provider.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/bank_account.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';

class BankProvider extends ChangeNotifier {
  List<BankAccount> _banks = [];
  bool _isLoading = false;
  String? _error;

  List<BankAccount> get banks => _banks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchBanks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if user is logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      if (!isLoggedIn) {
        _error = 'Please login to view banks';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get token from AuthService
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();

      if (token == null || token.isEmpty) {
        _error = 'Authentication required. Please login again.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.banks}');
      print('🟡 Fetching banks from: $url');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          if (userId != null) 'userId': userId,
        },
      );

      print('🔵 Bank API Response Status: ${response.statusCode}');
      print('🔵 Bank API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          _banks = (data['data'] as List)
              .map((json) => BankAccount.fromJson(json))
              .toList();
          _error = null;
          print('✅ Banks loaded: ${_banks.length}');
        } else {
          _error = data['error'] ?? data['message'] ?? 'Failed to load banks';
          _banks = _getFallbackBanks();
        }
      } else if (response.statusCode == 401) {
        // Token expired or invalid - clear it
        await AuthService.clearAllUserData();
        _error = 'Session expired. Please login again.';
        _banks = [];
        // Notify listeners to show login
        notifyListeners();
        return;
      } else {
        _error = 'Failed to load banks: ${response.statusCode}';
        _banks = _getFallbackBanks();
      }
    } catch (e) {
      print('❌ Error fetching banks: $e');
      _error = 'Error loading banks: $e';
      _banks = _getFallbackBanks();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Fallback banks in case API fails
  List<BankAccount> _getFallbackBanks() {
    return [
      BankAccount(
        id: '1',
        name: 'HDFC Bank',
        accountNumber: '50200119405733',
        ifsc: 'HDFC0001552',
        accountName: 'Neofyn Bharath Private Limited',
        accountType: 'Current Account',
        isActive: true,
      ),
      BankAccount(
        id: '2',
        name: 'Axis Bank',
        accountNumber: '925020049386006',
        ifsc: 'UTIB0001765',
        accountName: 'Neofyn Bharath Private Limited',
        accountType: 'Current Account',
        isActive: true,
      ),
      BankAccount(
        id: '3',
        name: 'IDFC First Bank',
        accountNumber: '10274584545',
        ifsc: 'IDFB0080551',
        accountName: 'Neofyn Bharath Private Limited',
        accountType: 'Current Account',
        isActive: true,
      ),
    ];
  }

  void reset() {
    _banks = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // Update user's banks after login
  Future<void> refreshBanks() async {
    await fetchBanks();
  }
}