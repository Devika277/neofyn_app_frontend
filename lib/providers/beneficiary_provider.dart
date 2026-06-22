// providers/beneficiary_provider.dart

import 'package:flutter/material.dart';
import 'package:my_app/models/beneficiary_model.dart';
import '../services/payout/payout_service.dart';  // ✅ Use consistent path

class BeneficiaryProvider extends ChangeNotifier {
  List<Beneficiary> _beneficiaries = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<Beneficiary> get beneficiaries => _beneficiaries;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // ✅ DECLARE the payout service instance
  final PayoutService _payoutService = PayoutService();

  // ✅ Load beneficiaries from local storage
  Future<void> loadBeneficiaries() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await _payoutService.getLocalBeneficiaries();
      if (result is List) {
        _beneficiaries = result;
      } else {
        _beneficiaries = [];
      }
      print('✅ Loaded ${_beneficiaries.length} beneficiaries from local storage');
    } catch (e) {
      _errorMessage = e.toString();
      _beneficiaries = [];
      print('❌ Load beneficiaries error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ✅ Add beneficiary (local storage)
  Future<void> addBeneficiary(Beneficiary beneficiary) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _payoutService.saveBeneficiary(beneficiary);
      await loadBeneficiaries();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Delete beneficiary (local storage)
  Future<void> deleteBeneficiary(String beneficiaryId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _payoutService.deleteBeneficiary(beneficiaryId);
      await loadBeneficiaries();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Clear error message
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  // ✅ Reset provider state
  void reset() {
    _beneficiaries = [];
    _isLoading = false;
    _errorMessage = '';
    notifyListeners();
  }

  Future<void> updateBeneficiary(Beneficiary beneficiary) async {}
}