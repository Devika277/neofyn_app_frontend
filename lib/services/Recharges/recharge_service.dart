import 'package:uuid/uuid.dart';
import '../../models/recharge_models.dart';
import '../BBPS/api_service.dart';

class RechargeService {
  static const _uuid = Uuid();

  static Future<RechargeResponse> processRecharge(RechargeRequest request) async {
    // Generate idempotency key if not provided
    final finalRequest = request.idempotencyKey == null
        ? RechargeRequest(
            mobile: request.mobile,
            operator: request.operator,
            serviceType: request.serviceType,
            amount: request.amount,
            idempotencyKey: _uuid.v4(),
          )
        : request;

    // Ensure all values are properly typed
    final jsonBody = finalRequest.toJson();
    
    // Make sure amount is a number, not string
    jsonBody['amount'] = finalRequest.amount.toDouble();
    
    print('📤 Sending recharge request: $jsonBody');
    
    final json = await ApiService.post('/api/recharge', jsonBody);
    return RechargeResponse.fromJson(json);
  }

  static Future<PlansResponse> getPlans(String operator, {String circle = 'ALL'}) async {
    print('📡 Fetching plans: operator=$operator, circle=$circle');
    final json = await ApiService.get(
      '/api/recharge/plans',
      queryParams: {'operator': operator, 'circle': circle},
    );
    print('📡 Response received');
    return PlansResponse.fromJson(json);
  }

  static Future<HistoryResponse> getUserHistory({int limit = 50, int offset = 0}) async {
    final json = await ApiService.get(
      '/api/recharge/history',
      queryParams: {'limit': limit.toString(), 'offset': offset.toString()},
    );
    return HistoryResponse.fromJson(json);
  }
}