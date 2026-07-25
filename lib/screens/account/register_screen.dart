import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../services/api_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN FIN TECH BRAND TOKENS
// ─────────────────────────────────────────────────────────────────────────────

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
      hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
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
  CountryCode('🇺🇸', '+1', 'USA'),
  CountryCode('🇬🇧', '+44', 'UK'),
  CountryCode('🇦🇪', '+971', 'UAE'),
  CountryCode('🇸🇬', '+65', 'Singapore'),
];

// ─────────────────────────────────────────────────────────────────────────────
//  REGISTER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 1;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  // Step 1 Controllers
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Step 2 Controllers
  final _businessNameCtrl = TextEditingController();
  final _businessTypeCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pinCodeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  // Step 3 Controllers
  final _aadhaarCtrl = TextEditingController();
  final _panCtrl = TextEditingController();

  CountryCode _selectedCountry = countryCodes.first;

  // Focus nodes
  final _phoneFocus = FocusNode();

  // Form keys
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  // ─────────────────────────────────────────────────────────────────────────
  //  VALIDATIONS
  // ─────────────────────────────────────────────────────────────────────────

  String? validateName(String? value) {
    if (value == null || value.isEmpty) return 'Required';
    if (value.length < 2) return 'Enter valid name';
    return null;
  }

  String? validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email required';
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value)) return 'Enter valid email';
    return null;
  }

  String? validatePhone(String? value) {
    if (value == null || value.isEmpty) return 'Phone number required';
    if (!RegExp(r'^\d{10}$').hasMatch(value)) return 'Enter 10-digit number';
    return null;
  }

  String? validatePinCode(String? value) {
    if (value == null || value.isEmpty) return 'PIN code required';
    if (!RegExp(r'^\d{6}$').hasMatch(value)) return 'Enter 6-digit PIN';
    return null;
  }

  String? validateAadhaar(String? value) {
    if (value == null || value.isEmpty) return 'Aadhaar required';
    if (!RegExp(r'^\d{12}$').hasMatch(value)) return 'Enter 12-digit Aadhaar';
    return null;
  }

  String? validatePan(String? value) {
    if (value == null || value.isEmpty) return 'PAN required';
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value.toUpperCase())) {
      return 'Enter valid PAN (e.g., ABCDE1234F)';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  REGISTRATION API
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _register() async {
    print('🔵 SUBMIT BUTTON TAPPED');
    print('═══════════════════════════════════════════');
    if (!_agreeToTerms) {
      _showToast('Please accept Terms & Conditions', error: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await LoggedHttpClient.post(
        Uri.parse('https://api.myneofyn.com/api/auth/register'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "first_name": _firstNameCtrl.text.trim(),
          "last_name": _lastNameCtrl.text.trim(),
          "email": _emailCtrl.text.trim(),
          "phone": _phoneCtrl.text.trim(),
          "business_name": _businessNameCtrl.text.trim(),
          "business_type": _businessTypeCtrl.text.trim(),
          "business_address": _addressCtrl.text.trim(),
          "city": _cityCtrl.text.trim(),
          "state": _stateCtrl.text.trim(),
          "pin_code": _pinCodeCtrl.text.trim(),
          "aadhaar_number": _aadhaarCtrl.text.trim(),
          "pan_number": _panCtrl.text.trim().toUpperCase(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showToast('Registration successful! Awaiting approval.');
        Navigator.pop(context);
      } else {
        _showToast(data['message'] ?? 'Registration failed', error: true);
      }
    } catch (e) {
      _showToast('Network error. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showToast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _nextStep() {
    bool isValid = false;
    switch (_currentStep) {
      case 1:
        isValid = _formKey1.currentState?.validate() ?? false;
        break;
      case 2:
        isValid = _formKey2.currentState?.validate() ?? false;
        break;
    }

    if (isValid && _currentStep < 3) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD UI - Dark theme matching login screen
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
            // Background decorations
            _buildBackgroundDecorations(),

            SafeArea(
              child: Column(
                children: [
                  // App Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text(
                            'Create Account',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48), // Balance the back button
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),

                          // Progress Indicator
                          _buildProgressIndicator(),
                          const SizedBox(height: 20),

                          // Glass Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
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
                                // Step Title
                                Text(
                                  _getStepTitle(),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getStepSubtitle(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.white60,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Form Sections
                                if (_currentStep == 1) _buildStep1(),
                                if (_currentStep == 2) _buildStep2(),
                                if (_currentStep == 3) _buildStep3(),

                                const SizedBox(height: 20),

                                // Navigation Buttons
                                _buildNavigationButtons(),

                                // Terms & Conditions (only on step 3)
                                if (_currentStep == 3) ...[
                                  const SizedBox(height: 16),
                                  _buildTermsCheckbox(),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
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

  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Personal Details';
      case 2:
        return 'Business Details';
      case 3:
        return 'KYC Verification';
      default:
        return '';
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 1:
        return 'Step 1 of 3 - Basic information';
      case 2:
        return 'Step 2 of 3 - Business information';
      case 3:
        return 'Step 3 of 3 - Identity verification';
      default:
        return '';
    }
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
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
        Positioned.fill(child: CustomPaint(painter: GridDotPainter())),
      ],
    );
  }

  Widget _buildProgressIndicator() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      _stepCircle(1),
      _stepConnector(1),
      _stepCircle(2),
      _stepConnector(2),
      _stepCircle(3),
    ],
  );

  Widget _stepCircle(int step) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: _currentStep >= step
          ? AppColors.primary
          : Colors.white.withOpacity(0.05),
      border: Border.all(
        color: _currentStep >= step
            ? AppColors.primary
            : Colors.white.withOpacity(0.2),
        width: 2,
      ),
      boxShadow: _currentStep >= step
          ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ]
          : null,
    ),
    child: Center(
      child: _currentStep > step
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : Text(
              '$step',
              style: TextStyle(
                color: _currentStep >= step ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
    ),
  );

  Widget _stepConnector(int step) => Container(
    width: 40,
    height: 2,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    decoration: BoxDecoration(
      color: _currentStep > step
          ? AppColors.primary
          : Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(1),
    ),
  );

  Widget _buildStep1() => Form(
    key: _formKey1,
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                _firstNameCtrl,
                'First Name',
                'John',
                validator: validateName,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                _lastNameCtrl,
                'Last Name',
                'Doe (optional)',
                // validator: validateName,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildTextField(
          _emailCtrl,
          'Email',
          'john@example.com',
          validator: validateEmail,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildPhoneField(),
      ],
    ),
  );

  Widget _buildStep2() => Form(
    key: _formKey2,
    child: Column(
      children: [
        _buildTextField(
          _businessNameCtrl,
          'Business Name',
          'Enter business name',
        ),
        const SizedBox(height: 14),
        _buildTextField(
          _businessTypeCtrl,
          'Business Type',
          'e.g., Retail, Service',
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildTextField(_cityCtrl, 'City', 'Mumbai')),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(_stateCtrl, 'State', 'Maharashtra'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildTextField(
          _pinCodeCtrl,
          'PIN Code',
          '400001',
          validator: validatePinCode,
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          _addressCtrl,
          'Business Address',
          'Full address',
          maxLines: 2,
        ),
      ],
    ),
  );

  Widget _buildStep3() => Form(
    key: _formKey3,
    child: Column(
      children: [
        _buildTextField(
          _aadhaarCtrl,
          'Aadhaar Number',
          '12-digit number',
          validator: validateAadhaar,
          keyboardType: TextInputType.number,
          maxLength: 12,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          _panCtrl,
          'PAN Number',
          'ABCDE1234F',
          validator: validatePan,
          textCapitalization: TextCapitalization.characters,
          maxLength: 10,
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
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
                        color: AppColors.primaryLight,
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
            Expanded(
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 15, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter mobile number',
                  hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 13,
                  ),
                ),
                validator: (_) => validatePhone(_phoneCtrl.text),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onVisibilityToggle,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          style: const TextStyle(fontSize: 15, color: Colors.white),
          decoration:
              AppTheme.inputDecoration(
                hintText: hint,
                suffixIcon: isPassword
                    ? Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(
                            obscure ? Icons.visibility_off : Icons.visibility,
                            color: Colors.white38,
                            size: 20,
                          ),
                          onPressed: onVisibilityToggle,
                        ),
                      )
                    : null,
              ).copyWith(
                counterStyle: TextStyle(color: Colors.white30, fontSize: 10),
              ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() => Row(
    children: [
      if (_currentStep > 1)
        Expanded(
          child: OutlinedButton(
            onPressed: _prevStep,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              minimumSize: const Size(0, 48),
            ),
            child: const Text('Back', style: TextStyle(fontSize: 14)),
          ),
        ),
      if (_currentStep > 1) const SizedBox(width: 12),
      Expanded(
        flex: _currentStep > 1 ? 2 : 1,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : (_currentStep == 3 ? _register : _nextStep),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
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
                : Text(
                    _currentStep == 3 ? 'Submit Registration' : 'Continue',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    ],
  );

  Widget _buildTermsCheckbox() => Row(
    children: [
      SizedBox(
        width: 20,
        height: 20,
        child: Checkbox(
          value: _agreeToTerms,
          onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
          activeColor: AppColors.primary,
          checkColor: Colors.white,
          side: BorderSide(color: Colors.white.withOpacity(0.3)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.white60),
              children: const [
                TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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
                    color: AppColors.primaryLight,
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
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _businessNameCtrl.dispose();
    _businessTypeCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCodeCtrl.dispose();
    _addressCtrl.dispose();
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    _phoneFocus.dispose();
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
