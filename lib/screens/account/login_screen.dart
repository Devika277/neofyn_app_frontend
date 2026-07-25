import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/services/session_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../layout/UserHomeScreen.dart';
import 'package:my_app/providers/wallet_provider.dart';
import 'package:my_app/providers/aeps_provider.dart';
import '../../services/api_logger.dart';
import 'register_screen.dart';
import '../../services/mpin_service.dart';
import 'set_mpin_screen.dart';
import 'mpin_verify_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN FIN TECH BRAND TOKENS - Clean Professional UI
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // Primary palette - New Green Theme
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);

  // Backgrounds
  static const Color background = Color(0xFFF6FAF9);
  static const Color cardColor = Colors.white;
  static const Color surface = Color(0xFFFFFFFF);
  static const Color inputBg = Color(0xFF1A1F1A);

  // Text colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF008169);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Border & Effects
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderFocus = Color(0xFF008169);
}

class AppTheme {
  static InputDecoration inputDecoration({
    required String hintText,
    String? labelText,
    Widget? suffixIcon,
    bool isPassword = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
      filled: true,
      fillColor: AppColors.inputBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      suffixIcon: suffixIcon,
    );
  }

  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );

  static ButtonStyle outlineButton = OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    minimumSize: const Size(double.infinity, 50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    side: const BorderSide(color: AppColors.borderLight),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  COUNTRY CODE MODEL
// ─────────────────────────────────────────────────────────────────────────────

class CountryCode {
  final String flag;
  final String code;
  final String name;

  const CountryCode(this.flag, this.code, this.name);
}

const List<CountryCode> countryCodes = [
  CountryCode('🇮🇳', '+91', 'India'),
  // CountryCode('🇺🇸', '+1', 'USA'),
  // CountryCode('🇬🇧', '+44', 'UK'),
  // CountryCode('🇦🇪', '+971', 'UAE'),
  // CountryCode('🇸🇬', '+65', 'Singapore'),
];

// ─────────────────────────────────────────────────────────────────────────────
//  LOGIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controllers
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = const FlutterSecureStorage();

  // Focus nodes
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  // State
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  CountryCode _selectedCountry = countryCodes.first;

  // Forgot password state
  bool _isFpLoading = false;
  int _fpStep = 1;
  final _fpPhoneController = TextEditingController();
  final _fpOtpController = TextEditingController();
  final _fpNewPassController = TextEditingController();
  final _fpConfirmPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  VALIDATIONS
  // ─────────────────────────────────────────────────────────────────────────

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegExp = RegExp(r'^\d{10}$');
    if (!phoneRegExp.hasMatch(value)) {
      return 'Enter valid 10-digit mobile number';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LOGIN API
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    // Validate
    final phoneError = validatePhone(_phoneController.text);
    final passwordError = validatePassword(_passwordController.text);

    if (phoneError != null || passwordError != null) {
      _showToast(phoneError ?? passwordError!, error: true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final response = await LoggedHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text,
        }),
      );

      final data = json.decode(response.body);
      debugPrint('📦 Login response: $data'); // ← add this

      if (response.statusCode == 200) {
        String? token;

        if (data['token'] != null && data['token'] != 'null') {
          token = data['token'];
        } else if (data['data']?['token'] != null &&
            data['data']['token'] != 'null') {
          token = data['data']['token'];
        } else if (data['accessToken'] != null &&
            data['accessToken'] != 'null') {
          token = data['accessToken'];
        }

        if (token != null && token != 'null' && token.isNotEmpty) {
          await _storage.write(key: 'jwt_token', value: token);
          final prefs = await SharedPreferences.getInstance();

          String? userId, name, phone;
          if (data['user'] != null) {
            userId =
                data['user']['id']?.toString() ??
                data['user']['_id']?.toString();
            name = data['user']['name']?.toString();
            phone = data['user']['phone']?.toString();
          } else if (data['data'] is Map) {
            userId =
                data['data']['id']?.toString() ??
                data['data']['_id']?.toString();
            name = data['data']['name']?.toString();
            phone = data['data']['phone']?.toString();
          }

          if (userId != null) {
            // ✅ Create local non-nullable variables
            final String finalUserId = userId;
            final String finalToken = token;

            await SessionService.saveLoginSession(finalToken, finalUserId);

            await prefs.setString('userId', finalUserId);
            await prefs.setString('name', name ?? '');
            await prefs.setString(
              'phone',
              phone ?? _phoneController.text.trim(),
            );
            await prefs.setString('accessToken', finalToken);
            await prefs.setString(
              'email',
              data['user']?['email'] ?? '',
            ); // ✅ ADD THIS LINE
            await prefs.setString(
              'member_id',
              data['user']?['member_id'] ?? '',
            );
            await prefs.setBool(
              'tpin',
              data['user']?['tpin'] ?? false,  // ✅ false is a bool
            );
            await prefs.setString('role', data['user']?['role'] ?? '');
            debugPrint('💾 Role saved: ${data['user']?['role']}');
            final aeps = Provider.of<AepsProvider>(context, listen: false);
            aeps.setAuthDetails(
              token: finalToken,
              userId: finalUserId,
              merchantId: '',
              mobileNo: phone ?? _phoneController.text.trim(),
            );

            final wallet = Provider.of<WalletProvider>(context, listen: false);
            wallet.setUserId(finalUserId);

            await _fetchMerchantData(finalToken, finalUserId, phone);

            HapticFeedback.heavyImpact();
            _showToast('Login successful!');

            if (mounted) {
              // ✅ Check if MPIN is set
              final isMpinSet = await MpinService.isMpinSet();

              if (isMpinSet) {
                // MPIN is already set → Navigate to MPIN Verify Screen
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (c, a, _) => MpinVerifyScreen(
                      userId: finalUserId,
                      token: finalToken,
                    ),
                    transitionsBuilder: (c, a, _, child) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: a,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                    transitionDuration: const Duration(milliseconds: 500),
                  ),
                );
              } else {
                // MPIN not set → Navigate to Set MPIN Screen
                Navigator.pushReplacement(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (c, a, _) =>
                        SetMpinScreen(userId: finalUserId, token: finalToken),
                    transitionsBuilder: (c, a, _, child) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(1.0, 0.0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: a,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                    transitionDuration: const Duration(milliseconds: 500),
                  ),
                );
              }
            }
          }
        } else {
          _showToast(data['message'] ?? 'Login failed', error: true);
        }
      } else {
        _showToast(data['message'] ?? 'Invalid credentials', error: true);
      }
    } catch (e) {
      _showToast('Network error. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

 Future<void> _fetchMerchantData(
  String token,
  String userId,
  String? phone,
) async {
  debugPrint('📍 _fetchMerchantData called with userId: $userId, phone: $phone');
  try {
    final url = '${ApiConfig.baseUrl}/api/aeps/merchant-status?userId=$userId';
    debugPrint('🔎 Calling: $url');
    final response = await http.get(Uri.parse(url), headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    });
    debugPrint('🔎 Response status: ${response.statusCode}');
    final body = json.decode(response.body);
    debugPrint('🔎 Raw response body: $body');

    if (body is List && body.isNotEmpty) {
      debugPrint('✅ Body is a non-empty list with ${body.length} items');
      Map<String, dynamic> bestMatch = body.first;
      debugPrint('📦 Initial bestMatch: $bestMatch');

      // Choose the most relevant pipe (active/verified first)
      for (final pipe in body) {
        debugPrint('🔍 Checking pipe: ${pipe['pipe']} with status ${pipe['registrationStatus']}');
        if (pipe['registrationStatus'] == 'active' || pipe['registrationStatus'] == 'otp_verified') {
          bestMatch = pipe;
          debugPrint('⭐ Found preferred pipe: ${pipe['pipe']} with status ${pipe['registrationStatus']}');
          break;
        }
      }

      final aeps = Provider.of<AepsProvider>(context, listen: false);
      debugPrint('📦 Setting merchant data with bestMatch: $bestMatch');
      aeps.setMerchantData({
        'merchantId': bestMatch['merchantId'],
        'merchantRefId': bestMatch['merchantRefId'],
        'pipe': bestMatch['pipe'],
        'phone': bestMatch['phone'] ?? phone,
        'registrationStatus': bestMatch['registrationStatus'],
      });
      aeps.setAuthDetails(
          token: token,
          userId: userId,
          merchantId: bestMatch['merchantId'] ?? '',
          mobileNo: bestMatch['phone'] ?? phone,
          aadhaarNo: bestMatch['aadhaarNo'],
          pipe: bestMatch['pipe']?.toString()
      );      debugPrint('✅ Merchant data set successfully');
    } else {
      debugPrint('⚠️ Body is not a non-empty list: $body');
    }
  } catch (e, stack) {
    debugPrint('❌ Error in _fetchMerchantData: $e');
    debugPrint('Stack trace: $stack');
  }
}

  // ─────────────────────────────────────────────────────────────────────────
  //  FORGOT PASSWORD API
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _requestPasswordOtp(
    Function(void Function()) setSheetState,
  ) async {
    final phone = _fpPhoneController.text.trim();

    if (phone.isEmpty) {
      _showToast('Please enter your phone number', error: true);
      return;
    }

    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      _showToast('Enter valid 10-digit mobile number', error: true);
      return;
    }

    setSheetState(() => _isFpLoading = true);

    try {
      final response = await LoggedHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['otp'] != null) {
          _fpOtpController.text = data['otp'].toString();
        }
        _showToast('OTP sent to $phone');
        setSheetState(() {
          _fpStep = 2;
          _isFpLoading = false;
        });
      } else {
        _showToast(data['message'] ?? 'Failed to send OTP', error: true);
        setSheetState(() => _isFpLoading = false);
      }
    } catch (e) {
      _showToast('Network error. Please try again.', error: true);
      setSheetState(() => _isFpLoading = false);
    }
  }

  Future<void> _resetPasswordWithOtp(
    Function(void Function()) setSheetState,
  ) async {
    final phone = _fpPhoneController.text.trim();
    final otp = _fpOtpController.text.trim();
    final newPass = _fpNewPassController.text.trim();
    final confirmPass = _fpConfirmPassController.text.trim();

    if (phone.isEmpty || otp.isEmpty || newPass.isEmpty) {
      _showToast('All fields are required', error: true);
      return;
    }

    if (newPass.length < 6) {
      _showToast('Password must be at least 6 characters', error: true);
      return;
    }

    if (newPass != confirmPass) {
      _showToast('Passwords do not match', error: true);
      return;
    }

    setSheetState(() => _isFpLoading = true);

    try {
      final response = await LoggedHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'phone': phone, 'otp': otp, 'newPassword': newPass}),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 &&
          (data['success'] == true || data['reset'] == true)) {
        _showToast('Password changed successfully');
        Navigator.pop(context);
        _passwordController.text = newPass;
      } else {
        _showToast(data['message'] ?? 'Password reset failed', error: true);
      }
    } catch (e) {
      _showToast('Network error. Please try again.', error: true);
    } finally {
      if (mounted) setSheetState(() => _isFpLoading = false);
    }
  }

  void _showToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    _fpPhoneController.text = _phoneController.text.trim();
    _fpStep = 1;
    _isFpLoading = false;
    _fpOtpController.clear();
    _fpNewPassController.clear();
    _fpConfirmPassController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Reset Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fpStep == 1
                              ? 'Enter your registered mobile number'
                              : 'Enter OTP and new password',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (_fpStep == 1) ...[
                          _buildFpPhoneField(),
                          const SizedBox(height: 24),
                          _buildFpSendOtpButton(setSheetState),
                        ],

                        if (_fpStep == 2) ...[
                          _buildFpOtpField(),
                          const SizedBox(height: 16),
                          _buildFpNewPasswordField(),
                          const SizedBox(height: 16),
                          _buildFpConfirmPasswordField(),
                          const SizedBox(height: 24),
                          _buildFpResetButton(setSheetState),
                        ],

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFpPhoneField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Phone Number',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _fpPhoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 16),
        decoration: AppTheme.inputDecoration(hintText: '9876543210'),
      ),
    ],
  );

  Widget _buildFpOtpField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'OTP',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _fpOtpController,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 16),
        decoration: AppTheme.inputDecoration(hintText: 'Enter 6-digit OTP'),
      ),
    ],
  );

  Widget _buildFpNewPasswordField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'New Password',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _fpNewPassController,
        obscureText: true,
        style: const TextStyle(fontSize: 16),
        decoration: AppTheme.inputDecoration(hintText: 'Minimum 6 characters'),
      ),
    ],
  );

  Widget _buildFpConfirmPasswordField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Confirm Password',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _fpConfirmPassController,
        obscureText: true,
        style: const TextStyle(fontSize: 16),
        decoration: AppTheme.inputDecoration(hintText: 'Retype new password'),
      ),
    ],
  );

  Widget _buildFpSendOtpButton(Function(void Function()) setSheetState) =>
      ElevatedButton(
        onPressed: _isFpLoading
            ? null
            : () => _requestPasswordOtp(setSheetState),
        style: AppTheme.primaryButton,
        child: _isFpLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Send OTP'),
      );

  Widget _buildFpResetButton(Function(void Function()) setSheetState) =>
      ElevatedButton(
        onPressed: _isFpLoading
            ? null
            : () => _resetPasswordWithOtp(setSheetState),
        style: AppTheme.primaryButton,
        child: _isFpLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Reset Password'),
      );

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD UI - Optimized for mobile screen
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E0A),
              Color(0xFF0F1A0F),
              Color(0xFF0A0E0A),
              Color(0xFF050805),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative background elements
            _buildBackgroundDecorations(),

            // Main content - Centered without scrolling
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Logo Section - Compact
                              _buildLogoSection(),

                              // Glass Card with form
                              _buildGlassCard(),

                              // Trust Indicators
                              _buildTrustIndicators(),
                            ],
                          ),
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
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        // Large circle top right
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.12),
                  AppColors.primary.withOpacity(0.04),
                  Colors.transparent,
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),

        // Medium circle bottom left
        Positioned(
          bottom: -60,
          left: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryLight.withOpacity(0.08),
                  AppColors.primaryDark.withOpacity(0.04),
                  Colors.transparent,
                ],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
        ),

        // Small circle middle
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          right: -25,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Grid dots
        Positioned.fill(child: CustomPaint(painter: GridDotPainter())),

        // Curved lines
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: CustomPaint(
            size: Size(MediaQuery.of(context).size.width, 200),
            painter: CurveLinePainter(),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoSection() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Logo
      Center(
        child: Image.asset(
          'assets/images/logo_white.png',
          height: 200,
          width: 450,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.account_balance_wallet,
            color: AppColors.primary,
            size: 40,
          ),
        ),
      ),
      const SizedBox(height: 8),
      // Tag line
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: const Text(
          'Smart Banking Solution',
          style: TextStyle(
            fontSize: 11,
            color: Colors.white70,
            letterSpacing: 0.8,
          ),
        ),
      ),
    ],
  );

  Widget _buildGlassCard() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.1),
          blurRadius: 20,
          spreadRadius: -3,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Welcome Text
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sign in to continue',
          style: TextStyle(fontSize: 13, color: Colors.white60),
        ),
        const SizedBox(height: 20),

        // Phone Field
        _buildPhoneField(),
        const SizedBox(height: 14),

        // Password Field
        _buildPasswordField(),
        const SizedBox(height: 8),

        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _showForgotPasswordDialog,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
            ),
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Login Button
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),

        // Create Account Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Don't have an account?",
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(left: 4),
                minimumSize: const Size(50, 30),
              ),
              child: Text(
                'Sign Up',
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildPhoneField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Phone Number',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _phoneFocus.hasFocus
                ? AppColors.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: _phoneFocus.hasFocus ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Country Code Picker
            GestureDetector(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedCountry.flag,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedCountry.code,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 18,
                      color: Colors.white38,
                    ),
                  ],
                ),
              ),
            ),
            // Phone Input
            Expanded(
              child: TextField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                style: const TextStyle(fontSize: 15, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter mobile number',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                  border: InputBorder.none,
                  counterText: '',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildPasswordField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Password',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
      ),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _passwordFocus.hasFocus
                ? AppColors.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: _passwordFocus.hasFocus ? 1.5 : 1,
          ),
        ),
        child: TextField(
          controller: _passwordController,
          focusNode: _passwordFocus,
          obscureText: !_isPasswordVisible,
          style: const TextStyle(fontSize: 15, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13, // Equal padding top and bottom
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildTrustIndicators() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _trustItem(Icons.security, 'Bank Grade\nSecurity'),
        _trustItem(Icons.verified, 'RBI Licensed'),
        _trustItem(Icons.people, '2M+ Users'),
      ],
    ),
  );

  Widget _trustItem(IconData icon, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 18),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white60,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );

  void _showCountryPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Country',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ...countryCodes.map(
              (cc) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(cc.flag, style: const TextStyle(fontSize: 28)),
                title: Text(
                  cc.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing: Text(
                  cc.code,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedCountry = cc);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _fpPhoneController.dispose();
    _fpOtpController.dispose();
    _fpNewPassController.dispose();
    _fpConfirmPassController.dispose();
    super.dispose();
  }
}

// Custom painter for grid dots
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

// Custom painter for curved lines
class CurveLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.1,
      size.width * 0.6,
      size.height * 0.4,
    );
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.6,
      size.width,
      size.height * 0.3,
    );
    canvas.drawPath(path, paint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.5);
    path2.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.3,
      size.width * 0.7,
      size.height * 0.6,
    );
    path2.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.7,
      size.width,
      size.height * 0.5,
    );
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
