// my_app/lib/services/AEPS/matm_service.dart

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class MatmService {
  static const MethodChannel _channel = MethodChannel('com.example.my_app/matm');

  // ── Replace with your real base URL or load from env ──────────────────────
  static const String _baseUrl = 'https://api.myneofyn.com';

  // ── Fetch merchantId from AEPS backend ────────────────────────────────────
  static Future<String> _fetchMerchantId(String phone) async {
    final uri = Uri.parse('$_baseUrl/api/aeps/merchant/by-phone?phone=$phone');
    final res = await http.get(uri, headers: {'Content-Type': 'application/json'});

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final id = body['merchantId'] ?? body['data']?['merchantId'];
      if (id == null || id.toString().isEmpty) {
        throw Exception('merchantId missing in response');
      }
      return id.toString();
    }
    throw Exception('Merchant fetch failed (${res.statusCode}): ${res.body}');
  }

  // ── Public API — called directly from UserHomeScreen ──────────────────────

  /// Called by _onMatmIconTap → Balance Enquiry tile
  static Future<Map<String, dynamic>> balanceEnquiry(String phone) async {
    try {
      final merchantId = await _fetchMerchantId(phone);
      final result = await _channel.invokeMethod<String>(
        'startBalanceEnquiry',
        {'merchantId': merchantId},
      );
      return {'success': true, 'data': result ?? ''};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message ?? 'MATM error'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Called by _doWithdrawal
  static Future<Map<String, dynamic>> cashWithdrawal(String phone, String amount) async {
    try {
      final merchantId = await _fetchMerchantId(phone);
      final result = await _channel.invokeMethod<String>(
        'startCashWithdrawal',
        {'merchantId': merchantId, 'amount': amount},
      );
      return {'success': true, 'data': result ?? ''};
    } on PlatformException catch (e) {
      return {'success': false, 'error': e.message ?? 'MATM error'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}