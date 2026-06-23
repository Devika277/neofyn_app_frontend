// providers/beneficiary_provider.dart

import 'package:flutter/material.dart';
import 'package:my_app/models/beneficiary_model.dart';
import '../services/payout/payout_service.dart';

class BeneficiaryProvider extends ChangeNotifier {
  List<Beneficiary> _beneficiaries = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<Beneficiary> get beneficiaries => _beneficiaries;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  final PayoutService _payoutService = PayoutService();

  // ✅ Load beneficiaries from BACKEND
  Future<void> loadBeneficiaries() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final result = await _payoutService.getBeneficiaries();
      if (result is List) {
        _beneficiaries = result;
      } else {
        _beneficiaries = [];
      }
      print('✅ Loaded ${_beneficiaries.length} beneficiaries from backend');
    } catch (e) {
      _errorMessage = e.toString();
      _beneficiaries = [];
      print('❌ Load beneficiaries error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ✅ Add beneficiary to BACKEND
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

  // ✅ Update beneficiary
  Future<void> updateBeneficiary(Beneficiary beneficiary) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _payoutService.updateBeneficiary(beneficiary);
      await loadBeneficiaries();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ Delete beneficiary from BACKEND
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
}