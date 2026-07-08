// lib/widgets/add_fund_sheet.dart
// Complete bottom sheet: method chooser → manual form → success
// Drop this file in lib/widgets/ and import wherever needed.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/fund_provider.dart';

// ─── Bank data ───────────────────────────────────────────────────────────────

class _BankInfo {
  final String name;
  final String accountNumber;
  final String ifsc;
  final String accountName;
  // final String accountType;
  const _BankInfo({
    required this.name,
    required this.accountNumber,
    required this.ifsc,
    required this.accountName,
    // required this.accountType,
  });
}

const List<_BankInfo> _banks = [
  _BankInfo(
    name:          'HDFC Bank',
    accountNumber: '50200119405733',
    ifsc:          'HDFC0001552',
    accountName:   'Neofyn Bharath Private Limited',
    // accountType:   'Current Account',
  ),
  _BankInfo(
    name:          'Axis Bank',
    accountNumber: '925020049386006',
    ifsc:          'UTIB0001765',
    accountName:   'Neofyn Bharath Private Limited',
    // accountType:   'Current Account',
  ),
  _BankInfo(
    name:          'IDFC First Bank',
    accountNumber: '10274584545',
    ifsc:          'IDFB0080551',
    accountName:   'Neofyn Bharath Private Limited',
    // accountType:   'Current Account',
  ),
];

const List<String> _paymentModes = [
  'IMPS', 'NEFT', 'NET BANKING', 'CASH', 'OTHER',
];

// ─── Entry point: call this on wallet card tap ────────────────────────────────

void showAddFundSheet(BuildContext context, String userId) {
  showModalBottomSheet(
    context:           context,
    isScrollControlled: true,
    backgroundColor:   Colors.transparent,
    builder:           (_) => _AddFundMethodChooser(userId: userId),
  );
}

// ─── Step 1: Method chooser ───────────────────────────────────────────────────

