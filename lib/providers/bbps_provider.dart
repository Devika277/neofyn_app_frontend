import 'package:flutter/foundation.dart';
import '../models/bbps_models.dart';
import '../services/bbps/bbps_onboarding_service.dart';
import '../services/bbps/bill_payment_service.dart';

class BBPSProvider extends ChangeNotifier {
  // Onboarding state
  bool onboardingLoading = false;
  String? onboardingError;
  OnboardingResponse? onboardingResponse;
  MerchantStatus? merchantStatus;
  List<BBPSState> states = [];
  List<BBPScity> cities = [];

  // Dynamic data loading
  bool loadingStates = false;
  bool loadingCities = false;

  // Bill Payment state
  bool fetchBillLoading = false;
  bool payBillLoading = false;
  String? paymentError;
  FetchBillResponse? fetchBillResponse;
  PayBillResponse? payBillResponse;

  List<Transaction> transactionHistory = [];
  bool historyLoading = false;

  List<PaymentServiceModel> activeServices = [];
  bool servicesLoading = false;



  // =========== NEW STATE FOR BBPS BILLER CATEGORIES ===========
List<BillerCategory> _categories = [];
List<BillerCategory> get categories => _categories;
bool categoriesLoading = false;

BillerCategory? _selectedCategory;
BillerCategory? get selectedCategory => _selectedCategory;

List<BillerProvider> _billers = [];
List<BillerProvider> get billers => _billers;
bool billersLoading = false;

BillerProvider? _selectedBiller;
BillerProvider? get selectedBiller => _selectedBiller;

BillerDetails? _billerDetails;
BillerDetails? get billerDetails => _billerDetails;
bool billerDetailsLoading = false;

// =========== METHODS ===========

Future<void> loadBillCategories() async {
  categoriesLoading = true;
  notifyListeners();
  try {
    _categories = await BBPSOnboardingService.getBillerCategories();
    print('📦 Categories loaded: ${_categories.length} items');
    if (_categories.isNotEmpty) {
      print('📋 First category: code="${_categories[0].code}" name="${_categories[0].name}"');
    }
  } catch (e) {
    print('❌ Error loading categories: $e');
    _categories = [];
  }
  categoriesLoading = false;
  notifyListeners();
}

void selectCategory(BillerCategory? cat) {
  _selectedCategory = cat;
  _selectedBiller = null;
  _billers = [];
  _billerDetails = null;
  notifyListeners();
}

Future<void> loadBillersForCategory(String categoryCode) async {
  billersLoading = true;
  _billers = [];
  _selectedBiller = null;
  _billerDetails = null;
  notifyListeners();
  try {
    _billers = await BBPSOnboardingService.getBillerCode(categoryCode);
  } catch (e) {
    _billers = [];
  }
  billersLoading = false;
  notifyListeners();
}

void selectBiller(BillerProvider? biller) {
  _selectedBiller = biller;
  _billerDetails = null;
  notifyListeners();
}

Future<void> loadBillerDetails(String billerCategoryCode, String billerCode) async {
  billerDetailsLoading = true;
  notifyListeners();
  try {
    _billerDetails = await BBPSOnboardingService.getBillerDetails(
      billerCategoryCode,
      billerCode,
    );
  } catch (e) {
    _billerDetails = null;
  }
  billerDetailsLoading = false;
  print('📦 Raw biller details: $_billerDetails');
  notifyListeners();
}







  // ---------- Onboarding ----------
  Future<void> onboardMerchant(MerchantOnboardingRequest request) async {
    onboardingLoading = true;
    onboardingError = null;
    notifyListeners();
    try {
      onboardingResponse = await BBPSOnboardingService.onboardMerchant(request);
    } catch (e) {
      onboardingError = e.toString();
    } finally {
      onboardingLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMerchantStatus(int userId) async {
    onboardingLoading = true;
    notifyListeners();
    try {
      merchantStatus = await BBPSOnboardingService.getMerchantStatus(userId);
    } catch (e) {
      onboardingError = e.toString();
    } finally {
      onboardingLoading = false;
      notifyListeners();
    }
  }

  /*Future<void> loadStates() async {
    loadingStates = true;
    notifyListeners();
    try {
      states = await BBPSOnboardingService.getStates();
    } catch (_) {}
    loadingStates = false;
    notifyListeners();
  }*/
// In BBPSProvider, temporarily change loadStates():
  Future<void> loadStates() async {
    loadingStates = true;
    notifyListeners();
    try {
      debugPrint('🔄 Attempting to load states...');
      states = await BBPSOnboardingService.getStates();
      debugPrint('✅ States loaded successfully: ${states.length} states');
      debugPrint('📋 States data: $states');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading states: $e');
      debugPrint('📚 Stack trace: $stackTrace');
    }
    loadingStates = false;
    notifyListeners();
  }
  Future<void> loadCities(String stateCode) async {
    loadingCities = true;
    notifyListeners();
    try {
      cities = await BBPSOnboardingService.getCities(stateCode);
    } catch (_) {
      cities = [];
    }
    loadingCities = false;
    notifyListeners();
  }

  // ---------- Bill Payment ----------
  Future<void> fetchBill({
    required String serviceType,
    required String customerId,
    Map<String, dynamic>? additionalData,
  }) async {
    fetchBillLoading = true;
    paymentError = null;
    fetchBillResponse = null;
    payBillResponse = null;
    notifyListeners();
    try {
      fetchBillResponse = await BillPaymentService.fetchBill(
        serviceType: serviceType,
        customerId: customerId,
        additionalData: additionalData,
      );
    } catch (e) {
      paymentError = e.toString();
    } finally {
      fetchBillLoading = false;
      notifyListeners();
    }
  }

  Future<void> payBill({
    required int transactionId,
    String? serviceType,
    String? customerId,
    double? amount,
    Map<String, dynamic>? additionalData,
  }) async {
    payBillLoading = true;
    paymentError = null;
    notifyListeners();
    try {
      payBillResponse = await BillPaymentService.payBill(
        transactionId: transactionId,
        serviceType: serviceType,
        customerId: customerId,
        amount: amount,
        additionalData: additionalData,
      );
    } catch (e) {
      paymentError = e.toString();
    } finally {
      payBillLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory({String? serviceType}) async {
    historyLoading = true;
    notifyListeners();
    try {
      transactionHistory = await BillPaymentService.getHistory(serviceType: serviceType);
    } catch (_) {
      transactionHistory = [];
    }
    historyLoading = false;
    notifyListeners();
  }

  Future<void> loadActiveServices() async {
    servicesLoading = true;
    notifyListeners();
    try {
      activeServices = await BillPaymentService.getActiveServices();
    } catch (_) {}
    servicesLoading = false;
    notifyListeners();
  }

  void clearBillState() {
    fetchBillResponse = null;
    payBillResponse = null;
    paymentError = null;
    notifyListeners();
  }

  // Reset the whole bill payment flow
void resetBillPaymentFlow() {
  _selectedCategory = null;
  _selectedBiller = null;
  _billers = [];
  _billerDetails = null;
  fetchBillResponse = null;
  payBillResponse = null;
  paymentError = null;
  notifyListeners();
}
}