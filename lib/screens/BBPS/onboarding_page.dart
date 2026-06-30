import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../providers/bbps_provider.dart';
import '../../models/bbps_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NEOFYN FIN TECH BRAND TOKENS - Clean Professional UI
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);

  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color darkCard = Color(0xFF1A1F1A);

  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);
  static const Color textDarkHint = Color(0xFF6B7280);

  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  static const Color borderDark = Color(0xFF2A342A);
  static const Color borderFocus = Color(0xFF008169);
}

class OnboardingPage extends StatefulWidget {
  final VoidCallback? onOnboardingComplete; // ✅ Callback parameter

  const OnboardingPage({
    super.key,
    this.onOnboardingComplete, // ✅ Optional parameter
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  String? _selectedState;
  String? _selectedStateName;
  String? _selectedCity;
  String? _selectedCityName;
  String? _selectedBusinessType;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Load states on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<BBPSProvider>();
      provider.loadStates();
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _pincodeCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _showSearchablePicker({
    required String title,
    required List<Map<String, String>> items,
    required Function(String code, String name) onSelected,
    String? selectedCode,
  }) {
    final searchController = TextEditingController();
    List<Map<String, String>> filteredItems = List.from(items);

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
                    Text(
                      'Select $title',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: TextField(
                        controller: searchController,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textWhite,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search $title...',
                          hintStyle: GoogleFonts.poppins(
                            color: Colors.white38,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Iconsax.search_normal,
                            color: Colors.white38,
                            size: 18,
                          ),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                            icon: const Icon(
                              Iconsax.close_circle,
                              color: Colors.white38,
                              size: 18,
                            ),
                            onPressed: () {
                              searchController.clear();
                              setModalState(() {
                                filteredItems = List.from(items);
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
                              filteredItems = List.from(items);
                            } else {
                              filteredItems = items
                                  .where((item) =>
                                  (item['name'] ?? '')
                                      .toLowerCase()
                                      .contains(value.toLowerCase()))
                                  .toList();
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredItems.isEmpty
                          ? Center(
                        child: Text(
                          'No $title found',
                          style: GoogleFonts.poppins(
                            color: AppColors.textDarkSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                          : ListView.separated(
                        controller: scrollController,
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => Divider(
                          color: Colors.white.withOpacity(0.05),
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final itemCode = item['code'] ?? '';
                          final itemName = item['name'] ?? '';
                          final isSelected = itemCode == selectedCode;
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
                              itemName,
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
                              onSelected(itemCode, itemName);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null) {
      setState(() => _errorMessage = 'Please select a state');
      return;
    }

    if (_selectedCity == null) {
      setState(() => _errorMessage = 'Please select a city');
      return;
    }

    if (_selectedBusinessType == null) {
      setState(() => _errorMessage = 'Please select a business type');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final request = MerchantOnboardingRequest(
        firstName: _firstNameCtrl.text.trim(),
        middleName: _middleNameCtrl.text.trim().isEmpty
            ? null
            : _middleNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        dob: _dobCtrl.text.trim(),
        shopName: _shopNameCtrl.text.trim(),
        shopAddress: _shopAddressCtrl.text.trim(),
        shopState: _selectedState!,
        shopCity: _selectedCity!,
        pincode: _pincodeCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        businessType: _selectedBusinessType!,
      );

      await context.read<BBPSProvider>().onboardMerchant(request);

      if (mounted) {
        final response = context.read<BBPSProvider>().onboardingResponse;
        if (response != null && response.success) {
          HapticFeedback.heavyImpact();

          // ✅ CALL THE CALLBACK BEFORE NAVIGATING BACK
          widget.onOnboardingComplete?.call();

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
                    child: const Icon(Icons.check_circle,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Onboarding successful!',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );

          // Navigate back after showing success
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) Navigator.pop(context);
          });
        } else {
          setState(() {
            _errorMessage = context.read<BBPSProvider>().onboardingError ??
                'Onboarding failed';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // Convert BBPSState list to Map list for searchable picker
  List<Map<String, String>> _convertStates(List<BBPSState> states) {
    return states.map((state) {
      return {
        'code': state.stateCode ?? '',
        'name': state.stateName ?? '',
      };
    }).toList();
  }

  // Convert BBPScity list to Map list for searchable picker
  List<Map<String, String>> _convertCities(List<BBPScity> cities) {
    return cities.map((city) {
      return {
        'code': city.cityCode ?? '',
        'name': city.cityName ?? '',
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'Merchant Onboarding',
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
      body: Consumer<BBPSProvider>(
        builder: (context, provider, _) {
          // Convert provider data to maps
          final statesList = _convertStates(provider.states);
          final citiesList = _convertCities(provider.cities);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Card
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // Personal Details Section
                  _buildSectionHeader('Personal Details'),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _firstNameCtrl,
                    label: 'First Name *',
                    hint: 'Enter your first name',
                    icon: Iconsax.user,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'First name is required';
                      }
                      if (v.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) {
                        return 'Only alphabets allowed';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _middleNameCtrl,
                    label: 'Middle Name',
                    hint: 'Enter middle name (optional)',
                    icon: Iconsax.user_tag,
                    validator: (v) {
                      if (v != null && v.isNotEmpty) {
                        if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) {
                          return 'Only alphabets allowed';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _lastNameCtrl,
                    label: 'Last Name *',
                    hint: 'Enter your last name',
                    icon: Iconsax.user,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Last name is required';
                      }
                      if (v.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v.trim())) {
                        return 'Only alphabets allowed';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _dobCtrl,
                    label: 'Date of Birth *',
                    hint: 'YYYY-MM-DD',
                    icon: Iconsax.calendar,
                    keyboardType: TextInputType.datetime,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'DOB is required';
                      }
                      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) {
                        return 'Format must be YYYY-MM-DD';
                      }
                      try {
                        final date = DateTime.parse(v);
                        if (date.isAfter(DateTime.now())) {
                          return 'Date cannot be in future';
                        }
                        if (DateTime.now().difference(date).inDays < 365 * 18) {
                          return 'Must be at least 18 years old';
                        }
                      } catch (e) {
                        return 'Invalid date';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Shop Details Section
                  _buildSectionHeader('Shop Details'),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _shopNameCtrl,
                    label: 'Shop Name *',
                    hint: 'Enter your shop name',
                    icon: Iconsax.shop,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Shop name is required';
                      }
                      if (v.trim().length < 3) {
                        return 'Must be at least 3 characters';
                      }
                      if (!RegExp(r"^[a-zA-Z0-9\s\-'&]+$").hasMatch(v.trim())) {
                        return 'Only alphanumeric characters allowed';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _shopAddressCtrl,
                    label: 'Shop Address *',
                    hint: 'Enter complete shop address',
                    icon: Iconsax.location,
                    maxLines: 2,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Address is required';
                      }
                      if (v.trim().length < 10) {
                        return 'Please enter complete address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // State Dropdown with Search
                  _buildSearchableSelector(
                    label: 'State *',
                    icon: Iconsax.map,
                    hint: 'Select state',
                    selectedName: _selectedStateName,
                    isLoading: provider.loadingStates,
                    onTap: () {
                      if (!provider.loadingStates && statesList.isNotEmpty) {
                        _showSearchablePicker(
                          title: 'State',
                          items: statesList,
                          selectedCode: _selectedState,
                          onSelected: (code, name) {
                            setState(() {
                              _selectedState = code;
                              _selectedStateName = name;
                              _selectedCity = null;
                              _selectedCityName = null;
                            });
                            provider.loadCities(code);
                          },
                        );
                      } else if (statesList.isEmpty && !provider.loadingStates) {
                        // Retry loading states if empty
                        provider.loadStates();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Loading states, please try again...',
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                            backgroundColor: AppColors.warning,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // City Dropdown with Search
                  if (provider.loadingCities)
                    _buildLoadingIndicator('Loading cities...'),
                  if (!provider.loadingCities && citiesList.isNotEmpty)
                    _buildSearchableSelector(
                      label: 'City *',
                      icon: Iconsax.buildings,
                      hint: 'Select city',
                      selectedName: _selectedCityName,
                      onTap: () {
                        _showSearchablePicker(
                          title: 'City',
                          items: citiesList,
                          selectedCode: _selectedCity,
                          onSelected: (code, name) {
                            setState(() {
                              _selectedCity = code;
                              _selectedCityName = name;
                            });
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 16),

                  _buildInputField(
                    controller: _pincodeCtrl,
                    label: 'Pincode *',
                    hint: 'Enter 6-digit pincode',
                    icon: Iconsax.location_tick,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Pincode is required';
                      }
                      if (!RegExp(r'^\d{6}$').hasMatch(v)) {
                        return 'Must be 6 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Contact Details Section
                  _buildSectionHeader('Contact Details'),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _mobileCtrl,
                    label: 'Mobile Number *',
                    hint: 'Enter 10-digit mobile number',
                    icon: Iconsax.mobile,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Mobile number is required';
                      }
                      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                        return 'Enter valid 10-digit number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _emailCtrl,
                    label: 'Email Address *',
                    hint: 'Enter your email address',
                    icon: Iconsax.sms,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(
                          r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                          .hasMatch(v)) {
                        return 'Enter valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Business Details Section
                  _buildSectionHeader('Business Details'),
                  const SizedBox(height: 16),

                  // Business Type with Search
                  _buildSearchableSelector(
                    label: 'Business Type *',
                    icon: Iconsax.briefcase,
                    hint: 'Select business type',
                    selectedName: _selectedBusinessType,
                    onTap: () {
                      final businessTypes = [
                        {'code': 'Retail', 'name': 'Retail'},
                        {'code': 'Wholesale', 'name': 'Wholesale'},
                        {'code': 'Services', 'name': 'Services'},
                        {'code': 'Manufacturing', 'name': 'Manufacturing'},
                        {'code': 'Distribution', 'name': 'Distribution'},
                        {'code': 'Other', 'name': 'Other'},
                      ];
                      _showSearchablePicker(
                        title: 'Business Type',
                        items: businessTypes,
                        selectedCode: _selectedBusinessType,
                        onSelected: (code, name) {
                          setState(() {
                            _selectedBusinessType = code;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Error Message
                  if (_errorMessage != null) ...[
                    _buildErrorCard(),
                    const SizedBox(height: 20),
                  ],

                  // Submit Button
                  _buildSubmitButton(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.information,
                color: AppColors.primaryLight, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Complete your merchant profile to start accepting BBPS payments',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textDarkSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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
          title,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textWhite,
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
    TextCapitalization textCapitalization = TextCapitalization.words,
    int? maxLength,
    int? maxLines,
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
            border: Border.all(color: AppColors.borderDark),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLength: maxLength,
            maxLines: maxLines ?? 1,
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.primaryLight, size: 18),
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
                borderSide: const BorderSide(
                    color: AppColors.borderFocus, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.error, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                const BorderSide(color: AppColors.error, width: 1.5),
              ),
              filled: true,
              fillColor: AppColors.darkSurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              counterText: '',
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchableSelector({
    required String label,
    required IconData icon,
    required String hint,
    String? selectedName,
    bool isLoading = false,
    required VoidCallback onTap,
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
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selectedName != null
                    ? AppColors.borderFocus
                    : AppColors.borderDark,
                width: selectedName != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                  Icon(icon, color: AppColors.primaryLight, size: 18),
                ),
                Expanded(
                  child: isLoading
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
                        'Loading...',
                        style: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                      : Text(
                    selectedName ?? hint,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: selectedName != null
                          ? AppColors.textWhite
                          : Colors.white38,
                    ),
                  ),
                ),
                Icon(
                  Iconsax.arrow_down_1,
                  color: selectedName != null
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

  Widget _buildLoadingIndicator(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: AppColors.textDarkSecondary,
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
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Iconsax.warning_2,
                color: AppColors.error, size: 18),
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

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSubmitting
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
            const Icon(Iconsax.tick_circle,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Submit Onboarding',
              style: GoogleFonts.poppins(
                fontSize: 15,
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