// lib/screens/payout/payout_form_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/payout_provider.dart';
import '../../models/beneficiary_model.dart';
import '../../services/payout/payout_service.dart';
import '../payout/payout_status_screen.dart';

class PayoutFormScreen extends StatefulWidget {
  final Beneficiary? beneficiary;

  const PayoutFormScreen({Key? key, this.beneficiary}) : super(key: key);

  @override
  State<PayoutFormScreen> createState() => _PayoutFormScreenState();
}

class _PayoutFormScreenState extends State<PayoutFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _mobileController = TextEditingController();
  final _beneficiaryNameController = TextEditingController();
  final _tpinController = TextEditingController();

  final _amountFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _accountFocus = FocusNode();
  final _ifscFocus = FocusNode();
  final _mobileFocus = FocusNode();
  final _tpinFocus = FocusNode();

  bool _isSubmitting = false;
  bool _obscureTpin = true;
  String? _selectedBankCode;
  String? _selectedPurposeCode;
  String? _selectedStateCode;
  String _selectedPaymentMode = 'NEFT';

  final PayoutService _payoutService = PayoutService();

  static const Color bg = Color(0xFF0A0E0A);
  static const Color card = Color(0xFF141914);
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color inputBg = Color(0xFF1A1F1A);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF2ECC71);

  @override
  void initState() {
    super.initState();
    if (widget.beneficiary != null) {
      _beneficiaryNameController.text = widget.beneficiary!.name;
      _accountNumberController.text = widget.beneficiary!.accountNumber;
      _ifscController.text = widget.beneficiary!.ifsc;
      _mobileController.text = widget.beneficiary!.mobile;
      _selectedBankCode = widget.beneficiary!.bankCode;
      _selectedStateCode = widget.beneficiary!.stateCode;
      _selectedPaymentMode = widget.beneficiary!.paymentMode;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<PayoutProvider>();
      if (p.banks.isEmpty && !p.isLoading) p.loadMasterData();
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
    _amountFocus.dispose();
    _nameFocus.dispose();
    _accountFocus.dispose();
    _ifscFocus.dispose();
    _mobileFocus.dispose();
    _tpinFocus.dispose();
    super.dispose();
  }

  Future<void> _submitPayout() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount < 100) { _showError('Minimum payout is ₹100'); return; }
    if (amount > 50000) { _showError('Maximum per transaction is ₹50,000'); return; }
    if (_tpinController.text.length != 6) { _showError('Enter 6-digit TPIN'); return; }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) throw Exception('User not logged in');

      final response = await _payoutService.initiatePayout({
        'userId': int.parse(userId),
        'amount': amount,
        'mode': _selectedPaymentMode,
        'tpin': _tpinController.text.trim(),
        'ip_address': '192.168.1.1',
        'fee': 3,
        'lat': '28.7041',
        'long': '77.1025',
      });

      if (mounted) {
        if (response['success'] == true) {
          final txnId = response['transactionId'] ??
              response['data']?['merchantRefId'] ?? response['merchantRefId'];
          HapticFeedback.heavyImpact();
          _showSuccess(txnId?.toString() ?? '');
          _clearForm();
        } else {
          _showError(response['message'] ?? 'Payout failed');
        }
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
      setState(() { _selectedBankCode = null; _selectedPurposeCode = null; _selectedStateCode = null; });
    }
  }

  void _showSuccess(String refId) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.check_circle_rounded, color: success, size: 24),
          SizedBox(width: 8),
          Text('Payout Initiated', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Request submitted successfully.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 12),
          _infoRow('Ref ID', refId),
          const SizedBox(height: 4),
          _infoRow('Amount', '₹${_amountController.text}'),
          const SizedBox(height: 4),
          _infoRow('Status', 'Processing'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PayoutStatusScreen(merchantRefId: refId))); },
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('View Status'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String l, String v) => Row(children: [
    SizedBox(width: 70, child: Text(l, style: const TextStyle(color: Colors.white54, fontSize: 11))),
    Expanded(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
  ]);

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [const Icon(Icons.error_outline, color: Colors.white, size: 18), const SizedBox(width: 8), Expanded(child: Text(msg, style: const TextStyle(fontSize: 12)))]),
      backgroundColor: error, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), margin: const EdgeInsets.all(16), duration: const Duration(seconds: 3),
    ));
  }

  // ─── COMPACT INPUT ────────────────────────────────────
  // ─── COMPACT INPUT (Fixed validation display) ──────────
  Widget _input({
    required TextEditingController c, required FocusNode f, required String label, required IconData icon,
    TextInputType? kb, String? Function(String?)? v, int? max, String? hint, bool ob = false, Widget? suf,
    TextCapitalization cap = TextCapitalization.none, TextAlign ta = TextAlign.start, TextStyle? st, bool ro = false, VoidCallback? onT,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        focusNode: f,
        keyboardType: kb,
        maxLength: max,
        obscureText: ob,
        textCapitalization: cap,
        textAlign: ta,
        readOnly: ro,
        onTap: onT,
        style: st ?? const TextStyle(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: f.hasFocus ? primaryLight : Colors.white60),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13),
          prefixIcon: Icon(icon, color: f.hasFocus ? primaryLight : Colors.white38, size: 18),
          suffixIcon: suf,
          filled: true,
          fillColor: inputBg,
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          // ✅ Border styling for normal, focused, and error states
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.06)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primary.withOpacity(0.5), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: error.withOpacity(0.6), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: error, width: 1.5),
          ),
          errorStyle: const TextStyle(color: error, fontSize: 10),
        ),
        validator: v,
      ),
    );
  }

  // ─── COMPACT DROPDOWN ─────────────────────────────────
  // ─── SEARCHABLE DROPDOWN ────────────────────────────────
  Widget _dropdown({
    required String? val,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onCh,
    String? Function(String?)? v,
    String? hint,
  }) {
    // Get display text for selected value
    String displayText = hint ?? 'Select';
    if (val != null) {
      final selectedItem = items.where((i) => i.value == val).firstOrNull;
      if (selectedItem != null && selectedItem.child is Text) {
        displayText = (selectedItem.child as Text).data ?? '';
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white60)),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: () => _showSearchablePicker(items, val, onCh, hint ?? 'Search...'),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Row(children: [
              Icon(icon, color: Colors.white38, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    color: val != null ? Colors.white : Colors.white.withOpacity(0.25),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38, size: 20),
            ]),
          ),
        ),
        // Validation message (if needed inside Form)
        if (v != null)
          FormField<String>(
            initialValue: val,
            validator: v,
            builder: (state) => state.hasError
                ? Padding(padding: const EdgeInsets.only(top: 4), child: Text(state.errorText!, style: const TextStyle(color: error, fontSize: 10)))
                : const SizedBox.shrink(),
          ),
      ]),
    );
  }

