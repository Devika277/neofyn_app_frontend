// lib/screens/CardPayOut/cardpay_out_initiate_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cardpay_out_provider.dart';
import '../../models/cardpay_out_models.dart';
import 'cardpay_out_beneficiaries_screen.dart';

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
  
  int? _selectedBeneficiaryId;
  String? _selectedMode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<CardPayOutProvider>(context, listen: false);
    await provider.fetchBeneficiaries();
    await provider.fetchLimits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw to Bank'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<CardPayOutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available Balance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal,
                                ),
                              ),
                              Text(
                                '₹${provider.balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
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
                  const SizedBox(height: 16),

                  // Beneficiary Dropdown
                  DropdownButtonFormField<int>(
                    value: _selectedBeneficiaryId,
                    decoration: const InputDecoration(
                      labelText: 'Select Beneficiary',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Select a beneficiary'),
                      ),
                      ...provider.beneficiaries.map((b) {
                        return DropdownMenuItem(
                          value: b.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.accountHolderName),
                              Text(
                                '${b.bankName} - ${b.accountNumber}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
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
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CardPayOutBeneficiariesScreen()),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add New Beneficiary'),
                  ),
                  const SizedBox(height: 16),

                  // Mode Selection
                  DropdownButtonFormField<String>(
                    value: _selectedMode,
                    decoration: const InputDecoration(
                      labelText: 'Transfer Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'IMPS',
                        child: Text('IMPS (Instant)'),
                      ),
                      DropdownMenuItem(
                        value: 'NEFT',
                        child: Text('NEFT (1-2 hours)'),
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
                  const SizedBox(height: 16),

                  // TPIN Field - ✅ Fixed to 6 digits
                  TextFormField(
                    controller: _tpinController,
                    decoration: const InputDecoration(
                      labelText: 'TPIN',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your 6-digit TPIN',
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,  // ✅ Changed from 4 to 6
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your TPIN';
                      }
                      if (value.length != 6) {  // ✅ Changed from 4 to 6
                        return 'TPIN must be 6 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Remark (Optional)
                  TextFormField(
                    controller: _remarkController,
                    decoration: const InputDecoration(
                      labelText: 'Remark (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitWithdrawal,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal,
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
                          : const Text(
                              'Withdraw Now',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
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
        remarks: _remarkController.text.isNotEmpty ? _remarkController.text : null,
      );

      final result = await provider.initiatePayout(request);
      
      if (!mounted) return;
      
      _showSuccessDialog(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(CardPayOutInitiateResponse result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Withdrawal Initiated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your withdrawal has been initiated successfully.'),
            const SizedBox(height: 12),
            const Text('Reference ID:'),
            Text(
              result.merchantRefId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Amount:'),
            Text(
              '₹${result.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (result.bankRefNo != null) ...[
              const SizedBox(height: 8),
              const Text('Bank Reference No:'),
              Text(
                result.bankRefNo!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'The amount will be credited to your bank account shortly.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tpinController.dispose();
    _remarkController.dispose();
    super.dispose();
  }
}