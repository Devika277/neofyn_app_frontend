// lib/screens/employee/create_account_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:my_app/services/api_logger.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

class CreateAccountScreen extends StatefulWidget {
  final String userId;
  const CreateAccountScreen({super.key, required this.userId});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingParents = false;

  // Dropdown values
  String? _selectedRole;
  int? _selectedParentId;
  List<Map<String, dynamic>> _parentOptions = [];

  // Form controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _businessTypeController = TextEditingController();
  final _businessAddressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _panController = TextEditingController();

  final List<String> _roles = ['master_distributor', 'distributor', 'retailer'];

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> _fetchParentOptions(String childRole) async {
    setState(() => _isLoadingParents = true);

    try {
      final token = await _getToken();
      if (token == null) return;

      final url = '${ApiConfig.baseUrl}/api/members/parent-options?childRole=$childRole';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _parentOptions = List<Map<String, dynamic>>.from(data['parents'] ?? []);
          _selectedParentId = null;
          _isLoadingParents = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching parent options: $e');
      setState(() => _isLoadingParents = false);
    }
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate parent selection for distributor and retailer
    if (_selectedRole != 'master_distributor' && _selectedParentId == null) {
      _showToast('Please select a parent', error: true);
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final token = await _getToken();
      if (token == null) return;

      // Use Map<String, dynamic> to allow mixed types
      final Map<String, dynamic> body = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'intended_role': _selectedRole,
        'account_type': 'regular',
        'business_name': _businessNameController.text.trim(),
        'business_type': _businessTypeController.text.trim(),
        'business_address': _businessAddressController.text.trim(),
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'pin_code': _pinCodeController.text.trim(),
        'aadhaar_number': _aadhaarController.text.trim(),
        'pan_number': _panController.text.trim(),
      };

      // Only add parent_id for non-master_distributor
      if (_selectedRole != 'master_distributor' && _selectedParentId != null) {
        body['parent_id'] = _selectedParentId; // int goes into Map<String, dynamic>
      }

      debugPrint('📦 Create body: ${json.encode(body)}');

      final response = await LoggedHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/members/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      final data = json.decode(response.body);
      debugPrint('📦 Create response: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        _showToast(data['message'] ?? 'Account created successfully!');
        _clearForm();
      } else {
        _showToast(data['message'] ?? 'Failed to create account', error: true);
      }
    } catch (e) {
      debugPrint('❌ Create error: $e');
      _showToast('Network error. Please try again.', error: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    _firstNameController.clear();
    _lastNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _businessNameController.clear();
    _businessTypeController.clear();
    _businessAddressController.clear();
    _cityController.clear();
    _stateController.clear();
    _pinCodeController.clear();
    _aadhaarController.clear();
    _panController.clear();
    setState(() {
      _selectedRole = null;
      _selectedParentId = null;
      _parentOptions = [];
    });
  }

  void _showToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? const Color(0xFFFF5252) : const Color(0xFF008169),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  String _getRoleDisplay(String role) {
    switch (role) {
      case 'master_distributor': return 'Master Distributor';
      case 'distributor': return 'Distributor';
      case 'retailer': return 'Retailer';
      default: return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151915),
        title: const Text('Create Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
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
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF008169).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF008169).withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF00C897), size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Fill in the details to create a new account under your network.',
                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Role Dropdown
              _buildSectionTitle('Select Role'),
              const SizedBox(height: 8),
              _buildDropdown<String>(
                value: _selectedRole,
                hint: 'Choose role',
                items: _roles.map((r) => DropdownMenuItem<String>(value: r, child: Text(_getRoleDisplay(r)))).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                    _selectedParentId = null;
                  });
                  if (value != null) _fetchParentOptions(value);
                },
                showValidator: false, // Don't show validator for role (optional selection)
              ),
              /*_buildDropdown(
                value: _selectedRole,
                hint: 'Choose role',
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(_getRoleDisplay(r)))).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                    _selectedParentId = null;
                  });
                  if (value != null) _fetchParentOptions(value);
                },
              ),*/
              const SizedBox(height: 20),

              // Parent Dropdown (only for distributor & retailer)
              if (_selectedRole != null && _selectedRole != 'master_distributor') ...[
                _buildSectionTitle('Select Parent'),
                const SizedBox(height: 8),
                _isLoadingParents
                    ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Color(0xFF00C897), strokeWidth: 2)))
                    : _buildDropdown<int>(
                  value: _selectedParentId,
                  hint: 'Choose parent',
                  items: _parentOptions.map((p) => DropdownMenuItem<int>(
                    value: p['id'] as int,
                    child: Text('${p['first_name']} ${p['last_name']} (${p['member_id']})'),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedParentId = value),
                ),
                /*_buildDropdown(
                  value: _selectedParentId,
                  hint: 'Choose parent',
                  items: _parentOptions.map((p) => DropdownMenuItem(
                    value: p['id'],
                    child: Text('${p['first_name']} ${p['last_name']} (${p['member_id']})'),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedParentId = value),
                ),*/
                const SizedBox(height: 20),
              ],

              // Only show form if role is selected
              if (_selectedRole != null) ...[
                // Personal Info
                _buildSectionTitle('Personal Information'),
                const SizedBox(height: 12),
                _buildTextField(_firstNameController, 'First Name'),
                const SizedBox(height: 12),
                _buildTextField(_lastNameController, 'Last Name'),
                const SizedBox(height: 12),
                _buildTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                _buildTextField(_phoneController, 'Phone', keyboardType: TextInputType.phone, maxLength: 10),
                const SizedBox(height: 24),

                // Business Info
                _buildSectionTitle('Business Information'),
                const SizedBox(height: 12),
                _buildTextField(_businessNameController, 'Business Name'),
                const SizedBox(height: 12),
                _buildTextField(_businessTypeController, 'Business Type'),
                const SizedBox(height: 12),
                _buildTextField(_businessAddressController, 'Business Address', maxLines: 2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField(_cityController, 'City')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTextField(_stateController, 'State')),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(_pinCodeController, 'PIN Code', keyboardType: TextInputType.number, maxLength: 6),
                const SizedBox(height: 24),

                // KYC Info
                _buildSectionTitle('KYC Information'),
                const SizedBox(height: 12),
                _buildTextField(_aadhaarController, 'Aadhaar Number', keyboardType: TextInputType.number, maxLength: 12),
                const SizedBox(height: 12),
                _buildTextField(_panController, 'PAN Number', maxLength: 10),
                const SizedBox(height: 32),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008169),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String hint, {
        TextInputType keyboardType = TextInputType.text,
        int? maxLength,
        int maxLines = 1,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: '',
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field is required';
        }
        return null;
      },
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    bool showValidator = true,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        dropdownColor: const Color(0xFF151915),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
        items: items,
        onChanged: onChanged,
        validator: showValidator ? (value) {
          if (value == null) return 'Please select an option';
          return null;
        } : null,
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _businessNameController.dispose();
    _businessTypeController.dispose();
    _businessAddressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pinCodeController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    super.dispose();
  }
}