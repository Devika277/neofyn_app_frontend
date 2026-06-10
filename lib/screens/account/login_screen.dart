import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:my_app/providers/wallet_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import '../../layout/UserHomeScreen.dart';
import 'package:my_app/providers/aeps_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN BRAND TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class _N {
  // backgrounds
  static const bg        = Color(0xFF1C0F06); // deepest espresso
  static const surface   = Color(0xFF2A1407); // elevated surface
  static const inputBg   = Color(0xFF0F0804); // input fill
  // accent
  static const caramel   = Color(0xFFC8956C); // primary CTA / accent
  static const caramelDim= Color(0xFF8B5E38); // muted caramel
  // glass
  static const glassFg   = Color(0x0DFFFFFF); // 5 % white
  static const glassBd   = Color(0x1AFFFFFF); // 10 % white border
  static const glowBd    = Color(0x80C8956C); // focused border glow
  // text
  static const white     = Colors.white;
  static const sub       = Color(0xFF8A7060);  // secondary label
  static const hint      = Color(0xFF4A3828);  // placeholder
  // error
  static const error     = Color(0xFFC62828);
}

// ─────────────────────────────────────────────────────────────────────────────
//  COUNTRY CODE MODEL
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
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  // ── controllers ──────────────────────────────────────────────────────────
  final _phoneController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFocus         = FocusNode();
  final _passwordFocus      = FocusNode();
  final _storage            = const FlutterSecureStorage();

  // ── state ─────────────────────────────────────────────────────────────────
  bool _isLoading          = false;
  bool _isPasswordVisible  = false;
  bool _isLoginMode        = true; // tab toggle

  _CountryCode _selectedCC = _countryCodes.first;
  bool _cardGlowing        = false;



   
    bool _isFpLoading = false;
    int _fpStep = 1;   // 1 = request OTP, 2 = reset password

 // ── forgot password state ──────────────────────────────────────────────────
    late final TextEditingController _fpPhoneController;
    late final TextEditingController _fpOtpController;
    late final TextEditingController _fpNewPassController;
    late final TextEditingController _fpConfirmPassController;
  
  // ── animations ────────────────────────────────────────────────────────────
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double>  _fade  = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
  late final Animation<Offset>  _slide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end:   Offset.zero,
  ).animate(CurvedAnimation(parent: _ac, curve: Curves.easeOutCubic));

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _ac.forward();
    _phoneFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
    _fpPhoneController = TextEditingController();
    _fpOtpController = TextEditingController();
    _fpNewPassController = TextEditingController();
    _fpConfirmPassController = TextEditingController();


  }


  void _showForgotPasswordDialog() {
  // Pre‑fill phone from main login field if available
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
              color: _N.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _N.glassBd),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Reset password',
                      style: TextStyle(color: _N.white, fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _N.sub),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _fpStep == 1
                      ? 'Enter your registered phone number'
                      : 'Enter the OTP and your new password',
                  style: const TextStyle(color: _N.sub, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Step 1: Phone + Send OTP
                if (_fpStep == 1) ...[
                  _buildFpPhoneField(),
                  const SizedBox(height: 20),
                  _buildFpSendOtpButton(setSheetState),
                ],

                // Step 2: OTP + New password + Reset
                if (_fpStep == 2) ...[
                  _buildFpOtpField(),
                  const SizedBox(height: 16),
                  _buildFpNewPasswordField(),
                  const SizedBox(height: 16),
                  _buildFpConfirmPasswordField(),
                  const SizedBox(height: 24),
                  _buildFpResetButton(setSheetState),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    ),
  );
}




  void _onFocusChange() {
    final glow = _phoneFocus.hasFocus || _passwordFocus.hasFocus;
    if (glow != _cardGlowing) setState(() => _cardGlowing = glow);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LOGIN LOGIC  (original — untouched except variable rename)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      _toast('Please fill in all fields', error: true); return;
    }
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'phone':    _phoneController.text.trim(),
          'password': _passwordController.text,
        }),
      );
      final data = json.decode(response.body);

      String? token;
      if (data['token'] != null && data['token'] != 'null') {
        token = data['token'];
      } else if (data['data']?['token'] != null && data['data']['token'] != 'null') {
        token = data['data']['token'];
      } else if (data['accessToken'] != null && data['accessToken'] != 'null') {
        token = data['accessToken'];
      } else if (data['success'] == true && data['data'] != null && data['data'] != 'null') {
        token = data['data'];
      }

      if (token != null && token != 'null' && token.isNotEmpty) {
        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(key: 'access_token', value: token);   // ✅ ADD THIS

        final prefs = await SharedPreferences.getInstance();

        String? userId, name, phone;
        if (data['user'] != null) {
          userId = data['user']['id']?.toString() ?? data['user']['_id']?.toString();
          name   = data['user']['name']?.toString();
          phone  = data['user']['phone']?.toString();
        } else if (data['data'] is Map) {
          userId = data['data']['id']?.toString() ?? data['data']['_id']?.toString();
          name   = data['data']['name']?.toString();
          phone  = data['data']['phone']?.toString();
        } else {
          userId = data['id']?.toString() ?? data['_id']?.toString() ?? data['userId']?.toString();
          name   = data['name']?.toString();
          phone  = data['phone']?.toString();
        }

        if (userId == null) {
          try {
            final parts = token.split('.');
            if (parts.length == 3) {
              final decoded = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
              final jwt     = json.decode(decoded);
              userId = jwt['id']?.toString() ?? jwt['_id']?.toString()
                    ?? jwt['userId']?.toString() ?? jwt['sub']?.toString();
              name  ??= jwt['name']?.toString();
              phone ??= jwt['phone']?.toString();
            }
          } catch (_) {}
        }

        if (userId != null) {
          await prefs.setString('userId',      userId);
          await prefs.setString('name',        name  ?? '');
          await prefs.setString('phone',       phone ?? '');
          await prefs.setString('accessToken', token);

          final aeps = Provider.of<AepsProvider>(context, listen: false);
          aeps.setAuthDetails(
            token:      token,
            userId:     userId,
            merchantId: '',
            mobileNo:   phone ?? _phoneController.text.trim(),
          );

          final wallet = Provider.of<WalletProvider>(context, listen: false);
          wallet.setUserId(userId);

          try {
            final mr = await http.get(
              Uri.parse('${ApiConfig.baseUrl}/api/aeps/merchant/by-phone'
                  '?phone=${_phoneController.text.trim()}'),
              headers: {'Content-Type': 'application/json'},
            );
            if (mr.statusCode == 200) {
              final md = json.decode(mr.body);
              if (md['success'] == true && md['data'] != null) {
                aeps.setMerchantData({
                  'merchantId':    md['data']['merchantId'],
                  'merchantRefId': md['data']['merchantRefId'],
                  'phone':         md['data']['phone'] ?? phone,
                  'aadhaarNo':     md['data']['aadhaarNo'],
                  'firstName':     md['data']['firstName'],
                  'lastName':      md['data']['lastName'],
                });
                aeps.setAuthDetails(
                  token:      token,
                  userId:     userId,
                  merchantId: md['data']['merchantId'] ?? '',
                  mobileNo:   md['data']['phone'] ?? _phoneController.text.trim(),
                );
              }
            }
          } catch (_) {}
        }

        final saved = await _storage.read(key: 'jwt_token');
        if (saved != null && saved != 'null' && mounted) {
          HapticFeedback.heavyImpact();
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (c, a, _) => UserHomeScreen(),
              transitionsBuilder: (c, a, _, child) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(1.0, 0.0),
                    end:   Offset.zero,
                  ).animate(CurvedAnimation(parent: a, curve: Curves.easeInOutCubic)),
                  child: child,
                ),
              ),
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      } else {
        _toast(data['message'] ?? 'Login failed. Please try again.', error: true);
      }
    } catch (e) {
      _toast('Network error: $e', error: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

Future<void> _requestPasswordOtp(Function(void Function()) setSheetState) async {
  final phone = _fpPhoneController.text.trim();
  print('>>> Forgot password phone: $phone');   // ✅ 1

  if (phone.isEmpty) {
    _toast('Please enter your phone number', error: true);
    return;
  }

  setSheetState(() => _isFpLoading = true);

  try {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'phone': phone}),
    );
    print('>>> Response status: ${response.statusCode}');   // ✅ 2
    print('>>> Response body: ${response.body}');           // ✅ 3

    final data = json.decode(response.body);
   
    if (response.statusCode == 200 && (data['success'] == true || data['otpSent'] == true)) {
    if (response.statusCode == 200 && data['success'] == true) {
  // For testing: auto-fill OTP if backend returns it
  if (data['otp'] != null) {
    _fpOtpController.text = data['otp'].toString();
  }
  _toast('OTP sent to $phone');
  setSheetState(() {
    _fpStep = 2;
    _isFpLoading = false;
  });
}
} else {
      print('>>> API returned error: ${data['message']}');
      _toast(data['message'] ?? 'Failed to send OTP', error: true);
      setSheetState(() => _isFpLoading = false);
    }
  } catch (e, stack) {
    print('>>> Exception: $e');
    print('>>> Stack: $stack');
    _toast('Network error: $e', error: true);
    setSheetState(() => _isFpLoading = false);
  }
}

