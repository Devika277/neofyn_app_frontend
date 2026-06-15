// lib/screens/account/Profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../services/session_service.dart';
import 'change_mpin_screen.dart';
import 'change_tpin_screen.dart' show ChangeTpinScreen;
import 'login_screen.dart';
import 'set_mpin_screen.dart';
import 'set_tpin_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BRAND COLORS
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFF008169);
  static const primaryLight = Color(0xFF1AA88A);
  static const primaryDark = Color(0xFF005F4E);
  static const white = Colors.white;
  static const grey = Color(0xFF8A9A8A);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF4CAF50);
  static const bg = Color(0xFF0A0E0A);
  static const card = Color(0xFF0F1A0F);
}

class ProfilePage extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfilePage({super.key, required this.onLogout});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _name = 'Merchant';
  String _phone = '';
  String _email = '';
  String _userId = '';
  String _selectedLanguage = 'English';
  bool _isDarkTheme = true;
  File? _profileImage;

  // Responsive dimensions - initialized with default values
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

    // Responsive calculations optimized for one-hand use
    _avatarSize = (_screenWidth * 0.2).clamp(65.0, 80.0);
    _iconSize = (_screenWidth * 0.045).clamp(18.0, 22.0);
    _fontSizeTitle = (_screenWidth * 0.04).clamp(14.0, 16.0);
    _fontSizeSubtitle = (_screenWidth * 0.032).clamp(11.0, 13.0);
    _fontSizeBody = (_screenWidth * 0.035).clamp(12.0, 14.0);
    _cardRadius = (_screenWidth * 0.04).clamp(12.0, 16.0);
    _paddingHorizontal = (_screenWidth * 0.04).clamp(12.0, 20.0);
    _spacing = (_screenHeight * 0.015).clamp(8.0, 16.0);

    if (!_isInitialized) {
      _isInitialized = true;
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('profile_image');
    if (!mounted) return;
    setState(() {
      _name = prefs.getString('name') ?? 'Merchant';
      _phone = prefs.getString('phone') ?? '';
      _email = prefs.getString('email') ?? 'merchant@neofyn.com';
      _userId = prefs.getString('userId') ?? 'PN8472193';
      _selectedLanguage = prefs.getString('language') ?? 'English';
      if (imagePath != null && File(imagePath).existsSync()) {
        _profileImage = File(imagePath);
      }
    });
  }

  Future<void> _pickFromGallery() async {
    Navigator.pop(context);
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );
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
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 500,
        maxHeight: 500,
      );
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_cardRadius * 1.5),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(_paddingHorizontal),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: _screenWidth * 0.08,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: _spacing * 1.5),
              Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: _fontSizeTitle * 1.1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: _spacing * 1.5),
              _buildImageOption(
                Icons.photo_library_rounded,
                'Choose from Gallery',
                AppColors.primaryLight,
                _pickFromGallery,
              ),
              SizedBox(height: _spacing * 0.5),
              _buildImageOption(
                Icons.camera_alt_rounded,
                'Take a Photo',
                AppColors.primaryLight,
                _takePhoto,
              ),
              if (_profileImage != null) ...[
                SizedBox(height: _spacing * 0.5),
                _buildImageOption(
                  Icons.delete_outline_rounded,
                  'Remove Photo',
                  AppColors.error,
                  _removePhoto,
                  isDestructive: true,
                ),
              ],
              SizedBox(height: _spacing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageOption(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _paddingHorizontal * 0.8,
          vertical: _spacing * 0.8,
        ),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppColors.error.withOpacity(0.1)
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: _iconSize * 0.9),
            SizedBox(width: _spacing),
            Text(
              title,
              style: TextStyle(
                color: isDestructive ? AppColors.error : Colors.white,
                fontSize: _fontSizeBody,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeLanguage() async {
    final languages = [
      'English',
      'हिंदी',
      'தமிழ்',
      'తెలుగు',
      'मराठी',
      'ગુજરાતી',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(_cardRadius * 1.5),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.all(_paddingHorizontal),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: _screenWidth * 0.08,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: _spacing),
            Text(
              'Select Language',
              style: TextStyle(
                fontSize: _fontSizeTitle * 1.1,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(height: _spacing),
            ...languages.map(
              (lang) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  lang,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _fontSizeBody,
                  ),
                ),
                trailing: _selectedLanguage == lang
                    ? Icon(
                        Icons.check_circle,
                        color: AppColors.primaryLight,
                        size: _iconSize * 0.9,
                      )
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('language', lang);
                  if (!mounted) return;
                  setState(() => _selectedLanguage = lang);
                  _showToast('Language changed to $lang');
                },
              ),
            ),
            SizedBox(height: _spacing * 0.5),
          ],
        ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius * 1.25),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(color: Colors.white, fontSize: _fontSizeTitle * 1.1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: Colors.white, fontSize: _fontSizeBody),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(
                  color: Colors.white54,
                  fontSize: _fontSizeSubtitle,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryLight),
                ),
              ),
            ),
            SizedBox(height: _spacing),
            TextField(
              controller: emailCtrl,
              style: TextStyle(color: Colors.white, fontSize: _fontSizeBody),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(
                  color: Colors.white54,
                  fontSize: _fontSizeSubtitle,
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.primary.withOpacity(0.5),
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryLight),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white54,
                fontSize: _fontSizeSubtitle,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('name', nameCtrl.text);
              await prefs.setString('email', emailCtrl.text);
              if (!mounted) return;
              setState(() {
                _name = nameCtrl.text;
                _email = emailCtrl.text;
              });
              _showToast('Profile updated');
            },
            child: Text(
              'Save',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w700,
                fontSize: _fontSizeSubtitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Replace the old _changeMpin with this:
  void _navigateToChangeMpin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangeMpinScreen()),
    );
  }

  void _navigateToTpin() {
    final auth = context.read<AuthProvider>();
    final hasTpin = auth.user?.tpinSet ?? false;

    if (hasTpin) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChangeTpinScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SetTPINScreen()),
      );
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius * 1.25),
        ),
        title: Text(
          'Sign Out?',
          style: TextStyle(color: Colors.white, fontSize: _fontSizeTitle * 1.1),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white60, fontSize: _fontSizeSubtitle),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.white54,
                fontSize: _fontSizeSubtitle,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            child: Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
                fontSize: _fontSizeSubtitle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: TextStyle(color: Colors.white, fontSize: _fontSizeSubtitle),
        ),
        backgroundColor: error ? AppColors.error : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
        ),
        margin: EdgeInsets.all(_paddingHorizontal),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(_paddingHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: _spacing * 0.5),

          // Header
          Text(
            'Profile',
            style: TextStyle(
              fontSize: _fontSizeTitle * 1.75,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),

          SizedBox(height: _spacing * 1.5),

          // ── Compact Profile Card ──
          _buildProfileCard(),

          SizedBox(height: _spacing * 2),

          // ── Account Section ──
          _buildSectionHeader('Account'),
          SizedBox(height: _spacing),

          _buildMenuItem(
            icon: Icons.lock_rounded,
            title: 'Change MPIN',
            subtitle: 'Update security PIN',
            onTap: _navigateToChangeMpin,
          ),
          SizedBox(height: _spacing * 0.5),

          // Show TPIN status and option based on whether TPIN is set
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final hasTpin = auth.user?.tpinSet ?? false;

              return _buildMenuItem(
                icon: Icons.security_rounded,
                title: hasTpin ? 'Change TPIN' : 'Set TPIN',
                subtitle: hasTpin
                    ? 'Transaction PIN is set'
                    : 'Transaction PIN not set',
                trailing: hasTpin
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'SET',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: _fontSizeSubtitle * 0.7,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: _spacing * 0.5),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white24,
                            size: _iconSize * 0.8,
                          ),
                        ],
                      )
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white24,
                        size: _iconSize * 0.8,
                      ),
                onTap: () {
                  if (hasTpin) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangeTpinScreen(),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SetTPINScreen()),
                    );
                  }
                },
              );
            },
          ),

          /*_buildMenuItem(
            icon: Icons.security_rounded,
            title: 'Set TPIN',
            subtitle: 'Transaction PIN',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SetTPINScreen()),
              );
            },
          ),*/
          SizedBox(height: _spacing * 2),

          // ── Preferences Section ──
          _buildSectionHeader('Preferences'),
          SizedBox(height: _spacing),

          _buildMenuItem(
            icon: Icons.language_rounded,
            title: 'Language',
            subtitle: _selectedLanguage,
            onTap: _changeLanguage,
          ),
          SizedBox(height: _spacing * 0.5),
          _buildMenuItem(
            icon: _isDarkTheme
                ? Icons.dark_mode_rounded
                : Icons.light_mode_rounded,
            title: 'Theme',
            subtitle: _isDarkTheme ? 'Dark Mode' : 'Light Mode',
            trailing: Switch(
              value: _isDarkTheme,
              onChanged: (val) {
                setState(() => _isDarkTheme = val);
                _showToast(val ? 'Dark theme applied' : 'Light theme applied');
              },
              activeColor: AppColors.primaryLight,
            ),
          ),
          SizedBox(height: _spacing * 0.5),
          _buildMenuItem(
            icon: Icons.notifications_rounded,
            title: 'Notifications',
            subtitle: 'Manage alerts',
            onTap: () {},
          ),

          SizedBox(height: _spacing * 2),

          // ── Support Section ──
          _buildSectionHeader('Support'),
          SizedBox(height: _spacing),

          _buildMenuItem(
            icon: Icons.help_rounded,
            title: 'Help Center',
            subtitle: 'Get help & support',
            onTap: () {},
            isCompact: true,
          ),
          SizedBox(height: _spacing * 0.5),
          _buildMenuItem(
            icon: Icons.info_rounded,
            title: 'About',
            subtitle: 'Version 1.0.0',
            onTap: () {},
            isCompact: true,
          ),
          SizedBox(height: _spacing * 0.5),
          _buildMenuItem(
            icon: Icons.description_rounded,
            title: 'Terms & Conditions',
            subtitle: 'Read our policies',
            onTap: () {},
            isCompact: true,
          ),

          SizedBox(height: _spacing * 2.5),

          // ── Sign Out Button ──
          _buildSignOutButton(),

          SizedBox(height: _spacing * 2),
        ],
      ),
    );
  }

  // ── Profile Card Widget ──
  Widget _buildProfileCard() {
    return GestureDetector(
      onTap: _showEditProfileDialog,
      child: Container(
        padding: EdgeInsets.all(_paddingHorizontal * 0.8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.25),
              AppColors.primaryDark.withOpacity(0.15),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(_cardRadius * 1.2),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Profile Image
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: Stack(
                children: [
                  Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(_cardRadius * 0.8),
                      image: _profileImage != null
                          ? DecorationImage(
                              image: FileImage(_profileImage!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _profileImage == null
                        ? Center(
                            child: Text(
                              _name.isNotEmpty ? _name[0].toUpperCase() : 'N',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: _fontSizeTitle * 1.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: _avatarSize * 0.32,
                      height: _avatarSize * 0.32,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(_cardRadius * 0.4),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: _iconSize * 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: _spacing),

            // Profile Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: TextStyle(
                      fontSize: _fontSizeTitle * 1.1,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: _spacing * 0.3),
                  Text(
                    _phone.isNotEmpty ? _phone : '+91 XXXXXXXXXX',
                    style: TextStyle(
                      fontSize: _fontSizeSubtitle,
                      color: Colors.white54,
                    ),
                  ),
                  SizedBox(height: _spacing * 0.2),
                  Text(
                    _email,
                    style: TextStyle(
                      fontSize: _fontSizeSubtitle * 0.9,
                      color: Colors.white38,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: _spacing * 0.4),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: _paddingHorizontal * 0.4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(_cardRadius * 0.4),
                    ),
                    child: Text(
                      'ID: $_userId',
                      style: TextStyle(
                        fontSize: _fontSizeSubtitle * 0.8,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Edit icon
            Icon(
              Icons.edit_rounded,
              color: Colors.white.withOpacity(0.3),
              size: _iconSize * 0.8,
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Header Widget ──
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: _fontSizeTitle * 0.9,
        fontWeight: FontWeight.w700,
        color: Colors.white.withOpacity(0.9),
        letterSpacing: 0.3,
      ),
    );
  }

  // ── Menu Item Widget ──
  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
    bool isCompact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _paddingHorizontal * 0.8,
          vertical: isCompact ? _spacing * 0.8 : _spacing,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: _iconSize * 1.8,
              height: _iconSize * 1.8,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(_cardRadius * 0.6),
              ),
              child: Icon(
                icon,
                color: AppColors.primaryLight,
                size: _iconSize * 0.9,
              ),
            ),
            SizedBox(width: _spacing * 0.8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _fontSizeBody,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: _fontSizeSubtitle * 0.85,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white24,
                  size: _iconSize * 0.8,
                ),
          ],
        ),
      ),
    );
  }

  // ── Sign Out Button Widget ──
  Widget _buildSignOutButton() {
    return GestureDetector(
      onTap: _showLogoutDialog,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: _spacing * 0.9),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.08),
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: AppColors.error.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: _iconSize * 0.9,
            ),
            SizedBox(width: _spacing * 0.5),
            Text(
              'Sign Out',
              style: TextStyle(
                color: AppColors.error,
                fontSize: _fontSizeBody,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
