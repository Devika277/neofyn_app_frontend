import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:my_app/services/api_logger.dart';
import 'package:uuid/uuid.dart';
import '../../models/recharge_models.dart';
import '../BBPS/api_service.dart';

class RechargeService {
  static const _uuid = Uuid();

  static Future<RechargeResponse> processRecharge(
    RechargeRequest request,
  ) async {
    // Generate idempotency key if not provided
    final finalRequest = request.idempotencyKey == null
        ? RechargeRequest(
            mobile: request.mobile,
            operator: request.operator,
            serviceType: request.serviceType,
            amount: request.amount,
            idempotencyKey: _uuid.v4(),
          )
        : request;

    // Ensure all values are properly typed
    final jsonBody = finalRequest.toJson();

    // Make sure amount is a number, not string
    jsonBody['amount'] = finalRequest.amount.toDouble();

    print('📤 Sending recharge request: $jsonBody');

    final json = await ApiService.post('/api/recharge', jsonBody);
    return RechargeResponse.fromJson(json);
  }

  static Future<PlansResponse> getPlans(
  String operator, {
  String circle = 'ALL',
}) async {
  print('📡 Fetching plans: operator=$operator, circle=$circle');
  
  final json = await ApiService.get(
    '/api/recharge/plans',
    queryParams: {'operator': operator, 'circle': circle},
  );
  
  print('📡 Response received');
  print('📊 Response keys: ${json.keys}');
  print('📊 Success: ${json['success']}');
  
  if (json['plans'] is Map) {
    final plansMap = json['plans'] as Map;
    print('📊 Plans keys: ${plansMap.keys}');
    plansMap.forEach((key, value) {
      if (value is List) {
        print('📊 $key: ${value.length} plans');
        if (value.isNotEmpty) {
          print('📊 First $key plan: ${value[0]}');
        }
      }
    });
  }
  
  final response = PlansResponse.fromJson(json);
  print('📊 Parsed: ${response.plans.keys.length} categories, ${response.totalPlans} total plans');
  
  return response;
}

  static Future<HistoryResponse> getUserHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await ApiService.get(
      '/api/recharge/history',
      queryParams: {'limit': limit.toString(), 'offset': offset.toString()},
    );
    return HistoryResponse.fromJson(json);
  }

  // ✅ ADD THIS NEW METHOD
  static Future<Map<String, dynamic>> checkTransactionStatus(
    int transactionId,
  ) async {
    try {
      print('🔍 Checking transaction status: $transactionId');
      final json = await ApiService.get('/api/recharge/status/$transactionId');

      print('📥 Status response: $json');

      if (json['success'] == true) {
        // Extract operator reference ID from nested response
        String operatorRefId = '';
        String message = json['message'] ?? '';

        // Try to get operator reference from different possible paths in data
        if (json['data'] != null) {
          final data = json['data'];

          // Check various paths for operator reference
          if (data['operator_ref_id'] != null &&
              data['operator_ref_id'].toString().isNotEmpty) {
            operatorRefId = data['operator_ref_id'].toString();
          }

          // Get message from data if available
          if (data['message'] != null &&
              data['message'].toString().isNotEmpty) {
            message = data['message'].toString();
          }
        }

        return {
          'status': json['status'] ?? 'pending',
          'message': message,
          'operator_ref_id': operatorRefId,
        };
      }

      return {
        'status': 'pending',
        'message': 'Checking status...',
        'operator_ref_id': '',
      };
    } catch (e) {
      print('❌ Error checking transaction status: $e');
      return {
        'status': 'pending',
        'message': 'Unable to fetch status',
        'operator_ref_id': '',
      };
    }
  }
  // ───────────────────────────────────────────────────────────────
//  Get Recharge History
// ───────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getRechargeHistory({
    required String userId,
    required String token,
  }) async {
    try {
      final url = 'https://api.myneofyn.com/api/recharge/history?userId=$userId';

      debugPrint('┌──────────────────────────────────────────');
      debugPrint('│ 🔍 [Recharge] Fetching History');
      debugPrint('│ 📍 URL: $url');
      debugPrint('└──────────────────────────────────────────');

      final response = await LoggedHttpClient.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      debugPrint('📊 [Recharge] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('❌ [Recharge] History error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
}
