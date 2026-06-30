// lib/services/AEPS/api_service.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../models/aeps_models.dart';
import '../api_logger.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  AepsStateModel? selectedState;
  final String backendBaseUrl = 'https://api.myneofyn.com/api/aeps';

  String get userId => ApiConfig.userId;

  // ✅ Get auth token from SharedPreferences
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? prefs.getString('token') ?? '';
  }

  // ✅ Get auth headers with token
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      'userId': userId,
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

    // ✅ Always get auth headers
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
        return jsonDecode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // ─── Bank & Location APIs ──────────────────────────────────
  Future<List<Bank>> getBankList() async {
    final response = await _request(ApiConfig.aepsBanks, isPost: false);
    if (response['success'] == true) {
      final List<dynamic> data = response['data'] ?? [];
      return data.map((json) => Bank.fromJson(json)).toList();
    }
    throw Exception(response['message'] ?? 'Failed to fetch banks');
  }

  Future<List<AepsStateModel>> getStateList() async {
    final headers = await _getAuthHeaders();
    final response = await LoggedHttpClient.get(
      Uri.parse('$backendBaseUrl/states'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List<dynamic> stateList = body['data'] ?? [];
      return stateList.map((s) => AepsStateModel.fromJson(s)).toList();
    } else {
      throw Exception('Failed to load states');
    }
  }

  Future<List<District>> getDistrictList(String stateCode) async {
    final headers = await _getAuthHeaders();
    final response = await LoggedHttpClient.post(
      Uri.parse('$backendBaseUrl/districts'),
      headers: headers,
      body: json.encode({'stateCode': stateCode}),
    );
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List<dynamic> districtList = body['data'] ?? [];
      return districtList.map((d) => District.fromJson(d)).toList();
    } else {
      throw Exception('Failed to load districts');
    }
  }

  // ─── Merchant APIs ─────────────────────────────────────────
  // ─── Merchant APIs ─────────────────────────────────────────
  Future<Map<String, dynamic>> registerMerchant(MerchantRegistrationRequest request) async {
    print('═══════════════════════════════════════════════════════');
    print('📤 API SERVICE: registerMerchant');
    print('───────────────────────────────────────────────────────');

    final body = request.toJson();

    print('📤 Full request.toJson():');
    print(jsonEncode(body));
    print('📤 Pipe in toJson: ${body["pipe"]}');
    print('📤 Request object pipe property: ${request.pipe}');

    // ✅ CRITICAL: Force the pipe from the request object
    // This ensures the pipe from the registration screen is used
    if (request.pipe.isNotEmpty) {
      body['pipe'] = request.pipe;
      print('✅ Forced pipe to: ${request.pipe}');
    }

    print('📤 Final body pipe: ${body["pipe"]}');
    print('═══════════════════════════════════════════════════════');

    final response = await _request(
      ApiConfig.merchantRegister,
      body: body,
    );

    print('📥 Register response: ${jsonEncode(response)}');

    if (response['success'] == true) {
      return response['data'] ?? {};
    }
    throw Exception(response['message'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> sendOtp(String merchantId, String mobileNo) async {
    final response = await _request(
      ApiConfig.sendOtp,
      body: {'merchantId': merchantId, 'mobileNo': mobileNo},
    );
    if (response['success'] == true) {
      return response['data'] ?? {};
    }
    throw Exception(response['message'] ?? 'Failed to send OTP');
  }

  Future<Map<String, dynamic>> verifyOtp(String merchantId, String otp, String merchantRefId) async {
    final response = await _request(
      ApiConfig.verifyOtp,
      body: {'merchantId': merchantId, 'otp': otp, 'merchantRefId': merchantRefId},
    );
    if (response['success'] == true) {
      return response['data'] ?? {};
    }
    throw Exception(response['message'] ?? 'OTP verification failed');
  }

  // ─── 2FA ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> twoFactorAuth(
      String merchantId,
      String aadhaarNumber,
      String pidData,
      String deviceType,
      String merchantRefId,
      ) async {
    final response = await _request(
      ApiConfig.twoFA,
      body: {
        'merchantId': merchantId,
        'aadhaarNumber': aadhaarNumber,
        'pidData': pidData,
        'deviceType': deviceType,
        'merchantRefId': merchantRefId,
      },
    );
    if (response['success'] == true) {
      return response['data'] ?? {};
    }
    throw Exception(response['message'] ?? '2FA failed');
  }

  // ─── AEPS Transaction ──────────────────────────────────────
  Future<TransactionResponse> aepsTransaction(
      AepsTransactionRequest request, {
        required String token,
        required String userId,
      }) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'userId': userId,
    };

    final body = request.toJson();

    print('\n========== API CALL ==========');
    print('URL    : ${ApiConfig.baseUrl}${ApiConfig.aepsTransaction}');
    print('userId : $userId');
    print('token  : ${token.substring(0, 20)}...');
    print('==============================\n');

    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aepsTransaction}');

    final response = await LoggedHttpClient.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 60));

    print('📥 Status : ${response.statusCode}');
    print('📥 Body   : ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
      if (jsonResponse['success'] == true || jsonResponse['status'] != null) {
        return TransactionResponse.fromJson(jsonResponse);
      } else {
        throw Exception(jsonResponse['message'] ?? 'Transaction failed');
      }
    } else {
      throw Exception('Server error: ${response.statusCode} - ${response.body}');
    }
  }

  // ─── Transaction Status ────────────────────────────────────
  Future<Map<String, dynamic>> getTransactionStatus(String txnRefId, String merchantRefId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await LoggedHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/aeps/transaction/status'),
        headers: headers,
        body: jsonEncode({'txnRefId': txnRefId}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      debugPrint('getTransactionStatus error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ─── ✅ FIXED: Get AEPS History with Authorization ─────────
  /*Future<Map<String, dynamic>> getAepsHistory({
    int limit = 20,
    int offset = 0,
    String? status,
    String? type,
    String? from,
    String? to,
    String? pipe,
  }) async {
    try {
      // ✅ Get auth headers
      final headers = await _getAuthHeaders();

      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        'userId': userId,
      };

      // Add optional filters
      if (status != null) queryParams['status'] = status;
      if (type != null) queryParams['type'] = type;
      if (from != null) queryParams['from'] = from;
      if (to != null) queryParams['to'] = to;
      if (pipe != null) queryParams['pipe'] = pipe;

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/aeps/transactions')
          .replace(queryParameters: queryParams);

      print('📤 GET $uri');
      print('📤 Headers: ${headers.keys.toList()}');

      final response = await LoggedHttpClient.get(
        uri,
        headers: headers, // ✅ Auth headers included
      ).timeout(const Duration(seconds: 15));

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      return {
        'success': false,
        'message': 'HTTP ${response.statusCode}',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('getAepsHistory error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }*/
// ─── ✅ FIXED: Get AEPS History with Authorization ─────────
  Future<dynamic> getAepsHistory({  // 🔥 Changed return type to dynamic
    int limit = 20,
    int offset = 0,
    String? status,
    String? type,
    String? from,
    String? to,
    String? pipe,
  }) async {
    try {
      // ✅ Get auth headers
      final headers = await _getAuthHeaders();

      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
        'userId': userId,
      };

      // Add optional filters
      if (status != null) queryParams['status'] = status;
      if (type != null) queryParams['type'] = type;
      if (from != null) queryParams['from'] = from;
      if (to != null) queryParams['to'] = to;
      if (pipe != null) queryParams['pipe'] = pipe;

      final uri = Uri.parse('${ApiConfig.baseUrl}/api/aeps/transactions')
          .replace(queryParameters: queryParams);

      print('📤 GET $uri');
      print('📤 Headers: ${headers.keys.toList()}');

      final response = await LoggedHttpClient.get(
        uri,
        headers: headers, // ✅ Auth headers included
      ).timeout(const Duration(seconds: 15));

      print('📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // 🔥 FIX: Don't force-cast to Map - return raw decoded JSON
        final decoded = jsonDecode(response.body);

        // If it's a List, wrap it in a Map for consistent handling
        if (decoded is List) {
          print('📦 Response is a List with ${decoded.length} items');
          return {
            'success': true,
            'data': decoded,
          };
        }

        // If it's already a Map, return as-is
        if (decoded is Map<String, dynamic>) {
          print('📦 Response is a Map');
          return decoded;
        }

        // Fallback
        return {
          'success': false,
          'message': 'Unexpected response format',
        };
      }

      return {
        'success': false,
        'message': 'HTTP ${response.statusCode}',
        'body': response.body,
      };
    } catch (e) {
      debugPrint('getAepsHistory error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
  // ─── Get Merchant by Phone ─────────────────────────────────
  Future<Map<String, dynamic>> getMerchantByPhone(String phone) async {
    final headers = await _getAuthHeaders();
    final response = await LoggedHttpClient.get(
      Uri.parse('${ApiConfig.baseUrl}/api/aeps/merchant/by-phone?phone=$phone'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {'success': false};
  }

  static Future<void> clearUser() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('name');
    await prefs.remove('phone');
  }
  // ───────────────────────────────────────────────────────────────
//  BBPS - Check Onboarding Status
// ───────────────────────────────────────────────────────────────
  Future<bool> checkBBPSOnboardingStatus(String userId) async {
    try {
      final token = await _getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}/api/bbps/merchant/status/$userId');

      debugPrint('┌──────────────────────────────────────────');
      debugPrint('│ 🔍 [BBPS] Checking Onboarding Status');
      debugPrint('│ 📍 URL: $url');
      debugPrint('│ 👤 UserID: $userId');
      debugPrint('│ 🔑 Token: ${token.isNotEmpty ? token.substring(0, token.length > 20 ? 20 : token.length) + '...' : 'EMPTY'}');
      debugPrint('└──────────────────────────────────────────');

      final headers = await _getAuthHeaders();

      final response = await LoggedHttpClient.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 8));

      debugPrint('┌──────────────────────────────────────────');
      debugPrint('│ 📥 [BBPS] Response');
      debugPrint('│ 📊 Status: ${response.statusCode}');
      debugPrint('│ 📦 Body: ${response.body}');
      debugPrint('└──────────────────────────────────────────');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        bool isOnboarded = false;

        // ✅ FIXED: Check for "active" status and bbps_merchant_code
        if (data is Map && data['success'] == true) {
          final innerData = data['data'];
          if (innerData is Map) {
            // Merchant is onboarded if status is "active" OR bbps_merchant_code exists
            isOnboarded = innerData['status'] == 'active' ||
                (innerData['bbps_merchant_code'] != null &&
                    innerData['bbps_merchant_code'].toString().isNotEmpty);
          }
        }

        debugPrint('✅ [BBPS] Onboarded: $isOnboarded');
        return isOnboarded;
      } else {
        debugPrint('⚠️ [BBPS] Status: ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [BBPS] Error: $e');
      return false;
    }
  }
// ───────────────────────────────────────────────────────────────
//  Profile - Get Merchant Profile
// ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> getMerchantProfile(String userId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/aeps/merchant/profile/$userId');
      final headers = await _getAuthHeaders();

      debugPrint('┌──────────────────────────────────────────');
      debugPrint('│ 🔍 [Profile] Fetching Merchant Profile');
      debugPrint('│ 📍 URL: $url');
      debugPrint('│ 👤 UserID: $userId');
      debugPrint('└──────────────────────────────────────────');

      final response = await LoggedHttpClient.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      debugPrint('┌──────────────────────────────────────────');
      debugPrint('│ 📥 [Profile] Response');
      debugPrint('│ 📊 Status: ${response.statusCode}');
      debugPrint('│ 📦 Body: ${response.body}');
      debugPrint('└──────────────────────────────────────────');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['success'] == true) {
          return data['data'] as Map<String, dynamic>?;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ [Profile] Error: $e');
      return null;
    }
  }
}