class _AddFundMethodChooser extends StatelessWidget {
  final String userId;
  const _AddFundMethodChooser({required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color:        Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Add Fund',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _MethodCard(
                  icon:    Icons.account_balance_wallet_outlined,
                  label:   'Manual',
                  color:   const Color(0xFF00FF9D),
                  onTap:   () {
                    Navigator.pop(context);
                    showModalBottomSheet(
                      context:            context,
                      isScrollControlled: true,
                      backgroundColor:    Colors.transparent,
                      builder:            (_) => _ManualFundForm(userId: userId),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodCard(
                  icon:    Icons.qr_code_scanner,
                  label:   'UPI',
                  color:   const Color(0xFF3B82F6),
                  onTap:   () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('UPI coming soon')),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final Color    color;
  final VoidCallback onTap;
  const _MethodCard({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.1),
          border:       Border.all(color: color.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Step 2: Manual fund request form ────────────────────────────────────────

class _ManualFundForm extends StatefulWidget {
  final String userId;
  const _ManualFundForm({required this.userId});

  @override
  State<_ManualFundForm> createState() => _ManualFundFormState();
}

class _ManualFundFormState extends State<_ManualFundForm> {
  final _formKey          = GlobalKey<FormState>();
  final _refCtrl          = TextEditingController();
  final _remarkCtrl       = TextEditingController();
  final _amountCtrl       = TextEditingController();

  _BankInfo?  _selectedBank;
  String?     _selectedPaymentMode;
  DateTime?   _selectedDate;
  File?       _receiptFile;
  String?     _receiptFileName;

  @override
  void dispose() {
    _refCtrl.dispose();
    _remarkCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context:     context,
      initialDate: DateTime.now(),
      firstDate:   DateTime(2020),
      lastDate:    DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary:   Color(0xFF00FF9D),
            onPrimary: Colors.black,
            surface:   Color(0xFF1A1F2E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickReceipt() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1F2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:  const Icon(Icons.photo_camera, color: Color(0xFF00FF9D)),
              title:    const Text('Take Photo', style: TextStyle(color: Colors.white)),
              onTap:    () async {
                Navigator.pop(context);
                final img = await ImagePicker().pickImage(
                  source: ImageSource.camera, imageQuality: 70,
                );
                if (img != null) {
                  setState(() {
                    _receiptFile     = File(img.path);
                    _receiptFileName = img.name;
                  });
                }
              },
            ),
            ListTile(
              leading:  const Icon(Icons.photo_library, color: Color(0xFF00FF9D)),
              title:    const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap:    () async {
                Navigator.pop(context);
                final img = await ImagePicker().pickImage(
                  source: ImageSource.gallery, imageQuality: 70,
                );
                if (img != null) {
                  setState(() {
                    _receiptFile     = File(img.path);
                    _receiptFileName = img.name;
                  });
                }
              },
            ),
            ListTile(
              leading:  const Icon(Icons.picture_as_pdf, color: Color(0xFF00FF9D)),
              title:    const Text('Choose PDF', style: TextStyle(color: Colors.white)),
              onTap:    () async {
                Navigator.pop(context);
                final result = await FilePicker.pickFiles(
                  type:           FileType.custom,
                  allowedExtensions: ['pdf'],
                );
                if (result?.files.single.path != null) {
                  setState(() {
                    _receiptFile     = File(result!.files.single.path!);
                    _receiptFileName = result.files.single.name;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  if (_selectedBank == null) { _showError('Please select a bank'); return; }
  if (_selectedPaymentMode == null) { _showError('Please select a payment mode'); return; }
  if (_selectedDate == null) { _showError('Please select payment date'); return; }

  print('🚀 Submitting fund request...');
  print('   amount: ${_amountCtrl.text}');
  print('   bank: ${_selectedBank?.name}');
  print('   mode: $_selectedPaymentMode');
  print('   ref: ${_refCtrl.text}');
  print('   date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}');

  final fundProvider = context.read<FundProvider>();

  try {
    // Create a remark string with payment date included
    String fullRemark = _remarkCtrl.text.trim();
    if (fullRemark.isNotEmpty) {
      fullRemark += ' | Payment Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}';
    } else {
      fullRemark = 'Payment Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate!)}';
    }

    final success = await fundProvider.submitFundRequest(
      amount: double.parse(_amountCtrl.text.trim()),
      paymentMode: _selectedPaymentMode!,
      bankName: _selectedBank!.name,
      referenceNumber: _refCtrl.text.trim(),
      remark: fullRemark,
      // receiptFile: _receiptFile, // For future use
    );

    print('✅ Submit result: $success');
    if (!success) {
      print('   error: ${fundProvider.submitError}');
    }

    if (!mounted) return;

    if (success) {
      // Pop the form
      Navigator.pop(context);

      // Show success sheet
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => const _SuccessSheet(),
      );
    } else {
      _showError(fundProvider.submitError ?? 'Submission failed. Please try again.');
    }
  } catch (e, stack) {
    print('❌ _submit exception: $e');
    print(stack);
    _showError(e.toString());
  }
}

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize:     0.5,
      maxChildSize:     0.96,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color:        Color(0xFF1A1F2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Column(
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color:        Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon:    const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Manual Fund Request',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Form body ────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding:    const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Bank selection ───────────────────────────────
                      _sectionLabel('Select Bank'),
                      const SizedBox(height: 8),
                      Row(
                        children: _banks.map((bank) {
                          final isSelected = _selectedBank?.name == bank.name;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedBank = bank),
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: bank != _banks.last ? 8 : 0,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color:        isSelected
                                      ? const Color(0xFF00FF9D).withOpacity(0.15)
                                      : Colors.white.withOpacity(0.05),
                                  border:       Border.all(
                                    color: isSelected
                                        ? const Color(0xFF00FF9D)
                                        : Colors.white12,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  bank.name.replaceFirst(' Bank', '\nBank'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:      isSelected
                                        ? const Color(0xFF00FF9D)
                                        : Colors.white60,
                                    fontSize:   11,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // ── Dynamic bank details card ────────────────────
                      if (_selectedBank != null) ...[
                        const SizedBox(height: 12),
                        _BankDetailsCard(bank: _selectedBank!),
                      ],

                      const SizedBox(height: 20),

                      // ── Payment mode ─────────────────────────────────
                      _sectionLabel('Payment Mode'),
                      const SizedBox(height: 8),
                      _styledDropdown<String>(
                        hint:   'Select payment mode',
                        value:  _selectedPaymentMode,
                        items:  _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (v) => setState(() => _selectedPaymentMode = v),
                      ),

                      const SizedBox(height: 20),

                      // ── Reference number ─────────────────────────────
                      _sectionLabel('Reference / UTR Number'),
                      const SizedBox(height: 8),
                      _styledField(
                        controller: _refCtrl,
                        hint:       'Enter transaction reference',
                        validator:  (v) => v!.isEmpty ? 'Reference number is required' : null,
                      ),

                      const SizedBox(height: 20),

                      // ── Payment date ─────────────────────────────────
                      _sectionLabel('Payment Date'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: _fieldDecoration(),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, color: Color(0xFF00FF9D), size: 18),
                              const SizedBox(width: 12),
                              Text(
                                _selectedDate == null
                                    ? 'Select payment date'
                                    : DateFormat('dd MMM yyyy').format(_selectedDate!),
                                style: TextStyle(
                                  color:    _selectedDate == null ? Colors.white38 : Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Remark ───────────────────────────────────────
                      _sectionLabel('Remark (Optional)'),
                      const SizedBox(height: 8),
                      _styledField(
                        controller: _remarkCtrl,
                        hint:       'Add a note',
                        maxLines:   2,
                      ),

                      const SizedBox(height: 20),

                      // ── Amount ───────────────────────────────────────
                      _sectionLabel('Amount (₹)'),
                      const SizedBox(height: 8),
                      _styledField(
                        controller:  _amountCtrl,
                        hint:        'Enter amount',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        prefix: const Text('₹ ', style: TextStyle(color: Color(0xFF00FF9D), fontWeight: FontWeight.bold)),
                        validator: (v) {
                          if (v!.isEmpty) return 'Amount is required';
                          final amt = double.tryParse(v);
                          if (amt == null || amt <= 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),

                      const SizedBox(height: 20),

                      // ── Receipt upload ───────────────────────────────
                      _sectionLabel('Upload Receipt'),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickReceipt,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:        _receiptFile != null
                                ? const Color(0xFF00FF9D).withOpacity(0.08)
                                : Colors.white.withOpacity(0.05),
                            border:       Border.all(
                              color:  _receiptFile != null
                                  ? const Color(0xFF00FF9D).withOpacity(0.5)
                                  : Colors.white12,
                              style: BorderStyle.solid,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _receiptFile != null ? Icons.check_circle : Icons.upload_file,
                                color: _receiptFile != null ? const Color(0xFF00FF9D) : Colors.white38,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _receiptFile != null ? _receiptFileName! : 'Tap to upload receipt',
                                      style: TextStyle(
                                        color:    _receiptFile != null ? Colors.white : Colors.white54,
                                        fontSize: 13,
                                      ),
                                      maxLines:  1,
                                      overflow:  TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'JPG, PNG or PDF · Max 2MB',
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              if (_receiptFile != null)
                                GestureDetector(
                                  onTap: () => setState(() { _receiptFile = null; _receiptFileName = null; }),
                                  child: const Icon(Icons.close, color: Colors.white38, size: 18),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // ── Submit button ────────────────────────────────
                      SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: context.watch<FundProvider>().isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00FF9D),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          disabledBackgroundColor: const Color(0xFF00FF9D).withOpacity(0.4),
                        ),
                        child: context.watch<FundProvider>().isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Submit Request',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bank details card ────────────────────────────────────────────────────────

class _BankDetailsCard extends StatelessWidget {
  final _BankInfo bank;
  const _BankDetailsCard({required this.bank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        const Color(0xFF00FF9D).withOpacity(0.07),
        border:       Border.all(color: const Color(0xFF00FF9D).withOpacity(0.25)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance, color: Color(0xFF00FF9D), size: 16),
              const SizedBox(width: 6),
              Text(
                bank.name,
                style: const TextStyle(color: Color(0xFF00FF9D), fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),
          _detailRow('Account Name', bank.accountName),
          _detailRow('Account Number', bank.accountNumber),
          _detailRow('IFSC Code', bank.ifsc),
          // _detailRow('Account Type', bank.accountType),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: bank.accountNumber));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account number copied'), duration: Duration(seconds: 1)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, color: Colors.white54, size: 13),
                  SizedBox(width: 4),
                  Text('Copy Account Number', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ─── Success sheet ────────────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color:        Color(0xFF1A1F2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color:  const Color(0xFF00FF9D).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: Color(0xFF00FF9D), size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Request Initiated!',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const Text(
            'Fund request has been initiated successfully.\nYour balance will be updated once the admin approves.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF9D),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared style helpers ─────────────────────────────────────────────────────

BoxDecoration _fieldDecoration() => BoxDecoration(
  color:        Colors.white.withOpacity(0.05),
  border:       Border.all(color: Colors.white12),
  borderRadius: BorderRadius.circular(12),
);

Widget _sectionLabel(String text) => Text(
  text,
  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
);

Widget _styledField({
  required TextEditingController controller,
  required String hint,
  String? Function(String?)? validator,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
  int maxLines = 1,
  Widget? prefix,
}) {
  return TextFormField(
    controller:        controller,
    validator:         validator,
    keyboardType:      keyboardType,
    inputFormatters:   inputFormatters,
    maxLines:          maxLines,
    style:             const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText:        hint,
      hintStyle:       const TextStyle(color: Colors.white38, fontSize: 14),
      prefixIcon:      prefix != null ? Padding(padding: const EdgeInsets.only(left: 14, top: 14), child: prefix) : null,
      prefixIconConstraints: const BoxConstraints(),
      filled:          true,
      fillColor:       Colors.white.withOpacity(0.05),
      contentPadding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border:          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
      enabledBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder:   OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF9D), width: 1.5)),
      errorBorder:     OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
    ),
  );
}

Widget _styledDropdown<T>({
  required String hint,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  return DropdownButtonFormField<T>(
    value:      value,
    items:      items,
    onChanged:  onChanged,
    dropdownColor: const Color(0xFF1A1F2E),
    style:      const TextStyle(color: Colors.white, fontSize: 14),
    decoration: InputDecoration(
      hintText:       hint,
      hintStyle:      const TextStyle(color: Colors.white38, fontSize: 14),
      filled:         true,
      fillColor:      Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border:         OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
      enabledBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white12)),
      focusedBorder:  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00FF9D), width: 1.5)),
    ),
    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white38),
  );
}

