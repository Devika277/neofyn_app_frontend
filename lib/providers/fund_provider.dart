// lib/providers/fund_provider.dart

import 'package:flutter/foundation.dart';
import '../services/bbps/api_service.dart';
import 'dart:io';

class FundProvider extends ChangeNotifier {
  // ─── State ──────────────────────────────────────────────────────────────
  bool _isSubmitting = false;
  String? _submitError;
  List<dynamic> _myRequests = [];
  bool _isLoadingRequests = false;
  String? _requestsError;
  bool _isCancelling = false;
  String? _cancelError;

  // ─── Getters ────────────────────────────────────────────────────────────
  bool get isSubmitting => _isSubmitting;
  String? get submitError => _submitError;
  List<dynamic> get myRequests => _myRequests;
  bool get isLoadingRequests => _isLoadingRequests;
  String? get requestsError => _requestsError;
  bool get isCancelling => _isCancelling;
  String? get cancelError => _cancelError;

  // ─── Submit Fund Request ───────────────────────────────────────────────
  Future<bool> submitFundRequest({
    required double amount,
    required String paymentMode,
    required String bankName,
    required String referenceNumber,
    required String remark,
    File? receiptFile, // For future use when API supports file upload
  }) async {
    try {
      _isSubmitting = true;
      _submitError = null;
      notifyListeners();

      // Prepare request body matching your API
      final Map<String, dynamic> requestBody = {
        'amount': amount,
        'payment_mode': paymentMode.toUpperCase(),
        'bank_name': bankName,
        'reference_number': referenceNumber,
        'remark': remark,
      };

      print('📤 Submitting fund request...');
      print('   Body: $requestBody');

      // Use ApiService to make the request
      final response = await ApiService.post('/api/fund/request', requestBody);

      print('✅ Fund request submitted successfully!');
      print('   Response: $response');

      _isSubmitting = false;
      notifyListeners();

      // Refresh the list after successful submission
      await getMyRequests();

      return true;
    } on ApiException catch (e) {
      print('❌ API Error: ${e.message}');
      _submitError = e.message;
      _isSubmitting = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Submit error: $e');
      _submitError = 'Network error. Please check your connection.';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Get User's Requests ──────────────────────────────────────────────
  Future<List<dynamic>> getMyRequests() async {
    try {
      _isLoadingRequests = true;
      _requestsError = null;
      notifyListeners();

      print('📤 Fetching user fund requests...');
      
      final response = await ApiService.get('/api/fund/user');
      
      // Extract data from response
      final data = response['data'] ?? [];
      _myRequests = data;
      
      print('✅ Fetched ${_myRequests.length} requests');
      
      _isLoadingRequests = false;
      notifyListeners();
      
      return _myRequests;
    } on ApiException catch (e) {
      print('❌ API Error fetching requests: ${e.message}');
      _requestsError = e.message;
      _isLoadingRequests = false;
      notifyListeners();
      return [];
    } catch (e) {
      print('❌ Fetch requests error: $e');
      _requestsError = 'Failed to load requests';
      _isLoadingRequests = false;
      notifyListeners();
      return [];
    }
  }

  // ─── Cancel Fund Request ──────────────────────────────────────────────
  Future<bool> cancelRequest(int requestId) async {
    try {
      _isCancelling = true;
      _cancelError = null;
      notifyListeners();

      print('📤 Cancelling request #$requestId');
      
      final response = await ApiService.post('/api/fund/cancel/$requestId', {});
      
      print('✅ Request cancelled successfully');
      
      _isCancelling = false;
      notifyListeners();

      // Refresh the list after cancellation
      await getMyRequests();
      
      return true;
    } on ApiException catch (e) {
      print('❌ API Error cancelling: ${e.message}');
      
      // Check specific error messages
      if (e.message.contains('within 2 hours')) {
        _cancelError = 'Requests can only be cancelled within 2 hours of submission';
      } else if (e.message.contains('pending')) {
        _cancelError = 'Only pending requests can be cancelled';
      } else {
        _cancelError = e.message;
      }
      
      _isCancelling = false;
      notifyListeners();
      return false;
    } catch (e) {
      print('❌ Cancel error: $e');
      _cancelError = 'Failed to cancel request';
      _isCancelling = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Clear Errors ─────────────────────────────────────────────────────
  void clearErrors() {
    _submitError = null;
    _requestsError = null;
    _cancelError = null;
    notifyListeners();
  }

  // ─── Reset State ──────────────────────────────────────────────────────
  void reset() {
    _isSubmitting = false;
    _submitError = null;
    _myRequests = [];
    _isLoadingRequests = false;
    _requestsError = null;
    _isCancelling = false;
    _cancelError = null;
    notifyListeners();
  }
}