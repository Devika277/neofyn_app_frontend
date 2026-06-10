import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN BRAND TOKENS (same as LoginScreen)
// ─────────────────────────────────────────────────────────────────────────────

class _N {
  static const bg        = Color(0xFF1C0F06); // deepest espresso
  static const surface   = Color(0xFF2A1407); // elevated surface
  static const inputBg   = Color(0xFF0F0804); // input fill
  static const caramel   = Color(0xFFC8956C); // primary accent
  static const caramelDim= Color(0xFF8B5E38);
  static const glassFg   = Color(0x0DFFFFFF); // 5% white
  static const glassBd   = Color(0x1AFFFFFF); // 10% white border
  static const glowBd    = Color(0x80C8956C);
  static const white     = Colors.white;
  static const sub       = Color(0xFF8A7060);
  static const hint      = Color(0xFF4A3828);
  static const error     = Color(0xFFC62828);
}

// ─────────────────────────────────────────────────────────────────────────────
//  COUNTRY CODE MODEL (same as LoginScreen)
// ─────────────────────────────────────────────────────────────────────────────

class _CountryCode {
  final String flag;
  final String code;
  final String name;
  const _CountryCode(this.flag, this.code, this.name);
}

const List<_CountryCode> _countryCodes = [
  _CountryCode('🇮🇳', '+91',  'India'),
  _CountryCode('🇦🇪', '+971', 'UAE'),
  _CountryCode('🇬🇧', '+44',  'UK'),
  _CountryCode('🇺🇸', '+1',   'USA'),
  _CountryCode('🇸🇬', '+65',  'Singapore'),
];

