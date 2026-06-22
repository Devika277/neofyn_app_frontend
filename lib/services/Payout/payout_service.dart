// services/payout/payout_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/models/beneficiary_model.dart';
import 'package:my_app/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_logger.dart';

class PayoutService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  Future<String?> _getValidToken() async {
    String? token = await _storage.read(key: 'jwt_token');
    
    if (token == null) {
      print('❌ No token found');
      return null;
    }
    
    token = token.trim();
    
    if (token == 'null' || token.isEmpty) {
      print('❌ Token is "null" or empty');
      await _storage.delete(key: 'jwt_token');
      return null;
    }
    
    if (token.startsWith('"') && token.endsWith('"')) {
      token = token.substring(1, token.length - 1);
    }
    
    if (token.startsWith('Bearer ')) {
      token = token.substring(7);
    }
    
    print('✅ Cleaned token: ${token.substring(0, token.length > 20 ? 20 : token.length)}...');
    return token;
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // ✅ Get Bank List
  Future<Map<String, dynamic>> getBankList() async {
    try {
      final token = await _getValidToken();
      
      if (token == null) {
        throw Exception('No valid token found. Please login again.');
      }
      
      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/banks'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': ApiConfig.contentType,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['banks'] ?? data['data'] ?? data,
          'message': data['message'] ?? 'Success'
        };
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Get banks error: $e');
      rethrow;
    }
  }
  
  // ✅ Get State List
  Future<Map<String, dynamic>> getStateList() async {
    try {
      final token = await _getValidToken();
      
      if (token == null) {
        throw Exception('No valid token found. Please login again.');
      }
      
      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/states'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': ApiConfig.contentType,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['states'] ?? data['data'] ?? data,
          'message': data['message'] ?? 'Success'
        };
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load states: ${response.statusCode}');
      }
    } catch (e) {
      print('Get states error: $e');
      rethrow;
    }
  }
  
  // ✅ Get Beneficiaries
  Future<List<Beneficiary>> getBeneficiaries() async {
    try {
      final token = await _getValidToken();
      final userId = await _getUserId();
      
      if (userId == null) {
        print('⚠️ No userId found, returning empty list');
        return [];
      }
      if (token == null) {
        print('⚠️ No token found, returning empty list');
        return [];
      }
      
      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/beneficiaries?userId=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': ApiConfig.contentType,
        },
      );
      
      print('Get beneficiaries response status: ${response.statusCode}');
      print('Get beneficiaries response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['status'] == 'success') {
            final beneficiariesData = data['data'];
            if (beneficiariesData is List) {
              return beneficiariesData.map((json) => Beneficiary.fromJson(json)).toList();
            }
          }
        }
        return [];
      } else {
        return [];
      }
    } catch (e) {
      print('Get beneficiaries error: $e');
      return [];
    }
  }

  // ✅ Save Beneficiary - Local storage
  Future<Map<String, dynamic>?> saveBeneficiary(Beneficiary beneficiary) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBeneficiaries = prefs.getStringList('beneficiaries') ?? [];
      
      final beneJson = json.encode({
        'id': DateTime.now().millisecondsSinceEpoch,
        'name': beneficiary.name,
        'accountNumber': beneficiary.accountNumber,
        'ifsc': beneficiary.ifsc,
        'mobile': beneficiary.mobile,
        'bankCode': beneficiary.bankCode,
        'bankName': beneficiary.bankName,
        'stateCode': beneficiary.stateCode,
        'stateName': beneficiary.stateName,
        'paymentMode': beneficiary.paymentMode,
      });
      
      savedBeneficiaries.add(beneJson);
      await prefs.setStringList('beneficiaries', savedBeneficiaries);
      
      print('✅ Beneficiary saved locally');
      
      return {
        'status': 'success',
        'message': 'Beneficiary added successfully'
      };
      
    } catch (e) {
      print('❌ Save beneficiary error: $e');
      rethrow;
    }
  }

  // ✅ Delete Beneficiary - Local storage
  Future<void> deleteBeneficiary(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBeneficiaries = prefs.getStringList('beneficiaries') ?? [];
      
      final updatedList = savedBeneficiaries.where((jsonStr) {
        try {
          final data = json.decode(jsonStr);
          return data['id'].toString() != id;
        } catch (e) {
          return true;
        }
      }).toList();
      
      await prefs.setStringList('beneficiaries', updatedList);
      print('✅ Beneficiary deleted locally');
      
    } catch (e) {
      print('❌ Delete beneficiary error: $e');
      rethrow;
    }
  }

  // ✅ Get Local Beneficiaries
  Future<List<Beneficiary>> getLocalBeneficiaries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBeneficiaries = prefs.getStringList('beneficiaries') ?? [];
      
      print('📥 Found ${savedBeneficiaries.length} beneficiaries in local storage');
      
      return savedBeneficiaries.map((jsonStr) {
        try {
          final data = json.decode(jsonStr);
          return Beneficiary(
            id: data['id'] is int ? data['id'] : int.tryParse(data['id']?.toString() ?? ''),
            name: data['name'] ?? '',
            accountNumber: data['accountNumber'] ?? '',
            ifsc: data['ifsc'] ?? '',
            mobile: data['mobile'] ?? '',
            bankCode: data['bankCode'] ?? '',
            bankName: data['bankName'] ?? '',
            stateCode: data['stateCode'] ?? '',
            stateName: data['stateName'] ?? '',
            paymentMode: data['paymentMode'] ?? 'IMPS',
          );
        } catch (e) {
          print('⚠️ Error parsing beneficiary: $e');
          return Beneficiary(
            name: 'Error',
            accountNumber: '',
            ifsc: '',
            mobile: '',
            bankCode: '',
            bankName: '',
            stateCode: '',
            stateName: '',
          );
        }
      }).where((b) => b.name != 'Error').toList();
      
    } catch (e) {
      print('Get local beneficiaries error: $e');
      return [];
    }
  }

  // ✅ Initiate Payout - MATCHES BACKEND
  Future<Map<String, dynamic>> initiatePayout(Map<String, dynamic> payoutData) async {
    try {
      final token = await _getValidToken();
      
      if (token == null) {
        throw Exception('No valid token found. Please login again.');
      }
      
      final userId = await _getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      final requestData = Map<String, dynamic>.from(payoutData);
      requestData['userId'] = int.parse(userId);
      
      print('📤 Initiating payout with data: $requestData');
      
      final response = await LoggedHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/transfer'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': ApiConfig.contentType,
        },
        body: json.encode(requestData),
      );
      
      print('📥 Payout response status: ${response.statusCode}');
      print('📥 Payout response body: ${response.body}');
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Payout failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Payout error: $e');
      rethrow;
    }
  }
  
  // ✅ Get Transaction Status
  // ✅ Get Transaction Status - Use merchant_ref_id