Future<void> _resetPasswordWithOtp(Function(void Function()) setSheetState) async {
  final phone = _fpPhoneController.text.trim();
  final otp = _fpOtpController.text.trim();
  final newPass = _fpNewPassController.text.trim();
  final confirmPass = _fpConfirmPassController.text.trim();

  if (phone.isEmpty || otp.isEmpty || newPass.isEmpty) {
    _toast('All fields are required', error: true);
    return;
  }
  if (newPass.length < 6) {
    _toast('Password must be at least 6 characters', error: true);
    return;
  }
  if (newPass != confirmPass) {
    _toast('Passwords do not match', error: true);
    return;
  }

  setSheetState(() => _isFpLoading = true);

  try {
    // 🔁 Replace with your actual "reset password" endpoint
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'phone': phone,
        'otp': otp,
        'newPassword': newPass,
      }),
    );

    final data = json.decode(response.body);
    if (response.statusCode == 200 && (data['success'] == true || data['reset'] == true)) {
      _toast('Password changed successfully. Please log in.');
      Navigator.pop(context); // close dialog
      // Optionally auto‑fill the new password in the main login form
      _passwordController.text = newPass;
    } else {
      _toast(data['message'] ?? 'Password reset failed', error: true);
    }
  } catch (e) {
    _toast('Network error: $e', error: true);
  } finally {
    if (mounted) setSheetState(() => _isFpLoading = false);
  }
}

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: error ? _N.error : _N.caramel,
      behavior:        SnackBarBehavior.floating,
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin:          const EdgeInsets.all(16),
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
          // ── Ambient background orbs ──────────────────────────────────
          const _AmbientBg(),

          SafeArea(
            child: FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
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
                      _buildTabToggle(),
                      const SizedBox(height: 14),
                      _buildGlassCard(),
                      const SizedBox(height: 16),
                      _buildBottomLink(),
                      const SizedBox(height: 20),
                      _buildTrustStrip(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFpPhoneField() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const _FieldLabel('Phone number'),
    const SizedBox(height: 8),
    Container(
      height: 52,
      decoration: BoxDecoration(
        color: _N.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _N.glassBd),
      ),
      child: TextField(
        controller: _fpPhoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(color: _N.white),
        decoration: const InputDecoration(
          hintText: 'e.g. 9876543210',
          hintStyle: TextStyle(color: _N.hint),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    ),
  ],
);

Widget _buildFpOtpField() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const _FieldLabel('OTP'),
    const SizedBox(height: 8),
    Container(
      height: 52,
      decoration: BoxDecoration(
        color: _N.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _N.glassBd),
      ),
      child: TextField(
        controller: _fpOtpController,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: _N.white),
        decoration: const InputDecoration(
          hintText: '6‑digit code',
          hintStyle: TextStyle(color: _N.hint),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    ),
  ],
);

