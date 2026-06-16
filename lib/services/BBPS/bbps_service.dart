// lib/services/bbps_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/bbps_models.dart';
import '../api_logger.dart';

class BBPSService {
  final String baseUrl;
  final String authToken;

  BBPSService(String baseUrl, {required this.authToken}) : baseUrl = baseUrl;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $authToken',
  };

  // ── Helper ───────────────────────────────────────────────────────────────
  Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      throw Exception(body['error'] ?? body['message'] ?? 'Request failed (${res.statusCode})');
    }
    return body;
  }

  // ── Get Categories ───────────────────────────────────────────────────────
  Future<List<BillerCategory>> getCategories() async {
    final res = await LoggedHttpClient.get(
      Uri.parse('$baseUrl/api/bbps/categories'),
      headers: _headers,
    );
    final body = _parse(res);
    final raw = body['data'];

    List<dynamic> list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map) {
      list = raw.values.first is List ? raw.values.first : [];
    } else {
      list = [];
    }

    return list
        .map((e) => BillerCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Get States ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getStates() async {
    final res = await LoggedHttpClient.get(
      Uri.parse('$baseUrl/api/bbps/states'),
      headers: _headers,
    );
    final body = _parse(res);
    return List<Map<String, dynamic>>.from(body['data'] ?? []);
  }

  // ── Get Billers ──────────────────────────────────────────────────────────
  Future<List<Biller>> getBillers(String categoryId) async {
    final res = await LoggedHttpClient.get(
      Uri.parse('$baseUrl/api/bbps/billers?categoryId=$categoryId'),
      headers: _headers,
    );
    final body = _parse(res);
    final list = body['data'] as List<dynamic>? ?? [];
    return list.map((e) => Biller.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Fetch Bill ───────────────────────────────────────────────────────────
  Future<FetchBillResult> fetchBill({
    required String billerId,
    required String consumerNumber,
    Map<String, dynamic>? additionalParams,
  }) async {
    final res = await LoggedHttpClient.post(
      Uri.parse('$baseUrl/api/bbps/fetch-bill'),
      headers: _headers,
      body: jsonEncode({
        'billerId': billerId,
        'consumerNumber': consumerNumber,
        'additionalParams': additionalParams ?? {},
      }),
    );
    final body = _parse(res);
    return FetchBillResult.fromApiResponse(body);
  }

  // ── Pay Bill ─────────────────────────────────────────────────────────────
  Future<PayBillResult> payBill({
    required String merchantRefId,
    required Map<String, dynamic> fetchBillResult,
    required double amount,
  }) async {
    final res = await LoggedHttpClient.post(
      Uri.parse('$baseUrl/api/bbps/pay-bill'),
      headers: _headers,
      body: jsonEncode({
        'merchantRefId': merchantRefId,
        'fetchBillResult': fetchBillResult,
        'amount': amount,
      }),
    );
    final body = _parse(res);
    return PayBillResult.fromJson(body);
  }

  // ── Check Status ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> checkStatus(String merchantRefId) async {
    final res = await LoggedHttpClient.get(
      Uri.parse('$baseUrl/api/bbps/status/$merchantRefId'),
      headers: _headers,
    );
    return _parse(res);
  }
}