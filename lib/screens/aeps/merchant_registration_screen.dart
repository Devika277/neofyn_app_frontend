// lib/screens/aeps/merchant_registration_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../layout/UserHomeScreen.dart';
import '../../services/AEPS/location_service.dart';
import 'aeps_wrapper_screen.dart';
import 'ekyc_screen.dart';
import 'otp_ekyc_screen.dart';

// ─── NEOFYN BRAND TOKENS ──────────────────────────────────────
class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color background = Color(0xFFF6FAF9);
  static const Color cardColor = Colors.white;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color inputBg = Color(0xFF1A1F1A);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF008169);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color pipePending = Color(0xFFF39C12);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderFocus = Color(0xFF008169);
}

class AppTheme {
  static InputDecoration inputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      suffixIcon: suffixIcon,
    );
  }

  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );
}

// ─── Grid Dot Painter ─────────────────────────────────────────
class GridDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 1;

    final spacing = 25.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── UpperCase Text Formatter ─────────────────────────────────
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// ─── Log Helper ───────────────────────────────────────────────
void _logRequest(String apiName, Map<String, dynamic> request) {
  print('═══════════════════════════════════════════════════════');
  print('📤 REQUEST: $apiName');
  print('───────────────────────────────────────────────────────');
  print(jsonEncode(request));
  print('═══════════════════════════════════════════════════════');
}

void _logResponse(String apiName, dynamic response, {bool isError = false}) {
  print('═══════════════════════════════════════════════════════');
  print('${isError ? '❌ ERROR' : '📥 RESPONSE'}: $apiName');
  print('───────────────────────────────────────────────────────');
  if (response is String) {
    try {
      final parsed = jsonDecode(response);
      print(jsonEncode(parsed));
    } catch (_) {
      print(response);
    }
  } else if (response is Map) {
    print(jsonEncode(response));
  } else {
    print(response.toString());
  }
  print('═══════════════════════════════════════════════════════');
}

class MerchantRegistrationScreen extends StatefulWidget {
  final bool isOtpPending;
  final Map<String, dynamic>? merchantData;
  final String? pipe;
  final String? phone;

  const MerchantRegistrationScreen({
    super.key,
    this.isOtpPending = false,
    this.merchantData,
    this.pipe,
    this.phone,
  });

  @override
  State<MerchantRegistrationScreen> createState() =>
      _MerchantRegistrationScreenState();
}

class _MerchantRegistrationScreenState extends State<MerchantRegistrationScreen> {
  bool _isSubmitting = false;
  bool _isRegistrationComplete = false;

  final _formKey = GlobalKey<FormState>();

  // Personal & address controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _dobController = TextEditingController();
  final _shopPanController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPinCodeController = TextEditingController();

  // Dropdown values
  String? _selectedStateCode;
  String? _selectedDistrictCode;
  String _selectedGender = 'M';
  String _accountType = 'Savings Account';
  String? _selectedBankCode;
  String? _selectedBankName;

  // Location
  Map<String, double>? _location;
  bool _isGettingLocation = false;

  String? _merchantId;
  String? _merchantRefId;
  final _otpController = TextEditingController();

  // OTP flow
  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  bool get _isOtpPending => widget.isOtpPending;
  String? get _pendingMerchantId =>
      widget.merchantData?['merchantId']?.toString();
  String? get _pendingMerchantRefId =>
      widget.merchantData?['merchantRefId']?.toString();

  // Get current pipe
  String get _currentPipe {
    if (widget.pipe != null && widget.pipe!.isNotEmpty) {
      return widget.pipe!;
    }
    final provider = context.read<AepsProvider>();
    return provider.pipe ?? '1';
  }

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _dobController.addListener(_onDobChanged);
    _panController.addListener(_onPanChanged);
    _shopPanController.addListener(_onShopPanChanged);