Widget _buildFpNewPasswordField() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const _FieldLabel('New password'),
    const SizedBox(height: 8),
    Container(
      height: 52,
      decoration: BoxDecoration(
        color: _N.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _N.glassBd),
      ),
      child: TextField(
        controller: _fpNewPassController,
        obscureText: true,
        style: const TextStyle(color: _N.white),
        decoration: const InputDecoration(
          hintText: 'Minimum 6 characters',
          hintStyle: TextStyle(color: _N.hint),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    ),
  ],
);

Widget _buildFpConfirmPasswordField() => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const _FieldLabel('Confirm password'),
    const SizedBox(height: 8),
    Container(
      height: 52,
      decoration: BoxDecoration(
        color: _N.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _N.glassBd),
      ),
      child: TextField(
        controller: _fpConfirmPassController,
        obscureText: true,
        style: const TextStyle(color: _N.white),
        decoration: const InputDecoration(
          hintText: 'Retype new password',
          hintStyle: TextStyle(color: _N.hint),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    ),
  ],
);


Widget _buildFpSendOtpButton(Function(void Function()) setSheetState) => GestureDetector(
  onTap: _isFpLoading ? null : () => _requestPasswordOtp(setSheetState),
  child: Container(
    width: double.infinity,
    height: 50,
    decoration: BoxDecoration(
      color: _N.caramel,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Center(
      child: _isFpLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _N.bg),
            )
          : const Text(
              'Send OTP',
              style: TextStyle(
                color: _N.bg,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
    ),
  ),
);

Widget _buildFpResetButton(Function(void Function()) setSheetState) => GestureDetector(
  onTap: _isFpLoading ? null : () => _resetPasswordWithOtp(setSheetState),
  child: Container(
    width: double.infinity,
    height: 50,
    decoration: BoxDecoration(
      color: _N.caramel,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Center(
      child: _isFpLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: _N.bg),
            )
          : const Text(
              'Reset password',
              style: TextStyle(
                color: _N.bg,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
    ),
  ),
);

  // ── Top bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      // Back
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
      // Security badge
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
            Text('256-bit SSL', style: TextStyle(color: _N.caramel, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
          ],
        ),
      ),
    ],
  );

