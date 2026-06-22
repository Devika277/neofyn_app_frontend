// lib/screens/payout/payout_form_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/payout_provider.dart';
import '../../models/beneficiary_model.dart';
import '../../services/payout/payout_service.dart';
import '../payout/payout_status_screen.dart';

class PayoutFormScreen extends StatefulWidget {
  final Beneficiary? beneficiary; // Optional pre-selected beneficiary
  
  const PayoutFormScreen({Key? key, this.beneficiary}) : super(key: key);
  
  @override
  State<PayoutFormScreen> createState() => _PayoutFormScreenState();
}

class _PayoutFormScreenState extends State<PayoutFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _mobileController = TextEditingController();
  final _beneficiaryNameController = TextEditingController();
  final _tpinController = TextEditingController();
  
  bool _isSubmitting = false;
  bool _obscureTpin = true;
  String? _selectedBankCode;
  String? _selectedPurposeCode;
  String? _selectedStateCode;
  String _selectedPaymentMode = 'IMPS';
  
  final PayoutService _payoutService = PayoutService();

  @override
  void initState() {
    super.initState();
    // Pre-fill if beneficiary is provided
    if (widget.beneficiary != null) {
      _beneficiaryNameController.text = widget.beneficiary!.name;
      _accountNumberController.text = widget.beneficiary!.accountNumber;
      _ifscController.text = widget.beneficiary!.ifsc;
      _mobileController.text = widget.beneficiary!.mobile;
      _selectedBankCode = widget.beneficiary!.bankCode;
      // _selectedPurposeCode = widget.beneficiary!.purposeCode;
      _selectedStateCode = widget.beneficiary!.stateCode;
      _selectedPaymentMode = widget.beneficiary!.paymentMode;
    }
    
    // Load master data if not loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PayoutProvider>();
      if (provider.banks.isEmpty && !provider.isLoading) {
        provider.loadMasterData();
      }
    });
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _mobileController.dispose();
    _beneficiaryNameController.dispose();
    _tpinController.dispose();
    super.dispose();
  }
  
  Future<void> _submitPayout() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate amount
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 100) {
      _showErrorDialog('Minimum payout amount is ₹100');
      return;
    }
    if (amount > 50000) {
      _showErrorDialog('Maximum per transaction is ₹50,000');
      return;
    }
    
    // Validate TPIN
    if (_tpinController.text.length != 4) {
      _showErrorDialog('Please enter 4-digit TPIN');
      return;
    }
    
    setState(() => _isSubmitting = true);
    
    try {
      // Get userId from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) {
        throw Exception('User not logged in');
      }
      
      // Build payout request matching backend format
      final payoutRequest = {
        'userId': int.parse(userId),
        'amount': amount,
        'mode': _selectedPaymentMode,
        'tpin': _tpinController.text.trim(),
        'ip_address': '192.168.1.1', // You can get actual IP
        'fee': 3,
        'lat': '28.7041',
        'long': '77.1025',
        // Note: Backend gets bank details from agent_bank_accounts table
        // So we don't need to send account details here
      };
      
      print('📤 Sending payout request: $payoutRequest');
      
      final response = await _payoutService.initiatePayout(payoutRequest);
      
      if (mounted) {
        if (response['success'] == true) {
          final transactionId = response['transactionId'] ?? 
                               response['data']?['merchantRefId'] ?? 
                               response['merchantRefId'];
          
          // Show success and navigate to status
          _showSuccessDialog(transactionId?.toString() ?? '');
          _clearForm();
        } else {
          _showErrorDialog(response['message'] ?? 'Payout failed');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
  
  void _clearForm() {
    _amountController.clear();
    _tpinController.clear();
    if (widget.beneficiary == null) {
      _accountNumberController.clear();
      _ifscController.clear();
      _mobileController.clear();
      _beneficiaryNameController.clear();
    }
  }
  
  void _showSuccessDialog(String merchantRefId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Payout Initiated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your payout request has been submitted successfully.'),
            const SizedBox(height: 12),
            Text('Reference ID: $merchantRefId', 
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Amount: ₹${_amountController.text}'),
            const SizedBox(height: 8),
            const Text('Status: Processing'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PayoutStatusScreen(
                    merchantRefId: merchantRefId,
                  ),
                ),
              );
            },
            child: const Text('View Status'),
          ),
        ],
      ),
    );
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<PayoutProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.banks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (provider.errorMessage.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(provider.errorMessage),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => provider.loadMasterData(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        return Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Beneficiary Info Card (if pre-selected)
              if (widget.beneficiary != null) ...[
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Beneficiary',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Name: ${widget.beneficiary!.name}'),
                        Text('Account: ${widget.beneficiary!.accountNumber}'),
                        Text('Bank: ${widget.beneficiary!.bankName}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Amount Field
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: Icon(Icons.currency_rupee),
                  border: OutlineInputBorder(),
                  hintText: 'Minimum ₹100',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter amount';
                  final amount = double.tryParse(value);
                  if (amount == null) return 'Invalid amount';
                  if (amount < 100) return 'Minimum amount is ₹100';
                  if (amount > 50000) return 'Maximum amount is ₹50,000';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // If no beneficiary pre-selected, show all fields
              if (widget.beneficiary == null) ...[
                // Beneficiary Name
                TextFormField(
                  controller: _beneficiaryNameController,
                  decoration: const InputDecoration(
                    labelText: 'Beneficiary Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => 
                      value == null || value.isEmpty ? 'Enter beneficiary name' : null,
                ),
                const SizedBox(height: 16),
                
                // Account Number
                TextFormField(
                  controller: _accountNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Account Number',
                    prefixIcon: Icon(Icons.account_balance),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter account number';
                    if (value.length < 9 || value.length > 18) {
                      return 'Account number must be 9-18 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // IFSC Code
                TextFormField(
                  controller: _ifscController,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    prefixIcon: Icon(Icons.code),
                    border: OutlineInputBorder(),
                    hintText: 'Example: HDFC0000516',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter IFSC code';
                    final ifscRegex = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
                    if (!ifscRegex.hasMatch(value.toUpperCase())) {
                      return 'Invalid IFSC code format';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Mobile Number
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter mobile number';
                    if (value.length != 10) return 'Enter 10 digits';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                      return 'Invalid mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Bank Dropdown - Fixed type issue
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Beneficiary Bank',
                    prefixIcon: Icon(Icons.account_balance),
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedBankCode,
                  items: provider.banks.map<DropdownMenuItem<String>>((bank) {
                    return DropdownMenuItem<String>(
                      value: bank['code'] as String?,
                      child: Text(bank['description'] as String? ?? bank['code'] as String? ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedBankCode = value),
                  validator: (value) => value == null ? 'Select bank' : null,
                ),
                const SizedBox(height: 16),
                
                // Purpose Dropdown - Fixed type issue
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Payment Purpose',
                    prefixIcon: Icon(Icons.receipt),
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedPurposeCode,
                  items: provider.purposes.map<DropdownMenuItem<String>>((purpose) {
                    return DropdownMenuItem<String>(
                      value: purpose['code'] as String?,
                      child: Text(purpose['description'] as String? ?? purpose['code'] as String? ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedPurposeCode = value),
                  validator: (value) => value == null ? 'Select purpose' : null,
                ),
                const SizedBox(height: 16),
                
                // State Dropdown - Fixed type issue
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Beneficiary Location (State)',
                    prefixIcon: Icon(Icons.location_city),
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedStateCode,
                  items: provider.states.map<DropdownMenuItem<String>>((state) {
                    return DropdownMenuItem<String>(
                      value: state['code'] as String?,
                      child: Text(state['description'] as String? ?? state['code'] as String? ?? ''),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedStateCode = value),
                  validator: (value) => value == null ? 'Select state' : null,
                ),
                const SizedBox(height: 16),
              ],
              
              // Payment Mode
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Payment Mode',
                  prefixIcon: Icon(Icons.speed),
                  border: OutlineInputBorder(),
                ),
                value: _selectedPaymentMode,
                items: const [
                  DropdownMenuItem<String>(value: 'IMPS', child: Text('IMPS (Instant)')),
                  DropdownMenuItem<String>(value: 'NEFT', child: Text('NEFT (1-2 hours)')),
                ],
                onChanged: (value) => setState(() => _selectedPaymentMode = value!),
              ),
              const SizedBox(height: 16),
              
              // TPIN Field
              TextFormField(
                controller: _tpinController,
                decoration: InputDecoration(
                  labelText: 'Transaction PIN (TPIN)',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureTpin ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscureTpin = !_obscureTpin),
                  ),
                ),
                obscureText: _obscureTpin,
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter TPIN';
                  if (value.length != 4) return 'Enter 4-digit TPIN';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitPayout,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Send Payout', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }
}