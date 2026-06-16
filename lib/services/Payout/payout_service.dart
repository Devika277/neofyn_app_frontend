// lib/services/payout_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/models/beneficiary_model.dart';
// import '../../config/api_config.dart';
import 'package:my_app/config/api_config.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_logger.dart';


class PayoutService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<String?> _getValidToken() async {
    String? token = await _storage.read(key: 'jwt_token');
    
    print('Raw token from storage: "$token"');
    
    if (token == null) {
      print('❌ No token found');
      return null;
    }
    
    // ✅ Clean the token
    token = token.trim();
    
    // Check if token is the string "null"
    if (token == 'null' || token.isEmpty) {
      print('❌ Token is "null" or empty');
      await _storage.delete(key: 'jwt_token');
      return null;
    }
    
    // Remove any quotes if present
    if (token.startsWith('"') && token.endsWith('"')) {
      token = token.substring(1, token.length - 1);
    }
    
    // Remove 'Bearer ' prefix if accidentally stored
    if (token.startsWith('Bearer ')) {
      token = token.substring(7);
    }
    
    print('✅ Cleaned token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    return token;
  }


  // Future<Map<String, dynamic>> getTransactionStatus(String merchantRefId) async {
  //     final token = await _getValidToken();
  //   final response = await http.get(
  //     Uri.parse('$baseUrl/api/payout/status/$merchantRefId'),
  //     headers: {'Authorization': 'Bearer $token'},
  //   );
  //   return jsonDecode(response.body);
  // }

  Future<String?> _getUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('userId');
}


  Future<Map<String, dynamic>> getBankList() async {
    try {
      final token = await _getValidToken();
      
      if (token == null) {
        throw Exception('No valid token found. Please login again.');
      }
      
      print('Making request with token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
      
      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.payoutBanks}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'ApiConfig.contentType',
        },
      );
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        // Token invalid - clear it
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Get banks error: $e');
      rethrow;
    }
  
}
  
  Future<Map<String, dynamic>> getPurposeList() async {
    final token = await _getValidToken();
    
    final response = await LoggedHttpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.payoutPurposes}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': ApiConfig.contentType,
      },
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load purposes: ${response.body}');
    }
  }
  
  Future<Map<String, dynamic>> getStateList() async {
    final token = await _getValidToken();
    
    final response = await LoggedHttpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.payoutStates}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': ApiConfig.contentType,
      },
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load states: ${response.body}');
    }
  }
  
  Future<Map<String, dynamic>> initiatePayout(Map<String, dynamic> payoutData) async {
    final token = await _getValidToken();
    
    final response = await LoggedHttpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.payoutInitiate}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': ApiConfig.contentType,
      },
      body: json.encode(payoutData),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Payout failed: ${response.body}');
    }
  }
  
// lib/services/Payout/payout_service.dart

Future<Map<String, dynamic>> getTransactionStatus(String merchantRefId) async {
  try {
    final token = await _getValidToken();
    
    if (token == null) {
      throw Exception('No valid token found. Please login again.');
    }
    
    print('Fetching status for merchantRefId: $merchantRefId');
    
    final response = await LoggedHttpClient.get(
      Uri.parse('${ApiConfig.baseUrl}/api/payout/status/$merchantRefId'), // ✅ includes ID in path
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json', // fixed from 'ApiConfig.contentType' (should be string)
      },
    );
    
    print('Status response status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 401) {
      // Token invalid - clear it
      await _storage.delete(key: 'jwt_token');
      throw Exception('Session expired. Please login again.');
    } else if (response.statusCode == 404) {
      // Transaction not found yet – return a placeholder instead of throwing
      return {
        'success': false,
        'message': 'Transaction not found (still processing)',
        'data': null
      };
    } else {
      throw Exception('Server error: ${response.statusCode}');
    }
  } catch (e) {
    print('Get transaction status error: $e');
    rethrow;
  }
}


