// lib/providers/cardpay_out_provider.dart
import 'package:flutter/material.dart';
import '../models/cardpay_out_models.dart';
import '../services/cardpay/cardpay_out_service.dart';

class CardPayOutProvider extends ChangeNotifier {
  final CardPayOutService _service = CardPayOutService();

  // State
  bool _isLoading = false;
  String? _errorMessage;
  double _balance = 0.0;
  List<CardPayOutBeneficiary> _beneficiaries = [];
  List<CardPayOutTransaction> _transactions = [];
  CardPayOutLimits? _limits;

  // Add to existing state
  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _states = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get balance => _balance;
  List<CardPayOutBeneficiary> get beneficiaries => _beneficiaries;
  List<CardPayOutTransaction> get transactions => _transactions;
  CardPayOutLimits? get limits => _limits;
  List<Map<String, dynamic>> get banks => _banks;
  List<Map<String, dynamic>> get states => _states;
  

  // ========== INITIALIZATION ==========

  // Add methods
Future<void> fetchBanks() async {
  try {
    _banks = await _service.getBanks();
    notifyListeners();
  } catch (e) {
    _setError(e.toString());
  }
}

Future<void> fetchStates() async {
  try {
    _states = await _service.getStates();
    notifyListeners();
  } catch (e) {
    _setError(e.toString());
  }
}



  Future<void> initializeCardPayOut() async {
    try {
      _setLoading(true);
      await Future.wait([
        fetchBalance(),
        fetchBeneficiaries(),
        fetchLimits(),
        fetchBanks(),    
        fetchStates(), 
      ]);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
    }
  }

  // ========== USER METHODS ==========

  Future<void> fetchBalance() async {
    try {
      _balance = await _service.getBalance();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> fetchBeneficiaries() async {
    try {
      _beneficiaries = await _service.getBeneficiaries();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      _beneficiaries = [];
    }
  }

  Future<void> fetchLimits() async {
    try {
      _limits = await _service.getLimits();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<Map<String, dynamic>> addBeneficiary(CardPayOutBeneficiaryRequest request) async {
    try {
      _setLoading(true);
      final result = await _service.addBeneficiary(request);
      await fetchBeneficiaries();
      _setLoading(false);
      return result;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteBeneficiary(int id) async {
    try {
      _setLoading(true);
      final result = await _service.deleteBeneficiary(id);
      await fetchBeneficiaries();
      _setLoading(false);
      return result;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<CardPayOutInitiateResponse> initiatePayout(CardPayOutInitiateRequest request) async {
    try {
      _setLoading(true);
      final result = await _service.initiatePayout(request);
      await fetchBalance();
      _setLoading(false);
      return result;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<CardPayOutStatus?> getStatus(String ref) async {
    try {
      _setLoading(true);
      final status = await _service.getStatus(ref);
      _setLoading(false);
      return status;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<Map<String, dynamic>?> getReceipt(String ref) async {
    try {
      final result = await _service.getReceipt(ref);
      return result;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  Future<void> fetchHistory({
    String? status,
    String? from,
    String? to,
  }) async {
    try {
      _setLoading(true);
      final result = await _service.getHistory(
        status: status,
        from: from,
        to: to,
      );
      _transactions = result['transactions'] ?? [];
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _transactions = [];
    }
  }

  // ========== HELPERS ==========

  void _setLoading(bool loading) {
    _isLoading = loading;
    if (loading) _errorMessage = null;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _isLoading = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _isLoading = false;
    _errorMessage = null;
    _balance = 0.0;
    _beneficiaries = [];
    _transactions = [];
    _limits = null;
    notifyListeners();
  }
}