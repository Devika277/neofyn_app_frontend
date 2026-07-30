// lib/screens/CardPay/cardpay_initiate_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../providers/cardpay_provider.dart';
import '../../services/cardpay/card_pay_service.dart';
import '../../models/cardpay_models.dart';

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

class CardPayInitiateScreen extends StatefulWidget {
  const CardPayInitiateScreen({Key? key}) : super(key: key);

  @override
  State<CardPayInitiateScreen> createState() => _CardPayInitiateScreenState();
}

class _CardPayInitiateScreenState extends State<CardPayInitiateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _mobileController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();

  bool _isLoading = false;
  bool _isFetchingLocation = false;
  String? _selectedState;
  List<String> _states = [];
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _loadStates();
    _getCurrentLocation();
  }

  Future<void> _loadStates() async {
    try {
      final provider = Provider.of<CardPayProvider>(context, listen: false);
      if (provider.states.isNotEmpty) {
        setState(() {
          _states = provider.states;
          if (_states.isNotEmpty && _selectedState == null) {
            _selectedState = _states.first;
          }
        });
      } else {
        final service = CardPayService();
        final states = await service.getStateList();
        setState(() {
          _states = states;
          if (_states.isNotEmpty && _selectedState == null) {
            _selectedState = _states.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading states: $e');
    }
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
          final state = place.administrativeArea ?? place.locality ?? '';
          setState(() {
            _currentAddress = '${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
            if (state.isNotEmpty && _states.contains(state)) {
              _selectedState = state;
            }
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
          'Initiate Card Payment',
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
      body: SingleChildScrollView(
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
                  if (amount >= 100000) {
                    return 'Amount must be below ₹1,00,000';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 14 : 16),

              // Mobile Field
              _buildSectionLabel('Mobile Number'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _mobileController,
                hintText: 'Enter 10-digit mobile number',
                prefixIcon: Iconsax.call,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter mobile number';
                  }
                  if (value.length != 10) {
                    return 'Enter valid 10-digit mobile number';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 14 : 16),

              // Name Field
              _buildSectionLabel('Full Name'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hintText: 'Enter your full name',
                prefixIcon: Iconsax.user,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 14 : 16),

              // Email Field
              _buildSectionLabel('Email'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hintText: 'Enter your email address',
                prefixIcon: Iconsax.sms,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!CardPayService.isValidEmail(value)) {
                    return 'Enter valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: isSmallScreen ? 14 : 16),

              // State Dropdown
              _buildSectionLabel('State'),
              const SizedBox(height: 8),
              _buildDropdown<String>(
                value: _selectedState,
                hintText: 'Select your state',
                prefixIcon: Iconsax.map,
                items: _states.map((state) {
                  return DropdownMenuItem(
                    value: state,
                    child: Text(
                      state,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: AppColors.textWhite,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedState = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a state';
                  }
                  return null;
                },
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
                  onPressed: _isLoading ? null : _submitPayment,
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
                      const Icon(Iconsax.card_send, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Pay Now',
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

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<CardPayProvider>(context, listen: false);
      final result = await provider.initiatePayment(
        amount: double.parse(_amountController.text),
        mobile: _mobileController.text,
        name: _nameController.text,
        email: _emailController.text,
        location: _selectedState!,
        lat: _latController.text,
        long: _longController.text,
      );

      if (result != null) {
        if (!mounted) return;
        _showSuccessDialog(result);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(CardPayInitiateResponse result) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderDark),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.tick_circle,
                      size: 56,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Payment Initiated',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textWhite,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your payment has been initiated successfully',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textDarkSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Reference Details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.darkBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderDark),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow('Reference ID', result.merchantRefId),
                        const SizedBox(height: 10),
                        _buildInfoRow('Transaction ID', result.txnId.toString()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Payment Link
                  Text(
                    'Complete payment using the link below:',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textDarkHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _launchPaymentLink(result.paymentLink),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Iconsax.link, color: AppColors.primaryLight, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              result.paymentLink,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.primaryLight,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Iconsax.arrow_right_3, color: AppColors.primaryLight, size: 16),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the link to open in browser',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.textDarkHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: const BorderSide(color: AppColors.borderDark),
                          ),
                          child: Text(
                            'Close',
                            style: GoogleFonts.poppins(
                              color: AppColors.textDarkSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () => _launchPaymentLink(result.paymentLink),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.export_3, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Open Payment Link',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textDarkHint,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textWhite,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Future<void> _launchPaymentLink(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar('Could not open link: $e', isError: true);
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
    _mobileController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }
}