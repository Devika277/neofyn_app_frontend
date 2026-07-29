// lib/services/cardpay/cardpay_out_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../models/cardpay_out_models.dart';
import '../api_logger.dart';

class CardPayOutService {
  static final CardPayOutService _instance = CardPayOutService._internal();
  factory CardPayOutService() => _instance;
  CardPayOutService._internal();

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
    bool isDelete = false,
    Map<String, String>? customHeaders,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    debugPrint('📤 [CardPayOut] Request: $endpoint');

    Map<String, String> headers = await _getAuthHeaders();
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    late http.Response response;
    try {
      if (isDelete) {
        response = await LoggedHttpClient.delete(
          url,
          headers: headers,
        ).timeout(const Duration(seconds: 30));
      } else if (isPost) {
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

      debugPrint('📥 [CardPayOut] Response status: ${response.statusCode}');
      
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
      debugPrint('❌ [CardPayOut] Request error: $e');
      rethrow;
    }
  }

  // ========== USER ROUTES ==========

  Future<List<CardPayOutBeneficiary>> getBeneficiaries() async {
    try {
      final response = await _request(ApiConfig.cardPayOutBeneficiaries, isPost: false);
      
      final data = response['data'];
      
      if (data == null) {
        return [];
      }
      
      if (data is List) {
        return data.map((e) => CardPayOutBeneficiary.fromJson(e)).toList();
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ [CardPayOut] getBeneficiaries error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> addBeneficiary(CardPayOutBeneficiaryRequest request) async {
    try {
      final response = await _request(
        ApiConfig.cardPayOutBeneficiaries,
        body: request.toJson(),
      );
      return {
        'success': true,
        'message': response['message'] ?? 'Beneficiary added successfully',
        'data': response['data'],
      };
    } catch (e) {
      debugPrint('❌ [CardPayOut] addBeneficiary error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteBeneficiary(int id) async {
    try {
      final response = await _request(
        '${ApiConfig.cardPayOutBeneficiaries}/$id',
        isPost: false,
        isDelete: true,
      );
      return {
        'success': true,
        'message': response['message'] ?? 'Beneficiary deleted successfully',
      };
    } catch (e) {
      debugPrint('❌ [CardPayOut] deleteBeneficiary error: $e');
      rethrow;
    }
  }

  Future<double> getBalance() async {
    try {
      final response = await _request(ApiConfig.cardPayOutBalance, isPost: false);
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return _parseDouble(data['balance']);
      }
      return 0.0;
    } catch (e) {
      debugPrint('❌ [CardPayOut] getBalance error: $e');
      return 0.0;
    }
  }

  Future<CardPayOutLimits> getLimits() async {
    try {
      final response = await _request(ApiConfig.cardPayOutLimits, isPost: false);
      if (response['data'] != null) {
        return CardPayOutLimits.fromJson(response['data']);
      }
      return CardPayOutLimits(
        dailyUsed: 0,
        dailyLimit: 100000,
        monthlyUsed: 0,
        monthlyLimit: 1000000,
      );
    } catch (e) {
      debugPrint('❌ [CardPayOut] getLimits error: $e');
      return CardPayOutLimits(
        dailyUsed: 0,
        dailyLimit: 100000,
        monthlyUsed: 0,
        monthlyLimit: 1000000,
      );
    }
  }

  Future<CardPayOutInitiateResponse> initiatePayout(CardPayOutInitiateRequest request) async {
    try {
      final response = await _request(
        ApiConfig.cardPayOutInitiate,
        body: request.toJson(),
      );
      
      if (response['data'] != null) {
        return CardPayOutInitiateResponse.fromJson(response['data']);
      }
      throw Exception(response['message'] ?? 'Failed to initiate payout');
    } catch (e) {
      debugPrint('❌ [CardPayOut] initiatePayout error: $e');
      rethrow;
    }
  }

  Future<CardPayOutStatus> getStatus(String ref) async {
    try {
      final response = await _request(
        '${ApiConfig.cardPayOutStatus}/$ref',
        isPost: false,
      );
      if (response['data'] != null) {
        return CardPayOutStatus.fromJson(response['data']);
      }
      throw Exception('Transaction not found');
    } catch (e) {
      debugPrint('❌ [CardPayOut] getStatus error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getReceipt(String ref) async {
    try {
      final response = await _request(
        '${ApiConfig.cardPayOutReceipt}/$ref',
        isPost: false,
      );
      return {
        'success': true,
        'receipt': response['data'],
        'message': response['message'] ?? 'Receipt retrieved',
      };
    } catch (e) {
      debugPrint('❌ [CardPayOut] getReceipt error: $e');
      rethrow;
    }
  }



  // ========== MASTER DATA ROUTES ==========

/// Get list of banks from payout provider
Future<List<Map<String, dynamic>>> getBanks() async {
  try {
    final response = await _request(ApiConfig.cardPayOutBanks, isPost: false);
    
    // Response format: { success: true, banks: [...] }
    final banks = response['banks'] ?? [];
    
    if (banks is List) {
      return banks.map((bank) {
        if (bank is Map<String, dynamic>) {
          return bank;
        }
        return {'name': bank.toString(), 'code': bank.toString()};
      }).toList();
    }
    return [];
  } catch (e) {
    debugPrint('❌ [CardPayOut] getBanks error: $e');
    return [];
  }
}

/// Get list of states from payout provider
Future<List<Map<String, dynamic>>> getStates() async {
  try {
    final response = await _request(ApiConfig.cardPayOutStates, isPost: false);
    
    // Response format: { success: true, states: [...] }
    final states = response['states'] ?? [];
    
    if (states is List) {
      return states.map((state) {
        if (state is Map<String, dynamic>) {
          return state;
        }
        return {'name': state.toString(), 'code': state.toString()};
      }).toList();
    }
    return [];
  } catch (e) {
    debugPrint('❌ [CardPayOut] getStates error: $e');
    return [];
  }
}

  Future<Map<String, dynamic>> getHistory({
    String? status,
    String? from,
    String? to,
  }) async {
    try {
      final queryParams = <String, String>{};
      
      if (status != null && status != 'all') queryParams['status'] = status;
      if (from != null) queryParams['from'] = from;
      if (to != null) queryParams['to'] = to;

      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final endpoint = queryString.isNotEmpty 
          ? '${ApiConfig.cardPayOutHistory}?$queryString'
          : ApiConfig.cardPayOutHistory;
          
      final response = await _request(endpoint, isPost: false);

      final data = response['data'] ?? [];
      final transactions = data is List 
          ? data.map((t) => CardPayOutTransaction.fromJson(t)).toList()
          : [];
      
      return {
        'success': true,
        'transactions': transactions,
        'message': response['message'] ?? 'History retrieved',
      };
    } catch (e) {
      debugPrint('❌ [CardPayOut] getHistory error: $e');
      return {
        'success': false,
        'transactions': <CardPayOutTransaction>[],
        'message': 'Failed to get history',
      };
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
}