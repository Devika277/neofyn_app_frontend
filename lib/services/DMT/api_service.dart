// lib/services/dmt/api_service.dart
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/services/api_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/dmt_models.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  static const String baseUrl = 'https://api.myneofyn.com';

  // Get auth token from SharedPreferences (same as AEPS)
  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Try both possible token keys
    final token =
        prefs.getString('accessToken') ?? prefs.getString('token') ?? '';
    print(
      '🔑 DMT Token: ${token.isNotEmpty ? '${token.substring(0, 20)}...' : 'EMPTY'}',
    );
    return token;
  }

  // Get auth headers with token (same pattern as AEPS)
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Get state list
  Future<List<Map<String, String>>> getStateList() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dmt/states'),
        headers: await _getAuthHeaders(),
      );

      print('📡 States API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List states = data['states'] ?? [];
          return states
              .map(
                (state) => {
                  'code': state['code']?.toString() ?? '',
                  'name': state['name']?.toString() ?? '',
                },
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Error loading states: $e');
      return [];
    }
  }

  // In api_service.dart
 /* Future<Map<String, dynamic>> getRemitterDetailsRaw(int remitterId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dmt/remitter/$remitterId'),
        headers: await _getAuthHeaders(),
      );
      print('📡 Remitter Details Status: ${response.statusCode}');
      print('📡 Remitter Details Body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to get remitter details');
      }
    } catch (e) {
      print('❌ Error getting remitter details: $e');
      rethrow;
    }
  }*/
  Future<Map<String, dynamic>> getRemitterDetailsRaw(int remitterId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dmt/remitter/$remitterId'),
        headers: await _getAuthHeaders(),
      );

      print('📡 Remitter Details Status: ${response.statusCode}');
      print('📡 Remitter Details Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // ✅ ADD THESE LOGS
        print('📡 Remitter Data Keys: ${data.keys}');
        print('📡 Remitter Full Data: $data');

        // Check for state-related fields
        if (data.containsKey('state_code')) {
          print('✅ Found state_code: ${data['state_code']}');
        }
        if (data.containsKey('state')) {
          print('✅ Found state: ${data['state']}');
        }
        if (data.containsKey('state_name')) {
          print('✅ Found state_name: ${data['state_name']}');
        }

        return data;
      } else {
        throw Exception('Failed to get remitter details');
      }
    } catch (e) {
      print('❌ Error getting remitter details: $e');
      rethrow;
    }
  }

  // Get bank list
  Future<List<Map<String, String>>> getBankList() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dmt/banks'),
        headers: await _getAuthHeaders(),
      );

      print('📡 Banks API Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List banks = data['banks'] ?? [];
          return banks
              .map(
                (bank) => {
                  'code': bank['code']?.toString() ?? '',
                  'name': bank['name']?.toString() ?? '',
                },
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Error loading banks: $e');
      return [];
    }
  }

  // Get city list
  Future<List<Map<String, String>>> getCityList(String stateCode) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dmt/cities?stateCode=$stateCode'),
        headers: await _getAuthHeaders(),
      );

      print(
        '📡 Cities API Response: ${response.statusCode} for state $stateCode',
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List cities = data['cities'] ?? [];
          return cities
              .map(
                (city) => {
                  'code': city['code']?.toString() ?? '',
                  'name': city['name']?.toString() ?? '',
                },
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('❌ Error loading cities: $e');
      return [];
    }
  }

  // Check if remitter exists
  Future<Map<String, dynamic>> checkRemitter(
    String phone,
    String productType,
  ) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/api/dmt/check-phone?phone=$phone&productType=$productType',
        ),
        headers: await _getAuthHeaders(),
      );

      print('📡 Check Remitter Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to check remitter: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error checking remitter: $e');
      rethrow;
    }
  }

  // Register remitter
  Future<Map<String, dynamic>> registerRemitter({
    required String mobile,
    required String firstName,
    required String lastName,
    required String stateCode,
    required String productType,
    required String aadhaarNumber,
    String? lat,
    String? long,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/dmt/remitter/register'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'mobile': mobile,
          'firstName': firstName,
          'lastName': lastName,
          'stateCode': stateCode,
          'productType': productType,
          'aadhaarNumber': aadhaarNumber,
          'lat': lat,
          'long': long,
        }),
      );

      print('📡 Register Remitter Response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to register remitter');
      }
    } catch (e) {
      print('❌ Error registering remitter: $e');
      rethrow;
    }
  }

  // Get remitter details
  Future<Remitter> getRemitterDetails(int remitterId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dmt/remitter/$remitterId'),
        headers: await _getAuthHeaders(),
      );

      print('📡 Remitter Details Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        return Remitter.fromJson(json.decode(response.body));
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to get remitter details');
      }
    } catch (e) {
      print('❌ Error getting remitter details: $e');
      rethrow;
    }
  }

  // Add beneficiary
  Future<Map<String, dynamic>> addBeneficiary({
    required int remitterId,
    required String accountHolderName,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
    String? bankCode,
    String? stateCode,
    String? cityCode,
    String? beneficiaryMobile,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/dmt/beneficiary'),
        headers: await _getAuthHeaders(),
        body: json.encode({
          'remitterId': remitterId,
          'accountHolderName': accountHolderName,
          'accountNumber': accountNumber,
          'ifscCode': ifscCode,
          'bankName': bankName,
          'bankCode': bankCode,
          'stateCode': stateCode,
          'cityCode': cityCode,
          'beneficiaryMobile': beneficiaryMobile,
        }),
      );

      print('📡 Add Beneficiary Response: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        return json.decode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to add beneficiary');
      }
    } catch (e) {
      print('❌ Error adding beneficiary: $e');
      rethrow;
    }
  }

  // Get beneficiaries
  Future<List<Beneficiary>> getBeneficiaries(int remitterId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/dmt/beneficiaries/$remitterId'),
        headers: await _getAuthHeaders(),
      );

      print('📡 Get Beneficiaries Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        print('📡 Beneficiaries Raw Data: $data');
        if (data is List && data.isNotEmpty) {
          print('📡 First Beneficiary Keys: ${data[0].keys}');
          print('📡 First Beneficiary Full Data: ${data[0]}');
        }
        return data.map((json) => Beneficiary.fromJson(json)).toList();
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to get beneficiaries');
      }
    } catch (e) {
      print('❌ Error getting beneficiaries: $e');
      rethrow;
    }
  }

  // Create DMT transfer
  Future<Map<String, dynamic>> createTransfer(
      DMTTransferRequest request,
      ) async {
    try {
      final body = request.toJson();
      print('📡 Create Transfer Body: $body');  // ✅ ADD THIS

      final response = await http.post(
        Uri.parse('$baseUrl/api/dmt/transfer'),
        headers: await _getAuthHeaders(),
        body: json.encode(body),
      );

      print('📡 Create Transfer Response: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'transactionId': data['transactionId'],
          'utrNumber': data['utrNumber'],
          'providerStatus': data['providerStatus'],
          'message': data['message'] ?? 'Transfer successful',
        };
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to create transfer');
      }
    } catch (e) {
      print('❌ Error creating transfer: $e');
      rethrow;
    }
  }

  // Get transactions
  Future<List<DMTTransaction>> getTransactions({
    int? remitterId,
    String? startDate,
    String? endDate,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (remitterId != null) queryParams['remitterId'] = remitterId.toString();
      if (startDate != null) queryParams['startDate'] = startDate;
      if (endDate != null) queryParams['endDate'] = endDate;
      queryParams['limit'] = limit.toString();

      final uri = Uri.parse(
        '$baseUrl/api/dmt/transactions',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: await _getAuthHeaders());

      print('📡 Get Transactions Response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          final List transactions = data['transactions'] ?? [];
          return transactions
              .map((json) => DMTTransaction.fromJson(json))
              .toList();
        }
        return [];
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Failed to get transactions');
      }
    } catch (e) {
      print('❌ Error getting transactions: $e');
      rethrow;
    }
  }

  // Delete beneficiary
  Future<void> deleteBeneficiary(int beneficiaryId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/dmt/beneficiary/$beneficiaryId'),
        headers: await _getAuthHeaders(),
      );

      print('📡 Delete Beneficiary Response: ${response.statusCode}');

      if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      } else if (response.statusCode != 200) {
        throw Exception('Failed to delete beneficiary');
      }
    } catch (e) {
      print('❌ Error deleting beneficiary: $e');
      rethrow;
    }
  }
  // ───────────────────────────────────────────────────────────────
