// services/commission/commission_service.dart

import 'dart:convert';

import '../../services/bbps/api_service.dart';

class CommissionService {
  // ✅ Hardcoded min transfer amount (matches backend default)
  static const double MIN_TRANSFER_AMOUNT = 100.0;

  // ✅ Helper function to parse amount from string or number
  static double parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    if (value is bool) {
      return value ? 1.0 : 0.0;
    }
    return 0.0;
  }

  // ────────────────────────────────────────────────────────────
  // GET HISTORY
  // ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getHistory({
    required int page,
    int limit = 20,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      print('🔍 Fetching commission history: page=$page, limit=$limit, status=$status');

      final response = await ApiService.get(
        '/api/commission/history',
        queryParams: queryParams,
      );

      print('✅ Commission history fetched successfully');
      const encoder = JsonEncoder.withIndent('  ');

      print('================ RAW HISTORY RESPONSE ================');
      print(encoder.convert(response));
      print('=====================================================');
      if (response['success'] == true && response['data'] != null) {
        final List<dynamic> rawData = response['data'];
        final List<Map<String, dynamic>> mappedData = rawData.map((item) {
          final Map<String, dynamic> data = item is Map 
              ? Map<String, dynamic>.from(item) 
              : <String, dynamic>{};
          
          return {
            'id': data['id'] ?? 0,
            'user_id': data['user_id'] ?? 0,
            'type': data['type']?.toString() ?? 
                    data['service_type']?.toString() ?? 
                    'unknown',
            'amount': parseAmount(data['txn_amount'] ?? data['amount'] ?? 0),
            'commission_amount': parseAmount(data['commission_amount'] ?? 0),
            'commission_rate': parseAmount(data['commission_rate'] ?? 0),
            'status': data['status']?.toString() ?? 'pending',
            'description': data['description']?.toString() ?? 
                           data['transaction_ref']?.toString() ?? '',
            'reference_id': data['reference_id']?.toString() ?? 
                            data['transaction_ref']?.toString() ?? '',
            'balance_after': parseAmount(data['balance_after'] ?? 0),
            'created_at': data['created_at']?.toString() ?? 
                          DateTime.now().toIso8601String(),
            'updated_at': data['updated_at']?.toString() ?? 
                          DateTime.now().toIso8601String(),
          };
        }).toList();
        
        print('📊 Mapped ${mappedData.length} items successfully');
        
        return {
          'success': true,
          'data': mappedData,
          'pagination': response['pagination'],
        };
      }
      
      return response;
    } catch (e) {
      print('❌ Failed to fetch commission history: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────
  // GET BALANCE
  // ────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getBalance() async {
    try {
      print('🔍 Fetching commission balance from API...');
      final response = await ApiService.get('/api/commission/balance');
      print('📥 Raw commission balance response: $response');
      
      if (response['success'] == true) {
        final data = response['data'] ?? {};
        
        final balance = parseAmount(data['balance']);
        final frozen = parseAmount(data['frozen']);
        
        print('💰 Parsed Balance: $balance, Frozen: $frozen');
        
        return {
          'success': true,
          'data': {
            'balance': balance,
            'frozen': frozen,
          }
        };
      } else {
        print('❌ API returned error: ${response['message']}');
        return response;
      }
    } catch (e) {
      print('❌ Failed to fetch commission balance: $e');
      rethrow;
    }
  }

  // ────────────────────────────────────────────────────────────
  // TRANSFER TO MAIN WALLET
  // ────────────────────────────────────────────────────────────

// services/commission/commission_service.dart

static Future<Map<String, dynamic>> transferToMain(double amount) async {
  try {
    print('🔍 ===== TRANSFER DEBUG =====');
    print('🔍 Amount: ₹$amount');
    
    // ✅ Explicitly check token
    final token = await ApiService.getToken();
    print('🔑 Token: ${token != null ? "✅ Present (${token.substring(0, 10)}...)" : "❌ MISSING"}');
    
    if (token == null) {
      throw Exception('No authentication token found. Please login again.');
    }
    
    print('🔍 Making POST request to /api/commission/transfer');
    print('📤 Request body: {"amount": $amount}');
    
    final response = await ApiService.post(
      '/api/commission/transfer',
      {'amount': amount},
    );
    
    print('✅ Transfer response: $response');
    print('🔍 ===== TRANSFER DEBUG END =====');
    return response;
  } catch (e) {
    print('❌ Transfer failed: $e');
    rethrow;
  }
}
  // ────────────────────────────────────────────────────────────
  // GET MIN TRANSFER AMOUNT - NO API CALL NEEDED
  // ────────────────────────────────────────────────────────────
  static Future<double> getMinTransferAmount() async {
    // ✅ Return hardcoded value - no API call to admin endpoint
    print('💰 Min transfer amount: ${MIN_TRANSFER_AMOUNT}');
    return MIN_TRANSFER_AMOUNT;
  }
}