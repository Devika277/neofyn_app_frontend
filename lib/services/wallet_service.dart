
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';



class WalletService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.myneofyn.com/api', // replace with your backend URL
  connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  Future<Map<String, dynamic>> fetchMainWalletBalance(String userId) async {
    final res = await _dio.get('/wallet/main/$userId');
    if (res.statusCode == 200) {
  return res.data as Map<String, dynamic>;  // Dio already decodes JSON — no jsonDecode needed
    } else {
      throw Exception('Failed to load main wallet balance');
    }
  }

Future<Map<String, dynamic>> fetchAepsWalletBalance(String userId) async {
  final res = await _dio.get('/wallet/aeps/$userId');
  print('🔍 Fetching AEPS wallet from: ${res.requestOptions.uri}');
  // if (res.statusCode == 200) {
    return res.data as Map<String, dynamic>;
  // print('📄 AEPS response body: ${response.body}');
  // if (response.statusCode == 200) {
  //   final decoded = jsonDecode(response.body);
  //   print('✅ AEPS decoded: $decoded');
  //   return decoded;
  // } else {
  //   throw Exception('Failed to load AEPS wallet balance: ${response.statusCode}');
  // }
}

  Future<Map<String, dynamic>> fetchStats(String userId) async {
    final res = await _dio.get('/wallet/stats/$userId');
    if (res.statusCode == 200) {
      return res.data as Map<String, dynamic>;
    } else {
      // return static demo data if endpoint doesn't exist yet
      return {
        'rewards': 1250,
        'commission': 3450,
        'ccBalance': 5000,
      };
    }
  }
// ── NEW: fetch wallet ledger ───────────────────────────────────────────────
  Future<List<dynamic>> fetchLedger(String userId) async {
    final res = await _dio.get('/wallet/ledger/$userId');
    return res.data['ledger'] ?? [];
  }

  // ── NEW: fetch fund requests ───────────────────────────────────────────────
  Future<List<dynamic>> fetchFundRequests(String userId) async {
    final res = await _dio.get('/wallet/fund-requests/$userId');
    print('📦 Raw response status: ${res.statusCode}');  // ADD THIS
    print('📦 Raw response data: ${res.data}');          // ADD THIS
    return res.data['requests'] ?? [];
  }

  // ── NEW: submit fund request ───────────────────────────────────────────────
  Future<Map<String, dynamic>> submitFundRequest({
    
    required String userId,
    required double amount,
    required String paymentMode,
    required String bankName,
    required String referenceNumber,
    required String payDate,        // format: YYYY-MM-DD
    String? remark,
    File? receiptFile,


    
  }) async {
    final formData = FormData.fromMap({
      'user_id':          userId,
      'amount':           amount.toString(),
      'payment_mode':     paymentMode,
      'bank_name':        bankName,
      'reference_number': referenceNumber,
      'pay_date':         payDate,
      if (remark != null && remark.isNotEmpty) 'remark': remark,
      if (receiptFile != null)
        'receipt': await MultipartFile.fromFile(
          receiptFile.path,
          contentType: receiptFile.path.endsWith('.pdf')
              ? MediaType('application', 'pdf')
              : MediaType('image', 'jpeg'),
        ),
        
    });
    
    final res = await _dio.post('/wallet/fund-request', data: formData);
    print('📦 Raw response status: ${res.statusCode}');  // ADD THIS
    print('📦 Raw response data: ${res.data}');          // ADD THIS
    return res.data;  }
}