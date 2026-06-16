// lib/services/recharge_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api_logger.dart';

class RechargeService {
  final String baseUrl;

  RechargeService({required this.baseUrl});

  Future<Map<String, dynamic>> getReceipt(int transactionId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null) throw Exception('No auth token');

    final response = await LoggedHttpClient.get(
      Uri.parse('$baseUrl/api/recharge/receipt/$transactionId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to load receipt');
    }

    final body = jsonDecode(response.body);
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Receipt fetch failed');
    }
    return body;
  }
}