Future<List<dynamic>> getTransactionHistory() async {
  try {
    final token = await _getValidToken();
    if (token == null) {
      throw Exception('No valid token found. Please login again.');
    }
    final response = await LoggedHttpClient.get(
      Uri.parse('${ApiConfig.baseUrl}/api/payout/history'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['data'] ?? [];
    } else if (response.statusCode == 401) {
      await _storage.delete(key: 'jwt_token');
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception('Failed to load history: ${response.statusCode}');
    }
  } catch (e) {
    print('Get history error: $e');
    rethrow;
  }
}
  
  // Future<Map<String, dynamic>> getBalance() async {
  //   final token = await _getValidToken();
    
  //   final response = await http.get(
  //     Uri.parse('${ApiConfig.baseUrl}${ApiConfig.payoutBalance}'),
  //     headers: {
  //       'Authorization': 'Bearer $token',
  //       'Content-Type': ApiConfig.contentType,
  //     },
  //   );
    
  //   if (response.statusCode == 200) {
  //     return json.decode(response.body);
  //   } else {
  //     throw Exception('Failed to get balance: ${response.body}');
  //   }
  // }



// Inside lib/services/payout_service.dart

Future<List<Beneficiary>> getBeneficiaries() async {
  final token = await _getValidToken();
  final userId = await _getUserId();
  
  if (userId == null) throw Exception('User not logged in');
  
  final response = await LoggedHttpClient.get(
    Uri.parse('${ApiConfig.baseUrl}/api/beneficiary/$userId'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body)['data'];
    return data.map((json) => Beneficiary.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load beneficiaries: ${response.statusCode} - ${response.body}');
  }
}

Future<Beneficiary> saveBeneficiary(Beneficiary beneficiary) async {
  final token = await _getValidToken();
  final userId = await _getUserId();

  if (userId == null) throw Exception('User not logged in');

  final body = {
    'userId': userId,
    'accountName': beneficiary.name,
    'accountNumber': beneficiary.accountNumber,
    'ifscCode': beneficiary.ifsc,
    'bankName': beneficiary.bankName,
    'bankCode': beneficiary.bankCode,
    'purposeCode': beneficiary.purposeCode,
    'purposeDesc': beneficiary.purposeDesc,
    'mobile': beneficiary.mobile,
    'state': beneficiary.stateCode,
    'stateName': beneficiary.stateName,
    'paymentMode': beneficiary.paymentMode,
    'upiId': null,
    'upiName': null,
  };

  // ← ADD THIS to see what's actually being sent
  print('=== SAVING BENEFICIARY ===');
  print('userId: $userId');
  print('bankCode: ${beneficiary.bankCode}');
  print('purposeCode: ${beneficiary.purposeCode}');
  print('mobile: ${beneficiary.mobile}');
  print('stateCode: ${beneficiary.stateCode}');
  print('stateName: ${beneficiary.stateName}');
  print('full body: ${json.encode(body)}');

  final response = await LoggedHttpClient.post(
    Uri.parse('${ApiConfig.baseUrl}/api/beneficiary'),
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: json.encode(body),
  );

  print('Save response: ${response.statusCode} - ${response.body}');

  if (response.statusCode == 200 || response.statusCode == 201) {
    final data = json.decode(response.body);
    return Beneficiary(
      id: data['id']?.toString(),
      name: beneficiary.name,
      accountNumber: beneficiary.accountNumber,
      ifsc: beneficiary.ifsc,
      mobile: beneficiary.mobile,
      bankCode: beneficiary.bankCode,
      bankName: beneficiary.bankName,
      purposeCode: beneficiary.purposeCode,
      purposeDesc: beneficiary.purposeDesc,
      stateCode: beneficiary.stateCode,
      stateName: beneficiary.stateName,
      paymentMode: beneficiary.paymentMode,
    );
  } else {
    final responseBody = json.decode(response.body);
    throw Exception('Failed to save beneficiary: ${response.statusCode} - ${responseBody['message'] ?? response.body}');
  }
}

Future<void> deleteBeneficiary(String id) async {
  final token = await _getValidToken();
  final response = await LoggedHttpClient.delete(
    Uri.parse('${ApiConfig.baseUrl}/api/beneficiary/$id'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to delete: ${response.statusCode} - ${response.body}');
  }
}

}