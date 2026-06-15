import 'dart:developer' as DebugLogger;
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/AEPS/aeps_service.dart' as aeps;   // ✅ prefix added
import '../services/AEPS/auth_service.dart';

class AepsProvider extends ChangeNotifier {
  final aeps.AepsService _aepsService = aeps.AepsService();
  final AuthService _authService = AuthService();

  // State variables – using prefixed types
  List<aeps.Bank> _banks = [];
  List<aeps.State> _states = [];           // ✅ now aeps.State
  List<aeps.District> _districts = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Merchant data
  String? _merchantId;
  String? _merchantRefId;
  String? _mobileNo;
  String? _aadhaarNo;

  // Auth fields
  String? _authToken;
  String? _userId;
  String? _ipAddress;
  String? _pipe = '1';

  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'auth_user_id';
  String? _realMerchantId;

  // Daily 2FA
  bool _is2FAVerifiedToday = false;
  String? _last2FADate;
  static const String _keyLast2FADate = 'last_2fa_date';

  // Getters
  List<aeps.Bank> get banks => _banks;
  List<aeps.State> get states => _states;
  List<aeps.District> get districts => _districts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get merchantId => _merchantId;
  String? get merchantRefId => _merchantRefId;
  String? get mobileNo => _mobileNo;
  String? get aadhaarNo => _aadhaarNo;
  bool get is2FAVerifiedToday => _is2FAVerifiedToday;
  bool get isMerchantActive => _merchantId != null && _merchantId!.isNotEmpty;
  String? get realMerchantId => _realMerchantId;
  String? get ipAddress => _ipAddress;
  String? get pipe => _pipe;

  // ----------------------------------------------------------------------
  // Initialization & Persistence
  // ----------------------------------------------------------------------
  Future<void> init() async {
    await _loadPersistedData();
  }

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _last2FADate = prefs.getString(_keyLast2FADate);
      _authToken = prefs.getString(_keyAuthToken);
      _userId = prefs.getString(_keyUserId);

      DebugLogger.log('📦 _loadPersistedData:');
      DebugLogger.log('   _last2FADate : $_last2FADate');
      DebugLogger.log('   _authToken   : ${_authToken != null ? "${_authToken!.substring(0, 20)}..." : "NULL ❌"}');
      DebugLogger.log('   _userId      : ${_userId ?? "NULL ❌"}');