Future<Map<String, dynamic>> getTransactionStatus(String merchantRefId) async {
  try {
    final token = await _getValidToken();
    
    if (token == null) {
      throw Exception('No valid token found. Please login again.');
    }
    
    print('Fetching status for merchantRefId: $merchantRefId');
    
    final response = await LoggedHttpClient.get(
      Uri.parse('${ApiConfig.baseUrl}/api/payout/status/$merchantRefId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': ApiConfig.contentType,
      },
    );
    
    print('Status response status: ${response.statusCode}');
    print('Status response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {
        'success': true,
        'data': data['data'] ?? data,
        'message': data['message'] ?? 'Success'
      };
    } else if (response.statusCode == 401) {
      await _storage.delete(key: 'jwt_token');
      throw Exception('Session expired. Please login again.');
    } else if (response.statusCode == 404) {
      // ✅ Check if transaction exists but not found - keep polling
      return {
        'success': false,
        'message': 'Transaction not found (still processing)',
        'data': null
      };
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Server error: ${response.statusCode}');
    }
  } catch (e) {
    print('Get transaction status error: $e');
    rethrow;
  }
}

  // ✅ Get Transaction History
  Future<List<dynamic>> getTransactionHistory() async {
    try {
      final token = await _getValidToken();
      if (token == null) {
        throw Exception('No valid token found. Please login again.');
      }
      
      final userId = await _getUserId();
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/transactions?userId=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': ApiConfig.contentType,
        },
      );
      
      print('History response status: ${response.statusCode}');
      print('History response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['data'] ?? data;
        } else {
          return data;
        }
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired. Please login again.');
      } else {
        final errorData = json.decode(response.body);
        throw Exception(errorData['message'] ?? 'Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      print('Get history error: $e');
      rethrow;
    }
  }
}