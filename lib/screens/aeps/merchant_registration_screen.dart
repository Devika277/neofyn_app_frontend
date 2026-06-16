import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
// import '../../models/aeps_models.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../layout/UserHomeScreen.dart';
import '../../services/AEPS/location_service.dart';
import 'aeps_wrapper_screen.dart';
import 'ekyc_screen.dart';

class MerchantRegistrationScreen extends StatefulWidget {
    final bool isOtpPending;
    final Map<String, dynamic>? merchantData;
    final String? pipe;
    final String? phone;
  
  const MerchantRegistrationScreen({
    super.key,
    this.isOtpPending = false,
    this.merchantData,
    this.pipe, 
    this.phone,
    });

  @override
  State<MerchantRegistrationScreen> createState() => _MerchantRegistrationScreenState();
}

class _MerchantRegistrationScreenState extends State<MerchantRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // Personal & address controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();      // merchant pin code
  final _cityController = TextEditingController();

  // New required controllers
  final _dobController = TextEditingController();          // DD-MM-YYYY
  final _shopPanController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  // final _bankNameController = TextEditingController();     // bank code from list
  final _shopAddressController = TextEditingController();
  final _shopPinCodeController = TextEditingController();

  // Dropdown values
  String? _selectedStateCode;       // abbreviation (e.g., "KL")
  String? _selectedDistrictCode;    // abbreviation (e.g., "MAY")
  String _selectedGender = 'M';
  String _accountType = 'Savings Account';  // default, can be dropdown
  String? _selectedBankCode;      // bank IIN to send
  String? _selectedBankName;      // for display only
  // Location
  Map<String, double>? _location;
  bool _isGettingLocation = false;


  String? _merchantId;
  String? _merchantRefId;
  final _otpController = TextEditingController();

  // ─── OTP flow (NEW FIELDS) ──────────────────────────────────
  bool _isOtpSent = false;
  bool _isOtpVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;


   // ─── OTP Pending handling ────────────────────────────────────
  bool get _isOtpPending => widget.isOtpPending;
  String? get _pendingMerchantId => widget.merchantData?['merchantId']?.toString();
  String? get _pendingMerchantRefId => widget.merchantData?['merchantRefId']?.toString();



  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AepsProvider>().fetchStates();
      context.read<AepsProvider>().fetchBanks();   // add this

    });

     // If OTP pending, pre‑fill mobile and auto‑send OTP
      if (_isOtpPending && widget.merchantData != null) {
    final phone = widget.phone ?? widget.merchantData!['phone']?.toString() ?? '';
    _mobileController.text = phone;
    _merchantId = _pendingMerchantId;
    _merchantRefId = _pendingMerchantRefId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showSuccess('OTP pending – please verify to activate your merchant.');
      _sendOtp();
    });
  }

  

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
    // _bankNameController.dispose();
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
        _showSuccess('Location captured successfully');
      }
    } catch (e) {
      _showError('Failed to get location: $e');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _registerMerchant() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStateCode == null) {
      _showError('Please select state');
      return;
    }
    if (_selectedDistrictCode == null) {
      _showError('Please select district');
      return;
    }
    if (_location == null) {
      _showError('Please capture your location first');
      await _getCurrentLocation();
      if (_location == null) return;
    }

    final provider = context.read<AepsProvider>();

    // Find selected state to get the abbreviation (already used as code)
    final selectedState = provider.states.firstWhere(
          (s) => s.code == _selectedStateCode,
      orElse: () => throw Exception('Selected state not found'),
    );

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
      merchantState: _selectedStateCode!,          // abbreviation
      merchantDistrict: _selectedDistrictCode!,    // abbreviation
      merchantPinCode: _pincodeController.text.trim(),
      shopPan: _shopPanController.text.trim(),
      bankAccountNumber: _bankAccountController.text.trim(),
      bankIfscCode: _bankIfscController.text.trim(),
      bankName: _selectedBankCode ?? '',   // bank code e.g. "013"
      accountType: _accountType,
      shopAddress: _shopAddressController.text.trim(),
      shopDistrict: _selectedDistrictCode!,       // same as merchant
      shopState: _selectedStateCode!,             // same as merchant
      shopPinCode: _shopPinCodeController.text.trim(),
      shopLat: _location!['latitude']!,
      shopLong: _location!['longitude']!,
      lat: _location!['latitude']!,
      long: _location!['longitude']!,
      ipAddress: '',                               // backend will set
      merchantRefId: '',                           // backend will generate
      pipe: '1',
      gender: _selectedGender,
      
    );

    final success = await provider.registerMerchant(request);

    if (success) {
      setState(() {
        _merchantId = provider.merchantId;
        _merchantRefId = provider.merchantRefId;
      });
      print('✅ Registration success, merchantId: $_merchantId');

      await _sendOtp();
    } else {
      _showError(provider.errorMessage ?? 'Registration failed');
    }
  }

   // ─── OTP Methods ─────────────────────────────────────────────

  Future<void> _sendOtp() async {
    if (_mobileController.text.isEmpty) {
      _showError('Mobile number not found');
      return;
    }
    setState(() => _isSendingOtp = true);
    try {
      final provider = context.read<AepsProvider>();
      final merchantId = _isOtpPending ? _pendingMerchantId! : _merchantId!;
      final success = await provider.sendOtp(merchantId, _mobileController.text);
      if (success) {
        setState(() => _isOtpSent = true);
        _showSuccess('OTP sent successfully!');
      } else {
        _showError(provider.errorMessage ?? 'Failed to send OTP');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isSendingOtp = false);
    }
  }

  // █████████████████████████████████████████████████████████████
  // ✅ CORRECTED _verifyOtp (uses the defined getters)
  // █████████████████████████████████████████████████████████████
  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      _showError('Enter valid 6‑digit OTP');
      return;
    }

    // Use the getters we defined above
    final merchantId = _isOtpPending ? _pendingMerchantId : _merchantId;
    final merchantRefId = _isOtpPending ? _pendingMerchantRefId : _merchantRefId;
    if (merchantId == null || merchantRefId == null) {
      _showError('Merchant information missing. Please restart.');
      return;
    }

    setState(() => _isVerifyingOtp = true);
    try {
      final provider = context.read<AepsProvider>();

      final success = await provider.verifyOtp(
        merchantId,
        _otpController.text,
        merchantRefId,
      );

      if (success) {
        setState(() => _isOtpVerified = true);
        _showSuccess('OTP verified!');

        final updatedStatus = await provider.fetchPipeStatus(widget.pipe ?? '1');
        final regStatus = updatedStatus?['registrationStatus'] ?? '';

        if (regStatus == 'active') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
          );
        } else if (regStatus == 'otp_verified') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => EKYC_Screen(
                merchantId: merchantId,
                merchantRefId: merchantRefId,
                pipe: widget.pipe ?? '1',
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
          );
        }
      } else {
        _showError(provider.errorMessage ?? 'OTP verification failed');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isVerifyingOtp = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AepsProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Merchant Registration', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF2ECC71), Color(0xFF27AE60)]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront, size: 50, color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Text('Register as Merchant',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 8),
                    const Text('Complete your registration to start AEPS services',
                        style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Personal Details Section
              _buildSectionContainer(
                icon: Icons.person,
                title: 'Personal Details',
                children: [
                  // First Name & Last Name
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'First Name *',
                          controller: _firstNameController,
                          hint: 'Enter first name',
                          validator: (v) => v!.isEmpty ? 'First name required' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: CustomTextField(
                          label: 'Last Name',
                          controller: _lastNameController,
                          hint: 'Enter last name',
                        ),
                      ),
                    ],
                  ),
                  // Date of Birth
                  CustomTextField(
                    label: 'Date of Birth (DD-MM-YYYY) *',
                    controller: _dobController,
                    hint: '15-07-1999',
                    keyboardType: TextInputType.datetime,
                    validator: (v) => v!.isEmpty ? 'DOB required' : null,
                  ),
                  // Mobile
                  CustomTextField(
                    label: 'Mobile Number *',
                    controller: _mobileController,
                    keyboardType: TextInputType.phone,
                    hint: 'Enter 10-digit mobile number',
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Mobile required';
                      if (v.length != 10) return 'Enter valid 10-digit number';
                      return null;
                    },
                  ),
                  // Email
                  CustomTextField(
                    label: 'Email ID',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    hint: 'Enter email address',
                    validator: (v) => (v != null && v.isNotEmpty && !v.contains('@')) ? 'Enter valid email' : null,
                  ),
                  // Aadhaar
                  CustomTextField(
                    label: 'Aadhaar Number *',
                    controller: _aadhaarController,
                    keyboardType: TextInputType.number,
                    hint: 'Enter 12-digit Aadhaar',
                    maxLength: 12,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Aadhaar required';
                      if (v.length != 12) return 'Enter valid 12-digit Aadhaar';
                      return null;
                    },
                  ),
                  // PAN
                  CustomTextField(
                    label: 'PAN Number *',
                    controller: _panController,
                    hint: 'Enter PAN number',
                    validator: (v) => v!.isEmpty ? 'PAN required' : null,
                  ),
                  // Gender
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gender *',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Male', style: TextStyle(color: Colors.white)),
                              value: 'M',
                              groupValue: _selectedGender,
                              onChanged: (v) => setState(() => _selectedGender = v!),
                              activeColor: const Color(0xFF2ECC71),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Female', style: TextStyle(color: Colors.white)),
                              value: 'F',
                              groupValue: _selectedGender,
                              onChanged: (v) => setState(() => _selectedGender = v!),
                              activeColor: const Color(0xFF2ECC71),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Address Details
              _buildSectionContainer(
                icon: Icons.location_on,
                title: 'Address Details',
                children: [
                  CustomTextField(
                    label: 'Address *',
                    controller: _addressController,
                    hint: 'Enter your shop address',
                    maxLines: 2,
                    validator: (v) => v!.isEmpty ? 'Address required' : null,
                  ),
                  CustomTextField(
                    label: 'City',
                    controller: _cityController,
                    hint: 'Enter city name',
                  ),
                  CustomTextField(
                    label: 'Merchant Pincode *',
                    controller: _pincodeController,
                    keyboardType: TextInputType.number,
                    hint: '6-digit pincode',
                    validator: (v) => v!.isEmpty ? 'Pincode required' : null,
                  ),
                  const SizedBox(height: 16),
                  // State Dropdown
                  if (provider.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    DropdownButtonFormField<String>(
                      decoration: _dropdownDecoration('State *'),
                      value: _selectedStateCode,
                      hint: const Text('Select State', style: TextStyle(color: Colors.grey)),
                      items: provider.states.map((state) {
                        return DropdownMenuItem<String>(
                          value: state.code,
                          child: Text(state.name, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStateCode = value;
                          _selectedDistrictCode = null;
                        });
                        if (value != null) provider.fetchDistricts(value);
                      },
                      style: const TextStyle(color: Colors.white),
                    ),
                  const SizedBox(height: 16),
                  // District Dropdown
                  if (provider.isLoadingDistricts)
                    const Center(child: CircularProgressIndicator())
                  else if (_selectedStateCode != null)
                    DropdownButtonFormField<String>(
                      decoration: _dropdownDecoration('District *'),
                      value: _selectedDistrictCode,
                      hint: const Text('Select District', style: TextStyle(color: Colors.grey)),
                      items: provider.districts.map((district) {
                        return DropdownMenuItem<String>(
                          value: district.code,
                          child: Text(district.name, style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedDistrictCode = value),
                      style: const TextStyle(color: Colors.white),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Bank & Shop Details
              _buildSectionContainer(
                icon: Icons.account_balance,
                title: 'Bank & Shop Details',
                children: [
                  CustomTextField(
                    label: 'Shop PAN *',
                    controller: _shopPanController,
                    hint: 'Enter shop PAN',
                    validator: (v) => v!.isEmpty ? 'Shop PAN required' : null,
                  ),
                  CustomTextField(
                    label: 'Bank Account Number *',
                    controller: _bankAccountController,
                    keyboardType: TextInputType.number,
                    hint: 'Enter account number',
                    validator: (v) => v!.isEmpty ? 'Account number required' : null,
                  ),
                  CustomTextField(
                    label: 'Bank IFSC Code *',
                    controller: _bankIfscController,
                    hint: 'e.g. BARB0GEETAP',
                    validator: (v) => v!.isEmpty ? 'IFSC required' : null,
                  ),
                  // Bank dropdown using fetched list
                  if (provider.banks.isEmpty)
                    const CircularProgressIndicator()
                  else
                    DropdownButtonFormField<String>(
                      decoration: _dropdownDecoration('Bank Name *'),
                      value: _selectedBankCode,
                      hint: const Text('Select Bank', style: TextStyle(color: Colors.grey)),
                      items: provider.banks.map((bank) {
                        return DropdownMenuItem<String>(
                          value: bank.code,
                          child: Text('${bank.name} (${bank.code})', style: const TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBankCode = value;
                          _selectedBankName = provider.banks.firstWhere((b) => b.code == value).name;
                        });
                      },
                      validator: (v) => v == null ? 'Please select a bank' : null,
                    ),
                  // Account type dropdown
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Account Type *',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white70)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: _dropdownDecoration('Account Type'),
                        value: _accountType,
                        items: const ['Savings Account', 'Current Account']
                            .map((type) => DropdownMenuItem(value: type, child: Text(type, style: const TextStyle(color: Colors.white))))
                            .toList(),
                        onChanged: (v) => setState(() => _accountType = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    label: 'Shop Address *',
                    controller: _shopAddressController,
                    hint: 'Shop address',
                    maxLines: 2,
                    validator: (v) => v!.isEmpty ? 'Shop address required' : null,
                  ),
                  CustomTextField(
                    label: 'Shop Pincode *',
                    controller: _shopPinCodeController,
                    keyboardType: TextInputType.number,
                    hint: '6-digit pincode',
                    validator: (v) => v!.isEmpty ? 'Shop pincode required' : null,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Location Section
              _buildSectionContainer(
                icon: Icons.gps_fixed,
                title: 'Shop Location',
                children: [
                  const Text('Location is mandatory for AEPS registration',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 16),
                  if (_isGettingLocation)
                    const Center(child: CircularProgressIndicator())
                  else if (_location != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF2ECC71)),
                      ),
                      child: Column(
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 16),
                              SizedBox(width: 8),
                              Text('Location Captured',
                                  style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lat: ${_location!['latitude']!.toStringAsFixed(6)}, '
                                'Lng: ${_location!['longitude']!.toStringAsFixed(6)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  else
                    CustomButton(
                      text: 'Get Current Location',
                      onPressed: _getCurrentLocation,
                      icon: Icons.my_location,
                      backgroundColor: const Color(0xFF2ECC71),
                      textColor: Colors.black,
                    ),
                ],
              ),

              const SizedBox(height: 30),

              // OTP Section
              if (_isOtpSent) ...[
                _buildSectionContainer(
                  icon: Icons.sms,
                  title: 'OTP Verification',
                  children: [
                    CustomTextField(
                      label: 'Enter OTP',
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      hint: 'Enter 6-digit OTP',
                      maxLength: 6,
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: 'Verify OTP',
                      onPressed: _verifyOtp,
                      isLoading: _isVerifyingOtp,
                      backgroundColor: const Color(0xFF2ECC71),
                      textColor: Colors.black,
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],

              // Register Button
              if (!_isOtpSent)
                CustomButton(
                  text: 'Register Merchant',
                  onPressed: _registerMerchant,
                  isLoading: provider.isLoading,
                  backgroundColor: const Color(0xFF2ECC71),
                  textColor: Colors.black,
                ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for section container
  Widget _buildSectionContainer({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2ECC71), size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[800]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[800]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2)),
    );
  }
}