//  DMT - Get Transaction History
// ───────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDmtHistory({
    String? userId,
    int limit = 50,
    int offset = 0,
    String? status,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (userId != null) queryParams['userId'] = userId;
      if (status != null) queryParams['status'] = status;
      if (fromDate != null) queryParams['from'] = fromDate;
      if (toDate != null) queryParams['to'] = toDate;

      // ✅ FIXED: Use baseUrl instead of ApiConfig.baseUrl
      final uri = Uri.parse('$baseUrl/api/dmt/history')
          .replace(queryParameters: queryParams);

      print('┌──────────────────────────────────────────');
      print('│ 🔍 [DMT] Fetching History');
      print('│ 📍 URL: $uri');
      print('└──────────────────────────────────────────');

      final response = await LoggedHttpClient.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      print('┌──────────────────────────────────────────');
      print('│ 📥 [DMT] Response');
      print('│ 📊 Status: ${response.statusCode}');
      print('│ 📦 Body: ${response.body.length > 300 ? response.body.substring(0, 300) + '...' : response.body}');
      print('└──────────────────────────────────────────');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> list = [];

        if (data is List) {
          list = data;
        } else if (data is Map) {
          if (data['transactions'] is List) {
            list = data['transactions'];
          } else if (data['data'] is List) {
            list = data['data'];
          } else if (data['history'] is List) {
            list = data['history'];
          }
        }

        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      print('❌ [DMT] History error: $e');
      return [];
    }
  }

  // Get remitter by phone (alias for checkRemitter)
  Future<Map<String, dynamic>> getRemitterByPhone(
    String phone,
    String productType,
  ) async {
    return await checkRemitter(phone, productType);
  }

  /// Check DMT Transaction Status (POST version)
