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
  List<Map<String, dynamic>> _bankAccounts = []; // ✅ NEW: Bank accounts list
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  List<dynamic> get banks => _banks;
  List<dynamic> get purposes => _purposes;
  List<dynamic> get states => _states;
  List<dynamic> get transactions => _transactions;
  List<Map<String, dynamic>> get bankAccounts => _bankAccounts; // ✅ NEW


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
      // ✅ Load bank accounts when loading master data
      await fetchBankAccounts();
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
  // ✅ NEW: Fetch bank accounts
  Future<void> fetchBankAccounts() async {
    try {
      final response = await _payoutService.getBankAccounts();
      if (response['success'] == true) {
        _bankAccounts = List<Map<String, dynamic>>.from(response['data'] ?? []);
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error fetching bank accounts: $e');
    }
  }
  // ✅ NEW: Set default/primary bank account
  Future<bool> setDefaultBankAccount(String accountId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await _payoutService.setDefaultBankAccount(accountId);

      if (response['success'] == true) {
        // Refresh bank accounts list
        await fetchBankAccounts();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to set primary account';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Error setting default account: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ✅ NEW: Get primary bank account
  Map<String, dynamic>? getPrimaryBankAccount() {
    try {
      return _bankAccounts.firstWhere(
            (account) => account['is_primary'] == true,
      );
    } catch (e) {
      return _bankAccounts.isNotEmpty ? _bankAccounts.first : null;
    }
  }
}