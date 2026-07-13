import 'dart:convert';
import 'dart:developer' as DebugLogger;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/config/api_config.dart';
import 'package:my_app/services/api_logger.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/AEPS/aeps_service.dart' as aeps;
import '../services/AEPS/auth_service.dart';

class AepsProvider extends ChangeNotifier {
  final aeps.AepsService _aepsService = aeps.AepsService();
  final AuthService _authService = AuthService();

  // State variables
  List<aeps.Bank> _banks = [];
  List<aeps.State> _states = [];
  List<aeps.District> _districts = [];
  bool _isLoading = false;
  String? _errorMessage;

  String? get authToken => _authToken;
  String? get last2FADate => _last2FADate;

  bool _isLoadingStates = false;
  bool _isLoadingBanks = false;
  List<aeps.BankIIN> _bankIINs = [];
  bool _isLoadingBankIINs = false;

  bool get isLoadingStates => _isLoadingStates;
  bool get isLoadingBanks => _isLoadingBanks;
  List<aeps.BankIIN> get bankIINs => _bankIINs;
  bool get isLoadingBankIINs => _isLoadingBankIINs;

  // Merchant data
  String? _merchantId;
  String? _merchantRefId;
  String? _mobileNo;
  String? _aadhaarNo;

  String? get userId => _userId;

  // Auth fields
  String? _authToken;
  String? _userId;
  String? _ipAddress;
  String? _pipe = '1';

  // ✅ ADD: Store error details for 409 conflicts
  String? _existingPipeNumber;
  String? get existingPipeNumber => _existingPipeNumber;

  static const String _keyAuthToken = 'aeps_auth_token';
  static const String _keyUserId = 'aeps_user_id';
  static const String _keyMerchantId = 'aeps_merchant_id';
  static const String _keyMobileNo = 'aeps_mobile_no';
  static const String _keyPipe = 'aeps_pipe';

  String? _realMerchantId;

  // Daily 2FA
  bool _is2FAVerifiedToday = false;
  String? _last2FADate;
  static const String _keyLast2FADate = 'last_2fa_date';

  // ✅ NEW: 2FA Status per pipe
  Map<String, Map<String, dynamic>> _pipes2FAStatus = {
    '1': {'merchant_id': null, 'last_2fa_at': null, '2fa_done_today': false},
    '2': {'merchant_id': null, 'last_2fa_at': null, '2fa_done_today': false},
    '3': {'merchant_id': null, 'last_2fa_at': null, '2fa_done_today': false},
  };
  bool _any2FADoneToday = false;

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

  // ✅ NEW: 2FA per-pipe getters
  Map<String, Map<String, dynamic>> get pipes2FAStatus => _pipes2FAStatus;
  bool get any2FADoneToday => _any2FADoneToday;

  bool is2FADoneForPipe(String pipe) {
    return _pipes2FAStatus[pipe]?['2fa_done_today'] ?? false;
  }

  // ✅ FIX: Make pipe settable
  String? get pipe => _pipe;
  set pipe(String? value) {
    _pipe = value ?? '1';
    print('🔄 Pipe changed to: $_pipe');
    notifyListeners();
  }

  String _activePipe = '1';

  static const String _keyMerchantRefId = 'aeps_merchant_ref_id';
  static const String _keyAadhaarNo = 'aeps_aadhaar_no';
  Map<String, Map<String, dynamic>> _pipeMerchants = {};

  // ----------------------------------------------------------------------
  // Initialization & Persistence
  // ----------------------------------------------------------------------
  Future<void> init() async {
    debugPrint('🚀 AepsProvider.init() called');
    await _loadPersistedData();
    debugPrint('✅ init() completed');
  }

