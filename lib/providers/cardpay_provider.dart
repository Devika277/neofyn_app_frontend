// lib/providers/cardpay_provider.dart
import 'package:flutter/material.dart';
import '../models/cardpay_models.dart';
import '../services/cardpay/card_pay_service.dart';
import 'package:url_launcher/url_launcher.dart';

class CardPayProvider extends ChangeNotifier {
  final CardPayService _service = CardPayService();

  // State variables
  bool _isLoading = false;
  String? _errorMessage;
  double _walletBalance = 0.0;
  List<CardPayTransaction> _transactions = [];
  List<CardPayWalletLedger> _ledgerEntries = [];
  CardPayUserBalance? _userBalance;
  List<String> _states = [];
  int _totalTransactions = 0;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get walletBalance => _walletBalance;
  List<CardPayTransaction> get transactions => _transactions;
  List<CardPayWalletLedger> get ledgerEntries => _ledgerEntries;
  CardPayUserBalance? get userBalance => _userBalance;
  List<String> get states => _states;
  int get totalTransactions => _totalTransactions;

  // ─── User Methods ──────────────────────────────────────────

  /// Initialize card pay data
  Future<void> initializeCardPay() async {
    try {
      _setLoading(true);
      await Future.wait([
        fetchWalletBalance(),
        fetchUserBalance(),
        fetchStates(),
      ]);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Fetch wallet balance
  Future<void> fetchWalletBalance() async {
    try {
      _walletBalance = await _service.getWalletBalance();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Fetch user balance (card pay + main)
  Future<void> fetchUserBalance() async {
    try {
      _userBalance = await _service.getUserBalance();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Fetch states
  Future<void> fetchStates() async {
    try {
      _states = await _service.getStateList();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Initiate payment
  Future<CardPayInitiateResponse?> initiatePayment({
    required double amount,
    required String mobile,
    required String name,
    required String email,
    required String location,
    required String lat,
    required String long,
    String? udf1,
    String? udf2,
    String? udf3,
  }) async {
    try {
      _setLoading(true);
      final request = CardPayInitiateRequest(
        amount: amount,
        mobile: mobile,
        name: name,
        email: email,
        location: location,
        lat: lat,
        long: long,
        udf1: udf1,
        udf2: udf2,
        udf3: udf3,
      );
      final response = await _service.initiatePayment(request);
      _setLoading(false);
      return response;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Check transaction status
  Future<CardPayTransaction?> checkStatus(String ref) async {
    try {
      _setLoading(true);
      final transaction = await _service.checkStatus(ref);
      _setLoading(false);
      return transaction;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Get transaction history
Future<void> fetchUserHistory({
  String? status,
  String? startDate,
  String? endDate,
  String? search,
  int limit = 20,
  int offset = 0,
}) async {
  try {
    _setLoading(true);
    final result = await _service.getUserHistory(
      status: status,
      startDate: startDate,
      endDate: endDate,
      search: search,
      limit: limit,
      offset: offset,
    );
    
    // Ensure we're assigning the correct type
    final transactionsData = result['transactions'];
    if (transactionsData is List) {
      _transactions = transactionsData.cast<CardPayTransaction>();
    } else {
      _transactions = [];
    }
    
    _totalTransactions = result['total'] ?? 0;
    _setLoading(false);
  } catch (e) {
    _setError(e.toString());
    _transactions = [];
    _totalTransactions = 0;
  }
}

  /// Get wallet ledger
  Future<void> fetchLedger({int limit = 50, int offset = 0}) async {
    try {
      _setLoading(true);
      _ledgerEntries = await _service.getCardPayLedger(
        limit: limit,
        offset: offset,
      );
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Move funds to main wallet
  Future<Map<String, dynamic>?> moveToMain(double amount) async {
    try {
      _setLoading(true);
      final result = await _service.moveToMain(amount);
      await fetchWalletBalance();
      await fetchUserBalance();
      _setLoading(false);
      return result;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Get receipt
  Future<Map<String, dynamic>?> getReceipt(String ref) async {
    try {
      // Don't set loading to avoid UI issues
      final result = await _service.getReceipt(ref);
      return result;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  // ─── Admin Methods ─────────────────────────────────────────

  /// Admin: Get dashboard
  Future<CardPayDashboard?> getDashboard() async {
    try {
      _setLoading(true);
      final dashboard = await _service.getDashboard();
      _setLoading(false);
      return dashboard;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Admin: Get all transactions
  Future<void> fetchAdminTransactions({
    String? status,
    String? search,
    String? startDate,
    String? endDate,
    String? userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      _setLoading(true);
      final result = await _service.getAdminTransactions(
        status: status,
        search: search,
        startDate: startDate,
        endDate: endDate,
        userId: userId,
        limit: limit,
        offset: offset,
      );
      _transactions = result['data'] ?? [];
      _totalTransactions = result['pagination']?['total'] ?? 0;
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
    }
  }

  /// Admin: Export report
  Future<String?> exportReport({
    String? status,
    String? startDate,
    String? endDate,
  }) async {
    try {
      _setLoading(true);
      final csv = await _service.exportReport(
        status: status,
        startDate: startDate,
        endDate: endDate,
      );
      _setLoading(false);
      return csv;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }


  Future<void> launchPaymentLink(String url) async {
  try {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      throw 'Could not launch $url';
    }
  } catch (e) {
    _setError('Failed to open payment link: $e');
    rethrow;
  }
}

  // ─── Helper Methods ────────────────────────────────────────

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
    _walletBalance = 0.0;
    _transactions = [];
    _ledgerEntries = [];
    _userBalance = null;
    _states = [];
    _totalTransactions = 0;
    notifyListeners();
  }
}