// ✅ Searchable Bottom Sheet Picker
  void _showSearchablePicker(List<DropdownMenuItem<String>> items, String? currentValue, void Function(String?) onCh, String searchHint) {
    final searchController = TextEditingController();
    List<DropdownMenuItem<String>> filteredItems = List.from(items);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(children: [
            // Handle
            Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: searchHint,
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18), onPressed: () { searchController.clear(); setSheetState(() => filteredItems = List.from(items)); })
                      : null,
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.03),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (q) {
                  setSheetState(() {
                    filteredItems = items.where((i) {
                      final text = i.child is Text ? (i.child as Text).data ?? '' : '';
                      return text.toLowerCase().contains(q.toLowerCase());
                    }).toList();
                  });
                },
              ),
            ),
            const SizedBox(height: 8),

            // List
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(child: Text('No results found', style: TextStyle(color: Colors.white38, fontSize: 13)))
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: filteredItems.length,
                itemBuilder: (_, i) {
                  final item = filteredItems[i];
                  final text = item.child is Text ? (item.child as Text).data ?? '' : '';
                  final isSelected = item.value == currentValue;
                  return ListTile(
                    dense: true,
                    title: Text(text, style: TextStyle(color: isSelected ? primaryLight : Colors.white, fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                    trailing: isSelected ? const Icon(Icons.check_rounded, color: primaryLight, size: 20) : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: isSelected ? primary.withOpacity(0.1) : null,
                    onTap: () {
                      onCh(item.value);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─── COMPACT BENEFICIARY CARD ─────────────────────────
  Widget _beneficiaryCard() {
    final b = widget.beneficiary!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [primary.withOpacity(0.15), primaryDark.withOpacity(0.08)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(12), border: Border.all(color: primary.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [primary, primaryLight]), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(b.name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(b.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('A/C: ${b.accountNumber}  •  ${b.bankName}', style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10)),
          ])),
          Icon(Icons.check_circle_rounded, color: success.withOpacity(0.7), size: 18),
        ]),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: Consumer<PayoutProvider>(builder: (context, provider, _) {
        if (provider.isLoading && provider.banks.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: primary));
        }
        if (provider.errorMessage.isNotEmpty && provider.banks.isEmpty) {
          return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 48, color: error)),
            const SizedBox(height: 16),
            Text(provider.errorMessage, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: () => provider.loadMasterData(), icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
          ])));
        }

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Header
              /*  Padding(
                  padding: const EdgeInsets.only(bottom: 14, top: 4),
                  child: Row(children: [
                    Container(width: 3, height: 22, decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    const Text('Send Money', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  ]),
                ),*/

                // Beneficiary Card
                if (widget.beneficiary != null) _beneficiaryCard(),

                // Amount
                _input(c: _amountController, f: _amountFocus, label: 'Amount', icon: Icons.currency_rupee_rounded, kb: TextInputType.number, hint: '₹100 - ₹50,000',
                    v: (v) { if (v == null || v.trim().isEmpty) return 'Enter amount'; final a = double.tryParse(v); if (a == null) return 'Invalid'; if (a < 100) return 'Min ₹100'; if (a > 50000) return 'Max ₹50,000'; return null; }),

                // Fields when no beneficiary
                if (widget.beneficiary == null) ...[
                  _input(c: _beneficiaryNameController, f: _nameFocus, label: 'Beneficiary Name', icon: Icons.person_rounded, cap: TextCapitalization.words, hint: 'Full name',
                      v: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
                  _input(c: _accountNumberController, f: _accountFocus, label: 'Account Number', icon: Icons.account_balance_rounded, kb: TextInputType.number, hint: '9-18 digits',
                      v: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (v.length < 9 || v.length > 18) return '9-18 digits'; return null; }),
                  _input(c: _ifscController, f: _ifscFocus, label: 'IFSC Code', icon: Icons.code_rounded, cap: TextCapitalization.characters, hint: 'HDFC0000516',
                      v: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(v.toUpperCase())) return 'Invalid format'; return null; }),
                  _input(c: _mobileController, f: _mobileFocus, label: 'Mobile Number', icon: Icons.phone_rounded, kb: TextInputType.phone, max: 10, hint: '10-digit',
                      v: (v) { if (v == null || v.trim().isEmpty) return 'Required'; if (v.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(v)) return 'Invalid'; return null; }),
                  _dropdown(val: _selectedBankCode, label: 'Bank', icon: Icons.account_balance_rounded, hint: 'Select bank',
                      items: provider.banks.map<DropdownMenuItem<String>>((b) => DropdownMenuItem<String>(value: b['code']?.toString(), child: Text(b['description']?.toString() ?? '', overflow: TextOverflow.ellipsis))).toList(),
                      onCh: (v) => setState(() => _selectedBankCode = v), v: (v) => v == null ? 'Required' : null),
                  _dropdown(val: _selectedPurposeCode, label: 'Purpose', icon: Icons.receipt_rounded, hint: 'Select purpose',
                      items: provider.purposes.map<DropdownMenuItem<String>>((p) => DropdownMenuItem<String>(value: p['code']?.toString(), child: Text(p['description']?.toString() ?? '', overflow: TextOverflow.ellipsis))).toList(),
                      onCh: (v) => setState(() => _selectedPurposeCode = v), v: (v) => v == null ? 'Required' : null),
                  _dropdown(val: _selectedStateCode, label: 'State', icon: Icons.location_on_rounded, hint: 'Select state',
                      items: provider.states.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s['code']?.toString(), child: Text(s['description']?.toString() ?? '', overflow: TextOverflow.ellipsis))).toList(),
                      onCh: (v) => setState(() => _selectedStateCode = v), v: (v) => v == null ? 'Required' : null),
                ],

                // Payment Mode
                _dropdown(val: _selectedPaymentMode, label: 'Payment Mode', icon: Icons.speed_rounded,
                    items: const [DropdownMenuItem<String>(value: 'NEFT', child: Text('NEFT'))], onCh: (v) => setState(() => _selectedPaymentMode = v!)),

                // TPIN
                _input(c: _tpinController, f: _tpinFocus, label: 'Transaction PIN (TPIN)', icon: Icons.lock_rounded, kb: TextInputType.number, max: 6, ob: _obscureTpin,
                    ta: TextAlign.center, st: const TextStyle(fontSize: 18, color: Colors.white, letterSpacing: 6, fontWeight: FontWeight.w600), hint: '• • • • • •',
                    suf: IconButton(padding: EdgeInsets.zero, icon: Icon(_obscureTpin ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white38, size: 18), onPressed: () => setState(() => _obscureTpin = !_obscureTpin)),
                    v: (v) { if (v == null || v.isEmpty) return 'Enter TPIN'; if (v.length != 6) return '6 digits required'; return null; }),

                const SizedBox(height: 8),

                // Submit
                Container(
                  width: double.infinity, height: 46,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [primary, primaryLight]), borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitPayout,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, disabledBackgroundColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.send_rounded, color: Colors.white, size: 18), SizedBox(width: 6), Text('Send Payout', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white))]),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      }),
    );
  }
}