import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recharge_models.dart';
import '../services/recharges/recharge_service.dart';

// ─── Form Provider ──────────────────────────────────────────

final rechargeFormProvider = StateNotifierProvider<RechargeFormNotifier, RechargeFormState>((ref) {
  return RechargeFormNotifier();
});

class RechargeFormState {
  final String mobile;
  final String operator;
  final String circle;
  final double amount;
  final bool isLoading;
  final String? error;
  final RechargeResponse? lastResponse;

  RechargeFormState({
    this.mobile = '',
    this.operator = '',
    this.circle = 'ALL',
    this.amount = 0,
    this.isLoading = false,
    this.error,
    this.lastResponse,
  });

  RechargeFormState copyWith({
    String? mobile,
    String? operator,
    String? circle,
    double? amount,
    bool? isLoading,
    String? error,
    RechargeResponse? lastResponse,
  }) {
    return RechargeFormState(
      mobile: mobile ?? this.mobile,
      operator: operator ?? this.operator,
      circle: circle ?? this.circle,
      amount: amount ?? this.amount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastResponse: lastResponse ?? this.lastResponse,
    );
  }
}

class RechargeFormNotifier extends StateNotifier<RechargeFormState> {
  RechargeFormNotifier() : super(RechargeFormState());

  void updateMobile(String mobile) => state = state.copyWith(mobile: mobile);
  void updateOperator(String operator) => state = state.copyWith(operator: operator);
  void updateCircle(String circle) => state = state.copyWith(circle: circle);
  void updateAmount(double amount) => state = state.copyWith(amount: amount);
  void clearError() => state = state.copyWith(error: null);

  // ✅ MODIFIED: Now returns the response for navigation
  Future<RechargeResponse?> submit() async {
    if (state.mobile.isEmpty || state.operator.isEmpty || state.amount <= 0) {
      state = state.copyWith(error: 'Please fill all fields correctly');
      return null;
    }

    // Validate mobile number
    if (state.mobile.length != 10) {
      state = state.copyWith(error: 'Please enter a valid 10-digit mobile number');
      return null;
    }

    state = state.copyWith(isLoading: true, error: null, lastResponse: null);

    try {
      final request = RechargeRequest(
        mobile: state.mobile.trim(),
        operator: state.operator.trim().toUpperCase(),
        amount: state.amount,
        serviceType: 'MBL',
      );

      print('📤 Submitting recharge: ${request.toJson()}');

      final response = await RechargeService.processRecharge(request);

      print('📥 Recharge response: ${response.toJson()}');

      // ✅ Don't show error for pending - let status screen handle it
      state = state.copyWith(
        isLoading: false,
        lastResponse: response,
        error: response.isFailed ? response.message : null, // Only set error for actual failures
      );

      return response; // ✅ Return response so page can navigate

    } catch (e) {
      print('❌ Recharge error: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }
}

// ─── Plans Provider ──────────────────────────────────────────

final plansProvider = FutureProvider.family<PlansResponse, Map<String, String>>((ref, params) {
  final operator = params['operator'] ?? '';
  final circle = params['circle'] ?? 'ALL';
  return RechargeService.getPlans(operator, circle: circle);
});

// ─── Static Lists ───────────────────────────────────────────

final operatorsListProvider = Provider<List<String>>((ref) {
  return ['JIO', 'AIRTEL', 'VI', 'BSNL'];
});

final circlesListProvider = Provider<List<String>>((ref) {
  return [
    'ALL',
    'Andhra Pradesh',
    'Assam',
    'Bihar',
    'Delhi',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jammu & Kashmir',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Mumbai',
    'North East',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Tamil Nadu',
    'Uttar Pradesh East',
    'Uttar Pradesh West',
    'West Bengal',
  ];
});

// ─── History Provider (with pagination) ────────────────────

final historyProvider = StateNotifierProvider<HistoryNotifier, AsyncValue<HistoryResponse>>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<AsyncValue<HistoryResponse>> {
  int _offset = 0;
  static const int _limit = 20;
  bool _hasMore = true;
  List<RechargeHistoryItem> _items = []; // ✅ Changed to RechargeHistoryItem

  HistoryNotifier() : super(const AsyncValue.loading()) {
    // Load initial data
    loadMore();
  }

  Future<void> loadMore() async {
    if (!_hasMore) return;
    
    try {
      state = const AsyncValue.loading();
      
      final response = await RechargeService.getUserHistory(
        limit: _limit, 
        offset: _offset,
      );
      
      if (response.success && response.data != null) {
        _items.addAll(response.data!);
        _offset += _limit;
        _hasMore = response.data!.length == _limit;
        
        // Create updated response with accumulated data
        state = AsyncValue.data(
          HistoryResponse(
            success: true,
            data: List.from(_items), // Create a copy
            message: response.message,
            pagination: Pagination(
              limit: _limit,
              offset: _offset,
              count: _items.length,
            ),
          ),
        );
      } else {
        state = AsyncValue.error(
          response.message ?? 'Failed to load history', 
          StackTrace.current,
        );
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    _offset = 0;
    _items.clear();
    _hasMore = true;
    await loadMore();
  }

  // Filter by status
  void filterByStatus(String status) {
    if (state is AsyncData) {
      final currentData = (state as AsyncData<HistoryResponse>).value;
      if (currentData.data != null) {
        final filtered = status == 'all' 
            ? currentData.data 
            : currentData.data!.where((item) => item.status == status).toList();
        
        state = AsyncValue.data(
          HistoryResponse(
            success: true,
            data: filtered,
            message: currentData.message,
            pagination: currentData.pagination,
          ),
        );
      }
    }
  }
}