// ── Hero logo (asset image with minimal bottom space) ─────────────────────
Widget _buildHeroLogo() => Column(
  mainAxisSize: MainAxisSize.min,  // ← important: no extra vertical space
  children: [
    SizedBox(
      height: 100,
      child: Image.asset(
        'assets/images/logo_white.png',
        fit: BoxFit.contain,
      ),
    ),
    // const SizedBox(height: 6),      // reduced from 8 to 6
    const Text(
      "India's smart money platform",
      style: TextStyle(
        fontSize: 11,
        color: Color(0x50FFFFFF),
        letterSpacing: 1.8,
      ),
    ),
  ],
);

  // ── Tab toggle ────────────────────────────────────────────────────────────
  Widget _buildTabToggle() => Container(
    height: 48,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: _N.glassFg,
      border: Border.all(color: _N.glassBd),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Stack(
      children: [
        // sliding pill
        AnimatedAlign(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOutCubic,
          alignment: _isLoginMode ? Alignment.centerLeft : Alignment.centerRight,
          child: FractionallySizedBox(
            widthFactor: 0.5,
            child: Container(
              decoration: BoxDecoration(
                color: _N.caramel,
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ),
        // buttons
        Row(
          children: [
            Expanded(child: _tabBtn('Log in',   _isLoginMode,  () => _setMode(true))),
            Expanded(child: _tabBtn('Sign up',  !_isLoginMode, () => _setMode(false))),
          ],
        ),
      ],
    ),
  );

  Widget _tabBtn(String label, bool active, VoidCallback onTap) =>
    GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xFF1C0F06) : const Color(0x60FFFFFF),
            letterSpacing: 0.3,
          ),
        ),
      ),
    );

  void _setMode(bool login) {
    HapticFeedback.selectionClick();
    setState(() => _isLoginMode = login);
  }

  // ── Glass card ─────────────────────────────────────────────────────────────
  Widget _buildGlassCard() => AnimatedContainer(
    duration: const Duration(milliseconds: 250),
    decoration: BoxDecoration(
      color: _N.glassFg,
      border: Border.all(
        color: _cardGlowing ? _N.glowBd : _N.glassBd,
        width: _cardGlowing ? 1.5 : 1,
      ),
      borderRadius: BorderRadius.circular(26),
    ),
    padding: const EdgeInsets.all(22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isLoginMode ? 'Welcome back' : 'Create account',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _N.white),
        ),
        const SizedBox(height: 4),
        Text(
          _isLoginMode
            ? 'Manage your money the smart way.'
            : 'Join 2M+ users building wealth digitally.',
          style: const TextStyle(fontSize: 13, color: _N.sub, height: 1.4),
        ),
        const SizedBox(height: 22),

        // Phone field
        _buildPhoneField(),
        const SizedBox(height: 16),

        // Password field
        _buildPasswordField(),

        if (_isLoginMode) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showForgotPasswordDialog();
            },              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: const Text('Forgot password?',
                style: TextStyle(color: _N.caramel, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // CTA button
        _buildCtaButton(),

        const SizedBox(height: 18),
        _buildDivider(),
        const SizedBox(height: 14),
        _buildSocialRow(),
      ],
    ),
  );

  // ── Phone field ────────────────────────────────────────────────────────────
  Widget _buildPhoneField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _FieldLabel('Phone number'),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0804),
          border: Border.all(
            color: _phoneFocus.hasFocus ? _N.caramel : const Color(0x1AFFFFFF),
            width: _phoneFocus.hasFocus ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        height: 54,
        child: Row(
          children: [
            // Country code picker
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
                    Text(_selectedCC.code,
                      style: const TextStyle(color: _N.caramel, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more_rounded, color: Color(0x50FFFFFF), size: 16),
                  ],
                ),
              ),
            ),
            // Input
            Expanded(
              child: TextField(
                controller:  _phoneController,
                focusNode:   _phoneFocus,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: _N.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText:      'Mobile number',
                  hintStyle:     TextStyle(color: _N.hint, fontSize: 14),
                  border:        InputBorder.none,
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
            const Text('Select country code',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
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

  // ── Password field ─────────────────────────────────────────────────────────
  Widget _buildPasswordField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _FieldLabel('Password'),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF0F0804),
          border: Border.all(
            color: _passwordFocus.hasFocus ? _N.caramel : const Color(0x1AFFFFFF),
            width: _passwordFocus.hasFocus ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        height: 54,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller:    _passwordController,
                focusNode:     _passwordFocus,
                obscureText:   !_isPasswordVisible,
                style: const TextStyle(color: _N.white, fontSize: 15),
                decoration: const InputDecoration(
                  hintText:       'Enter password',
                  hintStyle:      TextStyle(color: _N.hint, fontSize: 14),
                  border:         InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _N.sub, size: 20,
              ),
              onPressed: () {
                HapticFeedback.selectionClick();
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
            ),
          ],
        ),
      ),
    ],
  );

  // ── CTA button ─────────────────────────────────────────────────────────────
  Widget _buildCtaButton() => GestureDetector(
    onTap: _isLoading ? null : _login,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        color: _N.caramel,
        borderRadius: BorderRadius.circular(15),
        // subtle inner highlight at top
        border: Border.all(color: const Color(0x30FFFFFF), width: 0.5),
      ),
      child: Center(
        child: _isLoading
          ? const SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(_N.bg)),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isLoginMode ? 'Log in' : 'Create account',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _N.bg, letterSpacing: 0.3),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: _N.bg, size: 20),
              ],
            ),
      ),
    ),
  );

  // ── Divider ───────────────────────────────────────────────────────────────
  Widget _buildDivider() => Row(
    children: const [
      Expanded(child: Divider(color: Color(0x12FFFFFF))),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Text('or continue with',
          style: TextStyle(fontSize: 11, color: Color(0x40FFFFFF), fontWeight: FontWeight.w500)),
      ),
      Expanded(child: Divider(color: Color(0x12FFFFFF))),
    ],
  );

  // ── Social row ────────────────────────────────────────────────────────────
  Widget _buildSocialRow() => Row(
    children: [
      Expanded(child: _socialBtn(Icons.g_mobiledata_rounded, 'Google')),
      const SizedBox(width: 10),
      Expanded(child: _socialBtn(Icons.apple_rounded,         'Apple')),
    ],
  );

  Widget _socialBtn(IconData icon, String label) => GestureDetector(
    onTap: () => HapticFeedback.lightImpact(),
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        color: _N.glassFg,
        border: Border.all(color: _N.glassBd),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _N.sub, size: 20),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: _N.sub, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );

  // ── Bottom link ───────────────────────────────────────────────────────────
  Widget _buildBottomLink() => Center(
    child: GestureDetector(
      onTap: () => _setMode(!_isLoginMode),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: _N.sub),
          children: [
            TextSpan(text: _isLoginMode ? "New to Neofyn? " : "Already have an account? "),
            TextSpan(
              text: _isLoginMode ? 'Create account' : 'Log in',
              style: const TextStyle(color: _N.caramel, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Trust strip ───────────────────────────────────────────────────────────
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
    _ac.dispose();
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

// ─────────────────────────────────────────────────────────────────────────────
//  SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// Field label with uppercase style
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _N.sub, letterSpacing: 1.4),
  );
}

/// Trust badge at bottom strip
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
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

/// Ambient background orbs + grid pattern
class _AmbientBg extends StatelessWidget {
  const _AmbientBg();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // top-right warm orb
        Positioned(
          top: -80, right: -80,
          child: Container(
            width: 260, height: 260,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x20B46E32),
            ),
          ),
        ),
        // bottom-left cool orb
        Positioned(
          bottom: 100, left: -60,
          child: Container(
            width: 200, height: 200,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x158C4B19),
            ),
          ),
        ),
        // center micro orb
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: MediaQuery.of(context).size.width  * 0.5 - 60,
          child: Container(
            width: 120, height: 120,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x09C8956C),
            ),
          ),
        ),
      ],
    );
  }
}