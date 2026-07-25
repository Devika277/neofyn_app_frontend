// lib/services/cardpay/cardpay_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../models/cardpay_models.dart';
import '../api_logger.dart';

class CardPayService {
  static final CardPayService _instance = CardPayService._internal();
  factory CardPayService() => _instance;
  CardPayService._internal();

  // ✅ Get auth token from SharedPreferences
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? prefs.getString('token') ?? '';
  }

  // ✅ Get userId from SharedPreferences (NOT from ApiConfig)
  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId') ?? '';
  }

  // ✅ Get auth headers with token and userId from SharedPreferences
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    final userId = await _getUserId();  // ✅ Dynamically fetched
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (userId.isNotEmpty) 'userId': userId,  // ✅ Added dynamically
    };
  }

  // ─── Core request method ───────────────────────────────────
  Future<Map<String, dynamic>> _request(
    String endpoint, {
    Map<String, dynamic>? body,
    bool isPost = true,
    Map<String, String>? customHeaders,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    Map<String, String> headers = await _getAuthHeaders();  // ✅ Gets userId dynamically
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    late http.Response response;
    try {
      if (isPost) {
        response = await LoggedHttpClient.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));
      } else {
        response = await LoggedHttpClient.get(
          url,
          headers: headers,
        ).timeout(const Duration(seconds: 30));
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || data['successStatus'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Operation failed');
        }
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ─── Public Routes (No Auth) ──────────────────────────────

  /// Handle CardPay webhook callback (Public endpoint)
  Future<Map<String, dynamic>> processCallback(Map<String, dynamic> callbackData) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.cardPayCallback}');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(callbackData),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': data['success'] ?? false,
          'message': data['message'] ?? 'Callback processed',
        };
      } else {
        throw Exception('Callback failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [CardPay] processCallback error: $e');
      rethrow;
    }
  }

  // ─── User Routes (Requires Auth) ──────────────────────────

// In cardpay_service.dart

/// Get list of states
// lib/services/cardpay/cardpay_service.dart