      final today = DateTime.now().toIso8601String().split('T')[0];
      _is2FAVerifiedToday = _last2FADate == today;
    } catch (e) {
      DebugLogger.log('❌ Error loading persisted data: $e');
    }
  }

  Future<void> _persistAuthToken(String token, String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, token);
      await prefs.setString(_keyUserId, userId);
      DebugLogger.log('💾 Auth details persisted');
    } catch (e) {
      DebugLogger.log('❌ Failed to persist auth details: $e');
    }
  }

  Future<void> _saveLast2FADate(String date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLast2FADate, date);
      DebugLogger.log('💾 Saved last 2FA date: $date');
    } catch (e) {
      DebugLogger.log('❌ Error saving last 2FA date: $e');
    }
  }

  Future<void> _getLocalIp() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      _ipAddress = (ip != null && ip.isNotEmpty) ? ip : '127.0.0.1';
    } catch (e) {
      _ipAddress = '127.0.0.1';
    }
    notifyListeners();
  }

  // ----------------------------------------------------------------------
  // Auth & Merchant Data
  // ----------------------------------------------------------------------
  void setAuthDetails({
    required String token,
    required String userId,
    required String merchantId,
    String? mobileNo,
    String? pipe,
  }) {
    DebugLogger.log('🔐 setAuthDetails called');
    _authToken = token;
    _userId = userId;
    _merchantId = merchantId;
    _mobileNo = mobileNo;
    _pipe = pipe ?? '1';
    _getLocalIp();
    _persistAuthToken(token, userId);
    notifyListeners();
  }

  Future<void> loadMerchantData() async {
    final data = await _authService.getMerchantData();
    _merchantId = data['merchantId'];
    _merchantRefId = data['merchantRefId'];
    _mobileNo = data['mobileNo'];
    _aadhaarNo = data['aadhaarNo'];
    notifyListeners();
  }

  void setMerchantData(Map<String, dynamic> merchant) {
    _merchantId = merchant['merchantId']?.toString();
    _merchantRefId = merchant['merchantRefId']?.toString();
    _mobileNo = merchant['phone']?.toString();
    _aadhaarNo = merchant['aadhaarNo']?.toString();
    _last2FADate = null;
    _is2FAVerifiedToday = false;
    _authService.saveMerchantData(
      merchantId: _merchantId ?? '',
      merchantRefId: _merchantRefId ?? '',
      mobileNo: _mobileNo ?? '',
      aadhaarNo: _aadhaarNo,
    );
    notifyListeners();
  }

  Future<void> fetchMerchantByPhone(String phone) async {
    DebugLogger.log('fetchMerchantByPhone not implemented in AepsService');
  }

  bool needs2FA() {
    if (_merchantId == null || _merchantId!.isEmpty) return false;
    final today = DateTime.now().toIso8601String().split('T')[0];
    return _last2FADate != today;
  }

  Future<bool> performDaily2FA(
    String pidData, {
    String deviceType = 'mantra',
    String? aadhaarNumber,
    String? merchantRefId,
  }) async {
    if (_merchantId == null) return false;
    final aadhaar = aadhaarNumber ?? _aadhaarNo;
    if (aadhaar == null || aadhaar.isEmpty) {
      _errorMessage = 'Aadhaar number is required';
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      await _aepsService.perform2FA(
        aeps.Perform2FARequest(
          merchantId: _merchantId!,
          merchantRefId: merchantRefId ?? '2FA_${DateTime.now().millisecondsSinceEpoch}',
          aadhaarNumber: aadhaar,
          pipe: _pipe,
          deviceType: deviceType,
          pidData: pidData,
          lat: null,
          long: null,
        ),
      );

      final today = DateTime.now().toIso8601String().split('T')[0];
      _last2FADate = today;
      _is2FAVerifiedToday = true;
      _errorMessage = null;
      await _saveLast2FADate(today);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearMerchantData() async {
    await _authService.clearMerchantData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAuthToken);
    await prefs.remove(_keyUserId);
    _merchantId = null;
    _merchantRefId = null;
    _mobileNo = null;
    _aadhaarNo = null;
    _is2FAVerifiedToday = false;
    _last2FADate = null;
    _authToken = null;
    _userId = null;
    _ipAddress = null;
    _pipe = '1';
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ----------------------------------------------------------------------
  // AEPS Data Fetching (using AepsService)
  // ----------------------------------------------------------------------
  Future<void> fetchBanks() async {
    _isLoading = true;
    notifyListeners();
    try {
      _banks = await _aepsService.getBanks();
      DebugLogger.log('✅ Banks loaded: ${_banks.length}');
    } catch (e) {
      DebugLogger.log('❌ fetchBanks error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStates() async {
    _isLoading = true;
    notifyListeners();
    try {
      _states = await _aepsService.getStates();
      DebugLogger.log('✅ States loaded: ${_states.length}');
    } catch (e) {
      DebugLogger.log('❌ fetchStates error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isLoadingDistricts = false;
  bool get isLoadingDistricts => _isLoadingDistricts;

  Future<void> fetchDistricts(String stateCode) async {
    _isLoadingDistricts = true;
    notifyListeners();
    try {
      _districts = await _aepsService.getDistricts(stateCode);
    } catch (e) {
      _errorMessage = e.toString();
      _districts = [];
    } finally {
      _isLoadingDistricts = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------------
  // Merchant Registration & OTP
  // ----------------------------------------------------------------------
  Future<bool> registerMerchant(MerchantRegistrationRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final regRequest = aeps.RegisterMerchantRequest(
        stateCode: request.merchantState,
        districtCode: request.merchantDistrict,
        shopAddress: request.shopAddress,
        shopPincode: request.shopPinCode,
        bankAccount: request.bankAccountNumber,
        bankIfsc: request.bankIfscCode,
        bankNameCode: request.bankName,
        pipe: _pipe,
        merchantRefId: request.mobileNo,
        ipAddress: _ipAddress ?? '127.0.0.1',
        lat: request.lat.toString(),
        long: request.long.toString(),
        firstName: request.firstName,
        lastName: request.lastName,
        middleName: request.middleName,
        dob: request.dob,
        merchantPhoneNumber: request.mobileNo,
        merchantAddress1: request.merchantAddress1,
        merchantAddress2: request.merchantAddress2,
        merchantPan: request.panNo,
        shopPan: request.shopPan,
        aadhaarNo: request.aadhaarNo,
        pidData: null,
      );
      final response = await _aepsService.registerMerchant(regRequest);
      _merchantId = response.merchantId;
      _merchantRefId = response.merchantRefId ?? request.mobileNo;
      _mobileNo = request.mobileNo;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendOtp(String merchantId, String mobileNo) async {
    _isLoading = true;
    try {
      final response = await _aepsService.sendOTP(
        aeps.OtpRequest(
          merchantId: merchantId,
          merchantRefId: 'OTP_${DateTime.now().millisecondsSinceEpoch}',
          pipe: _pipe,
        ),
      );
      return response.status == '000';
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String merchantId, String otp, String merchantRefId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _aepsService.verifyOTP(
        aeps.VerifyOtpRequest(
          merchantId: merchantId,
          merchantRefId: merchantRefId,
          otp: otp,
          pipe: _pipe,
        ),
      );
      return response.status == '000';
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------------------
  // Transactions
  // ----------------------------------------------------------------------
  Future<TransactionResponse?> executeTransaction(AepsTransactionRequest request) async {
    if (_authToken == null || _authToken!.isEmpty) {
      _errorMessage = 'Auth token missing. Please logout and login again.';
      return null;
    }
    if (_userId == null || _userId!.isEmpty) {
      _errorMessage = 'User ID missing. Please logout and login again.';
      return null;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _aepsService.cashWithdrawal(
        aeps.CashWithdrawalRequest(
          amount: int.parse(request.amount),
          bankCode: request.bankIIN,
          pidData: request.pidData,
          accountType: null,
          lat: null,
          long: null,
          device: request.deviceType,
          aadhaarNo: request.aadhaarNumber,
          mobileNo: request.mobileNo,
          pipe: _pipe,
        ),
      );
      return TransactionResponse(
        status: response.status,
        statusDescription: response.statusDescription,
        txnRefId: response.txnRefId,
      );
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TransactionResponse?> performAepsTransaction({
    required String merchantId,
    required String transactionType,
    required String aadhaarNumber,
    required String bankIIN,
    required String amount,
    required String pidData,
    required String deviceType,
    required String merchantRefId,
    required String mobileNo,
  }) async {
    if (_merchantId == null) throw Exception('Merchant ID not set');
    if (_authToken == null || _authToken!.isEmpty) {
      await _loadPersistedData();
    }
    if (_ipAddress == null) await _getLocalIp();
    _pipe ??= '1';

    final request = AepsTransactionRequest(
      transactionType: transactionType,
      amount: amount,
      aadhaarNumber: aadhaarNumber,
      bankIIN: bankIIN,
      merchantId: _merchantId!,
      mobileNo: mobileNo,
      ipAddress: _ipAddress!,
      pidData: pidData,
      pipe: _pipe!,
      merchantRefId: merchantRefId,
      deviceType: deviceType,
    );
    return await executeTransaction(request);
  }

  Future<Map<String, dynamic>> getTransactionStatus(String merchantId, String merchantRefId) async {
    DebugLogger.log('getTransactionStatus not implemented in AepsService');
    return {'success': false};
  }

  void setMobileNo(String mobile) {
    _mobileNo = mobile;
    notifyListeners();
  }
}

// =========================================================================
// Models that are NOT defined in aeps_service.dart (stay here)
// =========================================================================

class MerchantRegistrationRequest {
  final String firstName;
  final String middleName;
  final String lastName;
  final String dob;
  final String emailId;
  final String mobileNo;
  final String aadhaarNo;
  final String panNo;
  final String merchantAddress1;
  final String merchantAddress2;
  final String merchantState;
  final String merchantDistrict;
  final String merchantPinCode;
  final String shopPan;
  final String bankAccountNumber;
  final String bankIfscCode;
  final String bankName;
  final String accountType;
  final String shopAddress;
  final String shopDistrict;
  final String shopState;
  final String shopPinCode;
  final double shopLat;
  final double shopLong;
  final double lat;
  final double long;
  final String ipAddress;
  final String merchantRefId;
  final String pipe;
  final String gender;

  MerchantRegistrationRequest({
    required this.firstName,
    required this.lastName,
    required this.emailId,
    required this.mobileNo,
    required this.aadhaarNo,
    required this.panNo,
    required this.shopAddress,
    required this.gender,
    required this.shopLat,
    required this.shopLong,
    required this.middleName,
    required this.dob,
    required this.merchantAddress1,
    required this.merchantAddress2,
    required this.merchantState,
    required this.merchantDistrict,
    required this.merchantPinCode,
    required this.shopPan,
    required this.bankAccountNumber,
    required this.bankIfscCode,
    required this.bankName,
    required this.accountType,
    required this.shopDistrict,
    required this.shopState,
    required this.shopPinCode,
    required this.lat,
    required this.long,
    required this.ipAddress,
    required this.merchantRefId,
    required this.pipe,
  });

  Map<String, dynamic> toJson() => {
        "firstName": firstName,
        "middleName": middleName,
        "lastName": lastName,
        "dob": dob,
        "emailId": emailId,
        "mobileNo": mobileNo,
        "aadhaarNo": aadhaarNo,
        "panNo": panNo,
        "merchantAddress1": merchantAddress1,
        "merchantAddress2": merchantAddress2,
        "merchantState": merchantState,
        "merchantDistrict": merchantDistrict,
        "merchantPinCode": merchantPinCode,
        "shopPan": shopPan,
        "bankAccountNumber": bankAccountNumber,
        "bankIfscCode": bankIfscCode,
        "bankName": bankName,
        "accountType": accountType,
        "shopAddress": shopAddress,
        "shopDistrict": shopDistrict,
        "shopState": shopState,
        "shopPinCode": shopPinCode,
        "shopLat": shopLat,
        "shopLong": shopLong,
        "lat": lat,
        "long": long,
        "ipAddress": ipAddress,
        "merchantRefId": merchantRefId,
        "pipe": pipe,
        "gender": gender,
      };
}

class AepsTransactionRequest {
  final String transactionType;
  final String amount;
  final String aadhaarNumber;
  final String bankIIN;
  final String merchantId;
  final String mobileNo;
  final String ipAddress;
  final String pidData;
  final String pipe;
  final String merchantRefId;
  final String deviceType;

  AepsTransactionRequest({
    required this.transactionType,
    required this.amount,
    required this.aadhaarNumber,
    required this.bankIIN,
    required this.merchantId,
    required this.mobileNo,
    required this.ipAddress,
    required this.pidData,
    required this.pipe,
    required this.merchantRefId,
    required this.deviceType,
  });

  Map<String, dynamic> toJson() => {
        'serviceType': transactionType,
        'merchantId': merchantId,
        'aadhaarNumber': aadhaarNumber,
        'bankIIN': bankIIN,
        'pidData': pidData,
        'mobileNo': mobileNo,
        'amount': amount,
        'deviceType': deviceType,
        'merchantRefId': merchantRefId,
        'ipAddress': ipAddress,
        'pipe': pipe,
        'latitude': '0',
        'longitude': '0',
      };
}

class TransactionResponse {
  final String status;
  final String? statusDescription;
  final String? rrn;
  final String? txnRefId;
  final String? availableBalance;
  final String? npciMessage;
  final String? responseCode;

  TransactionResponse({
    required this.status,
    this.statusDescription,
    this.rrn,
    this.txnRefId,
    this.availableBalance,
    this.npciMessage,
    this.responseCode,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> json) => TransactionResponse(
        status: json['status']?.toString() ?? json['responseCode']?.toString() ?? '',
        statusDescription: json['statusDescription'] ?? json['message'],
        rrn: json['rrn']?.toString(),
        txnRefId: json['txnRefId']?.toString(),
        availableBalance: json['availableBalance']?.toString(),
        npciMessage: json['npciMessage']?.toString(),
        responseCode: json['responseCode']?.toString(),
      );
}