// ─────────────────────────────────────────────────────────────────────────────
//  REGISTER SCREEN (3‑step flow with glassmorphism)
// ─────────────────────────────────────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 1; // 1, 2, 3
  bool _isLoading = false;
  bool _agreedToTerms = false;

  // ── Step 1 controllers ──────────────────────────────────────────────────
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _email     = TextEditingController();
  final _phone     = TextEditingController();
  final _password  = TextEditingController();

  // Country code picker for phone
  _CountryCode _selectedCC = _countryCodes.first;

  // ── Step 2 controllers ──────────────────────────────────────────────────
  final _busName    = TextEditingController();
  final _busType    = TextEditingController();
  final _city       = TextEditingController();
  final _state      = TextEditingController();
  final _pinCode    = TextEditingController();
  final _busAddress = TextEditingController();

  // ── Step 3 controllers ──────────────────────────────────────────────────
  final _aadhaar = TextEditingController();
  final _pan     = TextEditingController();

  // Password visibility (step 1)
  bool _isPasswordVisible = false;

  // Focus nodes for glow effect (optional, can be reused on fields)
  // For simplicity, we'll not implement per-field glow, but keep card consistent.

  // ─────────────────────────────────────────────────────────────────────────
  //  BACKEND LOGIC (unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> submitRegistration() async {
    if (!_agreedToTerms) {
      _showToast("Please accept Terms and Conditions");
      return;
    }
    if (_aadhaar.text.length != 12) {
      _showToast("Aadhaar must be 12 digits");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('https://neofyn-app-backend.onrender.com/api/auth/register');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "first_name": _firstName.text.trim(),
          "last_name": _lastName.text.trim(),
          "email": _email.text.trim(),
          "phone": "${_selectedCC.code}${_phone.text.trim()}", // include country code
          "password": _password.text.trim(),
          "business_name": _busName.text.trim(),
          "business_type": _busType.text.trim(),
          "business_address": _busAddress.text.trim(),
          "city": _city.text.trim(),
          "state": _state.text.trim(),
          "pin_code": _pinCode.text.trim(),
          "aadhaar_number": _aadhaar.text.trim(),
          "pan_number": _pan.text.trim(),
        }),
      );

      if (response.statusCode == 201) {
        _showToast("Registered successfully! Awaiting approval.");
        Navigator.pop(context);
      } else {
        final errorData = jsonDecode(response.body);
        _showToast(errorData['message'] ?? "Registration failed");
      }
    } catch (e) {
      _showToast("Network Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: _N.caramel,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _N.bg,
      body: Stack(
        children: [
          const _AmbientBg(),   // same orbs as LoginScreen
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 22),
                  _buildHeroLogo(),
                  const SizedBox(height: 22),
                  _buildProgressIndicator(),
                  const SizedBox(height: 24),
                  _buildStepCard(),
                  const SizedBox(height: 16),
                  _buildTrustStrip(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar (back + SSL badge) ──────────────────────────────────────────
  Widget _buildTopBar() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); Navigator.pop(context); },
        child: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: _N.glassFg,
            border: Border.all(color: _N.glassBd),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: _N.white, size: 16),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x1AC8956C),
          border: Border.all(color: const Color(0x40C8956C)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_user_outlined, color: _N.caramel, size: 13),
            SizedBox(width: 5),
            Text('256-bit SSL', style: TextStyle(color: _N.caramel, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ],
  );

  // ── Hero logo (same as LoginScreen) ─────────────────────────────────────
  Widget _buildHeroLogo() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: 100,
        child: Image.asset(
          'assets/images/logo_white.png',
          fit: BoxFit.contain,
        ),
      ),
      const Text(
        "India's smart money platform",
        style: TextStyle(fontSize: 11, color: Color(0x50FFFFFF), letterSpacing: 1.8),
      ),
    ],
  );

  // ── Progress indicator (step 1/3, 2/3, 3/3) ─────────────────────────────
  Widget _buildProgressIndicator() => Column(
    children: [
      LinearProgressIndicator(
        value: _currentStep / 3,
        backgroundColor: const Color(0x20FFFFFF),
        color: _N.caramel,
        minHeight: 4,
        borderRadius: BorderRadius.circular(2),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stepLabel(1, "Personal"),
          _stepLabel(2, "Business"),
          _stepLabel(3, "Identity"),
        ],
      ),
    ],
  );

  Widget _stepLabel(int step, String label) => Column(
    children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _currentStep >= step ? _N.caramel : const Color(0x20FFFFFF),
        ),
        child: Center(
          child: Text(
            "$step",
            style: TextStyle(
              color: _currentStep >= step ? _N.bg : _N.sub,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: _currentStep >= step ? _N.caramel : _N.sub,
          fontWeight: _currentStep >= step ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    ],
  );

  // ── Glass card that contains the current step content ────────────────────
  Widget _buildStepCard() => Container(
    decoration: BoxDecoration(
      color: _N.glassFg,
      border: Border.all(color: _N.glassBd, width: 1),
      borderRadius: BorderRadius.circular(26),
    ),
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getStepTitle(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _N.white),
        ),
        const SizedBox(height: 6),
        Text(
          _getStepSubtitle(),
          style: const TextStyle(fontSize: 13, color: _N.sub),
        ),
        const SizedBox(height: 24),
        // Dynamic content based on step
        if (_currentStep == 1) _buildStep1Content(),
        if (_currentStep == 2) _buildStep2Content(),
        if (_currentStep == 3) _buildStep3Content(),
        const SizedBox(height: 28),
        _buildNavigationButtons(),
      ],
    ),
  );

  String _getStepTitle() {
    switch (_currentStep) {
      case 1: return "Tell us about you";
      case 2: return "Business details";
      default: return "Verify your identity";
    }
  }

  String _getStepSubtitle() {
    switch (_currentStep) {
      case 1: return "We'll need your basic info to get started.";
      case 2: return "Your business profile helps us serve you better.";
      default: return "PAN & Aadhaar are required for KYC.";
    }
  }

  // ── Step 1 content ───────────────────────────────────────────────────────
  Widget _buildStep1Content() => Column(
    children: [
      _buildTextField(_firstName, "First name", TextInputType.text),
      const SizedBox(height: 14),
      _buildTextField(_lastName, "Last name", TextInputType.text),
      const SizedBox(height: 14),
      _buildTextField(_email, "Email address", TextInputType.emailAddress),
      const SizedBox(height: 14),
      _buildPhoneField(),      // custom phone with country code
      const SizedBox(height: 14),
      _buildPasswordField(),
    ],
  );

  // ── Phone field (with country code picker, same as LoginScreen) ──────────
  Widget _buildPhoneField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _FieldLabel('Phone number'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: _N.inputBg,
          border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        height: 54,
        child: Row(
          children: [
            GestureDetector(
              onTap: _showCCPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: Color(0x1AFFFFFF))),
                ),
                child: Row(
                  children: [
                    Text(_selectedCC.flag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(_selectedCC.code, style: const TextStyle(color: _N.caramel, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more_rounded, color: Color(0x50FFFFFF), size: 16),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: _N.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Mobile number',
                  hintStyle: TextStyle(color: _N.hint, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  void _showCCPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A1407),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select country code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ..._countryCodes.map((cc) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(cc.flag, style: const TextStyle(fontSize: 22)),
              title: Text(cc.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
              trailing: Text(cc.code, style: const TextStyle(color: _N.caramel, fontWeight: FontWeight.w700)),
              onTap: () {
                setState(() => _selectedCC = cc);
                Navigator.pop(context);
              },
            )),
          ],
        ),
      ),
    );
  }

  // ── Password field (with visibility toggle) ──────────────────────────────
  Widget _buildPasswordField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _FieldLabel('Password'),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: _N.inputBg,
          border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        height: 54,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _password,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: _N.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText: 'Create a strong password',
                  hintStyle: TextStyle(color: _N.hint, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _N.sub, size: 20,
              ),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ],
        ),
      ),
    ],
  );

  // ── Step 2 content (business details) ────────────────────────────────────
  Widget _buildStep2Content() => Column(
    children: [
      _buildTextField(_busName, "Business name", TextInputType.text),
      const SizedBox(height: 14),
      _buildTextField(_busType, "Business type (e.g., Retail, Service)", TextInputType.text),
      const SizedBox(height: 14),
      _buildTextField(_city, "City", TextInputType.text),
      const SizedBox(height: 14),
      _buildTextField(_state, "State", TextInputType.text),
      const SizedBox(height: 14),
      _buildTextField(_pinCode, "PIN code", TextInputType.number, maxLength: 6),
      const SizedBox(height: 14),
      _buildTextField(_busAddress, "Business address", TextInputType.streetAddress, lines: 2),
    ],
  );

  // ── Step 3 content (identity + terms) ────────────────────────────────────
  Widget _buildStep3Content() => Column(
    children: [
      _buildTextField(_aadhaar, "Aadhaar number (12 digits)", TextInputType.number, maxLength: 12),
      const SizedBox(height: 14),
      _buildTextField(_pan, "PAN number (10 digits)", TextInputType.text, maxLength: 10),
      const SizedBox(height: 18),
      Row(
        children: [
          SizedBox(
            width: 20, height: 20,
            child: Checkbox(
              value: _agreedToTerms,
              onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
              activeColor: _N.caramel,
              checkColor: _N.bg,
              side: const BorderSide(color: _N.sub),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: _N.sub),
                  children: const [
                    TextSpan(text: "I agree to the "),
                    TextSpan(text: "Terms & Conditions", style: TextStyle(color: _N.caramel, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );

  // ── Reusable text field (matches LoginScreen style) ──────────────────────
  Widget _buildTextField(TextEditingController ctrl, String hint, TextInputType type, {int? maxLength, int lines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(hint),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          maxLength: maxLength,
          maxLines: lines,
          style: const TextStyle(color: _N.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _N.hint, fontSize: 14),
            filled: true,
            fillColor: _N.inputBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: _N.caramel, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            counterText: "", // hide counter
          ),
        ),
      ],
    );
  }

  // ── Navigation buttons (Back / Next or Register) ─────────────────────────
  Widget _buildNavigationButtons() => Row(
    children: [
      if (_currentStep > 1)
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _currentStep--),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border.all(color: _N.glassBd),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text("← Back", style: TextStyle(color: _N.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      if (_currentStep > 1) const SizedBox(width: 12),
      Expanded(
        flex: _currentStep > 1 ? 2 : 1,
        child: GestureDetector(
          onTap: _currentStep == 3 ? submitRegistration : () => setState(() => _currentStep++),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: _N.caramel,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _N.caramel.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Center(
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(_N.bg)))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentStep == 3 ? "Register" : "Continue",
                          style: const TextStyle(color: _N.bg, fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        if (_currentStep != 3) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, color: _N.bg, size: 18),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    ],
  );

  // ── Trust strip (same as LoginScreen) ────────────────────────────────────
  Widget _buildTrustStrip() => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0x0FFFFFFF))),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: const [
        _TrustBadge(Icons.security_outlined,  'Bank-grade security'),
        _TrustBadge(Icons.verified_outlined,  'RBI licensed'),
        _TrustBadge(Icons.group_outlined,     '2M+ users'),
      ],
    ),
  );

  @override
  void dispose() {
    _firstName.dispose(); _lastName.dispose(); _email.dispose(); _phone.dispose(); _password.dispose();
    _busName.dispose(); _busType.dispose(); _city.dispose(); _state.dispose(); _pinCode.dispose(); _busAddress.dispose();
    _aadhaar.dispose(); _pan.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  REUSABLE HELPER WIDGETS (same as LoginScreen)
// ─────────────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _N.sub, letterSpacing: 1.4),
  );
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge(this.icon, this.label);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: const Color(0x60C8956C), size: 16),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0x40FFFFFF), fontWeight: FontWeight.w500)),
    ],
  );
}

class _AmbientBg extends StatelessWidget {
  const _AmbientBg();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -80, right: -80,
          child: Container(width: 260, height: 260, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x20B46E32))),
        ),
        Positioned(
          bottom: 100, left: -60,
          child: Container(width: 200, height: 200, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x158C4B19))),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: MediaQuery.of(context).size.width * 0.5 - 60,
          child: Container(width: 120, height: 120, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x09C8956C))),
        ),
      ],
    );
  }
}