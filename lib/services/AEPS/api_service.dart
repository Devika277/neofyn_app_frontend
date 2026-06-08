import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../models/aeps_models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  AepsStateModel? selectedState; // To store the user's choice
  
  // Base URL – consider moving to ApiConfig for consistency
  final String backendBaseUrl = 'https://neofyn-app-backend.onrender.com/api/aeps';

  // Get the userId from your AuthService (stored after login)
  String get userId => ApiConfig.userId;

  // ------------------------------------------------------------------------
  // Core request method (supports custom headers for specific calls)
  // ------------------------------------------------------------------------
  Future<Map<String, dynamic>> _request(
    String endpoint, {
    Map<String, dynamic>? body,
    bool isPost = true,
    Map<String, String>? customHeaders,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    Map<String, String> headers = {
      'Content-Type': ApiConfig.contentType,
    };
    // Add custom headers if provided (e.g., token, userId)
    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    
    late http.Response response;
    try {
      if (isPost) {
        response = await http.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 30));
      } else {
        response = await http.get(
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

  // Default headers for calls that need userId (without bearer token)
  Map<String, String> _defaultHeaders() {
    return {
      'Content-Type': 'application/json',
      'userId': userId,
    };
  }

  static Future<void> clearUser() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('name');
    await prefs.remove('phone');
    // Add any other user-related keys you store
  }

  // 1. Get Bank List
  Future<List<Bank>> getBankList() async {
    final response = await _request(ApiConfig.aepsBanks, isPost: false);
    if (response['success'] == true) {
      final List<dynamic> data = response['data'] ?? [];
      return data.map((json) => Bank.fromJson(json)).toList();
    }
    throw Exception(response['message'] ?? 'Failed to fetch banks');
  }
  
  // 2. Get State List
  Future<List<AepsStateModel>> getStateList() async {
    final response = await http.get(
      Uri.parse('$backendBaseUrl/states'),
      headers: _defaultHeaders(),
    );
    if (response.statusCode == 200) {
      final body = json.decode(response.body);
      final List<dynamic> stateList = body['data'] ?? [];
      return stateList.map((s) => AepsStateModel.fromJson(s)).toList();
    } else {
      throw Exception('Failed to load states');
    }
  }

  // 3. Get District List
  Future<List<District>> getDistrictList(String stateCode) async {
    final response = await http.post(
      Uri.parse('$backendBaseUrl/districts'),
      headers: _defaultHeaders(),
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
  
  // 4. Register Merchant
  Future<Map<String, dynamic>> registerMerchant(MerchantRegistrationRequest request) async {
    final response = await _request(
      ApiConfig.merchantRegister,
      body: request.toJson(),
    );
    if (response['success'] == true) {
      return response['data'] ?? {};
    }
    throw Exception(response['message'] ?? 'Registration failed');
  }
  
  // 5. Send OTP
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
  
  // 6. Verify OTP
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
  
  // 7. 2FA Authentication (unchanged)
  Future<Map<String, dynamic>> twoFactorAuth(
    String merchantId,
    String aadhaarNumber,
    String pidData,
    String deviceType,
    String merchantRefId,  // fixed parameter name
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
  
  // 8. AEPS Transaction (UPDATED: accepts token and userId headers)
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

  final body = request.toJson();  // ← already has debug print inside

  print('\n========== API CALL ==========');
  print('URL    : ${ApiConfig.baseUrl}${ApiConfig.aepsTransaction}');
  print('userId : $userId');
  print('token  : ${token.substring(0, 20)}...');
  print('body   : ${jsonEncode(body)}');
  print('==============================\n');

  final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.aepsTransaction}');

  final response = await http.post(
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
  
  // 9. Transaction Status (unchanged)
  // Future<Map<String, dynamic>> getTransactionStatus(String merchantId, String merchantRefId) async {
  //   final response = await _request(
  //     ApiConfig.transactionStatus,
  //     body: {'merchantId': merchantId, 'merchantRefId': merchantRefId},
  //   );
  //   if (response['success'] == true) {
  //     return response['data'] ?? {};
  //   }
  //   throw Exception(response['message'] ?? 'Failed to get status');
  // }

// ── 1. Get transaction status by reference ID ─────────────────────────────────
// Calls: POST /api/aeps/transaction/status
Future<Map<String, dynamic>> getTransactionStatus(String txnRefId, String merchantRefId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken') ?? '';
 
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/aeps/transaction/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
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
 
// ── 2. Get AEPS transaction history ──────────────────────────────────────────
// Calls: GET /api/aeps/history?limit=20&offset=0
//
// If your backend uses a different endpoint, update the URL below.
Future<Map<String, dynamic>> getAepsHistory({int limit = 20, int offset = 0}) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Get userId as String (supports both int and string storage)
    String? userId = prefs.getString('userId');
    if (userId == null) {
      final intId = prefs.getInt('userId');
      if (intId != null) userId = intId.toString();
    }

    if (userId == null) {
      return {'success': false, 'message': 'User not logged in'};
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/aeps/history')
        .replace(queryParameters: {
      'limit': limit.toString(),
      'offset': offset.toString(),
      'userId': userId,                 // ✅ send as string
    });

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        // ❌ No Authorization header (backend doesn't require JWT for history)
      },
    ).timeout(const Duration(seconds: 15));

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
}

Future<Map<String, dynamic>> getMerchantByPhone(String phone) async {
  final response = await http.get(
    Uri.parse('${ApiConfig.baseUrl}/api/aeps/merchant/by-phone?phone=$phone'),
    headers: {'Content-Type': 'application/json'},
  );
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  }
  return {'success': false};
}


}