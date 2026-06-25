// lib/screens/dmt/dmt_selector_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/dmt/api_service.dart';
import 'dmt_register_screen.dart';
import 'dmt_dashboard_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN FIN TECH BRAND TOKENS - Clean Professional UI
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // Primary palette - New Green Theme
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);

  // Dark Backgrounds (matching login screen)
  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color darkCard = Color(0xFF1A1F1A);

  // Text colors
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Card gradients
  static const List<Color> liteGradient = [Color(0xFF008169), Color(0xFF1AA88A)];
  static const List<Color> smartGradient = [Color(0xFF0984E3), Color(0xFF74B9FF)];

  // Border & Effects
  static const Color borderDark = Color(0xFF2A342A);
  static const Color borderFocus = Color(0xFF008169);
}

class DMTSelectorScreen extends StatefulWidget {
  const DMTSelectorScreen({Key? key}) : super(key: key);

  @override
  State<DMTSelectorScreen> createState() => _DMTSelectorScreenState();
}

class _DMTSelectorScreenState extends State<DMTSelectorScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  String? selectedType;
  String phoneNumber = '';
  bool isLoading = false;
  String? errorMessage;
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _selectDMTType(String type) {
    HapticFeedback.selectionClick();
    setState(() {
      selectedType = type;
      errorMessage = null;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  Future<void> _checkRemitter() async {
    if (phoneNumber.length != 10) {
      setState(() {
        errorMessage = 'Please enter a valid 10-digit phone number';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    if (selectedType == null) {
      setState(() {
        errorMessage = 'Please select a DMT type first';
      });
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await _apiService.checkRemitter(phoneNumber, selectedType!);

      if (response['exists'] == true) {
        final remitter = response['remitter'];
        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DMTDashboardScreen(
                remitterId: remitter['id'],
                productType: selectedType!,
              ),
            ),
          );
        }
      } else {
        HapticFeedback.mediumImpact();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DMTRegisterScreen(
                phoneNumber: phoneNumber,
                productType: selectedType!,
              ),
            ),
          );
        }
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'Money Transfer',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeaderSection(),

              const SizedBox(height: 24),

              // Plan Cards - Side by side
              _buildPlanCards(),

              const SizedBox(height: 24),

              // Phone Input Section
              _buildPhoneInputSection(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Transfer Type',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textWhite,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the plan that fits your business needs',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textDarkSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlanCards() {
    return Row(
      children: [
        Expanded(
          child: _buildPlanCard(
            title: 'DMT Lite',
            subtitle: 'For Small Business',
            icon: Iconsax.wallet_3,
            gradientColors: AppColors.liteGradient,
            features: [
              _FeatureItem(Iconsax.graph, 'Up to ₹25,000/month'),
              _FeatureItem(Iconsax.money_add, '₹10 registration fee'),
              _FeatureItem(Iconsax.percentage_circle, '1% surcharge (min ₹10)'),
              _FeatureItem(Iconsax.money_send, '₹5,000 per transaction'),
            ],
            isSelected: selectedType == 'lite',
            isRecommended: false,
            onTap: () => _selectDMTType('lite'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _buildPlanCard(
            title: 'DMT Smart',
            subtitle: 'For Growing Business',
            icon: Iconsax.crown_1,
            gradientColors: AppColors.smartGradient,
            features: [
              _FeatureItem(Iconsax.graph, 'Up to ₹2,00,000/month'),
              _FeatureItem(Iconsax.tick_circle, 'No registration fee'),
              _FeatureItem(Iconsax.discount_shape, 'Competitive rates'),
              _FeatureItem(Iconsax.money_send, '₹50,000 per transaction'),
            ],
            isSelected: selectedType == 'smart',
            isRecommended: true,
            onTap: () => _selectDMTType('smart'),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required List<_FeatureItem> features,
    required bool isSelected,
    required bool isRecommended,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        transform: isSelected
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.borderDark,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
                    : [],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gradient Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? gradientColors
                            : [Colors.grey[850]!, Colors.grey[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                icon,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Features List
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: features.map((feature) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.15)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  feature.icon,
                                  size: 12,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.white54,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature.label,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.textWhite
                                        : AppColors.textDarkSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Recommended Badge
            if (isRecommended)
              Positioned(
                top: -10,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.star, size: 10, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'BEST VALUE',
                        style: GoogleFonts.poppins(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Iconsax.mobile,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Enter Mobile Number',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textWhite,
                ),
              ),
              const Spacer(),
              if (selectedType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selectedType == 'lite' ? Iconsax.wallet_3 : Iconsax.crown_1,
                        size: 11,
                        color: AppColors.primaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        selectedType == 'lite' ? 'Lite' : 'Smart',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            'We\'ll check if you\'re already registered',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textDarkSecondary,
            ),
          ),

          const SizedBox(height: 14),

          // Phone Input Field
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _phoneFocus.hasFocus
                    ? AppColors.primary.withOpacity(0.5)
                    : errorMessage != null
                    ? AppColors.error.withOpacity(0.5)
                    : Colors.white.withOpacity(0.1),
                width: _phoneFocus.hasFocus ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Country Code
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 6),
                      Text(
                        '+91',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ],
                  ),
                ),

                // Phone Input
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    focusNode: _phoneFocus,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textWhite,
                      letterSpacing: 1.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter 10-digit number',
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.white30,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        phoneNumber = value;
                        errorMessage = null;
                      });
                    },
                    onSubmitted: (value) {
                      if (value.length == 10 && selectedType != null && !isLoading) {
                        _checkRemitter();
                      }
                    },
                  ),
                ),

                // Clear Button
                if (_phoneController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _phoneController.clear();
                          phoneNumber = '';
                          errorMessage = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Iconsax.close_circle,
                          size: 16,
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Phone number hint
          if (phoneNumber.isNotEmpty && phoneNumber.length < 10)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Row(
                children: [
                  Icon(
                    Iconsax.info_circle,
                    size: 12,
                    color: AppColors.warning.withOpacity(0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Enter complete 10-digit mobile number',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.warning.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

          // Error Message
          if (errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Iconsax.warning_2,
                      size: 14,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      errorMessage!,
                      style: GoogleFonts.poppins(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Continue Button
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: (selectedType != null && phoneNumber.length == 10)
                    ? [AppColors.primary, AppColors.primaryLight]
                    : [Colors.grey[800]!, Colors.grey[700]!],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: (selectedType != null && phoneNumber.length == 10)
                  ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ]
                  : [],
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : _checkRemitter,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.zero,
              ),
              child: isLoading
                  ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.arrow_right_3, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Select plan hint
          if (selectedType == null) ...[
            const SizedBox(height: 10),
            Center(
              child: Text(
                '👆 Select a plan above to continue',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textDarkSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureItem {
  final IconData icon;
  final String label;

  const _FeatureItem(this.icon, this.label);
}