    print('🔵 INIT: MerchantRegistrationScreen');
    print('🔵 isOtpPending: ${widget.isOtpPending}');
    print('🔵 merchantData: ${jsonEncode(widget.merchantData)}');
    print('🔵 pipe: ${widget.pipe}');
    print('🔵 phone: ${widget.phone}');
    print('🔵 Current Pipe: $_currentPipe');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AepsProvider>().fetchStates();
      context.read<AepsProvider>().fetchBanks();
      _checkMerchantStatusAndShowOtp();
    });
  }

  @override
  void dispose() {
    _dobController.removeListener(_onDobChanged);
    _panController.removeListener(_onPanChanged);
    _shopPanController.removeListener(_onShopPanChanged);
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _dobController.dispose();
    _shopPanController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _shopAddressController.dispose();
    _shopPinCodeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ─── Check Merchant Status & Show OTP ────────────────────────
  Future<void> _checkMerchantStatusAndShowOtp() async {
    print('🔍 Checking merchant status...');

    if (_isOtpPending && widget.merchantData != null) {
      final phone = widget.phone ?? widget.merchantData!['phone']?.toString() ?? '';
      _mobileController.text = phone;
      _merchantId = _pendingMerchantId;
      _merchantRefId = _pendingMerchantRefId;

      print('📱 OTP Pending - MerchantId: $_merchantId');
      print('📱 OTP Pending - MerchantRefId: $_merchantRefId');
      print('📱 OTP Pending - Phone: $phone');

      setState(() {
        _isRegistrationComplete = true;
        _isSubmitting = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleResendOtp();
        _showOtpPopup();
      });
      return;
    }

    try {
      final provider = context.read<AepsProvider>();
      final currentPipe = _currentPipe;

      print('🔍 Fetching pipe status for pipe: $currentPipe');

      final statusData = await provider.fetchPipeStatus(currentPipe);

      if (statusData != null && mounted) {
        _logResponse('fetchPipeStatus', statusData);

        final registrationStatus = statusData['registrationStatus']?.toString() ?? '';
        final merchantId = statusData['merchantId']?.toString() ?? provider.merchantId;
        final merchantRefId = statusData['merchantRefId']?.toString() ?? provider.merchantRefId;
        final phoneNumber = statusData['phone']?.toString() ?? provider.mobileNo ?? '';
        final errorMessage = statusData['message']?.toString() ?? statusData['error']?.toString() ?? '';

        print('📊 Registration Status: "$registrationStatus"');
        print('📊 MerchantId: $merchantId');
        print('📊 MerchantRefId: $merchantRefId');
        print('📊 Phone: $phoneNumber');
        print('📊 Error/Message: $errorMessage');

        if (errorMessage.toLowerCase().contains('already registered') ||
            errorMessage.toLowerCase().contains('already exist')) {
          print('⚠️ Merchant already registered in pipe $currentPipe');

          setState(() {
            _isRegistrationComplete = true;
            _isSubmitting = false;
            _merchantId = merchantId;
            _merchantRefId = merchantRefId;
          });

          _showSuccess('Merchant already registered! Proceeding to verification.');

          if (merchantId != null && merchantId.isNotEmpty) {
            if (phoneNumber.isNotEmpty) {
              _mobileController.text = phoneNumber;
            }

            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                _handleResendOtp();
                _showOtpPopup();
              }
            });
          }
          return;
        }

        if ((registrationStatus == 'otp_sent' || registrationStatus == 'otp_pending') &&
            merchantId != null && merchantId.isNotEmpty) {

          if (phoneNumber.isNotEmpty) {
            _mobileController.text = phoneNumber;
          } else if (widget.phone != null) {
            _mobileController.text = widget.phone!;
          }

          setState(() {
            _merchantId = merchantId;
            _merchantRefId = merchantRefId;
            _isRegistrationComplete = true;
            _isSubmitting = false;
          });

          print('📱 Status is "$registrationStatus" - Showing OTP popup');

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleResendOtp();
            _showOtpPopup();
          });
        } else if (registrationStatus == 'otp_verified') {
          print('✅ Status is otp_verified - Navigating to EKYC');
          setState(() {
            _isRegistrationComplete = true;
            _isSubmitting = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => EKYC_Screen(
                  merchantId: merchantId ?? '',
                  merchantRefId: merchantRefId ?? '',
                  pipe: currentPipe,
                  aadhaarNumber: provider.aadhaarNo ?? '',
                  // phoneNumber: _mobileController.text.isNotEmpty ? _mobileController.text : (widget.phone ?? ''),
                ),
              ),
            );
          });
        } else if (registrationStatus == 'active') {
          print('✅ Status is active - Navigating to AEPS wrapper');
          setState(() {
            _isRegistrationComplete = true;
            _isSubmitting = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
            );
          });
        } else {
          print('ℹ️ Registration status: "$registrationStatus" - User can register');
          setState(() {
            _isRegistrationComplete = false;
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error checking merchant status: $e');
      _logResponse('checkMerchantStatus', {'error': e.toString()}, isError: true);
      setState(() {
        _isRegistrationComplete = false;
        _isSubmitting = false;
      });
    }
  }

  // ─── PAN Auto Uppercase ──────────────────────────────────────
  void _onPanChanged() {
    final text = _panController.text.toUpperCase();
    if (_panController.text != text) {
      _panController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (text.length > 10) {
      _panController.text = text.substring(0, 10);
      _panController.selection = TextSelection.fromPosition(
        TextPosition(offset: _panController.text.length),
      );
    }
    final filtered = _panController.text.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (_panController.text != filtered) {
      _panController.text = filtered;
      _panController.selection = TextSelection.fromPosition(
        TextPosition(offset: filtered.length),
      );
    }
  }

  void _onShopPanChanged() {
    final text = _shopPanController.text.toUpperCase();
    if (_shopPanController.text != text) {
      _shopPanController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    if (text.length > 10) {
      _shopPanController.text = text.substring(0, 10);
      _shopPanController.selection = TextSelection.fromPosition(
        TextPosition(offset: _shopPanController.text.length),
      );
    }
    final filtered = _shopPanController.text.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (_shopPanController.text != filtered) {
      _shopPanController.text = filtered;
      _shopPanController.selection = TextSelection.fromPosition(
        TextPosition(offset: filtered.length),
      );
    }
  }

  // ─── DOB Date Picker ─────────────────────────────────────────
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Color(0xFF1A1F1A),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1A1F1A),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
        "${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}";
      });
    }
  }

  // ─── DOB Auto Format (DD-MM-YYYY) ────────────────────────────
  void _onDobChanged() {
    String text = _dobController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (text.length > 8) text = text.substring(0, 8);

    String formatted = '';
    if (text.length >= 2) {
      formatted += text.substring(0, 2);
      if (text.length > 2) {
        formatted += '-';
        if (text.length >= 4) {
          formatted += text.substring(2, 4);
          if (text.length > 4) {
            formatted += '-${text.substring(4)}';
          }
        } else {
          formatted += text.substring(2);
        }
      }
    } else {
      formatted = text;
    }

    if (_dobController.text != formatted) {
      _dobController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  // ─── Location ────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final isReady = await _locationService.showLocationDialog(context);
      if (isReady) {
        final location = await _locationService.getLocationMap();
        setState(() => _location = location);
        _showSuccess('Location captured successfully');
        print('📍 Location captured: $location');
      }
    } catch (e) {
      _showError('Failed to get location: $e');
      print('❌ Location error: $e');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  // ─── Searchable Dropdown Dialog ──────────────────────────────
  Future<T?> _showSearchableDropdown<T>({
    required String title,
    required List<T> items,
    required String Function(T) displayText,
    required String Function(T) itemValue,
    String? searchHint,
  }) async {
    final searchController = TextEditingController();
    return showDialog<T>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String query = searchController.text.toLowerCase();
            final filtered = query.isEmpty
                ? items
                : items.where((item) {
              return displayText(item).toLowerCase().contains(query) ||
                  itemValue(item).toLowerCase().contains(query);
            }).toList();

            return Dialog(
              backgroundColor: const Color(0xFF1A1F1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 500, maxWidth: 400),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: searchHint ?? 'Search...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No results found', style: TextStyle(color: Colors.grey)),
                      )
                          : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (_, index) {
                          final item = filtered[index];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.circle, size: 8, color: AppColors.primary),
                            title: Text(displayText(item), style: const TextStyle(color: Colors.white, fontSize: 14)),
                            subtitle: itemValue(item).isNotEmpty
                                ? Text('Code: ${itemValue(item)}', style: TextStyle(color: Colors.grey[500], fontSize: 12))
                                : null,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            hoverColor: AppColors.primary.withOpacity(0.1),
                            onTap: () => Navigator.pop(context, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Registration ────────────────────────────────────────────
  Future<void> _registerMerchant() async {
    if (_isSubmitting || _isRegistrationComplete) {
      print('⛔ BLOCKED: Registration already in progress');
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_selectedStateCode == null) { _showError('Please select state'); return; }
    if (_selectedDistrictCode == null) { _showError('Please select district'); return; }
    if (_location == null) {
      _showError('Please capture your location first');
      await _getCurrentLocation();
      if (_location == null) return;
    }
    if (_mobileController.text.trim().length != 10) {
      _showError('Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isRegistrationComplete = false;
    });

    final provider = context.read<AepsProvider>();
    final currentPipe = _currentPipe;

    final requestData = {
      'firstName': _firstNameController.text.trim(),
      'middleName': _middleNameController.text.trim(),
      'lastName': _lastNameController.text.trim(),
      'dob': _dobController.text.trim(),
      'emailId': _emailController.text.trim(),
      'mobileNo': _mobileController.text.trim(),
      'aadhaarNo': _aadhaarController.text.replaceAll(' ', '').trim(),
      'panNo': _panController.text.trim().toUpperCase(),
      'merchantAddress1': _addressController.text.trim(),
      'merchantAddress2': '',
      'merchantState': _selectedStateCode!,
      'merchantDistrict': _selectedDistrictCode!,
      'merchantPinCode': _pincodeController.text.trim(),
      'shopPan': _shopPanController.text.trim().toUpperCase(),
      'bankAccountNumber': _bankAccountController.text.trim(),
      'bankIfscCode': _bankIfscController.text.trim().toUpperCase(),
      'bankName': _selectedBankCode ?? '',
      'accountType': _accountType,
      'shopAddress': _shopAddressController.text.trim(),
      'shopDistrict': _selectedDistrictCode!,
      'shopState': _selectedStateCode!,
      'shopPinCode': _shopPinCodeController.text.trim(),
      'shopLat': _location!['latitude']!,
      'shopLong': _location!['longitude']!,
      'lat': _location!['latitude']!,
      'long': _location!['longitude']!,
      'ipAddress': '',
      'merchantRefId': '',
      'pipe': currentPipe,
      'gender': _selectedGender,
    };

    _logRequest('registerMerchant (Pipe: $currentPipe)', requestData);

    try {
      final request = MerchantRegistrationRequest(
        firstName: requestData['firstName'] as String,
        middleName: requestData['middleName'] as String,
        lastName: requestData['lastName'] as String,
        dob: requestData['dob'] as String,
        emailId: requestData['emailId'] as String,
        mobileNo: requestData['mobileNo'] as String,
        aadhaarNo: requestData['aadhaarNo'] as String,
        panNo: requestData['panNo'] as String,
        merchantAddress1: requestData['merchantAddress1'] as String,
        merchantAddress2: requestData['merchantAddress2'] as String,
        merchantState: requestData['merchantState'] as String,
        merchantDistrict: requestData['merchantDistrict'] as String,
        merchantPinCode: requestData['merchantPinCode'] as String,
        shopPan: requestData['shopPan'] as String,
        bankAccountNumber: requestData['bankAccountNumber'] as String,
        bankIfscCode: requestData['bankIfscCode'] as String,
        bankName: requestData['bankName'] as String,
        accountType: requestData['accountType'] as String,
        shopAddress: requestData['shopAddress'] as String,
        shopDistrict: requestData['shopDistrict'] as String,
        shopState: requestData['shopState'] as String,
        shopPinCode: requestData['shopPinCode'] as String,
        shopLat: requestData['shopLat'] as double,
        shopLong: requestData['shopLong'] as double,
        lat: requestData['lat'] as double,
        long: requestData['long'] as double,
        ipAddress: requestData['ipAddress'] as String,
        merchantRefId: requestData['merchantRefId'] as String,
        pipe: requestData['pipe'] as String,
        gender: requestData['gender'] as String,
      );

      final success = await provider.registerMerchant(request);

      if (!mounted) return;

      _merchantId = provider.merchantId;
      _merchantRefId = provider.merchantRefId;

      if (success) {
        if (success) {
          // ✅ SUCCESS
          print('✅ Registration SUCCESS');
          _merchantId = provider.merchantId;
          _merchantRefId = provider.merchantRefId;

          setState(() {
            _isRegistrationComplete = true;
            _isSubmitting = false;
          });

          // Show green snackbar
          _showSuccess('Merchant registered successfully!');

          // Show OTP popup IMMEDIATELY
          _handleResendOtp();
          _showOtpPopup();
        }
      } else {
        // ❌ FAILURE PATH
        print('❌ Registration returned false');

        final errorMsg = (provider.errorMessage ?? 'Registration failed');
        final lowerMsg = errorMsg.toLowerCase();

        // Already registered - treat as success (GREEN)
        if (lowerMsg.contains('already registered for pipe') ||
            lowerMsg.contains('already registered') ||
            (lowerMsg.contains('already exist') && !lowerMsg.contains('ekyc') && !lowerMsg.contains('2fa'))) {

          _merchantId = provider.merchantId;
          _merchantRefId = provider.merchantRefId;

          setState(() {
            _isRegistrationComplete = true;
            _isSubmitting = false;
          });

          _showSuccess('Merchant already registered! Proceeding to verification.');

          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _handleResendOtp();
              _showOtpPopup();
            }
          });

        } else if (lowerMsg.contains('ekyc') || lowerMsg.contains('2fa')) {
          // EKYC/2FA needed - Contact support (YELLOW)
          setState(() {
            _isSubmitting = false;
            _isRegistrationComplete = false;
          });
          _showContactSupportPopup(errorMsg);

        } else {
          // Real error - RED
          setState(() {
            _isSubmitting = false;
            _isRegistrationComplete = false;
          });
          _showError(errorMsg);
        }
      }
    } catch (e) {
      if (mounted) {
        print('❌ Registration exception: $e');
        setState(() {
          _isSubmitting = false;
          _isRegistrationComplete = false;
        });
        _showError('Registration failed: ${e.toString()}');
      }
    }
  }

  void _showContactSupportPopup(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.warning, Color(0xFFFF8F00)],
                ),
              ),
              child: const Icon(Icons.warning_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Merchant Already Exists',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Please contact support for assistance.',
              style: TextStyle(color: Colors.white60, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Go Back', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showError('Please contact support at support@neofyn.com');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Contact Support', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── Show Registration Success Popup ─────────────────────────
  void _showRegistrationSuccessPopup() {
    print('🎉 Showing registration success popup');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1F1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.success, Color(0xFF1AA88A)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_circle_outline, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Registration Successful! 🎉',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Congratulations! You have been successfully registered as a merchant for Pipe $_currentPipe.',
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_merchantId != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('Your Merchant ID', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        const SizedBox(height: 4),
                        Text(_merchantId!, style: const TextStyle(color: AppColors.primaryLight, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.warning, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Please verify your mobile number with OTP to activate your account.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        setState(() => _isSubmitting = false);
                        _handleResendOtp();
                        _showOtpPopup();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sms, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text('Proceed to OTP Verification',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    setState(() {
                      _isSubmitting = false;
                      _isRegistrationComplete = true;
                    });
                    Navigator.pop(context, true);
                  },
                  child: const Text('Verify Later', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Handle OTP Verification ─────────────────────────────────
  Future<void> _handleOtpVerification(
      BuildContext dialogContext,
      StateSetter setDialogState) async {

    if (_otpController.text.length != 6) {
      _showError('Please enter complete 6-digit OTP');
      return;
    }

    setDialogState(() => _isVerifyingOtp = true);

    final merchantId = _isOtpPending ? _pendingMerchantId : _merchantId;
    final merchantRefId = _isOtpPending ? _pendingMerchantRefId : _merchantRefId;
    final currentPipe = _currentPipe;

    final verifyRequest = {
      'merchantId': merchantId,
      'merchantRefId': merchantRefId,
      'otp': _otpController.text,
      'pipe': currentPipe,
    };

    _logRequest('verifyOtp', verifyRequest);

    if (merchantId == null || merchantRefId == null) {
      _showError('Merchant information missing. Please restart.');
      setDialogState(() => _isVerifyingOtp = false);
      return;
    }

    try {
      final provider = context.read<AepsProvider>();
      print('🔐 Verifying OTP for Pipe: $currentPipe, MerchantId: $merchantId');

      final success = await provider.verifyOtp(
        merchantId,
        _otpController.text,
        merchantRefId,
        pipe: currentPipe,
      );

      _logResponse('verifyOtp', {
        'success': success,
        'errorMessage': provider.errorMessage,
        'pipe': currentPipe,
        'merchantId': merchantId,
      });

      if (!mounted) return;

      if (success) {
        Navigator.pop(dialogContext);

        setState(() {
          _isOtpVerified = true;
          _isVerifyingOtp = false;
        });

        _showSuccess('OTP verified successfully!');
        print('✅ OTP Verified successfully for Pipe $currentPipe');

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EKYC_Screen(
              merchantId: merchantId,
              merchantRefId: merchantRefId,
              pipe: currentPipe,
              aadhaarNumber: _aadhaarController.text.replaceAll(' ', '').trim(),
              // phoneNumber: _mobileController.text.trim(),
            ),
          ),
        );
      } else {
        setDialogState(() => _isVerifyingOtp = false);
        final errorMsg = provider.errorMessage ?? 'OTP verification failed';
        print('❌ OTP verification failed: $errorMsg');
        _showError(errorMsg);
      }
    } catch (e) {
      if (mounted) {
        setDialogState(() => _isVerifyingOtp = false);
        print('❌ OTP verification exception: $e');
        _logResponse('verifyOtp', {'exception': e.toString()}, isError: true);
        _showError('Verification failed: ${e.toString()}');
      }
    }
  }

  // ─── Handle Resend OTP ───────────────────────────────────────
  Future<bool> _handleResendOtp() async {
    final merchantId = _isOtpPending ? _pendingMerchantId : _merchantId;

    if (merchantId == null || merchantId.isEmpty) {
      print('❌ Resend OTP failed: No merchant ID available');
      _showError('Merchant information missing');
      return false;
    }

    if (_mobileController.text.trim().length != 10) {
      print('❌ Resend OTP failed: Invalid mobile number');
      _showError('Invalid mobile number');
      return false;
    }

    final resendRequest = {
      'merchantId': merchantId,
      'mobile': _mobileController.text.trim(),
      'pipe': _currentPipe,
    };

    _logRequest('sendOtp (Resend)', resendRequest);

    try {
      final provider = context.read<AepsProvider>();
      final currentPipe = _currentPipe;

      print('📤 Sending/Resending OTP for Pipe: $currentPipe, MerchantId: $merchantId');

      final success = await provider.sendOtp(
        merchantId,
        _mobileController.text.trim(),
        pipe: currentPipe,
      );

      _logResponse('sendOtp', {
        'success': success,
        'errorMessage': provider.errorMessage,
        'pipe': currentPipe,
        'merchantId': merchantId,
      });

      if (!mounted) return false;

      if (success) {
        setState(() => _isOtpSent = true);
        _showSuccess('OTP sent successfully!');
        _otpController.clear();
        print('✅ OTP sent successfully for Pipe $currentPipe');
        return true;
      } else {
        final errorMsg = provider.errorMessage ?? 'Failed to send OTP';
        print('❌ Send OTP failed: $errorMsg');
        _showError(errorMsg);
        return false;
      }
    } catch (e) {
      if (mounted) {
        print('❌ Send OTP exception: $e');
        _logResponse('sendOtp', {'exception': e.toString()}, isError: true);
        _showError('Failed to send OTP: ${e.toString()}');
      }
      return false;
    }
  }

  // ─── OTP Popup (MODAL) ───────────────────────────────────────
  void _showOtpPopup() {
    _otpController.clear();

    print('🔔 Showing OTP popup');
    print('🔔 MerchantId: ${_isOtpPending ? _pendingMerchantId : _merchantId}');
    print('🔔 Phone: ${_mobileController.text}');

    // ✅ Declare localTimer OUTSIDE the builder so .then() can access it
    Timer? localTimer;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // ✅ LOCAL TIMER for this dialog
        int secondsRemaining = 30;

        void startLocalTimer(StateSetter setDialogState) {
          localTimer?.cancel();
          secondsRemaining = 30;
          localTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (secondsRemaining > 0) {
              secondsRemaining--;
              setDialogState(() {});
            } else {
              timer.cancel();
              setDialogState(() {});
            }
          });
        }

        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start timer on first build
            if (localTimer == null) {
              startLocalTimer(setDialogState);
            }

            return Dialog(
              backgroundColor: const Color(0xFF1A1F1A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: SingleChildScrollView(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.sms_outlined, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Verify Your Mobile',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the 6-digit OTP sent to',
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _mobileController.text.isNotEmpty
                            ? _mobileController.text
                            : 'your registered mobile',
                        style: const TextStyle(color: AppColors.primaryLight, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (_merchantId != null || _pendingMerchantId != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'ID: ${(_merchantId ?? _pendingMerchantId ?? '').length > 12
                                ? (_merchantId ?? _pendingMerchantId ?? '').substring(0, 12)
                                : (_merchantId ?? _pendingMerchantId ?? '')}...',
                            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                          ),
                        ),
                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            border: InputBorder.none,
                            hintText: '••••••',
                            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 28, letterSpacing: 12),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                          onChanged: (value) {
                            if (value.length == 6 && !_isVerifyingOtp) {
                              print('🔢 Auto-verifying OTP: $value');
                              _handleOtpVerification(dialogContext, setDialogState);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: (_isVerifyingOtp || _otpController.text.length != 6)
                                ? null
                                : () {
                              print('🔘 Verify button pressed');
                              _handleOtpVerification(dialogContext, setDialogState);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isVerifyingOtp
                                ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Verify OTP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // ✅ WORKING TIMER
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (secondsRemaining > 0) ...[
                            const Text("Resend OTP in ", style: TextStyle(color: Colors.white54, fontSize: 14)),
                            Text(
                              '${secondsRemaining}s',
                              style: TextStyle(
                                color: secondsRemaining <= 10 ? AppColors.error : AppColors.primaryLight,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ] else ...[
                            const Text("Didn't receive OTP? ", style: TextStyle(color: Colors.white54, fontSize: 14)),
                            GestureDetector(
                              onTap: _isSendingOtp ? null : () async {
                                print('🔄 Resend OTP tapped');
                                setDialogState(() => _isSendingOtp = true);
                                final success = await _handleResendOtp();
                                if (success) {
                                  startLocalTimer(setDialogState);
                                }
                                if (mounted) {
                                  setDialogState(() => _isSendingOtp = false);
                                }
                              },
                              child: _isSendingOtp
                                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2))
                                  : const Text('Resend OTP', style: TextStyle(color: AppColors.primaryLight, fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // ✅ Cleanup timer when dialog closes
      localTimer?.cancel();
    });
  }

  // ─── Show Error ──────────────────────────────────────────────
  void _showError(String message) {
    if (!mounted) return;
    print('🛑 ERROR SHOWN: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Show Success ────────────────────────────────────────────
  void _showSuccess(String message) {
    if (!mounted) return;
    print('✅ SUCCESS SHOWN: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Build Methods ───────────────────────────────────────────
  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(
          top: -80, right: -60,
          child: Container(
            width: 280, height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.12),
                  AppColors.primary.withOpacity(0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -60, left: -40,
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryLight.withOpacity(0.08),
                  AppColors.primaryDark.withOpacity(0.04),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(painter: GridDotPainter()),
        ),
      ],
    );
  }

  Widget _buildSearchableDropdownField({
    required String label,
    required String? value,
    required String hint,
    required bool isLoading,
    required VoidCallback onTap,
    String? displayText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        InkWell(
          onTap: isLoading ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: displayText != null ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))
                      : Text(displayText ?? hint, style: TextStyle(color: displayText != null ? Colors.white : Colors.white30, fontSize: 14)),
                ),
                Icon(Icons.search, color: displayText != null ? AppColors.primary : Colors.white38, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDobField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Date of Birth (DD-MM-YYYY) *', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _dobController,
          keyboardType: TextInputType.number,
          maxLength: 10,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: AppTheme.inputDecoration(
            hintText: 'DD-MM-YYYY',
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.date_range, color: AppColors.primaryLight, size: 20),
                onPressed: _selectDate,
              ),
            ),
          ).copyWith(counterStyle: const TextStyle(color: Colors.white30, fontSize: 10)),
          validator: (v) {
            if (v == null || v.isEmpty) return 'DOB is required';
            if (v.length != 10) return 'Enter complete date';
            final parts = v.split('-');
            if (parts.length != 3) return 'Invalid format';
            final day = int.tryParse(parts[0]);
            final month = int.tryParse(parts[1]);
            final year = int.tryParse(parts[2]);
            if (day == null || month == null || year == null) return 'Invalid date';
            if (month < 1 || month > 12) return 'Invalid month';
            if (day < 1 || day > 31) return 'Invalid day';
            if (year < 1900 || year > DateTime.now().year) return 'Invalid year';
            final dob = DateTime(year, month, day);
            if (dob.isAfter(DateTime.now())) return 'Date cannot be in future';
            final age = DateTime.now().difference(dob).inDays ~/ 365;
            if (age < 18) return 'Must be 18+ years old';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSectionContainer({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 12),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          style: const TextStyle(fontSize: 15, color: Colors.white),
          decoration: AppTheme.inputDecoration(hintText: hint).copyWith(
            counterStyle: const TextStyle(color: Colors.white30, fontSize: 10),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender *', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedGender == 'M' ? AppColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _selectedGender == 'M' ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                ),
                child: RadioListTile<String>(
                  title: const Text('Male', style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: 'M',
                  groupValue: _selectedGender,
                  onChanged: (v) => setState(() => _selectedGender = v!),
                  activeColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedGender == 'F' ? AppColors.primary.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _selectedGender == 'F' ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.1)),
                ),
                child: RadioListTile<String>(
                  title: const Text('Female', style: TextStyle(color: Colors.white, fontSize: 14)),
                  value: 'F',
                  groupValue: _selectedGender,
                  onChanged: (v) => setState(() => _selectedGender = v!),
                  activeColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account Type *', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          decoration: _dropdownDecoration('Account Type'),
          value: _accountType,
          dropdownColor: const Color(0xFF1A1F1A),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          items: const ['Savings Account', 'Current Account']
              .map((type) => DropdownMenuItem(value: type, child: Text(type, style: TextStyle(color: Colors.white))))
              .toList(),
          onChanged: (v) => setState(() => _accountType = v!),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AepsProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E0A), Color(0xFF0F1A0F), Color(0xFF0A0E0A), Color(0xFF050805)],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            _buildBackgroundDecorations(),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              const Text('Merchant Registration', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18), textAlign: TextAlign.center),
                              Text('Pipe $_currentPipe', style: const TextStyle(color: AppColors.primaryLight, fontSize: 12, fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  if ((_isOtpPending || (_isOtpSent && _merchantId != null)) && !_isOtpVerified)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.warning.withOpacity(0.15), AppColors.warning.withOpacity(0.05)]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.sms_failed, color: AppColors.warning, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('OTP Verification Required', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text('Please verify OTP to complete registration', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _handleResendOtp();
                              _showOtpPopup();
                            },
                            child: const Text('Verify', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  if (!_isOtpPending) ...[
                                    Center(
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, spreadRadius: 5)],
                                            ),
                                            child: const Icon(Icons.storefront, size: 50, color: Colors.white),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text('Register as Merchant', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                                            child: const Text('Complete your registration to start AEPS services', style: TextStyle(color: AppColors.primaryLight, fontSize: 13), textAlign: TextAlign.center),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                  ],
                                  _buildSectionContainer(
                                    icon: Icons.person,
                                    title: 'Personal Details',
                                    children: [
                                      _buildTextField(label: 'First Name *', controller: _firstNameController, hint: 'Enter first name', validator: (v) => v!.isEmpty ? 'First name required' : null),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Middle Name', controller: _middleNameController, hint: 'Enter middle name (optional)'),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Last Name', controller: _lastNameController, hint: 'Enter last name'),
                                      const SizedBox(height: 14),
                                      _buildDobField(),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Mobile Number *', controller: _mobileController, keyboardType: TextInputType.phone, hint: 'Enter 10-digit mobile number', maxLength: 10, validator: (v) {
                                        if (v == null || v.isEmpty) return 'Mobile required';
                                        if (v.trim().length != 10) return 'Enter valid 10-digit number';
                                        if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) return 'Only numbers allowed';
                                        return null;
                                      }),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Email ID', controller: _emailController, keyboardType: TextInputType.emailAddress, hint: 'Enter email address', validator: (v) => (v != null && v.isNotEmpty && !v.contains('@')) ? 'Enter valid email' : null),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Aadhaar Number *', controller: _aadhaarController, keyboardType: TextInputType.number, hint: 'Enter 12-digit Aadhaar', maxLength: 12, validator: (v) {
                                        if (v == null || v.isEmpty) return 'Aadhaar required';
                                        if (v.trim().length != 12) return 'Enter valid 12-digit Aadhaar';
                                        if (!RegExp(r'^[0-9]{12}$').hasMatch(v.trim())) return 'Only numbers allowed';
                                        return null;
                                      }),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'PAN Number *', controller: _panController, hint: 'Enter PAN (e.g., ABCDE1234F)', maxLength: 10, validator: (v) {
                                        if (v == null || v.isEmpty) return 'PAN required';
                                        final pan = v.trim().toUpperCase();
                                        if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(pan)) return 'Invalid PAN (e.g., ABCDE1234F)';
                                        return null;
                                      }),
                                      const SizedBox(height: 14),
                                      _buildGenderSelector(),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSectionContainer(
                                    icon: Icons.location_on,
                                    title: 'Address Details',
                                    children: [
                                      _buildTextField(label: 'Address *', controller: _addressController, hint: 'Enter your shop address', maxLines: 2, validator: (v) => v!.isEmpty ? 'Address required' : null),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'City', controller: _cityController, hint: 'Enter city name'),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Merchant Pincode *', controller: _pincodeController, keyboardType: TextInputType.number, hint: '6-digit pincode', maxLength: 6, validator: (v) {
                                        if (v == null || v.isEmpty) return 'Pincode required';
                                        if (v.trim().length != 6) return 'Enter valid 6-digit pincode';
                                        if (!RegExp(r'^[0-9]{6}$').hasMatch(v.trim())) return 'Only numbers allowed';
                                        return null;
                                      }),
                                      const SizedBox(height: 14),
                                      _buildSearchableDropdownField(label: 'State *', value: _selectedStateCode, hint: 'Search and select state', isLoading: provider.isLoading, onTap: () async {
                                        final selected = await _showSearchableDropdown(title: 'Select State', items: provider.states.map((s) => s).toList(), displayText: (s) => s.name, itemValue: (s) => s.code, searchHint: 'Type state name...');
                                        if (selected != null) {
                                          setState(() { _selectedStateCode = selected.code; _selectedDistrictCode = null; });
                                          provider.fetchDistricts(selected.code);
                                        }
                                      }, displayText: _selectedStateCode != null ? provider.states.firstWhere((s) => s.code == _selectedStateCode).name : null),
                                      const SizedBox(height: 14),
                                      if (_selectedStateCode != null)
                                        _buildSearchableDropdownField(label: 'District *', value: _selectedDistrictCode, hint: 'Search and select district', isLoading: provider.isLoadingDistricts, onTap: () async {
                                          final selected = await _showSearchableDropdown(title: 'Select District', items: provider.districts.map((d) => d).toList(), displayText: (d) => d.name, itemValue: (d) => d.code, searchHint: 'Type district name...');
                                          if (selected != null) setState(() => _selectedDistrictCode = selected.code);
                                        }, displayText: _selectedDistrictCode != null ? provider.districts.firstWhere((d) => d.code == _selectedDistrictCode).name : null),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSectionContainer(
                                    icon: Icons.account_balance,
                                    title: 'Bank & Shop Details',
                                    children: [
                                      _buildTextField(label: 'Shop PAN *', controller: _shopPanController, hint: 'Enter shop PAN', maxLength: 10, validator: (v) {
                                        if (v == null || v.isEmpty) return 'Shop PAN required';
                                        if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(v.trim().toUpperCase())) return 'Invalid PAN format';
                                        return null;
                                      }),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Bank Account Number *', controller: _bankAccountController, keyboardType: TextInputType.number, hint: 'Enter account number', validator: (v) => v!.isEmpty ? 'Account number required' : null),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Bank IFSC Code *', controller: _bankIfscController, hint: 'e.g. BARB0GEETAP', maxLength: 11, validator: (v) {
                                        if (v == null || v.isEmpty) return 'IFSC required';
                                        if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.trim().toUpperCase())) return 'Invalid IFSC (e.g., ABCD0123456)';
                                        return null;
                                      }),
                                      const SizedBox(height: 14),
                                      _buildSearchableDropdownField(label: 'Bank Name *', value: _selectedBankCode, hint: 'Search and select bank', isLoading: provider.banks.isEmpty, onTap: () async {
                                        final selected = await _showSearchableDropdown(title: 'Select Bank', items: provider.banks.map((b) => b).toList(), displayText: (b) => '${b.name} (${b.code})', itemValue: (b) => b.code, searchHint: 'Type bank name...');
                                        if (selected != null) setState(() { _selectedBankCode = selected.code; _selectedBankName = selected.name; });
                                      }, displayText: _selectedBankCode != null ? provider.banks.firstWhere((b) => b.code == _selectedBankCode).name : null),
                                      const SizedBox(height: 14),
                                      _buildAccountTypeDropdown(),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Shop Address *', controller: _shopAddressController, hint: 'Shop address', maxLines: 2, validator: (v) => v!.isEmpty ? 'Shop address required' : null),
                                      const SizedBox(height: 14),
                                      _buildTextField(label: 'Shop Pincode *', controller: _shopPinCodeController, keyboardType: TextInputType.number, hint: '6-digit pincode', maxLength: 6, validator: (v) {
                                        if (v == null || v.isEmpty) return 'Shop pincode required';
                                        if (v.trim().length != 6) return 'Enter valid 6-digit pincode';
                                        if (!RegExp(r'^[0-9]{6}$').hasMatch(v.trim())) return 'Only numbers allowed';
                                        return null;
                                      }),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  _buildSectionContainer(
                                    icon: Icons.gps_fixed,
                                    title: 'Shop Location',
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.info_outline, color: AppColors.primaryLight, size: 16),
                                            SizedBox(width: 8),
                                            Expanded(child: Text('Location is mandatory for AEPS registration', style: TextStyle(color: Colors.white60, fontSize: 12))),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      if (_isGettingLocation)
                                        const Center(child: CircularProgressIndicator(color: AppColors.primary))
                                      else if (_location != null)
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.success)),
                                          child: Column(
                                            children: [
                                              const Row(children: [Icon(Icons.check_circle, color: AppColors.success, size: 16), SizedBox(width: 8), Text('Location Captured', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold))]),
                                              const SizedBox(height: 8),
                                              Text('Lat: ${_location!['latitude']!.toStringAsFixed(6)}, Lng: ${_location!['longitude']!.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                            ],
                                          ),
                                        )
                                      else
                                        CustomButton(text: 'Get Current Location', onPressed: _getCurrentLocation, icon: Icons.my_location, backgroundColor: AppColors.primary, textColor: Colors.white),
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                  if (!_isOtpPending && !_isOtpSent)
                                    Container(
                                      height: 50,
                                      margin: const EdgeInsets.only(bottom: 50),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: (_isSubmitting || _isRegistrationComplete) ? [Colors.grey.shade600, Colors.grey.shade700] : [AppColors.primary, AppColors.primaryLight]),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: (_isSubmitting || _isRegistrationComplete) ? [] : [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: (_isSubmitting || _isRegistrationComplete) ? null : _registerMerchant,
                                        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, disabledBackgroundColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                        child: _isSubmitting
                                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                            : _isRegistrationComplete
                                            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.white, size: 20), SizedBox(width: 8), Text('Registration Complete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))])
                                            : const Text('Register Merchant', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                    ),
                                  if ((_isOtpPending || _isOtpSent) && !_isOtpVerified)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 50, top: 30),
                                      child: Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(colors: [AppColors.warning, AppColors.warning.withOpacity(0.8)]),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [BoxShadow(color: AppColors.warning.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: () { _handleResendOtp(); _showOtpPopup(); },
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sms, color: Colors.white, size: 20), SizedBox(width: 8), Text('Verify OTP Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white))]),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}