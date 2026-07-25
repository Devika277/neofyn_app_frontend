import 'package:flutter/foundation.dart';
import '../services/matm_service.dart';

/// Provider class for managing mATM state
class MatmProvider extends ChangeNotifier {
  MatmResponse? _lastResponse;
  MatmException? _lastError;
  bool _isLoading = false;

  MatmResponse? get lastResponse => _lastResponse;
  MatmException? get lastError => _lastError;
  bool get isLoading => _isLoading;

  /// Perform balance enquiry
  Future<MatmResponse?> balanceEnquiry(String merchantId) async {
    _setLoading(true);
    _clearErrors();
    
    try {
      final response = await MatmService.balanceEnquiry(merchantId);
      _lastResponse = response;
      _setLoading(false);
      notifyListeners();
      return response;
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  /// Perform cash withdrawal
  Future<MatmResponse?> cashWithdrawal(String merchantId, String amount) async {
    _setLoading(true);
    _clearErrors();
    
    try {
      final response = await MatmService.cashWithdrawal(merchantId, amount);
      _lastResponse = response;
      _setLoading(false);
      notifyListeners();
      return response;
    } catch (e) {
      _handleError(e);
      return null;
    }
  }

  /// Clear last response and error
  void clear() {
    _lastResponse = null;
    _lastError = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearErrors() {
    _lastError = null;
  }

  void _handleError(dynamic error) {
    _setLoading(false);
    if (error is MatmException) {
      _lastError = error;
    } else {
      _lastError = MatmException(error.toString(), 'UNKNOWN');
    }
    notifyListeners();
    debugPrint('mATM Error: ${_lastError}');
  }
}