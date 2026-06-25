// lib/screens/dmt/dmt_transfer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/dmt/api_service.dart';
import '../../models/dmt_models.dart';
import 'dmt_status_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN FIN TECH BRAND TOKENS - Clean Professional UI
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // Primary palette - New Green Theme
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);

  // Backgrounds
  static const Color background = Color(0xFFF6FAF9);
  static const Color cardColor = Colors.white;
  static const Color surface = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Border & Effects
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderFocus = Color(0xFF008169);
}

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
  bool _isTpinVisible = false;
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

  double get _maxAmount {
    return widget.productType == 'lite' ? 5000 : 50000;
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
        'beneficiaryAccount': selectedBeneficiary.accountNumber,
        'beneficiaryIfsc': selectedBeneficiary.ifscCode,
        'beneficiaryBank': selectedBeneficiary.bankName,
        'beneficiaryMobile': selectedBeneficiary.beneficiaryMobile ?? 'N/A',
        'remark': _remarkController.text.trim().isEmpty
            ? null
            : _remarkController.text.trim(),
        'userId': userId,
        'userName': userName,
      };

      HapticFeedback.heavyImpact();

      // Navigate to status screen
      if (mounted) {
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
      }

    } catch (e) {
      String errorMessage = e.toString().replaceFirst('Exception: ', '');

      HapticFeedback.heavyImpact();

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
          'beneficiaryAccount': selectedBeneficiary.accountNumber,
          'beneficiaryIfsc': selectedBeneficiary.ifscCode,
          'beneficiaryBank': selectedBeneficiary.bankName,
          'beneficiaryMobile': selectedBeneficiary.beneficiaryMobile ?? 'N/A',
          'remark': _remarkController.text.trim().isEmpty
              ? null
              : _remarkController.text.trim(),
        };

        // Navigate to status screen with error
        if (mounted) {
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
        }
      } catch (e2) {
        // If we can't get details, show error on current screen
        if (mounted) {
          setState(() {
            _errorMessage = errorMessage;
            _isLoading = false;
          });
        }
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
    return '••••$lastFour';
  }

  @override
  Widget build(BuildContext context) {
    final selectedBeneficiary = _selectedBeneficiaryId != null
        ? widget.beneficiaries.firstWhere((b) => b.id == _selectedBeneficiaryId)
        : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Transfer Money',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
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
              // Product Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.productType == 'lite' ? Iconsax.wallet_3 : Iconsax.crown,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.productType.toUpperCase()} Plan',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Max: ₹${_maxAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Beneficiary Selection
              _buildSectionHeader(
                icon: Iconsax.people,
                title: 'Select Beneficiary',
                iconColor: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _buildBeneficiaryDropdown(selectedBeneficiary),

              if (_selectedBeneficiaryId != null) ...[
                const SizedBox(height: 12),
                _buildSelectedBeneficiaryCard(selectedBeneficiary!),
              ],

              const SizedBox(height: 24),

              // Transfer Amount
              _buildSectionHeader(
                icon: Iconsax.money_send,
                title: 'Enter Amount',
                iconColor: AppColors.primary,
              ),
              const SizedBox(height: 12),
              _buildAmountField(),

              // Surcharge details for DMT Lite
              if (widget.productType == 'lite' && _amountController.text.isNotEmpty && (_surcharge > 0 || true)) ...[
                const SizedBox(height: 12),
                _buildSurchargeCard(),
              ],

              const SizedBox(height: 24),

              // TPIN
              _buildSectionHeader(
                icon: Iconsax.lock,
                title: 'Security PIN',
                iconColor: const Color(0xFF6366F1),
              ),
              const SizedBox(height: 12),
              _buildTpinField(),

              const SizedBox(height: 20),

              // Transfer Mode
              _buildSectionHeader(
                icon: Iconsax.flash_circle,
                title: 'Transfer Mode',
                iconColor: AppColors.warning,
              ),
              const SizedBox(height: 12),
              _buildTransferModeSelector(),

              const SizedBox(height: 20),

              // Remark
              _buildSectionHeader(
                icon: Iconsax.message_text,
                title: 'Remark (Optional)',
                iconColor: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              _buildRemarkField(),

              const SizedBox(height: 24),

              // Error Message
              if (_errorMessage != null) ...[
                _buildErrorCard(),
                const SizedBox(height: 16),
              ],

              // Transfer Summary
              if (_amountController.text.isNotEmpty && _selectedBeneficiaryId != null) ...[
                _buildTransferSummary(),
                const SizedBox(height: 20),
              ],

              // Transfer Button
              _buildTransferButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBeneficiaryDropdown(Beneficiary? selectedBeneficiary) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedBeneficiaryId,
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Iconsax.user_add,
                  size: 18,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 10),
                Text(
                  'Select beneficiary',
                  style: GoogleFonts.poppins(
                    color: AppColors.textHint,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          icon: const Icon(Iconsax.arrow_down_1, color: AppColors.primary),
          borderRadius: BorderRadius.circular(14),
          dropdownColor: AppColors.cardColor,
          items: widget.beneficiaries.map((beneficiary) {
            final initials = beneficiary.accountHolderName
                .split(' ')
                .take(2)
                .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
                .join();

            return DropdownMenuItem(
              value: beneficiary.id,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          beneficiary.accountHolderName,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${beneficiary.bankName} • ${_maskAccountNumber(beneficiary.accountNumber)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (beneficiary.verified)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.verify,
                        size: 14,
                        color: AppColors.success,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedBeneficiaryId = value;
              _errorMessage = null;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSelectedBeneficiaryCard(Beneficiary beneficiary) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Iconsax.bank,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  beneficiary.accountHolderName,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${beneficiary.bankName} • ${_maskAccountNumber(beneficiary.accountNumber)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'IFSC: ${beneficiary.ifscCode}',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          hintText: '0',
          hintStyle: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter amount';
          }
          final amount = double.tryParse(value);
          if (amount == null || amount < 100) {
            return 'Minimum amount is ₹100';
          }
          if (amount > _maxAmount) {
            return 'Maximum amount is ₹${_maxAmount.toStringAsFixed(0)}';
          }
          return null;
        },
        onChanged: (value) => setState(() {}),
      ),
    );
  }

  Widget _buildSurchargeCard() {
    final hasSurcharge = _surcharge > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasSurcharge
              ? AppColors.warning.withOpacity(0.3)
              : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSurchargeRow(
            'Transfer Amount',
            '₹${_amountController.text}',
            AppColors.textSecondary,
            false,
          ),
          if (hasSurcharge) ...[
            const SizedBox(height: 8),
            _buildSurchargeRow(
              'Processing Fee',
              '₹${_surcharge.toStringAsFixed(2)}',
              AppColors.warning,
              false,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.info_circle, size: 10, color: AppColors.warning),
                  const SizedBox(width: 4),
                  Text(
                    'Fee: ${_surcharge == 10 ? 'Flat ₹10' : '1% of amount'}',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.tick_circle, size: 10, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'No additional fees',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 20),
          _buildSurchargeRow(
            'Total to Debit',
            '₹${_totalAmount.toStringAsFixed(2)}',
            AppColors.primary,
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildSurchargeRow(String label, String amount, Color color, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400,
            color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          amount,
          style: GoogleFonts.poppins(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildTpinField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _tpinController,
        obscureText: !_isTpinVisible,
        maxLength: 6,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 8,
        ),
        decoration: InputDecoration(
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Iconsax.lock,
              size: 18,
              color: Color(0xFF6366F1),
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _isTpinVisible ? Iconsax.eye : Iconsax.eye_slash,
              size: 18,
              color: AppColors.textHint,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _isTpinVisible = !_isTpinVisible);
            },
          ),
          hintText: '••••••',
          hintStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
            letterSpacing: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }

  Widget _buildTransferModeSelector() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _transferMode = 'IMPS');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _transferMode == 'IMPS'
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(
                      Iconsax.flash,
                      size: 20,
                      color: _transferMode == 'IMPS'
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'IMPS',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _transferMode == 'IMPS'
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '24/7 Instant',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: _transferMode == 'IMPS'
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _transferMode = 'NEFT');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _transferMode == 'NEFT'
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(
                      Iconsax.clock,
                      size: 20,
                      color: _transferMode == 'NEFT'
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NEFT',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _transferMode == 'NEFT'
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      'Bank Hours',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: _transferMode == 'NEFT'
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemarkField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _remarkController,
        maxLength: 50,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'Add a remark (e.g., birthday gift)',
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: AppColors.textHint,
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Iconsax.message_text,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
          ),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Iconsax.warning_2,
              color: AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.poppins(
                color: AppColors.error,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferSummary() {
    final selectedBeneficiary = widget.beneficiaries.firstWhere(
          (b) => b.id == _selectedBeneficiaryId,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.document_text, size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Transfer Summary',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildSummaryRow('To', selectedBeneficiary.accountHolderName),
          _buildSummaryRow('Bank', '${selectedBeneficiary.bankName} (${selectedBeneficiary.ifscCode})'),
          _buildSummaryRow('Account', _maskAccountNumber(selectedBeneficiary.accountNumber)),
          _buildSummaryRow('Amount', '₹${_amountController.text}'),
          _buildSummaryRow('Mode', _transferMode),
          _buildSummaryRow('Total', '₹${_totalAmount.toStringAsFixed(2)}', isBold: true, color: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferButton() {
    final isEnabled = _selectedBeneficiaryId != null &&
        _amountController.text.isNotEmpty &&
        _tpinController.text.length == 6;

    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isEnabled
              ? [AppColors.primary, AppColors.primaryLight]
              : [AppColors.textHint, AppColors.textHint],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isEnabled
            ? [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ]
            : [],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _transfer,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.send_2, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Transfer Now',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}