// In your api_service.dart, replace the checkDmtStatus method with this:

  /// Check DMT Transaction Status (POST version - matches backend)
  Future<Map<String, dynamic>> checkDmtStatus({
    required String transactionId,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      print('┌──────────────────────────────────────────');
      print('│ 🔍 [DMT] Checking Transaction Status');
      print('│ 📍 Transaction ID: $transactionId');
      print('└──────────────────────────────────────────');

      final response = await LoggedHttpClient.post(
        Uri.parse('$baseUrl/api/dmt/status'),
        headers: headers,
        body: json.encode({
          'transactionId': transactionId,
        }),
      ).timeout(const Duration(seconds: 15));

      print('┌──────────────────────────────────────────');
      print('│ 📥 [DMT] Status Response');
      print('│ 📊 Status: ${response.statusCode}');
      print('│ 📦 Body: ${response.body.length > 300 ? response.body.substring(0, 300) + '...' : response.body}');
      print('└──────────────────────────────────────────');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final txData = data['data'] ?? data;

          print('✅ [DMT] Status: ${txData['status']} | UTR: ${txData['utrNumber']}');

          return {
            'success': true,
            'data': {
              'status': txData['status']?.toString().toLowerCase() ?? 'pending',
              'rrn': txData['utrNumber']?.toString(), // ✅ RRN is stored in utr_number
              'utrNumber': txData['utrNumber']?.toString(),
              'bankRefNo': txData['utrNumber']?.toString(),
              'message': txData['message']?.toString() ?? txData['failureReason']?.toString(),
              'failureReason': txData['failureReason']?.toString(),
              'amount': txData['amount']?.toString(),
              'transferMode': txData['transferMode']?.toString(),
              'remitterName': txData['remitterName']?.toString(),
              'remitterMobile': txData['remitterMobile']?.toString(),
              'beneficiaryName': txData['beneficiaryName']?.toString(),
              'beneficiaryAccount': txData['beneficiaryAccount']?.toString(),
              'beneficiaryIfsc': txData['beneficiaryIfsc']?.toString(),
              'beneficiaryBank': txData['beneficiaryBank']?.toString(),
              'beneficiaryMobile': txData['beneficiaryMobile']?.toString(),
              'commissionAmount': txData['commissionAmount']?.toString(),
              'createdAt': txData['createdAt']?.toString(),
              'updatedAt': txData['updatedAt']?.toString(),
            }
          };
        }
      } else if (response.statusCode == 404) {
        return {
          'success': false,
          'message': 'Transaction not found',
        };
      } else if (response.statusCode == 401) {
        throw Exception('Session expired. Please login again.');
      }

      return {
        'success': false,
        'message': 'Failed to check status. Code: ${response.statusCode}',
      };
    } catch (e) {
      print('❌ [DMT] Status check error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }
/*Future<Map<String, dynamic>> checkDmtStatus({
    required String transactionId,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      print('┌──────────────────────────────────────────');
      print('│ 🔍 [DMT] Checking Transaction Status');
      print('│ 📍 Transaction ID: $transactionId');
      print('└──────────────────────────────────────────');

      final response = await http.post(
        Uri.parse('$baseUrl/api/dmt/status'),
        headers: headers,
        body: json.encode({
          'transactionId': transactionId,
        }),
      ).timeout(const Duration(seconds: 15));

      print('┌──────────────────────────────────────────');
      print('│ 📥 [DMT] Status Response');
      print('│ 📊 Status: ${response.statusCode}');
      print('│ 📦 Body: ${response.body}');
      print('└──────────────────────────────────────────');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final txData = data['data'] ?? data['transaction'] ?? data;

          print('✅ [DMT] Status: ${txData['status']} | RRN: ${txData['rrn']}');

          return {
            'success': true,
            'data': {
              'status': txData['status']?.toString().toLowerCase() ?? 'pending',
              'rrn': txData['rrn']?.toString(),
              'utrNumber': txData['utrNumber']?.toString() ?? txData['utr_number']?.toString(),
              'bankRefNo': txData['bankRefNo']?.toString() ?? txData['bank_ref_no']?.toString(),
              'message': txData['message']?.toString(),
              'failureReason': txData['failureReason']?.toString() ?? txData['failure_reason']?.toString(),
            }
          };
        }
      }

      return {
        'success': false,
        'message': 'Failed to check status',
      };
    } catch (e) {
      print('❌ [DMT] Status check error: $e');
      return {
        'success': false,
        'message': e.toString(),
      };
    }
  }*/
}
