// providers/payout_provider.dart

import 'package:flutter/material.dart';
import 'package:my_app/services/payout/payout_service.dart';

class PayoutProvider extends ChangeNotifier {
  bool _isLoading = false;
  String _errorMessage = '';
  List<dynamic> _banks = [];
  List<dynamic> _purposes = [];
  List<dynamic> _states = [];
  List<dynamic> _transactions = [];

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<dynamic> get banks => _banks;
  List<dynamic> get purposes => _purposes;
  List<dynamic> get states => _states;
  List<dynamic> get transactions => _transactions;

  final PayoutService _payoutService = PayoutService();

  Future<void> loadMasterData() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final bankResponse = await _payoutService.getBankList();
      if (bankResponse['success'] == true) {
        _banks = bankResponse['data'] ?? [];
      }

      final stateResponse = await _payoutService.getStateList();
      if (stateResponse['success'] == true) {
        _states = stateResponse['data'] ?? [];
      }
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Load master data error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  String getBankName(String code) {
    try {
      final bank = _banks.firstWhere(
        (b) => b['code'] == code,
        orElse: () => null,
      );
      return bank?['description'] ?? code;
    } catch (e) {
      return code;
    }
  }

  String getPurposeName(String code) {
    try {
      final purpose = _purposes.firstWhere(
        (p) => p['code'] == code,
        orElse: () => null,
      );
      return purpose?['description'] ?? code;
    } catch (e) {
      return code;
    }
  }

  String getStateName(String code) {
    try {
      final state = _states.firstWhere(
        (s) => s['code'] == code,
        orElse: () => null,
      );
      return state?['description'] ?? code;
    } catch (e) {
      return code;
    }
  }

  Future<Map<String, dynamic>> initiatePayout(Map<String, dynamic> request) async {
  _isLoading = true;
  _errorMessage = '';
  notifyListeners();

  try {
    final response = await _payoutService.initiatePayout(request);
    
    // ✅ Ensure merchantRefId is returned properly
    if (response['success'] == true) {
      // The backend should return merchantRefId in the response
      // If not, try to get it from data field
      if (response['merchantRefId'] == null && response['data'] != null) {
        response['merchantRefId'] = response['data']['merchantRefId'] ?? 
                                   response['data']['merchant_ref_id'];
      }
    }
    
    return response;
  } catch (e) {
    _errorMessage = e.toString();
    print('❌ Initiate payout error: $e');
    rethrow;
  } finally {
    _isLoading = false;
    notifyListeners();
  }
}

  Future<void> loadTransactionHistory() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      _transactions = await _payoutService.getTransactionHistory();
      print('✅ Loaded ${_transactions.length} transactions');
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Load transaction history error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  Future<Map<String, dynamic>> getTransactionStatus(String merchantRefId) async {
    try {
      return await _payoutService.getTransactionStatus(merchantRefId);
    } catch (e) {
      print('❌ Get transaction status error: $e');
      rethrow;
    }
  }
}