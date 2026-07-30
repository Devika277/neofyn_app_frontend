// lib/screens/CardPayOut/cardpay_out_initiate_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../providers/cardpay_out_provider.dart';
import '../../models/cardpay_out_models.dart';
import 'cardpay_out_beneficiaries_screen.dart';
import 'cardpay_out_receipt_screen.dart';

class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);
  static const Color textDarkHint = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color processing = Color(0xFF8B5CF6);
  static const Color borderDark = Color(0xFF2A342A);
}

class CardPayOutInitiateScreen extends StatefulWidget {
  const CardPayOutInitiateScreen({Key? key}) : super(key: key);

  @override
  State<CardPayOutInitiateScreen> createState() => _CardPayOutInitiateScreenState();
}

class _CardPayOutInitiateScreenState extends State<CardPayOutInitiateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _tpinController = TextEditingController();
  final _remarkController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();

  int? _selectedBeneficiaryId;
  String? _selectedMode;
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _loadData();
    _getCurrentLocation();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<CardPayOutProvider>(context, listen: false);
    await provider.fetchBeneficiaries();
    await provider.fetchLimits();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isFetchingLocation = false);
          _showSnackBar('Location permission denied. Please enter manually.', isWarning: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isFetchingLocation = false);
        _showSnackBar('Location permission permanently denied. Please enter manually.', isError: true);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _longController.text = position.longitude.toStringAsFixed(6);
        _isFetchingLocation = false;
      });

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          setState(() {
            _currentAddress = '${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
          });
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      _showSnackBar('Location fetched successfully', isSuccess: true);
    } catch (e) {
      setState(() => _isFetchingLocation = false);
      debugPrint('Error getting location: $e');
      _showSnackBar('Could not fetch location. Please enter manually.', isWarning: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'Withdraw to Bank',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 16 : 18,
            color: AppColors.textWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFetchingLocation ? Iconsax.location : Iconsax.location_add,
              color: _isFetchingLocation ? AppColors.processing : AppColors.primaryLight,
              size: 20,
            ),
            onPressed: _isFetchingLocation ? null : _getCurrentLocation,
            tooltip: 'Get Current Location',
          ),
        ],
      ),
      body: Consumer<CardPayOutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Status
                  if (_isFetchingLocation)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.processing.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.processing.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.processing,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Fetching your location...',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: AppColors.textDarkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Current Address
                  if (_currentAddress != null && !_isFetchingLocation)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.success.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.location, color: AppColors.success, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _currentAddress!,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Balance Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Iconsax.wallet_2,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Available Balance',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${provider.balance.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 20 : 24),

                  // Amount Field
                  _buildSectionLabel('Amount'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _amountController,
                    hintText: 'Enter amount',
                    prefixIcon: Iconsax.money,
                    prefixText: '₹ ',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Enter valid amount';
                      }
                      if (provider.limits != null) {
                        if (amount < 100) {
                          return 'Minimum amount is ₹100';
                        }
                        if (amount > 50000) {
                          return 'Maximum amount is ₹50,000';
                        }
                      }
                      if (amount > provider.balance) {
                        return 'Insufficient balance';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: isSmallScreen ? 14 : 16),

                  // Beneficiary Dropdown
                  _buildSectionLabel('Select Beneficiary'),
                  const SizedBox(height: 8),
                  _buildDropdown<int>(
                    value: _selectedBeneficiaryId,
                    hintText: 'Choose a beneficiary',
                    prefixIcon: Iconsax.user,
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'Select a beneficiary',
                          style: GoogleFonts.poppins(color: AppColors.textDarkHint),
                        ),
                      ),
                      ...provider.beneficiaries.map((b) {
                        return DropdownMenuItem(
                          value: b.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                b.accountHolderName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textWhite,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${b.bankName} - ${b.accountNumber}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppColors.textDarkHint,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedBeneficiaryId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a beneficiary';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Add Beneficiary Button
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CardPayOutBeneficiariesScreen(),
                        ),
                      ).then((_) => _loadData());
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Iconsax.add_circle, color: AppColors.primaryLight, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Add New Beneficiary',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 14 : 16),

                  // Mode Selection
                  _buildSectionLabel('Transfer Mode'),
                  const SizedBox(height: 8),
                  _buildDropdown<String>(
                    value: _selectedMode,
                    hintText: 'Select transfer mode',
                    prefixIcon: Iconsax.flash,
                    items: [
                      DropdownMenuItem(
                        value: 'IMPS',
                        child: Row(
                          children: [
                            const Icon(Iconsax.flash, color: AppColors.success, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'IMPS (Instant)',
                              style: GoogleFonts.poppins(color: AppColors.success, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'NEFT',
                        child: Row(
                          children: [
                            const Icon(Iconsax.clock, color: AppColors.warning, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              'NEFT (1-2 hours)',
                              style: GoogleFonts.poppins(color: AppColors.warning, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedMode = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select transfer mode';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: isSmallScreen ? 14 : 16),

                  // TPIN Field
                  _buildSectionLabel('TPIN'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _tpinController,
                    hintText: 'Enter your 6-digit TPIN',
                    prefixIcon: Iconsax.lock,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your TPIN';
                      }
                      if (value.length != 6) {
                        return 'TPIN must be 6 digits';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: isSmallScreen ? 14 : 16),

                  // Remark Field
                  _buildSectionLabel('Remark (Optional)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _remarkController,
                    hintText: 'Add a note for this withdrawal',
                    prefixIcon: Iconsax.note_1,
                    maxLines: 2,
                    maxLength: 100,
                  ),
                  SizedBox(height: isSmallScreen ? 14 : 16),

                  // Location Coordinates
                  _buildSectionLabel('Location Coordinates'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          controller: _latController,
                          hintText: 'Latitude',
                          prefixIcon: Iconsax.location,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (double.tryParse(value) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildTextField(
                          controller: _longController,
                          hintText: 'Longitude',
                          prefixIcon: Iconsax.location,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            if (double.tryParse(value) == null) return 'Invalid';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Iconsax.information, size: 12, color: AppColors.textDarkHint),
                      const SizedBox(width: 4),
                      Text(
                        'Tap location icon in app bar to auto-fetch',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: AppColors.textDarkHint,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 24 : 28),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitWithdrawal,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Iconsax.money_send, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Withdraw Now',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textDarkSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? prefixIcon,
    String? prefixText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool obscureText = false,
    int? maxLines = 1,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppColors.textWhite,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.textDarkHint,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 18, color: AppColors.textDarkHint)
            : null,
        prefixText: prefixText,
        prefixStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.primaryLight,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterStyle: GoogleFonts.poppins(
          fontSize: 10,
          color: AppColors.textDarkHint,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hintText,
    required IconData prefixIcon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?)? onChanged,
    required String? Function(T?)? validator,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: AppColors.textDarkHint,
        ),
        prefixIcon: Icon(prefixIcon, size: 18, color: AppColors.textDarkHint),
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dropdownColor: AppColors.darkSurface,
      style: GoogleFonts.poppins(
        fontSize: 14,
        color: AppColors.textWhite,
      ),
      icon: const Icon(Iconsax.arrow_down_1, color: AppColors.textDarkHint, size: 16),
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      validator: validator,
    );
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<CardPayOutProvider>(context, listen: false);

      final request = CardPayOutInitiateRequest(
        amount: double.parse(_amountController.text),
        beneficiaryId: _selectedBeneficiaryId!,
        mode: _selectedMode!,
        tpin: _tpinController.text,
        lat: _latController.text,
        long: _longController.text,
        remarks: _remarkController.text.isNotEmpty ? _remarkController.text : null,
      );

      final result = await provider.initiatePayout(request);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CardPayOutReceiptScreen(ref: result.merchantRefId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false, bool isWarning = false, bool isSuccess = false}) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Iconsax.warning_2
                  : isWarning
                  ? Iconsax.info_circle
                  : Iconsax.tick_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError
            ? AppColors.error
            : isWarning
            ? AppColors.warning
            : AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tpinController.dispose();
    _remarkController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }
}