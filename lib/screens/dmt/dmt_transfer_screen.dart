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
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);
  static const Color textDarkHint = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color borderDark = Color(0xFF2A342A);
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
  String? _selectedBeneficiaryName;
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

  double get _maxAmount => widget.productType == 'lite' ? 5000 : 50000;

  @override
  void dispose() {
    _amountController.dispose();
    _tpinController.dispose();
    _remarkController.dispose();
    super.dispose();
  }

  void _showBeneficiaryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Select Beneficiary', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: widget.beneficiaries.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05)),
                  itemBuilder: (context, index) {
                    final b = widget.beneficiaries[index];
                    final isSelected = _selectedBeneficiaryId == b.id;
                    final initials = b.accountHolderName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0].toUpperCase() : '').join();
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text(initials, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? AppColors.primaryLight : AppColors.textDarkSecondary))),
                      ),
                      title: Text(b.accountHolderName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textWhite)),
                      subtitle: Text('${b.bankName} • ${_maskAccountNumber(b.accountNumber)}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkSecondary)),
                      trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary, size: 22) : null,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedBeneficiaryId = b.id;
                          _selectedBeneficiaryName = b.accountHolderName;
                          _errorMessage = null;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

    // ✅ Get selected beneficiary FIRST
    final selectedBeneficiary = widget.beneficiaries.firstWhere(
          (b) => b.id == _selectedBeneficiaryId,
    );

    try {
      // ✅ Get state code from REMITTER (not beneficiary)
      final remitterData = await _apiService.getRemitterDetailsRaw(widget.remitterId);
      final stateCode = remitterData['state_code']?.toString() ?? '';
      print('🔍 Using State Code from Remitter: $stateCode');

      final request = DMTTransferRequest(
        remitterId: widget.remitterId,
        beneficiaryId: _selectedBeneficiaryId!,
        amount: double.parse(_amountController.text),
        tpin: _tpinController.text,
        transferMode: _transferMode,
        remark: _remarkController.text.trim().isEmpty
            ? null
            : _remarkController.text.trim(),
        stateCode: stateCode, // ✅ Now using state from remitter
      );

      print('📡 Transfer Request: ${request.toJson()}');

      // Call API
      final response = await _apiService.createTransfer(request);
      final status = response['status'] ?? 'success'; // Get status from backend

      print('📡 Transfer Response: $response');

      // Get user details for status page
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      final userName = prefs.getString('name') ?? 'User';

      // Get remitter details for status page
      Remitter remitter;
      try {
        remitter = await _apiService.getRemitterDetails(widget.remitterId);
      } catch (e) {
        print('⚠️ Could not fetch remitter details: $e');
        remitter = Remitter(
          id: widget.remitterId,
          mobile: '',
          firstName: '',
          lastName: '',
          monthlyLimit: 0,
          monthlyUsed: 0,
          productType: widget.productType,
          isActive: true,
          kycStatus: 'basic',
        );
      }

      // Prepare transfer details for status page
      final transferDetails = {
        'transactionId': response['transactionId'] ?? 'N/A',
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

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DMTStatusScreen(
              transferResult: {
                'success': true,
                'transactionId': response['transactionId'] ?? 'N/A',
                'utrNumber': response['utrNumber'],
                'providerStatus': response['providerStatus'] ?? 'N/A',
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
      print('❌ Transfer error: $errorMessage');
      HapticFeedback.heavyImpact();

      try {
        Remitter remitter;
        try {
          remitter = await _apiService.getRemitterDetails(widget.remitterId);
        } catch (e2) {
          remitter = Remitter(
            id: widget.remitterId,
            mobile: '',
            firstName: '',
            lastName: '',
            monthlyLimit: 0,
            monthlyUsed: 0,
            productType: widget.productType,
            isActive: true,
            kycStatus: 'basic',
          );
        }

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
        print('❌ Error navigating to status: $e2');
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
    return '••••${accountNumber.substring(accountNumber.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text('Transfer Money', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textWhite)),
        centerTitle: true, backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Plan Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.productType == 'lite' ? Iconsax.wallet_3 : Iconsax.crown, size: 12, color: AppColors.primaryLight),
                const SizedBox(width: 4),
                Text('${widget.productType.toUpperCase()} • Max ₹${_maxAmount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
              ]),
            ),
            const SizedBox(height: 16),

            // Beneficiary Selection
            _buildSectionLabel('Select Beneficiary'),
            const SizedBox(height: 6),
            _buildBeneficiarySelector(),
            if (_selectedBeneficiaryId != null) ...[
              const SizedBox(height: 8),
              _buildSelectedBeneficiaryInfo(),
            ],
            const SizedBox(height: 18),

            // Amount
            _buildSectionLabel('Enter Amount'),
            const SizedBox(height: 6),
            _buildAmountField(),
            if (widget.productType == 'lite' && _amountController.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSurchargeCard(),
            ],
            const SizedBox(height: 18),

            // TPIN
            _buildSectionLabel('Enter TPIN'),
            const SizedBox(height: 6),
            _buildTpinField(),
            const SizedBox(height: 16),

            // Transfer Mode
            _buildSectionLabel('Transfer Mode'),
            const SizedBox(height: 6),
            _buildTransferModeSelector(),
            const SizedBox(height: 16),

            // Remark
            _buildSectionLabel('Remark (Optional)'),
            const SizedBox(height: 6),
            _buildRemarkField(),
            const SizedBox(height: 20),

            // Error
            if (_errorMessage != null) ...[
              _buildErrorCard(),
              const SizedBox(height: 12),
            ],

            // Summary
            if (_amountController.text.isNotEmpty && _selectedBeneficiaryId != null) ...[
              _buildTransferSummary(),
              const SizedBox(height: 16),
            ],

            // Button
            _buildTransferButton(),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textDarkSecondary));
  }

  Widget _buildBeneficiarySelector() {
    return GestureDetector(
      onTap: _showBeneficiaryPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _selectedBeneficiaryId != null ? AppColors.borderFocus : AppColors.borderDark, width: _selectedBeneficiaryId != null ? 1.5 : 1),
        ),
        child: Row(children: [
          Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Iconsax.people, color: AppColors.primaryLight, size: 16),
          ),
          Expanded(child: Text(_selectedBeneficiaryName ?? 'Tap to select beneficiary', style: GoogleFonts.poppins(fontSize: 13, color: _selectedBeneficiaryName != null ? AppColors.textWhite : Colors.white38))),
          Icon(Iconsax.arrow_down_1, color: _selectedBeneficiaryId != null ? AppColors.primaryLight : Colors.white38, size: 16),
        ]),
      ),
    );
  }

  Widget _buildSelectedBeneficiaryInfo() {
    final b = widget.beneficiaries.firstWhere((x) => x.id == _selectedBeneficiaryId);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.1))),
      child: Row(children: [
        const Icon(Iconsax.bank, size: 14, color: AppColors.primaryLight),
        const SizedBox(width: 8),
        Expanded(child: Text('${b.bankName} • ${_maskAccountNumber(b.accountNumber)} • IFSC: ${b.ifscCode}', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkSecondary), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _buildAmountField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: TextFormField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textWhite,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Text(
              '₹',
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryLight,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          hintText: '0',
          hintStyle: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white24,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Minimum amount is ₹100';
          final a = double.tryParse(v);
          if (a == null || a < 100) return 'Minimum amount is ₹100';
          if (a > _maxAmount) return 'Maximum amount is ₹${_maxAmount.toStringAsFixed(0)}';
          return null;
        },
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildSurchargeCard() {
    final hasSurcharge = _surcharge > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: hasSurcharge ? AppColors.warning.withOpacity(0.3) : AppColors.borderDark)),
      child: Column(children: [
        _buildSurchargeRow('Transfer Amount', '₹${_amountController.text}', AppColors.textDarkSecondary, false),
        if (hasSurcharge) ...[
          const SizedBox(height: 4),
          _buildSurchargeRow('Processing Fee', '₹${_surcharge.toStringAsFixed(2)}', AppColors.warning, false),
          const SizedBox(height: 4),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text('${_surcharge == 10 ? 'Flat ₹10' : '1% of amount'}', style: GoogleFonts.poppins(fontSize: 9, color: AppColors.warning))),
        ],
        const Divider(height: 14, color: AppColors.borderDark),
        _buildSurchargeRow('Total to Debit', '₹${_totalAmount.toStringAsFixed(2)}', AppColors.primaryLight, true),
      ]),
    );
  }

  Widget _buildSurchargeRow(String label, String amount, Color color, bool isTotal) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: GoogleFonts.poppins(fontSize: isTotal ? 13 : 11, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w400, color: isTotal ? AppColors.textWhite : AppColors.textDarkSecondary)),
      Text(amount, style: GoogleFonts.poppins(fontSize: isTotal ? 16 : 13, fontWeight: FontWeight.w700, color: color)),
    ]);
  }

  Widget _buildTpinField() {
    return Container(
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
      child: TextFormField(
        controller: _tpinController,
        obscureText: !_isTpinVisible,
        maxLength: 6,
        keyboardType: TextInputType.number,
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textWhite, letterSpacing: 6),
        decoration: InputDecoration(
          prefixIcon: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Iconsax.lock, size: 16, color: AppColors.primaryLight)),
          suffixIcon: IconButton(icon: Icon(_isTpinVisible ? Iconsax.eye : Iconsax.eye_slash, size: 16, color: Colors.white38), onPressed: () { HapticFeedback.selectionClick(); setState(() => _isTpinVisible = !_isTpinVisible); }),
          hintText: '••••••',
          hintStyle: GoogleFonts.poppins(fontSize: 16, color: Colors.white24, letterSpacing: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5)),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return 'Please enter your TPIN';
          if (v.length != 6) return 'TPIN must be 6 digits';
          return null;
        },
      ),
    );
  }

  Widget _buildTransferModeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
      child: Row(children: [
        Expanded(child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _transferMode = 'IMPS'); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: _transferMode == 'IMPS' ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Icon(Iconsax.flash, size: 18, color: _transferMode == 'IMPS' ? Colors.white : AppColors.textDarkSecondary),
              const SizedBox(height: 2),
              Text('IMPS', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _transferMode == 'IMPS' ? Colors.white : AppColors.textDarkSecondary)),
            ]),
          ),
        )),
        Expanded(child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); setState(() => _transferMode = 'NEFT'); },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: _transferMode == 'NEFT' ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              Icon(Iconsax.clock, size: 18, color: _transferMode == 'NEFT' ? Colors.white : AppColors.textDarkSecondary),
              const SizedBox(height: 2),
              Text('NEFT', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _transferMode == 'NEFT' ? Colors.white : AppColors.textDarkSecondary)),
            ]),
          ),
        )),
      ]),
    );
  }

  Widget _buildRemarkField() {
    return Container(
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
      child: TextFormField(
        controller: _remarkController,
        maxLength: 50,
        style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textWhite),
        decoration: InputDecoration(
          hintText: 'e.g., birthday gift',
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.white30),
          prefixIcon: Container(margin: const EdgeInsets.all(8), padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: const Icon(Iconsax.message_text, size: 14, color: Colors.white38)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.borderFocus, width: 1.5)),
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.error.withOpacity(0.3))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: const Icon(Iconsax.warning_2, color: AppColors.error, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Text(_errorMessage!, style: GoogleFonts.poppins(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildTransferSummary() {
    final b = widget.beneficiaries.firstWhere((x) => x.id == _selectedBeneficiaryId);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.primary.withOpacity(0.1))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Iconsax.document_text, size: 12, color: AppColors.primaryLight), const SizedBox(width: 6), Text('Transfer Summary', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryLight))]),
        const SizedBox(height: 8),
        _buildSummaryRow('To', b.accountHolderName),
        _buildSummaryRow('Bank', '${b.bankName} • ${b.ifscCode}'),
        _buildSummaryRow('Account', _maskAccountNumber(b.accountNumber)),
        _buildSummaryRow('Amount', '₹${_amountController.text}'),
        _buildSummaryRow('Mode', _transferMode),
        _buildSummaryRow('Total', '₹${_totalAmount.toStringAsFixed(2)}', isBold: true, color: AppColors.primaryLight),
      ]),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkSecondary)),
        Text(value, style: GoogleFonts.poppins(fontSize: 10, fontWeight: isBold ? FontWeight.w600 : FontWeight.w400, color: color ?? AppColors.textWhite)),
      ]),
    );
  }

  Widget _buildTransferButton() {
    final isEnabled = _selectedBeneficiaryId != null && _amountController.text.isNotEmpty && _tpinController.text.length == 6;
    return Container(
      width: double.infinity, height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isEnabled ? [AppColors.primary, AppColors.primaryLight] : [Colors.grey[800]!, Colors.grey[700]!]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isEnabled ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 5))] : [],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _transfer,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: EdgeInsets.zero),
        child: _isLoading
            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Iconsax.send_2, color: Colors.white, size: 18), const SizedBox(width: 8), Text('Transfer Now', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))]),
      ),
    );
  }
}