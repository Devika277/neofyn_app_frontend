import 'dart:io';

import 'package:flutter/foundation.dart';
import '../services/wallet_service.dart';
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
  }
  String get userId => _userId ?? '';
  String? get userName => _userName;

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



      // also refresh ledger and fund requests
      ledger       = await _service.fetchLedger(_userId!);
      fundRequests = await _service.fetchFundRequests(_userId!);
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
    required String userId,   // ← ADD THIS
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
    isSubmitting  = true;
    submitSuccess = null;
    submitError   = null;
    notifyListeners();

    try {
      final result = await _service.submitFundRequest(
        userId:          userId,
        amount:          amount,
        paymentMode:     paymentMode,
        bankName:        bankName,
        referenceNumber: referenceNumber,
        payDate:         payDate,
        remark:          remark,
        receiptFile:     receiptFile,
      );
      
      print('📦 submitFundRequest raw response: $result');  // ADD THIS

    if (result['success'] == true) {
      submitSuccess = result['message'];
      fundRequests  = await _service.fetchFundRequests(_userId ?? userId);
      return true;
    } else {
      submitError = result['message'] ?? 'Submission failed';
      return false;
    }
  } catch (e, stack) {
    print('❌ provider submitFundRequest error: $e');  // ADD THIS
    print(stack);
    submitError = e.toString();
    return false;
  } finally {
    isSubmitting = false;
    notifyListeners();
  }
}

  double get totalBalance => (mainWallet?.balance ?? 0) + (aepsWallet?.balance ?? 0);

  // String? get userName => null;
}