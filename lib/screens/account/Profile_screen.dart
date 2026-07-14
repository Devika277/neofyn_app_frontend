// lib/screens/account/Profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/AEPS/api_service.dart';
import '../../services/session_service.dart';
import 'change_mpin_screen.dart';
import 'change_tpin_screen.dart' show ChangeTpinScreen;
import 'login_screen.dart';
import 'set_mpin_screen.dart';
import 'set_tpin_screen.dart';
import '../../widgets/fund_requests_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BRAND COLORS
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFF008169);
  static const primaryLight = Color(0xFF1AA88A);
  static const primaryDark = Color(0xFF005F4E);
  static const accent = Color(0xFF00C897);
  static const white = Colors.white;
  static const grey = Color(0xFF8A9A8A);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFB74D);
  static const bg = Color(0xFF0A0E0A);
  static const surface = Color(0xFF151915);
  static const card = Color(0xFF0F1A0F);
  static const textHint = Color(0xFF6B7280);
}

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;
  final Map<String, dynamic>? profileData;

  const ProfilePage({super.key, required this.onLogout, this.profileData});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = 'Merchant';
  String _phone = '';
  String _email = '';
  String _userId = '';
  String _selectedLanguage = 'English';
  String _memberId = '';
  bool tpin = false;
  bool _isDarkTheme = true;
  File? _profileImage;

  // ✅ Merchant profile data from API
  Map<String, dynamic>? _merchantData;
  bool _isLoadingProfile = false;
  String _aadhaarNumber = '';
  String _panNumber = '';
  String _businessName = '';
  String _businessType = '';
  String _businessAddress = '';
  String _pincode = '';
  String _state = '';
  String _city = '';
  String _bankAccount = '';
  String _bankIfsc = '';
  String _bankName = '';
  String _merchantId = '';
  String _merchantRefId = '';
  String _pipe = '';

  // Support contact details
  static const String supportPhone = '+917994949990';
  static const String supportEmail = 'care@myneofin.com';

  // Responsive dimensions
  double _screenWidth = 0;
  double _screenHeight = 0;
  double _avatarSize = 70;
  double _iconSize = 20;
  double _fontSizeTitle = 15;
  double _fontSizeSubtitle = 12;
  double _fontSizeBody = 13;
  double _cardRadius = 14;
  double _paddingHorizontal = 16;
  double _spacing = 12;

  bool _isInitialized = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateDimensions();
  }

  void _updateDimensions() {
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;
    _screenHeight = size.height;
    _avatarSize = (_screenWidth * 0.2).clamp(65.0, 80.0);
    _iconSize = (_screenWidth * 0.045).clamp(18.0, 22.0);
    _fontSizeTitle = (_screenWidth * 0.04).clamp(14.0, 16.0);
    _fontSizeSubtitle = (_screenWidth * 0.032).clamp(11.0, 13.0);
    _fontSizeBody = (_screenWidth * 0.035).clamp(12.0, 14.0);
    _cardRadius = (_screenWidth * 0.04).clamp(12.0, 16.0);
    _paddingHorizontal = (_screenWidth * 0.04).clamp(12.0, 20.0);
    _spacing = (_screenHeight * 0.015).clamp(8.0, 16.0);
    if (!_isInitialized) _isInitialized = true;
  }

  void _navigateToFundRequests() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FundRequestsScreen()));
  }

  // ✅ UPDATED: Load profile from API with merchant details
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image');

    if (!mounted) return;

    setState(() {
      _name = prefs.getString('name') ?? 'Merchant';
      _phone = prefs.getString('phone') ?? '';
      _email = prefs.getString('email') ?? 'merchant@neofyn.com';
      _memberId = prefs.getString('member_id') ?? '';
      _userId = prefs.getString('userId') ?? '';
      tpin = prefs.getBool('tpin') ?? false;
      _selectedLanguage = prefs.getString('language') ?? 'English';
      if (imagePath != null && File(imagePath).existsSync()) {
        _profileImage = File(imagePath);
      }
    });

    // ✅ Fetch merchant profile from API
    await _fetchMerchantProfile();
  }

  Future<void> _fetchMerchantProfile() async {
    if (_userId.isEmpty) return;

    setState(() => _isLoadingProfile = true);

    try {
      final apiService = ApiService();
      final profileData = await apiService.getMerchantProfile(_userId);

      if (profileData != null && mounted) {
        setState(() async {
          _merchantData = profileData;

          // Personal Details
          final personal = profileData['personalDetails'] as Map<String, dynamic>?;
          if (personal != null) {
            _name = '${personal['firstName'] ?? ''} ${personal['lastName'] ?? ''}'.trim();
            _email = personal['email'] ?? _email;
            _phone = personal['mobile'] ?? _phone;
            _aadhaarNumber = personal['aadhaarNumber'] ?? '';
            _panNumber = personal['panNumber'] ?? '';
          }

          // Business Details
          final business = profileData['businessDetails'] as Map<String, dynamic>?;
          if (business != null) {
            _businessName = business['businessName'] ?? '';
            _businessType = business['businessType'] ?? '';
            _businessAddress = business['businessAddress'] ?? '';
            _pincode = business['pinCode'] ?? '';
            _state = business['state'] ?? '';
            _city = business['city'] ?? '';
          }

          // Bank Details
          final bank = profileData['bankDetails'] as Map<String, dynamic>?;
          if (bank != null) {
            _bankAccount = bank['bankAccount'] ?? '';
            _bankIfsc = bank['bankIfsc'] ?? '';
            _bankName = bank['bankNameCode'] ?? '';
          }

          // Merchant Details
          final merchant = profileData['merchantDetails'] as Map<String, dynamic>?;
          if (merchant != null) {
            _merchantId = merchant['merchantId'] ?? '';
            _merchantRefId = merchant['merchantRefId'] ?? '';
            _pipe = merchant['pipe'] ?? '';
          }

          // Save name to prefs
          final prefs = await SharedPreferences.getInstance();
          if (_name.isNotEmpty) prefs.setString('name', _name);
          if (_email.isNotEmpty) prefs.setString('email', _email);
          if (_phone.isNotEmpty) prefs.setString('phone', _phone);
        });

        debugPrint('✅ Merchant profile loaded successfully');
      }
    } catch (e) {
      debugPrint('❌ Profile API error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // ✅ Helper: Mask sensitive data - show only last 4 characters
  String _maskSensitive(String value) {
    if (value.isEmpty) return 'Not available';
    if (value.length <= 4) return value;
    final last4 = value.substring(value.length - 4);
    final masked = '•' * (value.length - 4);
    return '$masked$last4';
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SUPPORT POPUP METHODS
  // ─────────────────────────────────────────────────────────────────────────

  void _showSupportPopup() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
              ),
              child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 36),
            ),
            const SizedBox(height: 24),
            const Text(
              'Need Help?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose how you\'d like to reach us',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 24),
            // Call Option
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _launchCaller();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.call_rounded, color: AppColors.accent, size: 24),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Call Us', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('+91 7994949990', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                      ],
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textHint, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Email Option
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _launchEmail();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.email_rounded, color: AppColors.accent, size: 24),
                    SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Email Us', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('care@myneofin.com', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                      ],
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textHint, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white54, fontSize: 14)),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  Future<void> _launchCaller() async {
    final Uri launchUri = Uri(scheme: 'tel', path: supportPhone);
    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        _showToast('Unable to make a call', error: true);
      }
    }
  }

  Future<void> _launchEmail() async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query: 'subject=Support Request&body=Hello Neofin Support Team,',
    );
    try {
      await launchUrl(launchUri);
    } catch (e) {
      if (mounted) {
        _showToast('Unable to open email app', error: true);
      }
    }
  }

  Future<void> _pickFromGallery() async {
    Navigator.pop(context);
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 500, maxHeight: 500);
      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image', image.path);
        if (!mounted) return;
        setState(() => _profileImage = File(image.path));
        _showToast('Profile photo updated');
      }
    } catch (e) {
      _showToast('Failed to pick image', error: true);
    }
  }

  Future<void> _takePhoto() async {
    Navigator.pop(context);
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 500, maxHeight: 500);
      if (image != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image', image.path);
        if (!mounted) return;
        setState(() => _profileImage = File(image.path));
        _showToast('Profile photo updated');
      }
    } catch (e) {
      _showToast('Failed to capture photo', error: true);
    }
  }

  Future<void> _removePhoto() async {
    Navigator.pop(context);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profile_image');
    if (!mounted) return;
    setState(() => _profileImage = null);
    _showToast('Profile photo removed');
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(_cardRadius * 1.5))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(_paddingHorizontal),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: _screenWidth * 0.08, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: _spacing * 1.5),
            Text('Profile Photo', style: TextStyle(fontSize: _fontSizeTitle * 1.1, fontWeight: FontWeight.w700, color: Colors.white)),
            SizedBox(height: _spacing * 1.5),
            _buildImageOption(Icons.photo_library_rounded, 'Choose from Gallery', AppColors.primaryLight, _pickFromGallery),
            SizedBox(height: _spacing * 0.5),
            _buildImageOption(Icons.camera_alt_rounded, 'Take a Photo', AppColors.primaryLight, _takePhoto),
            if (_profileImage != null) ...[
              SizedBox(height: _spacing * 0.5),
              _buildImageOption(Icons.delete_outline_rounded, 'Remove Photo', AppColors.error, _removePhoto, isDestructive: true),
            ],
            SizedBox(height: _spacing),
          ]),
        ),
      ),
    );
  }

  Widget _buildImageOption(IconData icon, String title, Color color, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _paddingHorizontal * 0.8, vertical: _spacing * 0.8),
        decoration: BoxDecoration(color: isDestructive ? AppColors.error.withOpacity(0.1) : color.withOpacity(0.1), borderRadius: BorderRadius.circular(_cardRadius)),
        child: Row(children: [
          Icon(icon, color: color, size: _iconSize * 0.9),
          SizedBox(width: _spacing),
          Text(title, style: TextStyle(color: isDestructive ? AppColors.error : Colors.white, fontSize: _fontSizeBody, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Future<void> _changeLanguage() async {
    final languages = ['English', 'हिंदी', 'தமிழ்', 'తెలుగు', 'मराठी', 'ગુજરાતી'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(_cardRadius * 1.5))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(_paddingHorizontal),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: _screenWidth * 0.08, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          SizedBox(height: _spacing),
          Text('Select Language', style: TextStyle(fontSize: _fontSizeTitle * 1.1, fontWeight: FontWeight.w700, color: Colors.white)),
          SizedBox(height: _spacing),
          ...languages.map((lang) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(lang, style: TextStyle(color: Colors.white, fontSize: _fontSizeBody)),
            trailing: _selectedLanguage == lang ? Icon(Icons.check_circle, color: AppColors.primaryLight, size: _iconSize * 0.9) : null,
            onTap: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('language', lang);
              if (!mounted) return;
              setState(() => _selectedLanguage = lang);
              _showToast('Language changed to $lang');
            },
          )),
          SizedBox(height: _spacing * 0.5),
        ]),
      ),
    );
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius * 1.25)),
        title: Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: _fontSizeTitle * 1.1)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, style: TextStyle(color: Colors.white, fontSize: _fontSizeBody), decoration: InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white54, fontSize: _fontSizeSubtitle), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5))), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryLight)))),
          SizedBox(height: _spacing),
          TextField(controller: emailCtrl, style: TextStyle(color: Colors.white, fontSize: _fontSizeBody), decoration: InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: Colors.white54, fontSize: _fontSizeSubtitle), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary.withOpacity(0.5))), focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryLight)))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: _fontSizeSubtitle))),
          TextButton(onPressed: () async {
            Navigator.pop(ctx);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('name', nameCtrl.text);
            await prefs.setString('email', emailCtrl.text);
            if (!mounted) return;
            setState(() { _name = nameCtrl.text; _email = emailCtrl.text; });
            _showToast('Profile updated');
          }, child: Text('Save', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w700, fontSize: _fontSizeSubtitle))),
        ],
      ),
    );
  }

  void _navigateToChangeMpin() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeMpinScreen()));
  }

  void _navigateToTpin() async {
    if (tpin) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangeTpinScreen()));
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const SetTPINScreen()));
    }
    _loadProfile();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius * 1.25)),
        title: Text('Sign Out?', style: TextStyle(color: Colors.white, fontSize: _fontSizeTitle * 1.1)),
        content: Text('Are you sure you want to sign out?', style: TextStyle(color: Colors.white60, fontSize: _fontSizeSubtitle)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: Colors.white54, fontSize: _fontSizeSubtitle))),
          TextButton(onPressed: () { Navigator.pop(ctx); widget.onLogout(); }, child: Text('Sign Out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700, fontSize: _fontSizeSubtitle))),
        ],
      ),
    );
  }

  void _showToast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(color: Colors.white, fontSize: _fontSizeSubtitle)),
      backgroundColor: error ? AppColors.error : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      margin: EdgeInsets.all(_paddingHorizontal),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(_paddingHorizontal),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(height: _spacing * 0.5),
        Text('Profile', style: TextStyle(fontSize: _fontSizeTitle * 1.75, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
        SizedBox(height: _spacing * 1.5),
        _buildProfileCard(),
        SizedBox(height: _spacing * 2),

        // ✅ NEW: Merchant Details Section (only if data available)
        if (_merchantData != null) ...[
          _buildSectionHeader('Merchant Details'),
          SizedBox(height: _spacing),
          _buildDetailCard(),
          SizedBox(height: _spacing * 2),
        ],

        // Account Section
        _buildSectionHeader('Account'),
        SizedBox(height: _spacing),
        _buildMenuItem(icon: Icons.lock_rounded, title: 'Change MPIN', subtitle: 'Update security PIN', onTap: _navigateToChangeMpin),
        SizedBox(height: _spacing * 0.5),
        Consumer<AuthProvider>(builder: (context, auth, _) {
          return _buildMenuItem(
            icon: Icons.security_rounded,
            title: tpin ? 'Change TPIN' : 'Set TPIN',
            subtitle: tpin ? 'Transaction PIN is set' : 'Transaction PIN not set',
            trailing: tpin
                ? Row(mainAxisSize: MainAxisSize.min, children: [
              Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Text('SET', style: TextStyle(color: AppColors.success, fontSize: _fontSizeSubtitle * 0.7, fontWeight: FontWeight.w700))),
              SizedBox(width: _spacing * 0.5),
              Icon(Icons.chevron_right_rounded, color: Colors.white24, size: _iconSize * 0.8),
            ])
                : Icon(Icons.chevron_right_rounded, color: Colors.white24, size: _iconSize * 0.8),
            onTap: _navigateToTpin,
          );
        }),
        SizedBox(height: _spacing * 0.5),
        _buildSectionHeader('Transactions'),
        SizedBox(height: _spacing),
        _buildMenuItem(icon: Icons.history_rounded, title: 'Fund Requests', subtitle: 'View all your fund requests', onTap: _navigateToFundRequests),
        SizedBox(height: _spacing * 0.5),
        _buildSectionHeader('Support'),
        SizedBox(height: _spacing),
        _buildMenuItem(icon: Icons.help_rounded, title: 'Help Center', subtitle: 'Get help & support', onTap: _showSupportPopup, isCompact: true),
        SizedBox(height: _spacing * 0.5),
        _buildMenuItem(icon: Icons.description_rounded, title: 'Terms & Conditions', subtitle: 'Read our policies', onTap: () {}, isCompact: true),
        SizedBox(height: _spacing * 2.5),
        _buildSignOutButton(),
        SizedBox(height: _spacing * 2),
        Center(child: Text('Version 1.0.0', style: TextStyle(fontSize: _fontSizeSubtitle * 0.9, color: Colors.white38, fontWeight: FontWeight.w400))),
      ]),
    );
  }

  // ✅ NEW: Merchant Detail Card
  Widget _buildDetailCard() {
    return Container(
      padding: EdgeInsets.all(_paddingHorizontal * 0.9),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(children: [
        // ── Personal Details Section ──
        _buildSectionChip('👤 Personal Information'),
        const SizedBox(height: 12),
        _buildModernDetailCard(
          items: [
            if (_aadhaarNumber.isNotEmpty)
              _buildDetailItem(Icons.credit_card_rounded, 'Aadhaar Number', _maskSensitive(_aadhaarNumber)),
            _buildDetailItem(Icons.email_rounded, 'Email Address', _email),
            _buildDetailItem(Icons.phone_android_rounded, 'Mobile Number', _phone),
          ],
        ),
        const SizedBox(height: 20),

        // ── Business Details Section ──
        _buildSectionChip('🏢 Business Information'),
        const SizedBox(height: 12),
        _buildModernDetailCard(
          items: [
            if (_businessName.isNotEmpty)
              _buildDetailItem(Icons.store_rounded, 'Business Name', _businessName),
            if (_businessType.isNotEmpty)
              _buildDetailItem(Icons.category_rounded, 'Business Type', _businessType),
            if (_businessAddress.isNotEmpty)
              _buildDetailItem(Icons.location_on_rounded, 'Business Address', _businessAddress),
            if (_state.isNotEmpty || _city.isNotEmpty)
              _buildDetailItem(Icons.map_rounded, 'Location', '$_city, $_state'),
            if (_pincode.isNotEmpty)
              _buildDetailItem(Icons.pin_drop_rounded, 'Pincode', _pincode),
          ],
        ),
        const SizedBox(height: 20),

        // ── Bank Details Section ──
        _buildSectionChip('🏦 Bank Information'),
        const SizedBox(height: 12),
        _buildModernDetailCard(
          items: [
            if (_bankAccount.isNotEmpty)
              _buildDetailItem(Icons.account_balance_rounded, 'Account Number', _maskSensitive(_bankAccount)),
            if (_bankIfsc.isNotEmpty)
              _buildDetailItem(Icons.qr_code_2_rounded, 'IFSC Code', _bankIfsc),
          ],
        ),
        const SizedBox(height: 20),

        // ── Merchant Details Section ──
        _buildSectionChip('🔐 Merchant Information'),
        const SizedBox(height: 12),
        _buildModernDetailCard(
          items: [
            if (_merchantId.isNotEmpty)
              _buildDetailItem(Icons.badge_rounded, 'Merchant ID', _merchantId),
            if (_merchantRefId.isNotEmpty)
              _buildDetailItem(Icons.tag_rounded, 'Reference ID', _merchantRefId),
          ],
        ),
      ]),
    );
  }

  // ✅ Modern section chip
  Widget _buildSectionChip(String title) {
    return Row(children: [
      Container(
        width: 4,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: TextStyle(
          fontSize: _fontSizeTitle * 0.85,
          fontWeight: FontWeight.w700,
          color: Colors.white.withOpacity(0.9),
          letterSpacing: 0.3,
        ),
      ),
    ]);
  }

  // ✅ Modern detail card container
  Widget _buildModernDetailCard({required List<Widget> items}) {
    return Container(
      padding: EdgeInsets.all(_paddingHorizontal * 0.8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(_cardRadius * 1.2),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          return Column(children: [
            entry.value,
            if (!isLast)
              Divider(
                color: Colors.white.withOpacity(0.04),
                height: 1,
                indent: 8,
                endIndent: 8,
              ),
          ]);
        }).toList(),
      ),
    );
  }

  // ✅ Modern detail item (replaces old _detailRow)
  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: _spacing * 0.6,
        horizontal: _spacing * 0.3,
      ),
      child: Row(
        children: [
          // Icon container
          Container(
            width: _iconSize * 1.8,
            height: _iconSize * 1.8,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_cardRadius * 0.5),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryLight,
              size: _iconSize * 0.85,
            ),
          ),
          SizedBox(width: _spacing * 0.8),

          // Label & Value
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: _fontSizeSubtitle * 0.9,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    value.isNotEmpty ? value : '—',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _fontSizeBody * 0.95,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Copy icon for sensitive data
          if (label.contains('Aadhaar') || label.contains('IFSC') || label.contains('Account'))
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Clipboard.setData(ClipboardData(text: value));
                _showToast('$label copied');
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(
                  Icons.copy_rounded,
                  color: Colors.white.withOpacity(0.2),
                  size: _iconSize * 0.7,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ✅ Detail row widget (non-editable)
  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: _spacing * 0.4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.primaryLight, size: _iconSize * 0.8),
        SizedBox(width: _spacing * 0.8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value.isNotEmpty ? value : '-', style: TextStyle(color: Colors.white, fontSize: _fontSizeBody * 0.95)),
            SizedBox(height: 2),
            Text(label, style: TextStyle(color: Colors.white38, fontSize: _fontSizeSubtitle * 0.75)),
          ]),
        ),
      ]),
    );
  }

  // Profile Card
  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: _showEditProfileDialog,
      child: Container(
        padding: EdgeInsets.all(_paddingHorizontal * 0.8),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.25), AppColors.primaryDark.withOpacity(0.15)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(_cardRadius * 1.2),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: _showImagePickerOptions,
            child: Stack(children: [
              Container(
                width: _avatarSize, height: _avatarSize,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  borderRadius: BorderRadius.circular(_cardRadius * 0.8),
                  image: _profileImage != null ? DecorationImage(image: FileImage(_profileImage!), fit: BoxFit.cover) : null,
                ),
                child: _profileImage == null ? Center(child: Text(_name.isNotEmpty ? _name[0].toUpperCase() : 'N', style: TextStyle(color: Colors.white, fontSize: _fontSizeTitle * 1.5, fontWeight: FontWeight.bold))) : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: _avatarSize * 0.32, height: _avatarSize * 0.32,
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(_cardRadius * 0.4), border: Border.all(color: Colors.white, width: 1.5)),
                  child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: _iconSize * 0.7),
                ),
              ),
            ]),
          ),
          SizedBox(width: _spacing),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name, style: TextStyle(fontSize: _fontSizeTitle * 1.1, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
              SizedBox(height: _spacing * 0.3),
              Text(_phone.isNotEmpty ? _phone : '+91 XXXXXXXXXX', style: TextStyle(fontSize: _fontSizeSubtitle, color: Colors.white54)),
              SizedBox(height: _spacing * 0.2),
              Text(_email, style: TextStyle(fontSize: _fontSizeSubtitle * 0.9, color: Colors.white38), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (_isLoadingProfile) ...[
                SizedBox(height: _spacing * 0.4),
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight)),
              ],
            ]),
          ),
          Icon(Icons.edit_rounded, color: Colors.white.withOpacity(0.3), size: _iconSize * 0.8),
        ]),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(fontSize: _fontSizeTitle * 0.9, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.9), letterSpacing: 0.3));
  }

  Widget _buildMenuItem({required IconData icon, required String title, required String subtitle, VoidCallback? onTap, Widget? trailing, bool isCompact = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: _paddingHorizontal * 0.8, vertical: isCompact ? _spacing * 0.8 : _spacing),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(_cardRadius), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Row(children: [
          Container(width: _iconSize * 1.8, height: _iconSize * 1.8, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(_cardRadius * 0.6)), child: Icon(icon, color: AppColors.primaryLight, size: _iconSize * 0.9)),
          SizedBox(width: _spacing * 0.8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: Colors.white, fontSize: _fontSizeBody, fontWeight: FontWeight.w500)),
            SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: _fontSizeSubtitle * 0.85), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          trailing ?? Icon(Icons.chevron_right_rounded, color: Colors.white24, size: _iconSize * 0.8),
        ]),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return GestureDetector(
      onTap: _showLogoutDialog,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: _spacing * 0.9),
        decoration: BoxDecoration(color: AppColors.error.withOpacity(0.08), borderRadius: BorderRadius.circular(_cardRadius), border: Border.all(color: AppColors.error.withOpacity(0.2))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.logout_rounded, color: AppColors.error, size: _iconSize * 0.9),
          SizedBox(width: _spacing * 0.5),
          Text('Sign Out', style: TextStyle(color: AppColors.error, fontSize: _fontSizeBody, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}