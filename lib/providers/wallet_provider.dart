import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/wallet_service.dart';
import '../services/commission/commission_service.dart'; // ✅ ADD THIS
import '../models/wallet_models.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _service = WalletService();
  
  MainWallet? mainWallet;
  AepsWallet? aepsWallet;
  WalletStats? stats;
  bool isLoading = false;
  String? _userId;   // private, set via setUserId
  String? _userName;  // ✅ ADD THIS

  List<dynamic> ledger       = [];
  List<dynamic> fundRequests = [];

  bool isSubmitting    = false; // for fund request form submit button
  String? error;
  String? submitSuccess;
  String? submitError;

  // ─── Commission Balance ────────────────────────────────────────────────────
  double _commissionBalance = 0.0;
  double _commissionFrozen = 0.0;
  bool _isLoadingCommission = false;
  
  double get commissionBalance => _commissionBalance;
  double get commissionFrozen => _commissionFrozen;
  double get availableCommission => _commissionBalance - _commissionFrozen;
  bool get isLoadingCommission => _isLoadingCommission;

  WalletProvider() {
    print("WalletProvider instance created");
  }

  void setUserName(String name) {
    _userName = name;
    notifyListeners();
  }

  void setUserId(String id) {
    print("setUserId called with id: $id");
    _userId = id;
    fetchAllWalletData();
    fetchCommissionBalance(); // ✅ Also fetch commission balance
  }

  String get userId => _userId ?? '';
  String? get userName => _userName;

  // ─── Fetch Commission Balance ────────────────────────────────────────────
  // providers/wallet_provider.dart

Future<void> fetchCommissionBalance() async {
  if (_userId == null || _userId!.isEmpty) {
    print('⚠️ UserId is null, cannot fetch commission balance.');
    return;
  }
  
  print('💰 Fetching commission balance for userId: $_userId');
  _isLoadingCommission = true;
  notifyListeners();

  try {
    print('📤 Calling CommissionService.getBalance()...');
    final response = await CommissionService.getBalance();
    print('📥 Commission balance response: $response');
    
    if (response['success'] == true) {
      final data = response['data'] ?? {};
      
      // ✅ The data is already parsed as double from the service
      _commissionBalance = data['balance'] ?? 0.0;
      _commissionFrozen = data['frozen'] ?? 0.0;
      
      print('✅ Commission balance updated:');
      print('   Balance: $_commissionBalance');
      print('   Frozen: $_commissionFrozen');
    } else {
      print('❌ Failed to fetch commission balance: ${response['message']}');
      _commissionBalance = 0.0;
      _commissionFrozen = 0.0;
    }
  } catch (e) {
    print('❌ Error fetching commission balance: $e');
    _commissionBalance = 0.0;
    _commissionFrozen = 0.0;
  } finally {
    _isLoadingCommission = false;
    notifyListeners();
  }
}

  // ─── Fetch All Wallet Data ──────────────────────────────────────────────
  Future<void> fetchAllWalletData() async {
    if (_userId == null) {
      print('⚠️ UserId is null, cannot fetch wallet data.');
      return;
    }
    print('🚀 Fetching wallet data for userId: $_userId');
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final mainData = await _service.fetchMainWalletBalance(_userId!);
      print('🏦 Main wallet data: $mainData');
      mainWallet = MainWallet.fromJson(mainData);

      final aepsData = await _service.fetchAepsWalletBalance(_userId!);
      print('🏧 AEPS wallet data: $aepsData');
      aepsWallet = AepsWallet.fromJson(aepsData);

      final statsData = await _service.fetchStats(_userId!);
      stats = WalletStats.fromJson(statsData);

      // Also refresh ledger and fund requests
      ledger = await _service.fetchLedger(_userId!);
      fundRequests = await _service.fetchFundRequests(_userId!);
      
      // ✅ Fetch commission balance after wallet data
      await fetchCommissionBalance();
      
    } catch (e) {
      print('❌ Error fetching wallet data: $e');
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ── Submit fund request ────────────────────────────────────────────────────
  Future<bool> submitFundRequest({
    required String userId,
    required double amount,
    required String paymentMode,
    required String bankName,
    required String referenceNumber,
    required String payDate,
    String? remark,
    File? receiptFile,
  }) async {
    print('📦 provider userId at submit: $userId');
    
    if (userId.isEmpty) {
      print('❌ userId is EMPTY');
      return false;
    }

    if (_userId == null) return false;
    isSubmitting = true;
    submitSuccess = null;
    submitError = null;
    notifyListeners();

    try {
      final result = await _service.submitFundRequest(
        userId: userId,
        amount: amount,
        paymentMode: paymentMode,
        bankName: bankName,
        referenceNumber: referenceNumber,
        payDate: payDate,
        remark: remark,
        receiptFile: receiptFile,
      );
      
      print('📦 submitFundRequest raw response: $result');

      if (result['success'] == true) {
        submitSuccess = result['message'];
        fundRequests = await _service.fetchFundRequests(_userId ?? userId);
        // ✅ Refresh commission balance after fund request
        await fetchCommissionBalance();
        return true;
      } else {
        submitError = result['message'] ?? 'Submission failed';
        return false;
      }
    } catch (e, stack) {
      print('❌ provider submitFundRequest error: $e');
      print(stack);
      submitError = e.toString();
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  // ─── Refresh Commission Balance Only ─────────────────────────────────────
  Future<void> refreshCommissionBalance() async {
    await fetchCommissionBalance();
  }

  // ─── Refresh All Data ────────────────────────────────────────────────────
  Future<void> refreshAllData() async {
    if (_userId != null) {
      await fetchAllWalletData();
    }
  }

  double get totalBalance => (mainWallet?.balance ?? 0) + (aepsWallet?.balance ?? 0);
}