  Future<void> loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString(_keyAuthToken);
    _userId = prefs.getString(_keyUserId);
    _merchantId = prefs.getString(_keyMerchantId);
    _merchantRefId = prefs.getString(_keyMerchantRefId);
    _mobileNo = prefs.getString(_keyMobileNo);
    _aadhaarNo = prefs.getString(_keyAadhaarNo);
    _pipe = prefs.getString(_keyPipe) ?? '1';
    _last2FADate = prefs.getString(_keyLast2FADate);
    _is2FAVerifiedToday =
        _last2FADate == DateTime.now().toIso8601String().split('T')[0];
    debugPrint(
      '📂 loadFromStorage: userId=$_userId, token=${_authToken != null ? "${_authToken!.substring(0, 20)}..." : "NULL"}',
    );
    notifyListeners();
  }

  void setAuthDetails({
    required String token,
    required String userId,
    required String merchantId,
    String? mobileNo,
    String? aadhaarNo,
    String? pipe,
  }) {
    debugPrint(
      '🔐 setAuthDetails called with userId: $userId, merchantId: $merchantId, pipe: $pipe',
    );
    debugPrint('🔐 token (first 20): ${token.substring(0, 20)}...');
    _authToken = token;
    _userId = userId;
    _merchantId = merchantId;
    _merchantRefId = null;
    _mobileNo = mobileNo;
    _aadhaarNo = aadhaarNo;
    _pipe = pipe ?? '1';
    _getLocalIp();
    _persistAuthData(token, userId, merchantId, mobileNo, _pipe!);
    _last2FADate = null;
    _is2FAVerifiedToday = false;
    notifyListeners();
  }

  Future<void> _persistAuthData(
      String token,
      String userId,
      String merchantId,
      String? mobileNo,
      String pipe,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAuthToken, token);
    await prefs.setString(_keyUserId, userId);
    await prefs.setString(_keyMerchantId, merchantId);
    if (mobileNo != null) await prefs.setString(_keyMobileNo, mobileNo);
    await prefs.setString(_keyPipe, pipe);
    debugPrint('💾 Auth data persisted');
  }

  void clearMerchantData() {
    _authToken = null;
    _userId = null;
    _merchantId = null;
    _merchantRefId = null;
    _mobileNo = null;
    _aadhaarNo = null;
    _pipe = null;
    _last2FADate = null;
    _is2FAVerifiedToday = false;
    // ✅ NEW: Reset 2FA per-pipe status
    _pipes2FAStatus = {
      '1': {'merchant_id': null, 'last_2fa_at': null, '2fa_done_today': false},
      '2': {'merchant_id': null, 'last_2fa_at': null, '2fa_done_today': false},
      '3': {'merchant_id': null, 'last_2fa_at': null, '2fa_done_today': false},
    };
    _any2FADoneToday = false;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_keyAuthToken);
      prefs.remove(_keyUserId);
      prefs.remove(_keyMerchantId);
      prefs.remove(_keyMobileNo);
      prefs.remove(_keyPipe);
    });
    notifyListeners();
  }

  void setActivePipe(String pipe) {
    _activePipe = pipe;
  }

  // Fetch status for a specific pipe
  Future<Map<String, dynamic>?> fetchPipeStatus(String pipe) async {
    if (_userId == null || _authToken == null) {
      debugPrint('⚠️ fetchPipeStatus: userId or authToken is null');
      return null;
    }

    final url =
        '${ApiConfig.baseUrl}/api/aeps/merchant-status?userId=$_userId&pipe=$pipe';
    debugPrint('🔎 Calling: $url');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );
      debugPrint('🔎 Response status: ${response.statusCode}');

      final body = json.decode(response.body);
      debugPrint('🔎 Raw response for pipe $pipe: ${jsonEncode(body)}');

      if (response.statusCode == 200) {
        if (body is List) {
          final match = body.firstWhere(
                (item) => item['pipe']?.toString() == pipe,
            orElse: () => null,
          );
          if (match != null && match['merchantId'] != null) {
            debugPrint('✅ Found merchant for pipe $pipe: ${match['merchantId']}');
            return match as Map<String, dynamic>;
          } else {
            debugPrint('⚠️ No merchant found for pipe $pipe');
            return null;
          }
        } else if (body is Map<String, dynamic>) {
          if (body['merchantId'] != null) {
            return body;
          } else {
            return null;
          }
        } else {
          debugPrint('⚠️ Unexpected response type for pipe $pipe');
          return null;
        }
      } else {
        debugPrint('❌ Error response: ${response.body}');
        return null;
      }
    } catch (e, stack) {
      debugPrint('❌ fetchPipeStatus error: $e');
      debugPrint('Stack trace: $stack');
      return null;
    }
  }

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _last2FADate = prefs.getString(_keyLast2FADate);
      _authToken = prefs.getString(_keyAuthToken);
      _userId = prefs.getString(_keyUserId);

      DebugLogger.log('📦 _loadPersistedData:');
      DebugLogger.log('   _last2FADate : $_last2FADate');
      DebugLogger.log(
        '   _authToken   : ${_authToken != null ? "${_authToken!.substring(0, 20)}..." : "NULL ❌"}',
      );
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

  Future<void> loadMerchantData() async {
    final data = await _authService.getMerchantData();
    _merchantId = data['merchantId'];
    _merchantRefId = data['merchantRefId'];
    _mobileNo = data['mobileNo'];
    _aadhaarNo = data['aadhaarNo'];
    notifyListeners();
  }

  String? getMerchantIdForPipe(String pipe) {
    return _pipeMerchants[pipe]?['merchantId']?.toString();
  }

  String? getMerchantRefIdForPipe(String pipe) {
    return _pipeMerchants[pipe]?['merchantRefId']?.toString();
  }

  void setMerchantData(Map<String, dynamic> merchant) {
    debugPrint('📥 setMerchantData called with: $merchant');
    _merchantId = merchant['merchantId']?.toString();
    _merchantRefId = merchant['merchantRefId']?.toString();
    _mobileNo = merchant['phone']?.toString();
    _aadhaarNo = merchant['aadhaarNo']?.toString();
    _pipe = merchant['pipe']?.toString() ?? _pipe;
    _last2FADate = null;
    _is2FAVerifiedToday = false;
    final pipe = _pipe ?? '1';
    _pipeMerchants[pipe] = {
      'merchantId': _merchantId,
      'merchantRefId': _merchantRefId,
      'phone': _mobileNo,
      'aadhaarNo': _aadhaarNo,
      'pipe': pipe,
    };
    _authService.saveMerchantData(
      merchantId: _merchantId ?? '',
      merchantRefId: _merchantRefId ?? '',
      mobileNo: _mobileNo ?? '',
      aadhaarNo: _aadhaarNo,
    );
    notifyListeners();
    debugPrint('✅ setMerchantData completed: merchantId=$_merchantId, pipe=$_pipe');
  }

  Future<void> fetchMerchantByPhone(String phone) async {
    DebugLogger.log('fetchMerchantByPhone not implemented in AepsService');
  }

  bool needs2FA() {
    if (_merchantId == null || _merchantId!.isEmpty) return false;
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (_last2FADate == today) {
      _is2FAVerifiedToday = true;
      return false;
    }
    if (_is2FAVerifiedToday) return false;
    return true;
  }

  Future<bool> performDaily2FA(
      String pidData, {
        String deviceType = 'mantra',
        String? aadhaarNumber,
        String? merchantRefId,
      }) async {
    final currentPipe = _pipe ?? '1';
    final pipeMerchantId = getMerchantIdForPipe(currentPipe) ?? _merchantId;

    if (pipeMerchantId == null) {
      _errorMessage = 'Merchant not registered for pipe $currentPipe';
      return false;
    }

    final aadhaar = aadhaarNumber ?? _aadhaarNo;
    if (aadhaar == null || aadhaar.isEmpty) {
      _errorMessage = 'Aadhaar number is required';
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      print('🔵 2FA Request: merchantId=$_merchantId, pipe=$_pipe, aadhaar=$aadhaar');
      print('🔵 merchantRefId: $merchantRefId');
      print('🔵 pidData length: ${pidData.length}');

      final response = await _aepsService.perform2FA(
        aeps.Perform2FARequest(
          merchantId: _merchantId!,
          merchantRefId: merchantRefId ??
              getMerchantRefIdForPipe(currentPipe) ??
              'NEO_${_userId}_${DateTime.now().millisecondsSinceEpoch}',
          aadhaarNumber: aadhaar,
          pipe: currentPipe,
          deviceType: deviceType,
          pidData: pidData,
        ),
      );
      print('🔵 2FA Response: ${response.status} - ${response.statusDescription}');
      if (response.status == '000') {
        final today = DateTime.now().toIso8601String().split('T')[0];
        _last2FADate = today;
        _is2FAVerifiedToday = true;
        _errorMessage = null;
        await _saveLast2FADate(today);
        // ✅ NEW: Update per-pipe 2FA status
        set2FADoneForPipe(currentPipe);
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.statusDescription ?? '2FA failed with status: ${response.status}';
        return false;
      }
    } catch (e) {
      print('❌ 2FA Exception: $e');
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ----------------------------------------------------------------------
  // AEPS Data Fetching
  // ----------------------------------------------------------------------
  Future<void> fetchBanks() async {
    _isLoadingBanks = true;
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

  Future<void> fetchBankIINs() async {
    _isLoadingBankIINs = true;
    notifyListeners();
    try {
      final rawIINs = await _aepsService.getBankIINs();
      _bankIINs = rawIINs.map((iin) => aeps.BankIIN(
        iin: (iin.iin ?? '').trim(),
        description: (iin.description ?? '').trim(),
      )).toList();
      DebugLogger.log('✅ Bank IINs loaded: ${_bankIINs.length}');
    } catch (e) {
      DebugLogger.log('❌ fetchBankIINs error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoadingBankIINs = false;
      notifyListeners();
    }
  }

  Future<void> fetchStates() async {
    _isLoadingStates = true;
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
  // ✅ FIXED: Merchant Registration - Use the pipe from the request
  // ----------------------------------------------------------------------
  // In AepsProvider, replace registerMerchant response handling:

  Future<bool> registerMerchant(MerchantRegistrationRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    _existingPipeNumber = null;
    notifyListeners();

    try {
      final requestPipe = request.pipe.isNotEmpty ? request.pipe : (_pipe ?? '1');

      final regRequest = aeps.RegisterMerchantRequest(
        stateCode: request.merchantState,
        districtCode: request.merchantDistrict,
        shopAddress: request.shopAddress,
        shopPincode: request.shopPinCode,
        bankAccount: request.bankAccountNumber,
        bankIfsc: request.bankIfscCode,
        bankNameCode: request.bankName,
        pipe: requestPipe,
        merchantRefId: '',
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
        emailId: request.emailId,
      );

      final response = await _aepsService.registerMerchant(regRequest);

      final merchantId = response.merchantId?.toString() ?? '';
      final merchantRefId = response.merchantRefId?.toString() ?? '';
      final status = response.status?.toString() ?? '';
      final statusDescription = response.statusDescription?.toString() ?? '';

      print('📥 Registration Response:');
      print('   status: $status');
      print('   statusDescription: $statusDescription');
      print('   merchantId: $merchantId');

      // ❌ CASE 1: "Merchant already exist... EKYC/2FA" → Contact Support (return false)
      if (status == '003' &&
          statusDescription.toLowerCase().contains('ekyc')) {
        _errorMessage = statusDescription;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // ✅ CASE 2: "merchant already registered for pipe X" → Proceed with OTP (return true)
      if (status != '000' &&
          statusDescription.toLowerCase().contains('already registered for pipe')) {
        final pipeMatch = RegExp(r'pipe\s*(\d+)', caseSensitive: false)
            .firstMatch(statusDescription);
        if (pipeMatch != null) {
          _existingPipeNumber = pipeMatch.group(1);
        }

        // Save merchant details if available
        if (merchantId.isNotEmpty) {
          _merchantId = merchantId;
          _merchantRefId = merchantRefId;
          _mobileNo = request.mobileNo;
          _aadhaarNo = request.aadhaarNo;
          _pipe = requestPipe;

          await _authService.saveMerchantData(
            merchantId: _merchantId!,
            merchantRefId: _merchantRefId!,
            mobileNo: _mobileNo!,
            aadhaarNo: _aadhaarNo,
          );
        }

        DebugLogger.log('✅ Existing merchant (different pipe). ID: $_merchantId');
        _isLoading = false;
        notifyListeners();
        return true; // ✅ Return true to proceed with OTP
      }

      // ✅ CASE 3: New registration success
      if (merchantId.isNotEmpty) {
        _merchantId = merchantId;
        _merchantRefId = merchantRefId;
        _mobileNo = request.mobileNo;
        _aadhaarNo = request.aadhaarNo;
        _pipe = requestPipe;

        await _authService.saveMerchantData(
          merchantId: _merchantId!,
          merchantRefId: _merchantRefId!,
          mobileNo: _mobileNo!,
          aadhaarNo: _aadhaarNo,
        );

        DebugLogger.log('✅ New merchant saved. ID: $_merchantId');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = statusDescription.isNotEmpty ? statusDescription : 'Registration failed';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('❌ Registration error: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /*Future<bool> registerMerchant(MerchantRegistrationRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    _existingPipeNumber = null;
    notifyListeners();

    try {
      final requestPipe = request.pipe.isNotEmpty ? request.pipe : (_pipe ?? '1');
      print('🔑 Registering merchant with pipe: $requestPipe');

      final regRequest = aeps.RegisterMerchantRequest(
        stateCode: request.merchantState,
        districtCode: request.merchantDistrict,
        shopAddress: request.shopAddress,
        shopPincode: request.shopPinCode,
        bankAccount: request.bankAccountNumber,
        bankIfsc: request.bankIfscCode,
        bankNameCode: request.bankName,
        pipe: requestPipe,
        merchantRefId: '',
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
        emailId: request.emailId,
      );
      print('📤 Sending registration request with pipe: ${regRequest.pipe}');

      final response = await _aepsService.registerMerchant(regRequest);

      // ✅ ADD NULL SAFETY FOR ALL RESPONSE FIELDS
      final merchantId = response.merchantId?.toString() ?? '';
      final merchantRefId = response.merchantRefId?.toString() ?? '';
      final status = response.status?.toString() ?? '';
      final statusDescription = response.statusDescription?.toString() ?? '';
      final txnRefId = response.txnRefId?.toString() ?? '';

      print('📥 Registration Response:');
      print('   merchantId: $merchantId');
      print('   merchantRefId: $merchantRefId');
      print('   status: $status');
      print('   statusDescription: $statusDescription');
      print('   txnRefId: $txnRefId');

      // ✅ Handle case where merchant already exists (status 003)
      if (status == '003' || statusDescription.toLowerCase().contains('already exist')) {
        _errorMessage = statusDescription.isNotEmpty
            ? statusDescription
            : 'Merchant already registered with this mobile number';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // ✅ Success case
      if (merchantId.isNotEmpty) {
        _merchantId = merchantId;
        _merchantRefId = merchantRefId;
        _mobileNo = request.mobileNo;
        _aadhaarNo = request.aadhaarNo;
        _pipe = requestPipe;

        // Persist merchant data
        await _authService.saveMerchantData(
          merchantId: _merchantId!,
          merchantRefId: _merchantRefId!,
          mobileNo: _mobileNo!,
          aadhaarNo: _aadhaarNo,
        );

        DebugLogger.log('✅ Merchant saved. ID: $_merchantId, Pipe: $_pipe');
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        // ✅ Handle failure with proper message
        _errorMessage = statusDescription.isNotEmpty
            ? statusDescription
            : 'Registration failed: No merchant ID returned';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      // ✅ Handle 409 Conflict - extract existing pipe info
      final errorStr = e.toString();
      print('❌ Registration error: $errorStr');

      // Try to extract existing pipe from error message
      final pipeMatch = RegExp(r'pipe\s*(\d+)', caseSensitive: false)
          .firstMatch(errorStr);
      if (pipeMatch != null) {
        _existingPipeNumber = pipeMatch.group(1);
        print('⚠️ Existing pipe found: $_existingPipeNumber');
      }

      _errorMessage = errorStr;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }*/

  Future<bool> sendOtp(String merchantId, String mobileNo, {String? pipe}) async {
    _isLoading = true;
    try {
      final response = await _aepsService.sendOTP(
        aeps.OtpRequest(
          merchantId: merchantId,
          merchantRefId: 'OTP_${DateTime.now().millisecondsSinceEpoch}',
          pipe: pipe ?? _pipe ?? '1',
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

  Future<bool> verifyOtp(
      String merchantId,
      String otp,
      String merchantRefId,
      {String? pipe}
      ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _aepsService.verifyOTP(
        aeps.VerifyOtpRequest(
          merchantId: merchantId,
          merchantRefId: merchantRefId,
          otp: otp,
          pipe: pipe ?? _pipe ?? '1',
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

  Future<void> fetchMerchantByUserId(String userId, {String pipe = '1'}) async {
    try {
      final res = await LoggedHttpClient.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/aeps/merchant-status?userId=$userId&pipe=$pipe',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );
      final body = json.decode(res.body);
      if (body['isRegistered'] == true) {
        setMerchantData({
          'merchantId': body['merchantId'],
          'merchantRefId': body['merchantRefId'],
          'phone': body['mobileNo'] ?? _mobileNo,
          'aadhaarNo': _aadhaarNo,
          'firstName': '',
          'lastName': '',
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch merchant by userId: $e');
    }
  }

  Future<bool> resendOtp(
      String merchantId,
      String merchantRefId, {
        String? pipe,
      }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _aepsService.resendOTP(
        aeps.OtpRequest(
          merchantId: merchantId,
          merchantRefId: merchantRefId,
          pipe: pipe ?? _pipe ?? '1',
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

  Future<bool> startEkyc({
    required String merchantId,
    required String merchantRefId,
    required String pipe,
    String? pidData,
    String? deviceType,
    String? aadhaarNumber,
    String? ipAddress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _aepsService.merchantEkyc(
        aeps.MerchantEkycRequest(
          merchantId: merchantId,
          merchantRefId: merchantRefId,
          pipe: pipe,
          pidData: pidData ?? '',
          deviceType: deviceType ?? 'mantra',
          aadhaarNumber: aadhaarNumber ?? '',
        ),
      );
      if (response.status == '000') {
        return true;
      } else {
        _errorMessage = response.statusDescription ?? 'EKYC failed';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> perform2FA({
    required String merchantId,
    required String merchantRefId,
    required String pipe,
    required String aadhaarNumber,
    String? pidData,
    String? deviceType,
    double? lat,
    double? long,
    String? ipAddress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _aepsService.perform2FA(
        aeps.Perform2FARequest(
          merchantId: merchantId,
          merchantRefId: merchantRefId,
          aadhaarNumber: aadhaarNumber,
          pipe: pipe,
          deviceType: deviceType ?? 'mantra',
          pidData: pidData ?? '',
          lat: lat?.toString(),
          long: long?.toString(),
        ),
      );
      if (response.status == '000') {
        final today = DateTime.now().toIso8601String().split('T')[0];
        _last2FADate = today;
        _is2FAVerifiedToday = true;
        await _saveLast2FADate(today);
        // ✅ NEW: Update per-pipe 2FA status
        set2FADoneForPipe(pipe);
        return true;
      } else {
        _errorMessage = response.statusDescription ?? '2FA failed';
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // =========================================================================
  // ✅ NEW: 2FA STATUS CHECKING METHODS
  // =========================================================================

  /// Fetch 2FA status for all pipes from backend
  Future<void> fetch2FAStatus(String userId) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/aeps/2fa/status/$userId');

      debugPrint('┌──────────────────────────────────────────');
      debugPrint('│ 🔍 [2FA] Checking 2FA Status');
      debugPrint('│ 📍 URL: $url');
      debugPrint('│ 👤 UserID: $userId');
      debugPrint('└──────────────────────────────────────────');

      final response = await LoggedHttpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_authToken ?? ''}',
        },
      ).timeout(const Duration(seconds: 8));

      debugPrint('│ 📥 [2FA] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final pipesData = data['data']['pipes'];

          if (pipesData != null && pipesData is Map<String, dynamic>) {
            pipesData.forEach((pipe, status) {
              if (_pipes2FAStatus.containsKey(pipe)) {
                _pipes2FAStatus[pipe] = {
                  'merchant_id': status['merchant_id'],
                  'last_2fa_at': status['last_2fa_at'],
                  '2fa_done_today': status['2fa_done_today'] ?? false,
                };
              }
            });
          }

          _any2FADoneToday = data['data']['any_2fa_done_today'] ?? false;

          debugPrint('│ ✅ [2FA] Status updated:');
          _pipes2FAStatus.forEach((pipe, status) {
            debugPrint('│    Pipe $pipe: 2FA Done = ${status['2fa_done_today']}');
          });

          notifyListeners();
        }
      } else {
        debugPrint('│ ⚠️ [2FA] Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('│ ❌ [2FA] Error: $e');
    }
  }

  /// Update 2FA status for a specific pipe after successful 2FA
  void set2FADoneForPipe(String pipe) {
    if (_pipes2FAStatus.containsKey(pipe)) {
      _pipes2FAStatus[pipe] = {
        'merchant_id': _pipes2FAStatus[pipe]!['merchant_id'],
        'last_2fa_at': DateTime.now().toIso8601String(),
        '2fa_done_today': true,
      };
      _any2FADoneToday = true;

      // Also update local 2FA tracking
      final today = DateTime.now().toIso8601String().split('T')[0];
      _last2FADate = today;
      _is2FAVerifiedToday = true;
      _saveLast2FADate(today);

      notifyListeners();
      debugPrint('✅ [2FA] Pipe $pipe marked as done for today');
    }
  }

  // =========================================================================
  // TRANSACTION METHODS
  // =========================================================================

  // Transaction methods (unchanged)
  Future<TransactionResponse?> executeTransaction(
      AepsTransactionRequest request,
      ) async {
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
      final currentPipe = request.pipe.isNotEmpty ? request.pipe : (_pipe ?? '1');

      debugPrint('🔵 Transaction: type=${request.transactionType}, pipe=$currentPipe');
      debugPrint('🔵 Aadhaar: ${request.aadhaarNumber}, Bank: ${request.bankIIN}');

      switch (request.transactionType) {
        case 'CW':
          final response = await _aepsService.cashWithdrawal(
            aeps.CashWithdrawalRequest(
              amount: int.parse(request.amount),
              bankCode: request.bankIIN,
              pidData: request.pidData,
              accountType: null,
              lat: request.lat ?? '0.0',
              long: request.long ?? '0.0',
              device: request.deviceType,
              aadhaarNo: request.aadhaarNumber,
              mobileNo: request.mobileNo,
              pipe: currentPipe,
            ),
          );
          return TransactionResponse(
            status: response.status,
            statusDescription: response.statusDescription,
            txnRefId: response.txnRefId,
            rrn: response.rrn,
            availableBalance: response.availableBalance,
            npciMessage: response.npciMessage,
          );

        case 'CD':
          final response = await _aepsService.cashDeposit(
            aeps.CashDepositRequest(
              amount: int.parse(request.amount),
              bankCode: request.bankIIN,
              pidData: request.pidData,
              accountType: null,
              lat: request.lat ?? '0.0',
              long: request.long ?? '0.0',
              device: request.deviceType,
              aadhaarNo: request.aadhaarNumber,
              mobileNo: request.mobileNo,
              pipe: currentPipe,
            ),
          );
          return TransactionResponse(
            status: response.status,
            statusDescription: response.statusDescription,
            txnRefId: response.txnRefId,
            rrn: response.rrn,
            availableBalance: response.availableBalance,
            npciMessage: response.npciMessage,
          );

        case 'BE':
          final response = await _aepsService.balanceEnquiry(
            aeps.BalanceEnquiryRequest(
              bankCode: request.bankIIN,
              pidData: request.pidData,
              accountType: null,
              lat: request.lat ?? '0.0',
              long: request.long ?? '0.0',
              device: request.deviceType,
              aadhaarNo: request.aadhaarNumber,
              mobileNo: request.mobileNo,
              pipe: currentPipe,
            ),
          );
          return TransactionResponse(
            status: response.status,
            statusDescription: response.statusDescription,
            txnRefId: response.txnRefId,
            rrn: response.rrn,
            availableBalance: response.availableBalance,
            npciMessage: response.npciMessage,
          );

        case 'MS':
          final response = await _aepsService.miniStatement(
            aeps.MiniStatementRequest(
              bankCode: request.bankIIN,
              pidData: request.pidData,
              accountType: null,
              lat: request.lat ?? '0.0',
              long: request.long ?? '0.0',
              device: request.deviceType,
              aadhaarNo: request.aadhaarNumber,
              mobileNo: request.mobileNo,
              pipe: currentPipe,
            ),
          );
          return TransactionResponse(
            status: response.status,
            statusDescription: response.statusDescription,
            txnRefId: response.txnRefId,
            rrn: null,
            availableBalance: response.availableBalance,
            npciMessage: response.npciMessage,
          );

        case 'AP':
          final response = await _aepsService.cashWithdrawal(
            aeps.CashWithdrawalRequest(
              amount: int.parse(request.amount),
              bankCode: request.bankIIN,
              pidData: request.pidData,
              accountType: 'AP',
              lat: request.lat ?? '0.0',
              long: request.long ?? '0.0',
              device: request.deviceType,
              aadhaarNo: request.aadhaarNumber,
              mobileNo: request.mobileNo,
              pipe: currentPipe,
            ),
          );
          return TransactionResponse(
            status: response.status,
            statusDescription: response.statusDescription,
            txnRefId: response.txnRefId,
            rrn: response.rrn,
            availableBalance: response.availableBalance,
            npciMessage: response.npciMessage,
          );

        default:
          _errorMessage = 'Unknown transaction type: ${request.transactionType}';
          return null;
      }
    } catch (e) {
      debugPrint('❌ Transaction error: $e');
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
    String? lat,
    String? long,
  }) async {
    if (_authToken == null || _authToken!.isEmpty) {
      await _loadPersistedData();
    }
    if (_ipAddress == null) await _getLocalIp();

    final currentPipe = _pipe ?? '1';

    final request = AepsTransactionRequest(
      transactionType: transactionType,
      amount: amount,
      aadhaarNumber: aadhaarNumber,
      bankIIN: bankIIN,
      merchantId: merchantId,
      mobileNo: mobileNo,
      ipAddress: _ipAddress ?? '127.0.0.1',
      pidData: pidData,
      pipe: currentPipe,
      merchantRefId: merchantRefId,
      deviceType: deviceType,
      lat: lat ?? '0.0',
      long: long ?? '0.0',
    );
    return await executeTransaction(request);
  }

  Future<Map<String, dynamic>> getTransactionStatus(
      String merchantId,
      String merchantRefId,
      ) async {
    DebugLogger.log('getTransactionStatus not implemented in AepsService');
    return {'success': false};
  }

  void setMobileNo(String mobile) {
    _mobileNo = mobile;
    notifyListeners();
  }
}

// =========================================================================
// Models
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
  final String lat;
  final String long;

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
    this.lat = '0.0',
    this.long = '0.0',
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
    'latitude': lat,
    'longitude': long,
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

  factory TransactionResponse.fromJson(Map<String, dynamic> json) =>
      TransactionResponse(
        status:
        json['status']?.toString() ??
            json['responseCode']?.toString() ??
            '',
        statusDescription: json['statusDescription'] ?? json['message'],
        rrn: json['rrn']?.toString(),
        txnRefId: json['txnRefId']?.toString(),
        availableBalance: json['availableBalance']?.toString(),
        npciMessage: json['npciMessage']?.toString(),
        responseCode: json['responseCode']?.toString(),
      );
}