import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/models/beneficiary_model.dart';
import 'package:my_app/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_logger.dart';

class PayoutService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> _getValidToken() async {
    String? token = await _storage.read(key: 'jwt_token');
    if (token == null) return null;
    token = token.trim();
    if (token == 'null' || token.isEmpty) {
      await _storage.delete(key: 'jwt_token');
      return null;
    }
    if (token.startsWith('"') && token.endsWith('"')) {
      token = token.substring(1, token.length - 1);
    }
    if (token.startsWith('Bearer ')) {
      token = token.substring(7);
    }
    return token;
  }

  Future<String?> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId');
  }

  // Get Bank List
  Future<Map<String, dynamic>> getBankList() async {
    try {
      final token = await _getValidToken();
      if (token == null) throw Exception('No valid token found');

      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/banks'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': ApiConfig.contentType},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['banks'] ?? data['data'] ?? data};
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired');
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Get banks error: $e');
      rethrow;
    }
  }

  // Get State List
  Future<Map<String, dynamic>> getStateList() async {
    try {
      final token = await _getValidToken();
      if (token == null) throw Exception('No valid token found');

      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/states'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': ApiConfig.contentType},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['states'] ?? data['data'] ?? data};
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired');
      } else {
        throw Exception('Failed to load states: ${response.statusCode}');
      }
    } catch (e) {
      print('Get states error: $e');
      rethrow;
    }
  }

  // Get Beneficiaries
  Future<List<Beneficiary>> getBeneficiaries() async {
    try {
      final token = await _getValidToken();
      final userId = await _getUserId();
      if (userId == null || token == null) return [];

      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/beneficiaries?userId=$userId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': ApiConfig.contentType},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          final list = data['data'];
          if (list is List) return list.map((j) => Beneficiary.fromJson(j)).toList();
        }
        return [];
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired');
      }
      return [];
    } catch (e) {
      print('Get beneficiaries error: $e');
      return [];
    }
  }

  // Save Beneficiary
  Future<Map<String, dynamic>?> saveBeneficiary(Beneficiary beneficiary) async {
    try {
      final token = await _getValidToken();
      final userId = await _getUserId();
      if (userId == null || token == null) throw Exception('Not logged in');

      final body = {
        'userId': int.parse(userId),
        'phone': beneficiary.mobile,
        'beneData': {
          'account_name': beneficiary.name,
          'account_number': beneficiary.accountNumber,
          'ifsc_code': beneficiary.ifsc.toUpperCase(),
          'bank_code': beneficiary.bankCode,
          'bank_name': beneficiary.bankName,
          'state_code': beneficiary.stateCode,
          'payment_mode': beneficiary.paymentMode,
          'mobile': beneficiary.mobile,
        }
      };

      final response = await LoggedHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/beneficiary/add'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': ApiConfig.contentType},
        body: json.encode(body),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        if (data['status'] == 'success') return data;
        // Handle case where status is not success even with 200
        throw Exception(data['message'] ?? 'Failed to add beneficiary');
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired. Please login again.');
      } else {
        // Handle all other error status codes (400, 500, etc.)
        final errorMessage = data['message'] ?? 'Failed to add beneficiary';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Save beneficiary error: $e');
      rethrow; // Re-throw so UI layer can handle it properly
    }
  }

  // Delete Beneficiary
  Future<void> deleteBeneficiary(String id) async {
    try {
      final token = await _getValidToken();
      final userId = await _getUserId();
      if (userId == null || token == null) throw Exception('Not logged in');

      final response = await LoggedHttpClient.delete(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/beneficiary/$id?userId=$userId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': ApiConfig.contentType},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] != 'success') throw Exception(data['message'] ?? 'Failed');
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired');
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Delete beneficiary error: $e');
      rethrow;
    }
  }

  // Update Beneficiary
  Future<Map<String, dynamic>?> updateBeneficiary(Beneficiary beneficiary) async {
    try {
      if (beneficiary.id != null) await deleteBeneficiary(beneficiary.id!.toString());
      return await saveBeneficiary(beneficiary);
    } catch (e) {
      print('Update beneficiary error: $e');
      rethrow;
    }
  }

  // Initiate Payout
  Future<Map<String, dynamic>> initiatePayout(Map<String, dynamic> payoutData) async {
    try {
      final token = await _getValidToken();
      if (token == null) throw Exception('No valid token');

      final userId = await _getUserId();
      if (userId == null) throw Exception('Not logged in');

      final requestData = Map<String, dynamic>.from(payoutData);
      requestData['userId'] = int.parse(userId);

      final response = await LoggedHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/transfer'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': ApiConfig.contentType},
        body: json.encode(requestData),
      );

      if (response.statusCode == 200) return json.decode(response.body);
      if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired');
      }
      throw Exception('Payout failed: ${response.statusCode}');
    } catch (e) {
      print('Payout error: $e');
      rethrow;
    }
  }

  // Get Transaction Status
  Future<Map<String, dynamic>> getTransactionStatus(String merchantRefId) async {
    try {
      final token = await _getValidToken();
      if (token == null) throw Exception('No valid token');

      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/status/$merchantRefId'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': ApiConfig.contentType},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {'success': true, 'data': data['data'] ?? data};
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired');
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Transaction not found'};
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Get status error: $e');
      rethrow;
    }
  }

  // Get Transaction History
  Future<List<dynamic>> getTransactionHistory() async {
    try {
      final token = await _getValidToken();
      if (token == null) throw Exception('No valid token');

      final userId = await _getUserId();
      if (userId == null) throw Exception('Not logged in');

      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/transactions?userId=$userId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': ApiConfig.contentType
        },
      );

      if (response.statusCode == 200) {

        final data = json.decode(response.body);

        print("Transaction decoded type: ${data.runtimeType}");

        if (data is List) {
          return data;
        }

        if (data is Map<String,dynamic>) {
          return data['data'] ?? [];
        }

        return [];

      } else if (response.statusCode == 401) {

        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired');

      } else {
        throw Exception('Failed: ${response.statusCode}');
      }

    } catch (e) {
      print('Get history error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════
  // ✅ NEW METHODS
  // ═══════════════════════════════════════════

  // Get Bank Accounts
  Future<Map<String, dynamic>> getBankAccounts() async {
    try {
      final token = await _getValidToken();
      if (token == null) throw Exception('No valid token found');

      final response = await LoggedHttpClient.get(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/my-bank-accounts'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': ApiConfig.contentType},
      );

      print('Get bank accounts: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'data': data['data'] ?? [],
        };
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired');
      }
      throw Exception('Failed');
    } catch (e) {
      print('Error fetching bank accounts: $e');
      return {'success': false, 'message': e.toString(), 'data': []};
    }
  }

  // Set Default Bank Account
  Future<Map<String, dynamic>> setDefaultBankAccount(String accountId) async {
    try {
      final token = await _getValidToken();
      if (token == null) throw Exception('No valid token found');

      print('Setting default bank account:: $accountId');

      final response = await LoggedHttpClient.patch(
        Uri.parse('${ApiConfig.baseUrl}/api/payout/bank-account/$accountId/default'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': ApiConfig.contentType},
      );

      print('Set default response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': data['success'] ?? true,
          'data': data['data'] ?? null,
          'message': data['message'] ?? 'Updated'
        };
      } else if (response.statusCode == 401) {
        await _storage.delete(key: 'jwt_token');
        throw Exception('Session expired');
      } else {
        throw Exception('Failed');
      }
    } catch (e) {
      print('Error setting default: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

}