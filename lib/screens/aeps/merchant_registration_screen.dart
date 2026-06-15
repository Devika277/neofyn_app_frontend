import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../layout/UserHomeScreen.dart';
import '../../services/AEPS/location_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THEME COLORS
// ─────────────────────────────────────────────────────────────────────────────
const _primary = Color(0xFF008169);
const _primaryLight = Color(0xFF1AA88A);
const _primaryDark = Color(0xFF005F4E);
const _cardBg = Color(0xFF0F1A0F);
const _bgStart = Color(0xFF0A0E0A);
const _bgEnd = Color(0xFF050805);

class MerchantRegistrationScreen extends StatefulWidget {
  const MerchantRegistrationScreen({super.key});

  @override
  State<MerchantRegistrationScreen> createState() =>
      _MerchantRegistrationScreenState();
}

class _MerchantRegistrationScreenState
    extends State<MerchantRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _dobController = TextEditingController();
  final _shopPanController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _shopPinCodeController = TextEditingController();

  String? _selectedStateCode;
  String? _selectedDistrictCode;
  String _selectedGender = 'M';
  String _accountType = 'Savings Account';
  String? _selectedBankCode;
  String? _selectedBankName;
  Map<String, double>? _location;
  bool _isGettingLocation = false;
  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  String? _merchantId;
  String? _merchantRefId;
  final _otpController = TextEditingController();
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  final LocationService _locationService = LocationService();
  int _currentStep = 0; // 0=Personal, 1=Address, 2=Bank, 3=Location, 4=OTP

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AepsProvider>().fetchStates(),
    );
    context.read<AepsProvider>().fetchBanks();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _cityController.dispose();
    _dobController.dispose();
    _shopPanController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _shopAddressController.dispose();
    _shopPinCodeController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final isReady = await _locationService.showLocationDialog(context);
      if (isReady) {
        final location = await _locationService.getLocationMap();
        setState(() => _location = location);
        _showSuccess('Location captured');
      }
    } catch (e) {
      _showError('Failed: $e');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _registerMerchant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStateCode == null) {
      _showError('Select state');
      return;
    }
    if (_selectedDistrictCode == null) {
      _showError('Select district');
      return;
    }
    if (_location == null) {
      _showError('Capture location first');
      await _getCurrentLocation();
      if (_location == null) return;
    }
    final provider = context.read<AepsProvider>();
    final request = MerchantRegistrationRequest(
      firstName: _firstNameController.text.trim(),
      middleName: '',
      lastName: _lastNameController.text.trim(),
      dob: _dobController.text.trim(),
      emailId: _emailController.text.trim(),
      mobileNo: _mobileController.text.trim(),
      aadhaarNo: _aadhaarController.text.trim(),
      panNo: _panController.text.trim(),
      merchantAddress1: _addressController.text.trim(),
      merchantAddress2: '',
      merchantState: _selectedStateCode!,
      merchantDistrict: _selectedDistrictCode!,
      merchantPinCode: _pincodeController.text.trim(),
      shopPan: _shopPanController.text.trim(),
      bankAccountNumber: _bankAccountController.text.trim(),
      bankIfscCode: _bankIfscController.text.trim(),
      bankName: _selectedBankCode ?? '',
      accountType: _accountType,
      shopAddress: _shopAddressController.text.trim(),
      shopDistrict: _selectedDistrictCode!,
      shopState: _selectedStateCode!,
      shopPinCode: _shopPinCodeController.text.trim(),
      shopLat: _location!['latitude']!,
      shopLong: _location!['longitude']!,
      lat: _location!['latitude']!,
      long: _location!['longitude']!,
      ipAddress: '',
      merchantRefId: '',
      pipe: '1',
      gender: _selectedGender,
    );
    final success = await provider.registerMerchant(request);
    if (success) {
      setState(() {
        _merchantId = provider.merchantId;
        _merchantRefId = provider.merchantRefId;
        _currentStep = 4;
      });
      await _sendOtp();
    } else {
      _showError(provider.errorMessage ?? 'Registration failed');
    }
  }

  Future<void> _sendOtp() async {
    if (_mobileController.text.isEmpty) {
      _showError('Enter mobile');
      return;
    }
    setState(() => _isSendingOtp = true);
    try {
      final success = await context.read<AepsProvider>().sendOtp(
        _merchantId!,
        _mobileController.text,
      );
      if (success) {
        setState(() => _isOtpSent = true);
        _showSuccess('OTP sent!');
      } else {
        _showError('Failed to send OTP');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      _showError('Enter valid OTP');
      return;
    }
    setState(() => _isVerifyingOtp = true);
    try {
      final success = await context.read<AepsProvider>().verifyOtp(
        _merchantId!,
        _otpController.text,
        _merchantRefId!,
      );
      if (success) {
        _showSuccess('Registration completed!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserHomeScreen()),
        );
      } else {
        _showError('OTP verification failed');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isVerifyingOtp = false);
    }
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ),
  );

  void _showSuccess(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AepsProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgStart, _cardBg, _bgEnd],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildHero(),
                        const SizedBox(height: 16),
                        _buildStepper(),
                        const SizedBox(height: 16),
                        _buildPersonalSection(),
                        const SizedBox(height: 12),
                        _buildAddressSection(provider),
                        const SizedBox(height: 12),
                        _buildBankSection(provider),
                        const SizedBox(height: 12),
                        _buildLocationSection(),
                        if (_isOtpSent) ...[
                          const SizedBox(height: 12),
                          _buildOtpSection(),
                        ],
                        const SizedBox(height: 16),
                        if (!_isOtpSent) _buildRegisterButton(provider),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white60,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Merchant Registration',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );

  Widget _buildHero() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_primary.withOpacity(0.2), _primaryDark.withOpacity(0.15)],
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _primary.withOpacity(0.25)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_primary, _primaryLight]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: _primary.withOpacity(0.3), blurRadius: 12),
            ],
          ),
          child: const Icon(Icons.store_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            'Register as Merchant\nStart accepting AEPS payments',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildStepper() => Row(
    children: [
      _step(0, 'Personal'),
      _stepLine(),
      _step(1, 'Address'),
      _stepLine(),
      _step(2, 'Bank'),
      _stepLine(),
      _step(3, 'Location'),
    ],
  );

  Widget _step(int i, String l) => Column(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _currentStep >= i ? _primary : Colors.white.withOpacity(0.08),
          border: Border.all(
            color: _currentStep >= i ? _primary : Colors.white.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Center(
          child: _currentStep > i
              ? const Icon(Icons.check, color: Colors.white, size: 14)
              : Text(
                  '${i + 1}',
                  style: TextStyle(
                    color: _currentStep >= i ? Colors.white : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),

      const SizedBox(height: 3),
      Text(
        l,
        style: TextStyle(
          fontSize: 8,
          color: _currentStep >= i ? Colors.white54 : Colors.white24,
        ),
      ),
    ],
  );

  Widget _stepLine() => Container(
    width: 16,
    height: 1.5,
    color: Colors.white.withOpacity(0.1),
    margin: const EdgeInsets.only(bottom: 14),
  );

  Widget _buildPersonalSection() => _card('👤 Personal Details', [
    _row([
      _field(
        'First Name *',
        _firstNameController,
        (v) => (v ?? '').isEmpty ? 'Required' : null,
      ),
      const SizedBox(width: 10),
      _field('Last Name', _lastNameController, null),
    ]),
    const SizedBox(height: 10),
    _row([
      _field(
        'DOB *',
        _dobController,
        (v) => (v ?? '').isEmpty ? 'Required' : null,
        hint: 'DD-MM-YYYY',
      ),
      const SizedBox(width: 10),
      _field(
        'Mobile *',
        _mobileController,
        (v) {
          if ((v ?? '').isEmpty) return 'Required';
          if (v!.length != 10) return 'Invalid';
          return null;
        },
        type: TextInputType.phone,
        hint: '10-digit',
      ),
    ]),
    const SizedBox(height: 10),
    _field(
      'Email ID',
      _emailController,
      null,
      type: TextInputType.emailAddress,
      hint: 'email@example.com',
    ),
    const SizedBox(height: 10),
    _row([
      _field(
        'Aadhaar *',
        _aadhaarController,
        (v) {
          if ((v ?? '').isEmpty) return 'Required';
          if (v!.length != 12) return 'Invalid';
          return null;
        },
        type: TextInputType.number,
        max: 12,
        hint: '12-digit',
      ),
      const SizedBox(width: 10),
      _field(
        'PAN *',
        _panController,
        (v) => (v ?? '').isEmpty ? 'Required' : null,
        hint: 'ABCDE1234F',
      ),
    ]),
    const SizedBox(height: 8),
    Row(
      children: [
        Expanded(child: _genderOption('Male', 'M')),
        const SizedBox(width: 8),
        Expanded(child: _genderOption('Female', 'F')),
      ],
    ),
  ]);

  Widget _genderOption(String label, String value) => GestureDetector(
    onTap: () => setState(() => _selectedGender = value),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: _selectedGender == value
            ? _primary.withOpacity(0.2)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _selectedGender == value
              ? _primary
              : Colors.white.withOpacity(0.08),
          width: _selectedGender == value ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedGender == value
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: _selectedGender == value ? _primaryLight : Colors.white38,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: _selectedGender == value ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildAddressSection(AepsProvider p) => _card('📍 Address Details', [
    _field(
      'Address *',
      _addressController,
      (v) => (v ?? '').isEmpty ? 'Required' : null,
      hint: 'Shop/House address',
    ),
    const SizedBox(height: 10),
    _row([
      _field('City', _cityController, null, hint: 'City'),
      const SizedBox(width: 10),
      _field(
        'Pincode *',
        _pincodeController,
        (v) => (v ?? '').isEmpty ? 'Required' : null,
        type: TextInputType.number,
        hint: '6-digit',
      ),
    ]),
    const SizedBox(height: 10),
    _dropdown(
      'State *',
      _selectedStateCode,
      p.states
          .map(
            (s) => DropdownMenuItem(
              value: s.code,
              child: Text(
                s.name,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          )
          .toList(),
      (v) {
        setState(() {
          _selectedStateCode = v;
          _selectedDistrictCode = null;
        });
        if (v != null) p.fetchDistricts(v);
      },
      isLoading: p.isLoading,
    ),
    if (_selectedStateCode != null) ...[
      const SizedBox(height: 10),
      _dropdown(
        'District *',
        _selectedDistrictCode,
        p.districts
            .map(
              (d) => DropdownMenuItem(
                value: d.code,
                child: Text(
                  d.name,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            )
            .toList(),
        (v) => setState(() => _selectedDistrictCode = v),
        isLoading: p.isLoadingDistricts,
      ),
    ],
  ]);

  Widget _buildBankSection(AepsProvider p) => _card('🏦 Bank & Shop Details', [
    _row([
      _field(
        'Shop PAN *',
        _shopPanController,
        (v) => (v ?? '').isEmpty ? 'Required' : null,
        hint: 'Shop PAN',
      ),
      const SizedBox(width: 10),
      _field(
        'A/C No *',
        _bankAccountController,
        (v) => (v ?? '').isEmpty ? 'Required' : null,
        type: TextInputType.number,
        hint: 'Account No',
      ),
    ]),
    const SizedBox(height: 10),
    _field(
      'IFSC Code *',
      _bankIfscController,
      (v) => (v ?? '').isEmpty ? 'Required' : null,
      hint: 'e.g. BARB0GEETAP',
    ),
    const SizedBox(height: 10),
    _dropdown(
      'Bank *',
      _selectedBankCode,
      p.banks
          .map(
            (b) => DropdownMenuItem(
              value: b.code,
              child: Text(
                b.name,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          )
          .toList(),
      (v) {
        setState(() {
          _selectedBankCode = v;
          _selectedBankName = p.banks.firstWhere((b) => b.code == v).name;
        });
      },
      isLoading: p.banks.isEmpty,
    ),
    const SizedBox(height: 10),
    _dropdown(
      'Account Type',
      _accountType,
      ['Savings Account', 'Current Account']
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Text(
                t,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          )
          .toList(),
      (v) => setState(() => _accountType = v!),
    ),
    const SizedBox(height: 10),
    _row([
      _field(
        'Shop Address *',
        _shopAddressController,
        (v) => (v ?? '').isEmpty ? 'Required' : null,
        hint: 'Shop address',
      ),
      const SizedBox(width: 10),
      _field(
        'Shop Pincode *',
        _shopPinCodeController,
        (v) => (v ?? '').isEmpty ? 'Required' : null,
        type: TextInputType.number,
        hint: '6-digit',
      ),
    ]),
  ]);

  Widget _buildLocationSection() => _card('📍 Shop Location', [
    const Text(
      'GPS location is mandatory for AEPS registration',
      style: TextStyle(color: Colors.white38, fontSize: 11),
    ),
    const SizedBox(height: 10),
    if (_isGettingLocation)
      const Center(child: CircularProgressIndicator(color: _primaryLight))
    else if (_location != null)
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Captured!\nLat: ${_location!['latitude']!.toStringAsFixed(5)}, Lng: ${_location!['longitude']!.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ),
            GestureDetector(
              onTap: _getCurrentLocation,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.green,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      )
    else
      CustomButton(
        text: 'Get Current Location',
        onPressed: _getCurrentLocation,
        icon: Icons.my_location,
        backgroundColor: _primary,
        textColor: Colors.white,
      ),
  ]);

  Widget _buildOtpSection() => _card('📱 OTP Verification', [
    CustomTextField(
      label: 'Enter OTP',
      controller: _otpController,
      keyboardType: TextInputType.number,
      hint: '6-digit OTP',
      maxLength: 6,
    ),
    const SizedBox(height: 12),
    CustomButton(
      text: 'Verify OTP',
      onPressed: _verifyOtp,
      isLoading: _isVerifyingOtp,
      backgroundColor: _primary,
      textColor: Colors.white,
    ),
  ]);

  Widget _buildRegisterButton(AepsProvider p) => CustomButton(
    text: 'Register Merchant',
    onPressed: _registerMerchant,
    isLoading: p.isLoading,
    backgroundColor: _primary,
    textColor: Colors.white,
  );

  // ── REUSABLE WIDGETS ──
  Widget _card(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController ctrl,
    FormFieldValidator<String>? validator, {
    TextInputType type = TextInputType.text,
    int? max,
    String? hint,
  }) => Expanded(
    child: TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLength: max,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primaryLight, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        counterText: '',
        isDense: true,
      ),
      validator: validator,
    ),
  );

  Widget _row(List<Widget> children) => Row(children: children);

  Widget _dropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    Function(String?) onChanged, {
    bool isLoading = false,
  }) {
    if (isLoading)
      return const Center(
        child: CircularProgressIndicator(color: _primaryLight),
      );
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 10),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primaryLight, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        isDense: true,
      ),
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: _cardBg,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      icon: const Icon(
        Icons.expand_more_rounded,
        color: Colors.white38,
        size: 18,
      ),
    );
  }
}
