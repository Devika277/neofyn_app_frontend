// lib/services/cardpay/card_pay_service.dart
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

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? prefs.getString('token') ?? '';
  }

  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId') ?? '';
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    final userId = await _getUserId();
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      if (userId.isNotEmpty) 'userId': userId,
    };
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, {
    Map<String, dynamic>? body,
    bool isPost = true,
    Map<String, String>? customHeaders,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    debugPrint('📤 [CardPay] Request: $endpoint');

    Map<String, String> headers = await _getAuthHeaders();
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
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ [CardPay] Request error: $e');
      rethrow;
    }
  }

  // ========== USER ROUTES ==========

// lib/services/cardpay/card_pay_service.dart

Future<List<String>> getStateList() async {
  try {
    final response = await _request(ApiConfig.cardPayStates, isPost: false);
    
    // Get the states data
    final statesData = response['states'] ?? response['data'];
    
    if (statesData == null) {
      debugPrint('⚠️ [CardPay] No states data found');
      return [];
    }

    List<String> stateNames = [];

    // Handle List response - states are objects with description and code
    if (statesData is List) {
      for (var item in statesData) {
        if (item is String) {
          stateNames.add(item);
        } else if (item is Map<String, dynamic>) {
          // Extract state name from object - try description first, then name, then state
          final name = item['description'] ?? 
                       item['name'] ?? 
                       item['state'] ?? 
                       item['stateName'] ?? 
                       item['state_name'] ??
                       item['value'] ??
                       item['label'];
          if (name is String && name.isNotEmpty) {
            stateNames.add(name);
          } else {
            // If no name found, try to get any string value
            for (var value in item.values) {
              if (value is String && value.isNotEmpty) {
                stateNames.add(value);
                break;
              }
            }
          }
        }
      }
    }
    // Handle Map response
    else if (statesData is Map<String, dynamic>) {
      final possibleKeys = ['states', 'stateList', 'list', 'data', 'items'];
      for (var key in possibleKeys) {
        if (statesData.containsKey(key)) {
          final value = statesData[key];
          if (value is List) {
            for (var item in value) {
              if (item is String) {
                stateNames.add(item);
              } else if (item is Map<String, dynamic>) {
                final name = item['description'] ?? item['name'] ?? item['state'] ?? item['value'];
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
  } catch (e) {
    debugPrint('❌ [CardPay] getStateList error: $e');
    return [];
  }
}

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

  Future<double> getWalletBalance() async {
    try {
      final response = await _request(ApiConfig.cardPayWalletBalance, isPost: false);
      return _parseDouble(response['balance']);
    } catch (e) {
      debugPrint('❌ [CardPay] getWalletBalance error: $e');
      return 0.0;
    }
  }

  Future<List<CardPayWalletLedger>> getCardPayLedger({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _request(
        '${ApiConfig.cardPayWalletLedger}?limit=$limit&offset=$offset',
        isPost: false,
      );

      final entries = response['entries'] ?? [];
      return entries.map((e) => CardPayWalletLedger.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ [CardPay] getCardPayLedger error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> moveToMain(double amount) async {
    try {
      final response = await _request(
        ApiConfig.cardPayMoveToMain,
        body: {'amount': amount},
      );

      return {
        'success': true,
        'message': response['message'] ?? 'Funds moved successfully',
        'newCardPayBalance': _parseDouble(response['newCardPayBalance']),
        'newMainBalance': _parseDouble(response['newMainBalance']),
      };
    } catch (e) {
      debugPrint('❌ [CardPay] moveToMain error: $e');
      rethrow;
    }
  }

  Future<CardPayUserBalance> getUserBalance() async {
    try {
      final response = await _request(ApiConfig.cardPayBalance, isPost: false);
      if (response['data'] != null) {
        return CardPayUserBalance.fromJson(response['data']);
      }
      throw Exception(response['message'] ?? 'Failed to get balance');
    } catch (e) {
      debugPrint('❌ [CardPay] getUserBalance error: $e');
      return CardPayUserBalance(balance: 0.0);
    }
  }

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
    final response = await _request(endpoint, isPost: false);

    // Get transactions list
    final transactionsData = response['transactions'] ?? [];
    
    // Convert to List<CardPayTransaction>
    final List<CardPayTransaction> transactions = [];
    if (transactionsData is List) {
      for (var item in transactionsData) {
        try {
          if (item is Map<String, dynamic>) {
            transactions.add(CardPayTransaction.fromJson(item));
          }
        } catch (e) {
          debugPrint('⚠️ [CardPay] Error parsing transaction: $e');
          // Continue with next item
        }
      }
    }
    
    return {
      'success': true,
      'transactions': transactions,  // Now properly typed
      'total': response['total'] ?? transactions.length,
      'message': response['message'] ?? 'History retrieved',
    };
  } catch (e) {
    debugPrint('❌ [CardPay] getUserHistory error: $e');
    return {
      'success': false,
      'transactions': <CardPayTransaction>[],  // Empty typed list
      'total': 0,
      'message': 'Failed to get history',
    };
  }
}

  // ========== ADMIN ROUTES ==========

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

      final data = response['data'] ?? [];
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
        throw Exception('Failed to export report');
      }
    } catch (e) {
      debugPrint('❌ [CardPay] exportReport error: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> adminGetAllUserBalances() async {
    try {
      final response = await _request(
        ApiConfig.cardPayAdminUsersBalances,
        isPost: false,
      );
      return List<Map<String, dynamic>>.from(response['data'] ?? []);
    } catch (e) {
      debugPrint('❌ [CardPay] adminGetAllUserBalances error: $e');
      return [];
    }
  }

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

      final data = response['data'] ?? [];
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

  Future<List<CardPayConfig>> getConfig() async {
    try {
      final response = await _request(ApiConfig.cardPayAdminConfig, isPost: false);
      final data = response['data'] ?? [];
      return data.map((c) => CardPayConfig.fromJson(c)).toList();
    } catch (e) {
      debugPrint('❌ [CardPay] getConfig error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> updateConfig({
    required int id,
    required String keyValue,
  }) async {
    try {
      final response = await _request(
        ApiConfig.cardPayAdminConfig,
        body: {'id': id, 'keyValue': keyValue},
        isPost: true,
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

  // ========== PUBLIC ROUTE ==========

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

  // ========== HELPER METHODS ==========

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  static bool isValidEmail(String email) {
    final RegExp emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidAmount(double amount) {
    return amount > 0 && amount < 100000;
  }
}