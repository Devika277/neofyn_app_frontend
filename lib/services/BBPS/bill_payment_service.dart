import 'api_service.dart';
import '../../models/bbps_models.dart';

class BillPaymentService {
  // Fetch bill details
  static Future<FetchBillResponse> fetchBill({
    required String serviceType,
    required String customerId,
    Map<String, dynamic>? additionalData,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'step': 'fetch',
      'serviceType': serviceType,
      'customerId': customerId,
      if (additionalData != null) 'additionalData': additionalData,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
    final json = await ApiService.post('/api/payments', body);
    return FetchBillResponse.fromJson(json);
  }

  // Pay bill
  static Future<PayBillResponse> payBill({
    required int transactionId,
    String? serviceType,
    String? customerId,
    double? amount,
    Map<String, dynamic>? additionalData,
    String? idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'step': 'pay',
      'transactionId': transactionId,
      if (serviceType != null) 'serviceType': serviceType,
      if (customerId != null) 'customerId': customerId,
      if (amount != null) 'amount': amount,
      if (additionalData != null) 'additionalData': additionalData,
      if (idempotencyKey != null) 'idempotencyKey': idempotencyKey,
    };
    final json = await ApiService.post('/api/payments', body);
    return PayBillResponse.fromJson(json);
  }

  // Payment history
  static Future<List<Transaction>> getHistory({
    String? serviceType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (serviceType != null) params['serviceType'] = serviceType;
    if (startDate != null) params['startDate'] = startDate.toIso8601String().split('T').first;
    if (endDate != null) params['endDate'] = endDate.toIso8601String().split('T').first;
    final json = await ApiService.get('/api/payments/history', queryParams: params);
    final List<dynamic> list = json['data'] ?? [];
    return list.map((e) => Transaction.fromJson(e)).toList();
  }

  // Single transaction
  static Future<Transaction> getTransactionById(int id) async {
    final json = await ApiService.get('/api/payments/transaction/$id');
    return Transaction.fromJson(json['data']);
  }

  // Active services list
  static Future<List<PaymentServiceModel>> getActiveServices() async {
    final json = await ApiService.get('/api/payments/services');
    final List<dynamic> list = json['data'] ?? [];
    return list.map((e) => PaymentServiceModel.fromJson(e)).toList();
  }
}