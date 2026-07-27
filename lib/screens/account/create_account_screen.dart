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

  String? _selectedAccountType; // regular or employee
  String? _selectedRole; // master_distributor, distributor, retailer, employee
  int? _selectedParentId;
  List<Map<String, dynamic>> _parentOptions = [];
  int _currentStep = 0;

  final _fn = TextEditingController();
  final _ln = TextEditingController();
  final _em = TextEditingController();
  final _ph = TextEditingController();
  final _bn = TextEditingController();
  final _bt = TextEditingController();
  final _ba = TextEditingController();
  final _ct = TextEditingController();
  final _st = TextEditingController();
  final _pc = TextEditingController();
  final _aa = TextEditingController();
  final _pa = TextEditingController();

  final List<String> _accountTypes = ['regular', 'employee'];
  final List<String> _roles = ['master_distributor', 'distributor', 'retailer', 'employee'];

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> _fetchParentOptions(String childRole) async {
    setState(() => _isLoadingParents = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/members/parent-options?childRole=$childRole'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _parentOptions = List<Map<String, dynamic>>.from(data['parents'] ?? []);
          _selectedParentId = null;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoadingParents = false);
    }
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccountType == null) {
      _showToast('Please select account type', error: true);
      return;
    }
    if (_selectedRole == null) {
      _showToast('Please select role', error: true);
      return;
    }
    if (_selectedRole != 'master_distributor' && _selectedParentId == null) {
      _showToast('Select a parent', error: true);
      return;
    }
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    try {
      final token = await _getToken();
      if (token == null) return;
      final Map<String, dynamic> body = {
        'first_name': _fn.text.trim(),
        'last_name': _ln.text.trim(),
        'email': _em.text.trim(),
        'phone': _ph.text.trim(),
        'accountType': _selectedAccountType, // regular or employee
        'intended_role': _selectedRole, // master_distributor, distributor, retailer, employee
        'business_name': _bn.text.trim(),
        'business_type': _bt.text.trim(),
        'business_address': _ba.text.trim(),
        'city': _ct.text.trim(),
        'state': _st.text.trim(),
        'pin_code': _pc.text.trim(),
        'aadhaar_number': _aa.text.trim(),
        'pan_number': _pa.text.trim(),
      };
      if (_selectedRole != 'master_distributor' && _selectedParentId != null) {
        body['parent_id'] = _selectedParentId;
      }
      final response = await LoggedHttpClient.post(
        Uri.parse('${ApiConfig.baseUrl}/api/members/create'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        _showToast(data['message'] ?? 'Account created successfully!');
        _clearForm();
      } else {
        _showToast(data['message'] ?? 'Failed to create account', error: true);
      }
    } catch (e) {
      _showToast('Network error', error: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearForm() {
    for (final c in [_fn, _ln, _em, _ph, _bn, _bt, _ba, _ct, _st, _pc, _aa, _pa]) {
      c.clear();
    }
    setState(() {
      _selectedAccountType = null;
      _selectedRole = null;
      _selectedParentId = null;
      _parentOptions = [];
      _currentStep = 0;
    });
  }

  void _showToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: error ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  String _accountTypeLabel(String type) {
    return type.substring(0, 1).toUpperCase() + type.substring(1);
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'master_distributor':
        return 'Master Distributor';
      case 'distributor':
        return 'Distributor';
      case 'retailer':
        return 'Retailer';
      case 'employee':
        return 'Employee';
      default:
        return r;
    }
  }

  IconData _getAccountTypeIcon(String type) {
    switch (type) {
      case 'regular':
        return Icons.person_outline;
      case 'employee':
        return Icons.badge_outlined;
      default:
        return Icons.person;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'master_distributor':
        return Icons.stars_rounded;
      case 'distributor':
        return Icons.local_shipping_rounded;
      case 'retailer':
        return Icons.store_rounded;
      case 'employee':
        return Icons.work_outline;
      default:
        return Icons.person;
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'master_distributor':
        return 'Top-level distributor with full access';
      case 'distributor':
        return 'Mid-level distribution partner';
      case 'retailer':
        return 'End-point retailer account';
      case 'employee':
        return 'Company employee account';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1F3A),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.person_add_rounded, color: Color(0xFF6C63FF), size: 24),
            SizedBox(width: 10),
            Text(
              'Create Account',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Indicator
              _buildProgressIndicator(),
              const SizedBox(height: 24),

              // Step 1: Account Type & Role Selection
              if (_currentStep == 0) ...[
                // Account Type Selection
                _buildSectionCard(
                  title: 'Account Type',
                  icon: Icons.account_circle_outlined,
                  child: _buildAccountTypeSelector(),
                ),

                // Role Selection (only show after account type is selected)
                if (_selectedAccountType != null) ...[
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Select Role',
                    icon: Icons.badge_outlined,
                    child: _buildRoleSelector(),
                  ),
                ],

                // Parent Selection (only for non-master_distributor roles)
                if (_selectedRole != null && _selectedRole != 'master_distributor') ...[
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'Select Parent',
                    icon: Icons.account_tree_outlined,
                    child: _buildParentSelector(),
                  ),
                ],

                const SizedBox(height: 24),
                _buildNextButton(),
              ],

              // Step 2: Personal Information
              if (_currentStep == 1) ...[
                _buildSectionCard(
                  title: 'Personal Information',
                  icon: Icons.person_outline,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildModernField(_fn, 'First Name', Icons.person)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildModernField(_ln, 'Last Name', Icons.person_outline)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildModernField(_em, 'Email Address', Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _buildModernField(_ph, 'Phone Number', Icons.phone_outlined,
                          keyboardType: TextInputType.phone, maxLength: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildNavigationButtons(),
              ],

              // Step 3: Business Details
              if (_currentStep == 2) ...[
                _buildSectionCard(
                  title: 'Business Details',
                  icon: Icons.business_outlined,
                  child: Column(
                    children: [
                      _buildModernField(_bn, 'Business Name', Icons.store),
                      const SizedBox(height: 16),
                      _buildModernField(_bt, 'Business Type', Icons.category_outlined),
                      const SizedBox(height: 16),
                      _buildModernField(_ba, 'Business Address', Icons.location_on_outlined,
                          maxLines: 2),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildModernField(_ct, 'City', Icons.location_city)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildModernField(_st, 'State', Icons.map_outlined)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildModernField(_pc, 'PIN Code', Icons.pin_outlined,
                          keyboardType: TextInputType.number, maxLength: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildNavigationButtons(),
              ],

              // Step 4: KYC Details & Submit
              if (_currentStep == 3) ...[
                _buildSectionCard(
                  title: 'KYC Verification',
                  icon: Icons.verified_user_outlined,
                  child: Column(
                    children: [
                      _buildModernField(_aa, 'Aadhaar Number', Icons.credit_card_outlined,
                          keyboardType: TextInputType.number, maxLength: 12),
                      const SizedBox(height: 16),
                      _buildModernField(_pa, 'PAN Number', Icons.description_outlined,
                          maxLength: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSummaryCard(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentStep--),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6C63FF),
                            side: const BorderSide(color: Color(0xFF6C63FF)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_back_rounded, size: 20),
                              SizedBox(width: 8),
                              Text('Back', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSubmitButton(),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final steps = ['Account Type', 'Personal', 'Business', 'KYC'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF6C63FF).withOpacity(0.1), const Color(0xFF6C63FF).withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (index) {
              final isActive = index <= _currentStep;
              final isCurrent = index == _currentStep;
              return Column(
                children: [
                  Container(
                    width: isCurrent ? 36 : 30,
                    height: isCurrent ? 36 : 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isActive
                          ? const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF8B83FF)],
                      )
                          : null,
                      color: isActive ? null : Colors.white.withOpacity(0.1),
                      border: isActive
                          ? null
                          : Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                    ),
                    child: Center(
                      child: isActive
                          ? Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: isCurrent ? 20 : 16,
                      )
                          : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[index],
                    style: TextStyle(
                      color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6C63FF)),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildAccountTypeSelector() {
    return Column(
      children: _accountTypes.map((type) {
        final isSelected = _selectedAccountType == type;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedAccountType = type;
                  _selectedRole = null; // Reset role when account type changes
                  _selectedParentId = null;
                });
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF6C63FF)
                        : Colors.white.withOpacity(0.08),
                    width: isSelected ? 2 : 1,
                  ),
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [
                      const Color(0xFF6C63FF).withOpacity(0.15),
                      const Color(0xFF6C63FF).withOpacity(0.05),
                    ],
                  )
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.02),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.white.withOpacity(0.05),
                      ),
                      child: Icon(
                        _getAccountTypeIcon(type),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _accountTypeLabel(type),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            type == 'regular' ? 'Standard user account' : 'Employee account with company access',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6C63FF)
                              : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        color: isSelected
                            ? const Color(0xFF6C63FF)
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      children: _roles.map((role) {
        final isSelected = _selectedRole == role;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedRole = role;
                  _selectedParentId = null;
                });
                if (role != 'master_distributor') {
                  _fetchParentOptions(role);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF10B981)
                        : Colors.white.withOpacity(0.08),
                    width: isSelected ? 2 : 1,
                  ),
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.15),
                      const Color(0xFF10B981).withOpacity(0.05),
                    ],
                  )
                      : null,
                  color: isSelected ? null : Colors.white.withOpacity(0.02),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF10B981)
                            : Colors.white.withOpacity(0.05),
                      ),
                      child: Icon(
                        _getRoleIcon(role),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _roleLabel(role),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getRoleDescription(role),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF10B981)
                              : Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        color: isSelected
                            ? const Color(0xFF10B981)
                            : Colors.transparent,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParentSelector() {
    if (_isLoadingParents) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF6C63FF),
          ),
        ),
      );
    }

    if (_parentOptions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.people_outline, color: Colors.white.withOpacity(0.3), size: 40),
              const SizedBox(height: 8),
              Text(
                'No parents available',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: DropdownButtonFormField<int>(
        value: _selectedParentId,
        dropdownColor: const Color(0xFF1A1F3A),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          hintText: 'Select parent account',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          prefixIcon: const Icon(Icons.account_tree_outlined, color: Color(0xFF6C63FF), size: 20),
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6C63FF)),
        items: _parentOptions.map((p) {
          return DropdownMenuItem<int>(
            value: p['id'] as int,
            child: Text(
              '${p['first_name']} ${p['last_name']} (${p['member_id']})',
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
        onChanged: (v) => setState(() => _selectedParentId = v),
        validator: (v) => v == null ? 'Please select a parent' : null,
      ),
    );
  }

  Widget _buildModernField(
      TextEditingController controller,
      String hint,
      IconData icon, {
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
        fillColor: Colors.white.withOpacity(0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6C63FF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEF4444)),
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        counterText: '',
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null,
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F3A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.summarize_outlined, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Summary',
                style: TextStyle(
                  color: Color(0xFF10B981),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Account Type', _accountTypeLabel(_selectedAccountType ?? '')),
          _buildSummaryRow('Role', _roleLabel(_selectedRole ?? '')),
          _buildSummaryRow('Name', '${_fn.text} ${_ln.text}'),
          _buildSummaryRow('Email', _em.text),
          _buildSummaryRow('Business', _bn.text),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
          ),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: () {
          if (_selectedAccountType == null) {
            _showToast('Please select account type', error: true);
            return;
          }
          if (_selectedRole == null) {
            _showToast('Please select a role', error: true);
            return;
          }
          if (_selectedRole != 'master_distributor' && _selectedParentId == null) {
            _showToast('Please select a parent', error: true);
            return;
          }
          setState(() => _currentStep = 1);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF6C63FF),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Continue',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep--),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6C63FF),
                side: const BorderSide(color: Color(0xFF6C63FF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Back', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) return;
                setState(() => _currentStep++);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C63FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Next', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createAccount,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF10B981).withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
        )
            : const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 22),
            SizedBox(width: 10),
            Text(
              'Create Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in [_fn, _ln, _em, _ph, _bn, _bt, _ba, _ct, _st, _pc, _aa, _pa]) {
      c.dispose();
    }
    super.dispose();
  }
}