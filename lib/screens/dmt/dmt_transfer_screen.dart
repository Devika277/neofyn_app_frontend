// lib/screens/dmt/dmt_transfer_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/dmt/api_service.dart';
import '../../models/dmt_models.dart';
import 'dmt_status_screen.dart';

class DMTTransferScreen extends StatefulWidget {
  final int remitterId;
  final List<Beneficiary> beneficiaries;
  final String productType;

  const DMTTransferScreen({
    Key? key,
    required this.remitterId,
    required this.beneficiaries,
    required this.productType,
  }) : super(key: key);

  @override
  State<DMTTransferScreen> createState() => _DMTTransferScreenState();
}

class _DMTTransferScreenState extends State<DMTTransferScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _tpinController = TextEditingController();
  final _remarkController = TextEditingController();
  
  int? _selectedBeneficiaryId;
  String _transferMode = 'IMPS';
  bool _isLoading = false;
  String? _errorMessage;

  double get _surcharge {
    if (widget.productType != 'lite') return 0;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount >= 100 && amount <= 1000) return 10;
    if (amount > 1000) return amount * 0.01;
    return 0;
  }

  double get _totalAmount {
    final amount = double.tryParse(_amountController.text) ?? 0;
    return amount + _surcharge;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tpinController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  Future<void> _transfer() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBeneficiaryId == null) {
      setState(() {
        _errorMessage = 'Please select a beneficiary';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final request = DMTTransferRequest(
        remitterId: widget.remitterId,
        beneficiaryId: _selectedBeneficiaryId!,
        amount: double.parse(_amountController.text),
        tpin: _tpinController.text,
        transferMode: _transferMode,
        remark: _remarkController.text.trim().isEmpty 
            ? null 
            : _remarkController.text.trim(),
      );

      // Call API
      final response = await _apiService.createTransfer(request);
      
      // Get user details for status page
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      final userName = prefs.getString('name') ?? 'User';
      
      // Get remitter details
      final remitter = await _apiService.getRemitterDetails(widget.remitterId);
      
      // Get selected beneficiary
      final selectedBeneficiary = widget.beneficiaries.firstWhere(
        (b) => b.id == _selectedBeneficiaryId,
      );

      // Prepare transfer details for status page
      final transferDetails = {
        'transactionId': response['transactionId'],
        'amount': double.parse(_amountController.text),
        'transferMode': _transferMode,
        'remitterName': '${remitter.firstName} ${remitter.lastName}',
        'remitterMobile': remitter.mobile,
        'productType': widget.productType,
        'monthlyLimit': remitter.monthlyLimit,
        'monthlyUsed': remitter.monthlyUsed,
        'beneficiaryName': selectedBeneficiary.accountHolderName,
        'beneficiaryAccount': _maskAccountNumber(selectedBeneficiary.accountNumber),
        'beneficiaryIfsc': selectedBeneficiary.ifscCode,
        'beneficiaryBank': selectedBeneficiary.bankName,
        'beneficiaryMobile': selectedBeneficiary.beneficiaryMobile ?? 'N/A',
        'remark': _remarkController.text.trim().isEmpty 
            ? null 
            : _remarkController.text.trim(),
        'userId': userId,
        'userName': userName,
      };

      // Navigate to status screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DMTStatusScreen(
            transferResult: {
              'success': true,
              'transactionId': response['transactionId'],
              'utrNumber': response['utrNumber'],
              'providerStatus': response['providerStatus'],
              'message': 'Transfer completed successfully',
              'error': null,
            },
            transferDetails: transferDetails,
          ),
        ),
      );
      
    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');
      
      // Get remitter details for status page (even on error)
      try {
        final remitter = await _apiService.getRemitterDetails(widget.remitterId);
        final selectedBeneficiary = widget.beneficiaries.firstWhere(
          (b) => b.id == _selectedBeneficiaryId,
        );
        
        final transferDetails = {
          'transactionId': 'N/A',
          'amount': double.parse(_amountController.text),
          'transferMode': _transferMode,
          'remitterName': '${remitter.firstName} ${remitter.lastName}',
          'remitterMobile': remitter.mobile,
          'productType': widget.productType,
          'monthlyLimit': remitter.monthlyLimit,
          'monthlyUsed': remitter.monthlyUsed,
          'beneficiaryName': selectedBeneficiary.accountHolderName,
          'beneficiaryAccount': _maskAccountNumber(selectedBeneficiary.accountNumber),
          'beneficiaryIfsc': selectedBeneficiary.ifscCode,
          'beneficiaryBank': selectedBeneficiary.bankName,
          'beneficiaryMobile': selectedBeneficiary.beneficiaryMobile ?? 'N/A',
          'remark': _remarkController.text.trim().isEmpty 
              ? null 
              : _remarkController.text.trim(),
        };

        // Navigate to status screen with error
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DMTStatusScreen(
              transferResult: {
                'success': false,
                'error': errorMessage,
                'message': 'Transfer failed',
              },
              transferDetails: transferDetails,
            ),
          ),
        );
      } catch (e2) {
        // If we can't get details, show error on current screen
        setState(() {
          _errorMessage = errorMessage;
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) return accountNumber;
    final lastFour = accountNumber.substring(accountNumber.length - 4);
    return 'XXXX$lastFour';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Transfer Money',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Beneficiary Selection
                Text(
                  'Select Beneficiary',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedBeneficiaryId,
                      hint: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Select beneficiary',
                          style: GoogleFonts.poppins(
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                      isExpanded: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      items: widget.beneficiaries.map((beneficiary) {
                        return DropdownMenuItem(
                          value: beneficiary.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                beneficiary.accountHolderName,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${beneficiary.bankName} • ${_maskAccountNumber(beneficiary.accountNumber)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBeneficiaryId = value;
                          _errorMessage = null;
                        });
                      },
                    ),
                  ),
                ),
                if (_selectedBeneficiaryId == null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Please select a beneficiary',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Transfer Amount
                Text(
                  'Enter Amount',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'Enter amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter amount';
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount < 100) {
                      return 'Minimum amount is ₹100';
                    }
                    final maxAmount = widget.productType == 'lite' ? 5000 : 50000;
                    if (amount > maxAmount) {
                      return 'Maximum amount is ₹$maxAmount';
                    }
                    return null;
                  },
                  onChanged: (value) => setState(() {}),
                ),
                
                // Surcharge details for DMT Lite
                if (widget.productType == 'lite' && _amountController.text.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Transfer Amount',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '₹${_amountController.text}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Surcharge',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                            Text(
                              '₹${_surcharge.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total to Debit',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '₹${_totalAmount.toStringAsFixed(2)}',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // TPIN
                Text(
                  'Enter TPIN',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _tpinController,
                  obscureText: true,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: 'Enter your TPIN',
                    prefixIcon: const Icon(Iconsax.lock),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText: '',
                  ),
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
                const SizedBox(height: 16),

                // Transfer Mode
                Text(
                  'Transfer Mode',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(
                          'IMPS',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        value: 'IMPS',
                        groupValue: _transferMode,
                        onChanged: (value) {
                          setState(() {
                            _transferMode = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: Text(
                          'NEFT',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        value: 'NEFT',
                        groupValue: _transferMode,
                        onChanged: (value) {
                          setState(() {
                            _transferMode = value!;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Remark
                TextFormField(
                  controller: _remarkController,
                  maxLength: 50,
                  decoration: InputDecoration(
                    hintText: 'Add a remark (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Iconsax.danger, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Transfer Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _transfer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Transfer Now',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}