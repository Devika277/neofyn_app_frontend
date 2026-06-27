import 'api_service.dart';
import '../../models/bbps_models.dart';

class BBPSOnboardingService {
  static Future<OnboardingResponse> onboardMerchant(MerchantOnboardingRequest request) async {
    final json = await ApiService.post('/api/bbps/merchant/onboard', request.toJson());
    return OnboardingResponse.fromJson(json);
  }

  static Future<MerchantStatus?> getMerchantStatus(int userId) async {
    final json = await ApiService.get('/api/bbps/merchant/status/$userId');
    if (json['success'] && json['data'] != null) {
      return MerchantStatus.fromJson(json['data']);
    }
    return null;
  }

  static Future<List<BBPSState>> getStates() async {
    final json = await ApiService.get('/api/bbps/states');
    final List<dynamic> list = json['data'] ?? [];
    return list.map((e) => BBPSState.fromJson(e)).toList();
  }

  static Future<List<BBPScity>> getCities(String stateCode) async {
    final json = await ApiService.post('/api/bbps/cities', {'stateCode': stateCode});
    final List<dynamic> list = json['data'] ?? [];
    return list.map((e) => BBPScity.fromJson(e)).toList();
  }

  static Future<List<BillerCategory>> getBillerCategories() async {
  try {
    final json = await ApiService.get('/api/bbps/billerCategories');
    print('📦 Categories API response: $json');
    
    // Handle both success and failure cases
    if (json['success'] == true) {
      final List<dynamic> list = json['data'] ?? [];
      print('📊 Categories loaded: ${list.length}');
      return list.map((e) => BillerCategory.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      print('⚠️ Categories API returned success=false: ${json['message']}');
      return [];
    }
  } catch (e) {
    print('❌ Categories API exception: $e');
    return [];
  }
}

  static Future<List<BillerProvider>> getBillerCode(String categoryCode) async {
  print('📡 Requesting billers for category: $categoryCode');
  final json = await ApiService.post('/api/bbps/billerCode', {
    'categoryCode': categoryCode,
  });
  print('📦 Biller response: $json');

  final data = json['data'];
  print('📊 Data field: $data (type: ${data.runtimeType})');

  if (data is List) {
    print('✅ Data is a List with ${data.length} items');
    return data.map((e) => BillerProvider.fromJson(e as Map<String, dynamic>)).toList();
  } else {
    print('❌ Unexpected data format – not a List');
    return [];
  }
}

  static Future<BillerDetails> getBillerDetails(String billerCategoryCode, String billerCode) async {
    final json = await ApiService.post('/api/bbps/billerDetails', {
      'billerCategoryCode': billerCategoryCode,
      'billerCode': billerCode,
    });
    return json['data'] as Map<String, dynamic>;
  }
}