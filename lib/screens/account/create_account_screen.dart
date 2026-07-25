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

  String? _selectedRole;
  int? _selectedParentId;
  List<Map<String, dynamic>> _parentOptions = [];

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
        'intended_role': _selectedRole,
        'accountType': 'regular',
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
        _showToast(data['message'] ?? 'Created!');
        _clearForm();
      } else {
        _showToast(data['message'] ?? 'Failed', error: true);
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
      _selectedRole = null;
      _selectedParentId = null;
      _parentOptions = [];
    });
  }

  void _showToast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: error ? const Color(0xFFFF5252) : const Color(0xFF008169),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    ));
  }

  String _roleLabel(String r) {
    switch (r) {
      case 'master_distributor':
        return 'Master Distributor';
      case 'distributor':
        return 'Distributor';
      case 'retailer':
        return 'Retailer';
      default:
        return r;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151915),
        title: const Text('Create Account',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Role
              _section('Role'),
              const SizedBox(height: 6),
              _dropdown<String>(
                value: _selectedRole,
                hint: 'Select role',
                items: _roles
                    .map((r) => DropdownMenuItem<String>(
                  value: r,
                  child: Text(_roleLabel(r), style: const TextStyle(fontSize: 13)),
                ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedRole = v;
                    _selectedParentId = null;
                  });
                  if (v != null) _fetchParentOptions(v);
                },
              ),
              const SizedBox(height: 14),

              // Parent
              if (_selectedRole != null && _selectedRole != 'master_distributor') ...[
                _section('Parent'),
                const SizedBox(height: 6),
                _isLoadingParents
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF00C897))),
                  ),
                )
                    : _dropdown<int>(
                  value: _selectedParentId,
                  hint: 'Select parent',
                  items: _parentOptions
                      .map((p) => DropdownMenuItem<int>(
                    value: p['id'] as int,
                    child: Text(
                        '${p['first_name']} ${p['last_name']} (${p['member_id']})',
                        style: const TextStyle(fontSize: 13)),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedParentId = v),
                ),
                const SizedBox(height: 14),
              ],

              if (_selectedRole != null) ...[
                // Personal
                _section('Personal'),
                const SizedBox(height: 8),
                _field(_fn, 'First Name'),
                const SizedBox(height: 8),
                _field(_ln, 'Last Name'),
                const SizedBox(height: 8),
                _field(_em, 'Email', keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 8),
                _field(_ph, 'Phone', keyboardType: TextInputType.phone, maxLength: 10),
                const SizedBox(height: 16),

                // Business
                _section('Business'),
                const SizedBox(height: 8),
                _field(_bn, 'Business Name'),
                const SizedBox(height: 8),
                _field(_bt, 'Business Type'),
                const SizedBox(height: 8),
                _field(_ba, 'Address', maxLines: 2),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _field(_ct, 'City')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_st, 'State')),
                ]),
                const SizedBox(height: 8),
                _field(_pc, 'PIN Code', keyboardType: TextInputType.number, maxLength: 6),
                const SizedBox(height: 16),

                // KYC
                _section('KYC'),
                const SizedBox(height: 8),
                _field(_aa, 'Aadhaar', keyboardType: TextInputType.number, maxLength: 12),
                const SizedBox(height: 8),
                _field(_pa, 'PAN', maxLength: 10),
                const SizedBox(height: 20),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF008169),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                        CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Create Account',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String t) => Text(t,
      style: const TextStyle(
          color: Color(0xFF9CA3AF), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5));

  Widget _field(
      TextEditingController c,
      String h, {
        TextInputType keyboardType = TextInputType.text,
        int? maxLength,
        int maxLines = 1,
      }) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: h,
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        counterText: '',
        isDense: true,
      ),
      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
    );
  }

  Widget _dropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration:
      BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonFormField<T>(
        value: value,
        dropdownColor: const Color(0xFF151915),
        isDense: true,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
          contentPadding: EdgeInsets.zero,
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280), size: 18),
        items: items,
        onChanged: onChanged,
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