/// Get list of states
Future<List<String>> getStateList() async {
  try {
    debugPrint('📤 [CardPay] Getting states from: ${ApiConfig.cardPayStates}');
    final response = await _request(ApiConfig.cardPayStates, isPost: false);
    
    // Get the states data from response
    final statesData = response['states'];
    
    if (statesData == null) {
      debugPrint('⚠️ [CardPay] No states data found in response');
      return [];
    }
    
    debugPrint('📦 [CardPay] States data type: ${statesData.runtimeType}');
    debugPrint('📦 [CardPay] States data: $statesData');
    
    List<String> stateNames = [];
    
    // Case 1: If it's already a List<String>
    if (statesData is List<String>) {
      stateNames = statesData;
    }
    // Case 2: If it's a List<dynamic> (could be objects or strings)
    else if (statesData is List) {
      for (var item in statesData) {
        if (item is String) {
          stateNames.add(item);
        } else if (item is Map<String, dynamic>) {
          // Try to extract state name from object
          // Common field names for state name
          final name = item['name'] ?? 
                       item['state'] ?? 
                       item['stateName'] ?? 
                       item['state_name'] ?? 
                       item['value'] ?? 
                       item['label'] ??
                       item['text'];
          
          if (name is String && name.isNotEmpty) {
            stateNames.add(name);
          } else {
            // If we can't extract a name, add the object as string (fallback)
            debugPrint('⚠️ [CardPay] Could not extract state name from: $item');
            // Try to get the first value from the object
            if (item.isNotEmpty) {
              final firstValue = item.values.firstWhere(
                (v) => v is String && v.isNotEmpty,
                orElse: () => item.toString(),
              );
              if (firstValue is String) {
                stateNames.add(firstValue);
              }
            }
          }
        } else {
          // Fallback: convert to string
          stateNames.add(item.toString());
        }
      }
    }
    // Case 3: If it's a Map, try to extract state list from it
    else if (statesData is Map<String, dynamic>) {
      // Try common keys that might contain the state list
      final possibleKeys = ['states', 'stateList', 'data', 'list', 'items', 'results'];
      for (var key in possibleKeys) {
        if (statesData.containsKey(key)) {
          final value = statesData[key];
          if (value is List) {
            for (var item in value) {
              if (item is String) {
                stateNames.add(item);
              } else if (item is Map<String, dynamic>) {
                final name = item['name'] ?? 
                            item['state'] ?? 
                            item['stateName'] ?? 
                            item['state_name'] ??
                            item['value'] ??
                            item['label'];
                if (name is String && name.isNotEmpty) {
                  stateNames.add(name);
                }
              }
            }
            if (stateNames.isNotEmpty) break;
          }
        }
      }
    }
    
    // Remove duplicates and sort
    stateNames = stateNames.toSet().toList();
    stateNames.sort();
    
    debugPrint('✅ [CardPay] Extracted ${stateNames.length} states');
    return stateNames;
  } catch (e, stackTrace) {
    debugPrint('❌ [CardPay] getStateList error: $e');
    debugPrint('❌ [CardPay] Stack trace: $stackTrace');
    return [];
  }
}

  /// Initiate a card payment
  Future<CardPayInitiateResponse> initiatePayment(CardPayInitiateRequest request) async {
    try {
      final body = request.toJson();
      final response = await _request(
        ApiConfig.cardPayInitiate,
        body: body,
      );

      if (response['data'] != null) {
        return CardPayInitiateResponse.fromJson(response['data']);
      }
      throw Exception(response['message'] ?? 'Failed to initiate payment');
    } catch (e) {
      debugPrint('❌ [CardPay] initiatePayment error: $e');
      rethrow;
    }
  }

  /// Check transaction status by reference
  Future<CardPayTransaction> checkStatus(String ref) async {
    try {
      final response = await _request(
        '${ApiConfig.cardPayStatus}/$ref',
        isPost: false,
      );

      if (response['data'] != null) {
        return CardPayTransaction.fromJson(response['data']);
      }
      throw Exception(response['message'] ?? 'Transaction not found');
    } catch (e) {
      debugPrint('❌ [CardPay] checkStatus error: $e');
      rethrow;
    }
  }

  /// Get receipt for a transaction
  Future<Map<String, dynamic>> getReceipt(String ref) async {
    try {
      final response = await _request(
        '${ApiConfig.cardPayReceipt}/$ref',
        isPost: false,
      );
      return {
        'success': true,
        'receipt': response['receipt'],
        'message': response['message'] ?? 'Receipt retrieved',
      };
    } catch (e) {
      debugPrint('❌ [CardPay] getReceipt error: $e');
      rethrow;
    }
  }

  /// Get card pay wallet balance
  Future<double> getWalletBalance() async {
    try {
      final response = await _request(ApiConfig.cardPayWalletBalance, isPost: false);
      return (response['balance'] ?? 0.0).toDouble();
    } catch (e) {
      debugPrint('❌ [CardPay] getWalletBalance error: $e');
      rethrow;
    }
  }

  /// Get card pay wallet ledger
  Future<List<CardPayWalletLedger>> getCardPayLedger({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _request(
        '${ApiConfig.cardPayWalletLedger}?limit=$limit&offset=$offset',
        isPost: false,
      );

      final List<dynamic> entries = response['entries'] ?? [];
      return entries.map((e) => CardPayWalletLedger.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ [CardPay] getCardPayLedger error: $e');
      rethrow;
    }
  }

  /// Move funds from card pay wallet to main wallet
  Future<Map<String, dynamic>> moveToMain(double amount) async {
    try {
      final response = await _request(
        ApiConfig.cardPayMoveToMain,
        body: {'amount': amount},
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Funds moved successfully',
        'newCardPayBalance': (response['newCardPayBalance'] ?? 0.0).toDouble(),
        'newMainBalance': (response['newMainBalance'] ?? 0.0).toDouble(),
      };
    } catch (e) {
      debugPrint('❌ [CardPay] moveToMain error: $e');
      rethrow;
    }
  }

  /// Get user's card pay balance and main balance
  Future<CardPayUserBalance> getUserBalance() async {
    try {
      final response = await _request(ApiConfig.cardPayBalance, isPost: false);
      if (response['data'] != null) {
        return CardPayUserBalance.fromJson(response['data']);
      }
      throw Exception(response['message'] ?? 'Failed to get balance');
    } catch (e) {
      debugPrint('❌ [CardPay] getUserBalance error: $e');
      rethrow;
    }
  }

  // In cardpay_service.dart - getUserHistory method

Future<Map<String, dynamic>> getUserHistory({
  String? status,
  String? startDate,
  String? endDate,
  String? search,
  int limit = 20,
  int offset = 0,
}) async {
  try {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (status != null && status != 'all') queryParams['status'] = status;
    if (startDate != null) queryParams['startDate'] = startDate;
    if (endDate != null) queryParams['endDate'] = endDate;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final queryString = queryParams.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final endpoint = '${ApiConfig.cardPayHistory}?$queryString';
    debugPrint('📤 [CardPay] Getting history from: $endpoint');
    
    final response = await _request(endpoint, isPost: false);

    // Get transactions list - could be null or empty
    final transactionsData = response['transactions'] ?? [];
    final List<CardPayTransaction> transactions = [];
    
    if (transactionsData is List) {
      for (var item in transactionsData) {
        try {
          if (item is Map<String, dynamic>) {
            transactions.add(CardPayTransaction.fromJson(item));
          }
        } catch (e) {
          debugPrint('⚠️ [CardPay] Error parsing transaction: $e');
        }
      }
    }
    
    return {
      'success': true,
      'transactions': transactions,
      'total': response['total'] ?? transactions.length,
      'message': response['message'] ?? 'History retrieved',
    };
  } catch (e) {
    debugPrint('❌ [CardPay] getUserHistory error: $e');
    return {
      'success': false,
      'transactions': [],
      'total': 0,
      'message': 'Failed to get history',
    };
  }
}
  // ─── Admin Routes (Requires Admin Auth) ───────────────────

  /// Admin: Get dashboard data
  Future<CardPayDashboard> getDashboard() async {
    try {
      final response = await _request(ApiConfig.cardPayAdminDashboard, isPost: false);
      if (response['data'] != null) {
        return CardPayDashboard.fromJson(response['data']);
      }
      throw Exception(response['message'] ?? 'Failed to get dashboard');
    } catch (e) {
      debugPrint('❌ [CardPay] getDashboard error: $e');
      rethrow;
    }
  }

  /// Admin: Get all transactions with filters
  Future<Map<String, dynamic>> getAdminTransactions({
    String? status,
    String? search,
    String? startDate,
    String? endDate,
    String? userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (status != null) queryParams['status'] = status;
      if (search != null) queryParams['search'] = search;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (userId != null) queryParams['userId'] = userId;

      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _request(
        '${ApiConfig.cardPayAdminTransactions}?$queryString',
        isPost: false,
      );

      final List<dynamic> data = response['data'] ?? [];
      return {
        'success': true,
        'data': data.map((t) => CardPayTransaction.fromJson(t)).toList(),
        'pagination': response['pagination'],
        'message': response['message'] ?? 'Transactions retrieved',
      };
    } catch (e) {
      debugPrint('❌ [CardPay] getAdminTransactions error: $e');
      rethrow;
    }
  }

  /// Admin: Export report as CSV
  Future<String> exportReport({
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;

      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final headers = await _getAuthHeaders();
      final url = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.cardPayAdminExport}?$queryString',
      );

      final response = await LoggedHttpClient.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed to export report: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [CardPay] exportReport error: $e');
      rethrow;
    }
  }

  /// Admin: Get all user balances
  Future<List<Map<String, dynamic>>> adminGetAllUserBalances() async {
    try {
      final response = await _request(
        ApiConfig.cardPayAdminUsersBalances,
        isPost: false,
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('❌ [CardPay] adminGetAllUserBalances error: $e');
      rethrow;
    }
  }

  /// Admin: Get card pay ledger with filters
  Future<Map<String, dynamic>> adminGetCardPayLedger({
    int limit = 20,
    int offset = 0,
    String? startDate,
    String? endDate,
    String? searchTerm,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      if (searchTerm != null) queryParams['searchTerm'] = searchTerm;

      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _request(
        '${ApiConfig.cardPayAdminLedger}?$queryString',
        isPost: false,
      );

      final List<dynamic> data = response['data'] ?? [];
      return {
        'success': true,
        'data': data.map((l) => CardPayWalletLedger.fromJson(l)).toList(),
        'total': response['total'] ?? 0,
        'message': response['message'] ?? 'Ledger data retrieved',
      };
    } catch (e) {
      debugPrint('❌ [CardPay] adminGetCardPayLedger error: $e');
      rethrow;
    }
  }

  /// Admin: Get configuration
  Future<List<CardPayConfig>> getConfig() async {
    try {
      final response = await _request(ApiConfig.cardPayAdminConfig, isPost: false);
      final List<dynamic> data = response['data'] ?? [];
      return data.map((c) => CardPayConfig.fromJson(c)).toList();
    } catch (e) {
      debugPrint('❌ [CardPay] getConfig error: $e');
      rethrow;
    }
  }

  /// Admin: Update configuration
  Future<Map<String, dynamic>> updateConfig({
    required int id,
    required String keyValue,
  }) async {
    try {
      final response = await _request(
        ApiConfig.cardPayAdminConfig,
        body: {'id': id, 'keyValue': keyValue},
        isPost: false, // Using PUT internally via _request
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Configuration updated',
      };
    } catch (e) {
      debugPrint('❌ [CardPay] updateConfig error: $e');
      rethrow;
    }
  }

  // ─── Helper Methods ────────────────────────────────────────

  /// Validate email format
  static bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Validate amount
  static bool isValidAmount(double amount) {
    return amount > 0 && amount < 100000;
  }

  /// Validate coordinates
  static bool isValidCoordinates(String lat, String long) {
    try {
      final latDouble = double.parse(lat);
      final longDouble = double.parse(long);
      return latDouble >= -90 && latDouble <= 90 &&
          longDouble >= -180 && longDouble <= 180;
    } catch (_) {
      return false;
    }
  }
}