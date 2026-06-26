// // lib/services/bbps_service.dart

// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:my_app/models/biller.dart';
// import '../../models/bbps_models.dart';
// import '../api_logger.dart';

// class BBPSService {
//   final String baseUrl;
//   final String authToken;

//   BBPSService(String baseUrl, {required this.authToken}) : baseUrl = baseUrl;

//   Map<String, String> get _headers => {
//     'Content-Type': 'application/json',
//     'Authorization': 'Bearer $authToken',
//   };

//   // ── Helper to convert "success" from String to bool ──────────────────
//   bool _isSuccess(dynamic value) {
//     if (value == null) return false;
//     if (value is bool) return value;
//     if (value is String) return value.toLowerCase() == 'true';
//     if (value is int) return value == 1;
//     if (value is double) return value == 1.0;
//     return false;
//   }

//   // ── Helper to parse response and fix "success" field ──────────────────
//   Map<String, dynamic> _parse(http.Response res) {
//     final body = jsonDecode(res.body) as Map<String, dynamic>;
    
//     // ✅ FIX: Convert "success" from String to bool if needed
//     if (body.containsKey('success')) {
//       final successValue = body['success'];
//       if (successValue is String) {
//         body['success'] = successValue.toLowerCase() == 'true';
//         print('🔄 Converted "success" from String "$successValue" to bool ${body['success']}');
//       } else if (successValue is int) {
//         body['success'] = successValue == 1;
//       }
//     }
    
//     // Also fix nested data if present
//     if (body.containsKey('data') && body['data'] is Map<String, dynamic>) {
//       final data = body['data'] as Map<String, dynamic>;
//       if (data.containsKey('success')) {
//         final successValue = data['success'];
//         if (successValue is String) {
//           data['success'] = successValue.toLowerCase() == 'true';
//         } else if (successValue is int) {
//           data['success'] = successValue == 1;
//         }
//       }
//     }
    
//     if (res.statusCode >= 400) {
//       throw Exception(body['error'] ?? body['message'] ?? 'Request failed (${res.statusCode})');
//     }
//     return body;
//   }

//   // ── Get Categories ───────────────────────────────────────────────────────
//   Future<List<BillerCategory>> getCategories() async {
//     try {
//       final res = await LoggedHttpClient.get(
//         Uri.parse('$baseUrl/api/bbps/categories'),
//         headers: _headers,
//       );
//       final body = _parse(res);
      
//       // ✅ Check success using the helper
//       if (!_isSuccess(body['success'])) {
//         throw Exception(body['message'] ?? 'Failed to fetch categories');
//       }
      
//       final raw = body['data'];

//       List<dynamic> list;
//       if (raw is List) {
//         list = raw;
//       } else if (raw is Map) {
//         list = raw.values.first is List ? raw.values.first : [];
//       } else {
//         list = [];
//       }

//       return list
//           .map((e) => BillerCategory.fromJson(e as Map<String, dynamic>))
//           .toList();
//     } catch (e) {
//       print('❌ Error fetching categories: $e');
//       rethrow;
//     }
//   }

//   // ── Get States ───────────────────────────────────────────────────────────
//   Future<List<Map<String, dynamic>>> getStates() async {
//     try {
//       final res = await LoggedHttpClient.get(
//         Uri.parse('$baseUrl/api/bbps/states'),
//         headers: _headers,
//       );
//       final body = _parse(res);
      
//       // ✅ Check success using the helper
//       if (!_isSuccess(body['success'])) {
//         print('⚠️ States API returned success: false');
//         return [];
//       }
      
//       final data = body['data'];
//       if (data is List) {
//         print('✅ Found ${data.length} states');
//         return List<Map<String, dynamic>>.from(data);
//       }
//       return [];
//     } catch (e) {
//       print('❌ Error fetching states: $e');
//       rethrow;
//     }
//   }

//   // ── Get Cities ───────────────────────────────────────────────────────────
//   Future<List<Map<String, dynamic>>> getCities(String stateCode) async {
//     try {
//       final res = await LoggedHttpClient.get(
//         Uri.parse('$baseUrl/api/bbps/cities/$stateCode'),
//         headers: _headers,
//       );
//       final body = _parse(res);
      
//       if (!_isSuccess(body['success'])) {
//         return [];
//       }
      
//       final data = body['data'];
//       if (data is List) {
//         return List<Map<String, dynamic>>.from(data);
//       }
//       return [];
//     } catch (e) {
//       print('❌ Error fetching cities: $e');
//       rethrow;
//     }
//   }

//   // ── Get Billers ──────────────────────────────────────────────────────────
//   Future<List<Biller>> getBillers(String categoryId) async {
//     try {
//       final res = await LoggedHttpClient.get(
//         Uri.parse('$baseUrl/api/bbps/billers?categoryId=$categoryId'),
//         headers: _headers,
//       );
//       final body = _parse(res);
      
//       if (!_isSuccess(body['success'])) {
//         throw Exception(body['message'] ?? 'Failed to fetch billers');
//       }
      
//       final list = body['data'] as List<dynamic>? ?? [];
//       return list.map((e) => Biller.fromJson(e as Map<String, dynamic>)).toList();
//     } catch (e) {
//       print('❌ Error fetching billers: $e');
//       rethrow;
//     }
//   }

//   // ── Fetch Bill ───────────────────────────────────────────────────────────
//   Future<FetchBillResult> fetchBill({
//     required String billerId,
//     required String consumerNumber,
//     Map<String, dynamic>? additionalParams,
//   }) async {
//     try {
//       final res = await LoggedHttpClient.post(
//         Uri.parse('$baseUrl/api/bbps/fetch-bill'),
//         headers: _headers,
//         body: jsonEncode({
//           'billerId': billerId,
//           'consumerNumber': consumerNumber,
//           'additionalParams': additionalParams ?? {},
//         }),
//       );
//       final body = _parse(res);
      
//       if (!_isSuccess(body['success'])) {
//         throw Exception(body['message'] ?? 'Failed to fetch bill');
//       }
      
//       return FetchBillResult.fromApiResponse(body);
//     } catch (e) {
//       print('❌ Error fetching bill: $e');
//       rethrow;
//     }
//   }

//   // ── Pay Bill ─────────────────────────────────────────────────────────────
//   Future<PayBillResult> payBill({
//     required String merchantRefId,
//     required Map<String, dynamic> fetchBillResult,
//     required double amount,
//   }) async {
//     try {
//       final res = await LoggedHttpClient.post(
//         Uri.parse('$baseUrl/api/bbps/pay-bill'),
//         headers: _headers,
//         body: jsonEncode({
//           'merchantRefId': merchantRefId,
//           'fetchBillResult': fetchBillResult,
//           'amount': amount,
//         }),
//       );
//       final body = _parse(res);
      
//       if (!_isSuccess(body['success'])) {
//         throw Exception(body['message'] ?? 'Failed to pay bill');
//       }
      
//       return PayBillResult.fromJson(body);
//     } catch (e) {
//       print('❌ Error paying bill: $e');
//       rethrow;
//     }
//   }

//   // ── Check Status ─────────────────────────────────────────────────────────
//   Future<Map<String, dynamic>> checkStatus(String merchantRefId) async {
//     try {
//       final res = await LoggedHttpClient.get(
//         Uri.parse('$baseUrl/api/bbps/status/$merchantRefId'),
//         headers: _headers,
//       );
//       final body = _parse(res);
//       return body;
//     } catch (e) {
//       print('❌ Error checking status: $e');
//       rethrow;
//     }
//   }
// }