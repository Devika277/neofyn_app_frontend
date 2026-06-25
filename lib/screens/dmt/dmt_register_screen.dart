// lib/screens/dmt/dmt_register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/dmt/api_service.dart';
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
  static const Color textDarkHint = Color(0xFF6B7280);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Border & Effects
  static const Color borderDark = Color(0xFF2A342A);
  static const Color borderFocus = Color(0xFF008169);
}

class DMTRegisterScreen extends StatefulWidget {
  final String phoneNumber;
  final String productType;

  const DMTRegisterScreen({
    Key? key,
    required this.phoneNumber,
    required this.productType,
  }) : super(key: key);

  @override
  State<DMTRegisterScreen> createState() => _DMTRegisterScreenState();
}

class _DMTRegisterScreenState extends State<DMTRegisterScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _aadhaarController = TextEditingController();
  String? _selectedState;
  String? _selectedStateName;
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _filteredStates = [];
  bool _isLoading = false;
  bool _loadingStates = true;
  String? _errorMessage;
  final TextEditingController _stateSearchController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadStates();

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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _aadhaarController.dispose();
    _stateSearchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStates() async {
    try {
      final states = await _apiService.getStateList();
      if (mounted) {
        setState(() {
          _states = states;
          _filteredStates = states;
          _loadingStates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingStates = false;
          _errorMessage = 'Failed to load states. Please check your connection.';
        });
      }
    }
  }

  void _filterStates(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredStates = _states;
      } else {
        _filteredStates = _states.where((state) {
          final name = (state['name'] ?? '').toString().toLowerCase();
          return name.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showStatePicker() {
    _stateSearchController.clear();
    _filteredStates = _states;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Select State',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search Field
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: TextField(
                        controller: _stateSearchController,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textWhite,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search state...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Iconsax.search_normal,
                            color: Colors.white38,
                            size: 18,
                          ),
                          suffixIcon: _stateSearchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(
                              Iconsax.close_circle,
                              color: Colors.white38,
                              size: 18,
                            ),
                            onPressed: () {
                              _stateSearchController.clear();
                              setModalState(() {
                                _filteredStates = _states;
                              });
                            },
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setModalState(() {
                            if (value.isEmpty) {
                              _filteredStates = _states;
                            } else {
                              _filteredStates = _states.where((state) {
                                final name = (state['name'] ?? '').toString().toLowerCase();
                                return name.contains(value.toLowerCase());
                              }).toList();
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // States List
                    Expanded(
                      child: _filteredStates.isEmpty
                          ? Center(
                        child: Text(
                          'No states found',
                          style: GoogleFonts.poppins(
                            color: AppColors.textDarkSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                          : ListView.separated(
                        controller: scrollController,
                        itemCount: _filteredStates.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withOpacity(0.05),
                        ),
                        itemBuilder: (context, index) {
                          final state = _filteredStates[index];
                          final isSelected = _selectedState == state['code'];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isSelected
                                    ? Iconsax.tick_circle
                                    : Iconsax.location,
                                size: 18,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white38,
                              ),
                            ),
                            title: Text(
                              state['name'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : AppColors.textWhite,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                              size: 20,
                            )
                                : null,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedState = state['code'] as String?;
                                _selectedStateName = state['name'] as String?;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null) {
      setState(() {
        _errorMessage = 'Please select your state';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.registerRemitter(
        mobile: widget.phoneNumber,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        stateCode: _selectedState!,
        productType: widget.productType,
        aadhaarNumber: _aadhaarController.text.trim(),
      );

      if (response.containsKey('id')) {
        HapticFeedback.heavyImpact();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Registration successful!',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DMTDashboardScreen(
                remitterId: response['id'],
                productType: widget.productType,
              ),
            ),
          );
        }
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
          'Register Remitter',
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Registration Info Card
                _buildRegistrationInfoCard(),

                const SizedBox(height: 24),

                // Section Header
                _buildSectionHeader(),

                const SizedBox(height: 20),

                // First Name
                _buildInputField(
                  controller: _firstNameController,
                  label: 'First Name',
                  hint: 'Enter your first name',
                  icon: Iconsax.user,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter first name';
                    }
                    if (value.length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Last Name
                _buildInputField(
                  controller: _lastNameController,
                  label: 'Last Name (Optional)',
                  hint: 'Enter your last name',
                  icon: Iconsax.user_tag,
                ),

                const SizedBox(height: 16),

                // Aadhaar Number
                _buildInputField(
                  controller: _aadhaarController,
                  label: 'Aadhaar Number',
                  hint: 'Enter 12-digit Aadhaar number',
                  icon: Iconsax.card,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter Aadhaar number';
                    }
                    if (value.length != 12 || !RegExp(r'^\d{12}$').hasMatch(value)) {
                      return 'Please enter a valid 12-digit Aadhaar';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // State Selection (Searchable)
                _buildStateSelector(),

                // Registration Fee Info
                if (widget.productType == 'lite') ...[
                  const SizedBox(height: 16),
                  _buildFeeInfoCard(),
                ],

                const SizedBox(height: 28),

                // Error Message
                if (_errorMessage != null) ...[
                  _buildErrorCard(),
                  const SizedBox(height: 16),
                ],

                // Register Button
                _buildRegisterButton(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegistrationInfoCard() {
    final isLite = widget.productType == 'lite';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderDark,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isLite
                      ? AppColors.primary.withOpacity(0.15)
                      : const Color(0xFF0984E3).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLite ? Iconsax.wallet_3 : Iconsax.crown_1,
                  color: isLite ? AppColors.primaryLight : const Color(0xFF74B9FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.productType.toUpperCase()} Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Complete registration to start transferring',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Phone Number Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Iconsax.call,
                    size: 14,
                    color: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Registered Mobile',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textDarkSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '+91 ${widget.phoneNumber}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textWhite,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 22,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Personal Information',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textWhite,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '(Required for KYC)',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: AppColors.textDarkHint,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textWhite,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.borderDark,
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: maxLength,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textWhite,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                color: Colors.white38,
                fontSize: 13,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryLight,
                  size: 18,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.error, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.error, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.darkSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              counterText: '',
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildStateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'State',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textWhite,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _loadingStates ? null : _showStatePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedState != null
                    ? AppColors.borderFocus
                    : AppColors.borderDark,
                width: _selectedState != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Iconsax.location,
                    color: AppColors.primaryLight,
                    size: 18,
                  ),
                ),
                Expanded(
                  child: _loadingStates
                      ? Row(
                    children: [
                      SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Loading states...',
                        style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                      : Text(
                    _selectedStateName ?? 'Select your state',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _selectedStateName != null
                          ? AppColors.textWhite
                          : Colors.white38,
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_down_1,
                  color: _selectedState != null
                      ? AppColors.primaryLight
                      : Colors.white38,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeeInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Iconsax.money_add,
              size: 18,
              color: AppColors.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration Fee',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A one-time fee of ₹10 will be charged',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textDarkSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '₹10',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Iconsax.warning_2,
              color: AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    final isFormValid = _firstNameController.text.isNotEmpty &&
        _aadhaarController.text.length == 12 &&
        _selectedState != null;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isFormValid
              ? [AppColors.primary, AppColors.primaryLight]
              : [Colors.grey[800]!, Colors.grey[700]!],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFormValid
            ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: EdgeInsets.zero,
        ),
        child: _isLoading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.user_add, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Complete Registration',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}