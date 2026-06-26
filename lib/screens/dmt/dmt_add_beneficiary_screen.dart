// lib/screens/dmt/dmt_add_beneficiary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/dmt/api_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN FIN TECH BRAND TOKENS - Clean Professional UI
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

class DMTAddBeneficiaryScreen extends StatefulWidget {
  final int remitterId;

  const DMTAddBeneficiaryScreen({
    Key? key,
    required this.remitterId,
  }) : super(key: key);

  @override
  State<DMTAddBeneficiaryScreen> createState() => _DMTAddBeneficiaryScreenState();
}

class _DMTAddBeneficiaryScreenState extends State<DMTAddBeneficiaryScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _mobileController = TextEditingController();

  String? _selectedState;
  String? _selectedStateName;
  String? _selectedCity;
  String? _selectedCityName;
  List<Map<String, String>> _states = [];
  List<Map<String, String>> _cities = [];
  List<Map<String, String>> _banks = [];

  String? _selectedBankCode;
  String? _selectedBankName;

  bool _isLoading = false;
  bool _loadingStates = true;
  bool _loadingBanks = true;
  bool _loadingCities = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _apiService.getStateList(),
        _apiService.getBankList(),
      ]);

      final states = results[0] as List<Map<String, String>>;
      final banks = results[1] as List<Map<String, String>>;

      setState(() {
        _states = states;
        _banks = banks;
        _loadingStates = false;
        _loadingBanks = false;
      });
    } catch (e) {
      setState(() {
        _loadingStates = false;
        _loadingBanks = false;
        _errorMessage = 'Failed to load data. Please check your connection.';
      });
    }
  }

  Future<void> _loadCities(String stateCode) async {
    setState(() {
      _cities = [];
      _selectedCity = null;
      _selectedCityName = null;
      _loadingCities = true;
      _errorMessage = null;
    });

    try {
      final cities = await _apiService.getCityList(stateCode);
      final List<Map<String, String>> cityList = cities
          .map((e) => {
        'code': e['code']?.toString() ?? '',
        'name': e['name']?.toString() ?? '',
      })
          .toList();

      setState(() {
        _cities = cityList;
        _loadingCities = false;
      });
    } catch (e) {
      setState(() {
        _cities = [];
        _loadingCities = false;
        _errorMessage = 'Failed to load cities for this state';
      });
    }
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
                          final isSelected = item['code'] == selectedCode;
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
                              item['name'] ?? '',
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
                              onSelected(
                                item['code'] ?? '',
                                item['name'] ?? '',
                              );
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

  Future<void> _addBeneficiary() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null) {
      setState(() => _errorMessage = 'Please select a state');
      return;
    }

    if (_selectedBankCode == null) {
      setState(() => _errorMessage = 'Please select a bank');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.addBeneficiary(
        remitterId: widget.remitterId,
        accountHolderName: _nameController.text.trim(),
        accountNumber: _accountController.text.trim(),
        ifscCode: _ifscController.text.trim().toUpperCase(),
        bankName: _selectedBankName ?? '',
        bankCode: _selectedBankCode!,
        stateCode: _selectedState!,
        cityCode: _selectedCity,
        beneficiaryMobile: _mobileController.text.trim().isEmpty
            ? null
            : _mobileController.text.trim(),
      );

      if (response.containsKey('id')) {
        if (mounted) {
          HapticFeedback.heavyImpact();
          Navigator.pop(context, true);
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
                    'Beneficiary added successfully!',
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
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'Add Beneficiary',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fee Info Card
              _buildFeeInfoCard(),
              const SizedBox(height: 24),
              // Section Title
              _buildSectionHeader(),
              const SizedBox(height: 20),
              // Form Fields
              _buildInputField(
                controller: _nameController,
                label: 'Account Holder Name',
                hint: 'Enter full name as per bank records',
                icon: Iconsax.user,
                validator: (v) => v == null || v.isEmpty ? 'Please enter account holder name' : null,
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _accountController,
                label: 'Account Number',
                hint: 'Enter account number',
                icon: Iconsax.card,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter account number';
                  if (v.length < 9) return 'Account number must be at least 9 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: _ifscController,
                label: 'IFSC Code',
                hint: 'Enter 11 character IFSC code',
                icon: Iconsax.code,
                textCapitalization: TextCapitalization.characters,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter IFSC code';
                  if (v.length != 11) return 'IFSC code must be 11 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Bank Name (Searchable)
              _buildSearchableSelector(
                label: 'Bank Name',
                icon: Iconsax.bank,
                hint: 'Select bank',
                selectedName: _selectedBankName,
                isLoading: _loadingBanks,
                onTap: () {
                  if (!_loadingBanks) {
                    _showSearchablePicker(
                      title: 'Bank',
                      items: _banks,
                      selectedCode: _selectedBankCode,
                      onSelected: (code, name) {
                        setState(() {
                          _selectedBankCode = code;
                          _selectedBankName = name;
                        });
                      },
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              // State (Searchable)
              _buildSearchableSelector(
                label: 'State',
                icon: Iconsax.location,
                hint: 'Select state',
                selectedName: _selectedStateName,
                isLoading: _loadingStates,
                onTap: () {
                  if (!_loadingStates) {
                    _showSearchablePicker(
                      title: 'State',
                      items: _states,
                      selectedCode: _selectedState,
                      onSelected: (code, name) {
                        setState(() {
                          _selectedState = code;
                          _selectedStateName = name;
                          _selectedCity = null;
                          _selectedCityName = null;
                          _cities = [];
                        });
                        if (code.isNotEmpty) _loadCities(code);
                      },
                    );
                  }
                },
              ),
              // Cities
              if (_loadingCities) ...[
                const SizedBox(height: 16),
                _buildLoadingCitiesIndicator(),
              ] else if (_cities.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSearchableSelector(
                  label: 'City (Optional)',
                  icon: Iconsax.buildings,
                  hint: 'Select city',
                  selectedName: _selectedCityName,
                  onTap: () {
                    _showSearchablePicker(
                      title: 'City',
                      items: _cities,
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
              ] else if (_selectedState != null && !_loadingStates && !_loadingCities) ...[
                const SizedBox(height: 12),
                _buildNoCitiesInfo(),
              ],
              const SizedBox(height: 16),
              _buildInputField(
                controller: _mobileController,
                label: 'Mobile Number (Optional)',
                hint: 'Enter 10-digit mobile number',
                icon: Iconsax.mobile,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (v) {
                  if (v != null && v.isNotEmpty && v.length != 10) {
                    return 'Please enter a valid 10-digit number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
              if (_errorMessage != null) ...[
                _buildErrorCard(),
                const SizedBox(height: 20),
              ],
              _buildSubmitButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeeInfoCard() {
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
            child: const Icon(Iconsax.information, color: AppColors.primaryLight, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Registration Fee', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
                const SizedBox(height: 2),
                Text('A nominal fee will be charged', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('₹3', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(width: 4, height: 22, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text('Beneficiary Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textWhite)),
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
            style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textWhite),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
              prefixIcon: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: AppColors.primaryLight, size: 18),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error, width: 1)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
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
        Text(label, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textWhite)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selectedName != null ? AppColors.borderFocus : AppColors.borderDark,
                width: selectedName != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: AppColors.primaryLight, size: 18),
                ),
                Expanded(
                  child: isLoading
                      ? Row(
                    children: [
                      SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight)),
                      const SizedBox(width: 10),
                      Text('Loading...', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 14)),
                    ],
                  )
                      : Text(
                    selectedName ?? hint,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: selectedName != null ? AppColors.textWhite : Colors.white38,
                    ),
                  ),
                ),
                Icon(Iconsax.arrow_down_1, color: selectedName != null ? AppColors.primaryLight : Colors.white38, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingCitiesIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Row(
        children: [
          SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight)),
          const SizedBox(width: 12),
          Text('Loading cities...', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDarkSecondary)),
        ],
      ),
    );
  }

  Widget _buildNoCitiesInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.info_circle, size: 14, color: AppColors.textDarkSecondary),
          const SizedBox(width: 8),
          Text('No cities available for this state', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDarkSecondary)),
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
            decoration: BoxDecoration(color: AppColors.error.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Iconsax.warning_2, color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_errorMessage!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w500)),
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
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _addBeneficiary,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.user_add, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Add Beneficiary', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}