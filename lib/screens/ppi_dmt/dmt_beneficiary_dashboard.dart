import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/remitter_provider.dart';
import '../../providers/wallet_provider.dart';


import 'package:my_app/providers/beneficiary_provider.dart';
import 'package:my_app/providers/payout_provider.dart';
import 'package:my_app/models/beneficiary_model.dart';
import 'package:my_app/providers/wallet_provider.dart';
import 'package:my_app/screens/payout/payout_status_screen.dart';




// ─── Theme constants (unchanged) ────────────────────────────────────────────
const _bg        = Color(0xFF0D0D0D);
const _surface   = Color(0xFF1A1A1A);
const _card      = Color(0xFF222222);
const _green     = Color(0xFF00FF9D);
const _blue      = Color(0xFF3B82F6);
const _border    = Color(0xFF2A2A2A);
const _textPrim  = Colors.white;
const _textSec   = Color(0xFF888888);


// ─────────────────────────────────────────────────────────────────────────────
// DmtBeneficiaryDashboard – uses PPI balance from WalletProvider
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// DmtBeneficiaryDashboard – uses PPI balance from WalletProvider
// ─────────────────────────────────────────────────────────────────────────────
class DmtBeneficiaryDashboard extends StatefulWidget {
  final String remitterPhone;

  const DmtBeneficiaryDashboard({required this.remitterPhone, super.key});

  @override
  State<DmtBeneficiaryDashboard> createState() => DmtBeneficiaryDashboardState();
}

class DmtBeneficiaryDashboardState extends State<DmtBeneficiaryDashboard> {
  static const int _maxBeneficiaries = 3;
  double _ppiBalance = 0.0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadPpiBalance();
    // Load beneficiaries after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<BeneficiaryProvider>().loadBeneficiaries();
      }
    });
  }

  Future<void> _loadPpiBalance() async {
    try {
      final walletProvider = context.read<WalletProvider>();
      // Ensure wallet data is fetched
      if (walletProvider.mainWallet == null && !walletProvider.isLoading) {
        await walletProvider.fetchAllWalletData();
      }
      if (mounted) {
        setState(() {
          _ppiBalance = walletProvider.mainWallet?.balance ?? 0.0;
          _loadingBalance = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBalance = false);
      }
    }
  }

  void _openAdd() {
    Navigator.push(
      context,
      _slide(
        _AddBeneficiaryPage(
          phone: widget.remitterPhone,
          onSave: () => context.read<BeneficiaryProvider>().loadBeneficiaries(),
        ),
      ),
    );
  }

  void _openEdit(Beneficiary beneficiary) {
    Navigator.push(
      context,
      _slide(
        _AddBeneficiaryPage(
          phone: widget.remitterPhone,
          existing: beneficiary,
          onSave: () => context.read<BeneficiaryProvider>().loadBeneficiaries(),
        ),
      ),
    );
  }

  void _openTransfer(Beneficiary beneficiary) {
    Navigator.push(
      context,
      _slide(
        DmtTransferPage(
          beneficiary: beneficiary,
          ppiBalance: _ppiBalance,
        ),
      ),
    );
  }

  void _confirmDelete(Beneficiary beneficiary) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Beneficiary', style: TextStyle(color: _textPrim)),
        content: Text(
          'Remove ${beneficiary.name}?',
          style: const TextStyle(color: _textSec),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: _textSec)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // ✅ FIXED: Convert int? to String
              final id = beneficiary.id?.toString() ?? '';
              if (id.isNotEmpty) {
                await context.read<BeneficiaryProvider>().deleteBeneficiary(id);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BeneficiaryProvider>(
      builder: (context, provider, child) {
        final beneficiaries = provider.beneficiaries;
        final bool canAdd = beneficiaries.length < _maxBeneficiaries;

        return Scaffold(
          backgroundColor: _bg,
          appBar: _darkAppBar('Beneficiaries'),
          body: Column(
            children: [
              // Header strip (shows remitter phone + optional balance indicator)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android_rounded, color: _blue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      '+91 ${widget.remitterPhone}',
                      style: const TextStyle(
                        color: _textPrim,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    // Show PPI balance chip
                    if (!_loadingBalance)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance_wallet_rounded,
                                color: _green, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '₹${_ppiBalance.toStringAsFixed(2)}',
                              style: const TextStyle(color: _green, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _blue.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${beneficiaries.length}/$_maxBeneficiaries accounts',
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Beneficiary list or empty state
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator(color: _blue))
                    : beneficiaries.isEmpty
                        ? _emptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: beneficiaries.length,
                            itemBuilder: (_, i) => _BeneficiaryCard(
                              beneficiary: beneficiaries[i],
                              onTap: () => _openTransfer(beneficiaries[i]),
                              onEdit: () => _openEdit(beneficiaries[i]),
                              onDelete: () => _confirmDelete(beneficiaries[i]),
                            ),
                          ),
              ),

              // Add button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: _primaryButton(
                  label: canAdd ? 'Add Beneficiary' : 'Maximum 3 accounts reached',
                  color: canAdd ? _blue : _textSec,
                  icon: canAdd ? Icons.add_rounded : Icons.block_rounded,
                  onTap: canAdd ? _openAdd : null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_rounded,
                size: 56, color: _textSec.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No beneficiaries added',
                style: TextStyle(color: _textSec, fontSize: 15)),
            const SizedBox(height: 6),
            const Text('Tap "Add Beneficiary" to get started',
                style: TextStyle(color: _textSec, fontSize: 12)),
          ],
        ),
      );
}
// ─────────────────────────────────────────────────────────────────────────────
// Beneficiary Card – updated to use Beneficiary model fields
// ─────────────────────────────────────────────────────────────────────────────
// _BeneficiaryCard - Fixed version with null safety
class _BeneficiaryCard extends StatelessWidget {
  final Beneficiary beneficiary;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BeneficiaryCard({
    required this.beneficiary,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _blue.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      beneficiary.name.isNotEmpty ? beneficiary.name[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: _blue,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        beneficiary.name,
                        style: const TextStyle(
                          color: _textPrim,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // ✅ FIX: Handle null bankName
                      Text(
                        beneficiary.bankName ?? 'Unknown Bank',
                        style: const TextStyle(color: _textSec, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, color: _textSec, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _chip(Icons.account_balance_rounded, beneficiary.accountNumber),
                const SizedBox(width: 8),
                _chip(Icons.code_rounded, beneficiary.ifsc),
                const Spacer(),
                // ✅ FIX: Handle null stateName
                _chip(
                  Icons.location_on_rounded,
                  beneficiary.stateName ?? beneficiary.stateCode ?? 'Unknown',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.arrow_forward_rounded, color: _blue, size: 14),
                const SizedBox(width: 4),
                const Text(
                  'Tap to transfer',
                  style: TextStyle(color: _blue, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _textSec),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(color: _textSec, fontSize: 11),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Beneficiary Page – now uses API for banks, purposes, states
// ─────────────────────────────────────────────────────────────────────────────
class _AddBeneficiaryPage extends StatefulWidget {
  final String phone;
  final Beneficiary? existing;
  final VoidCallback onSave;

  const _AddBeneficiaryPage({
    required this.phone,
    this.existing,
    required this.onSave,
  });

  @override
  State<_AddBeneficiaryPage> createState() => _AddBeneficiaryPageState();
}

class _AddBeneficiaryPageState extends State<_AddBeneficiaryPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _accCtrl;
  late final TextEditingController _ifscCtrl;
  late final TextEditingController _mobileCtrl;
  String? _selectedBankCode;
  String? _selectedPurposeCode;
  String? _selectedStateCode;

  String _selectedPaymentMode = 'IMPS';
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _accCtrl = TextEditingController(text: e?.accountNumber ?? '');
    _ifscCtrl = TextEditingController(text: e?.ifsc ?? '');
    _mobileCtrl = TextEditingController(text: e?.mobile ?? '');
    _selectedBankCode = e?.bankCode;
    // _selectedPurposeCode = e?.purposeCode;
    _selectedStateCode = e?.stateCode;
    _selectedPaymentMode = e?.paymentMode ?? 'IMPS';

    // Load master data if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PayoutProvider>();
      if (provider.banks.isEmpty && !provider.isLoading) {
        provider.loadMasterData();
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _accCtrl.dispose();
    _ifscCtrl.dispose();
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    print('_selectedBankCode: $_selectedBankCode');
    print('_selectedPurposeCode: $_selectedPurposeCode');
    print('_selectedStateCode: $_selectedStateCode');
    print('_mobileCtrl: ${_mobileCtrl.text}');
    
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBankCode == null) {
      _showSnack('Please select a bank');
      return;
    }
    if (_selectedPurposeCode == null) {
      _showSnack('Please select a purpose');
      return;
    }
    if (_selectedStateCode == null) {
      _showSnack('Please select a state');
      return;
    }
    setState(() => _loading = true);

    try {
      final beneficiary = Beneficiary(
        id: widget.existing?.id,
        name: _nameCtrl.text.trim(),
        accountNumber: _accCtrl.text.trim(),
        ifsc: _ifscCtrl.text.trim().toUpperCase(),
        mobile: _mobileCtrl.text.trim(),
        bankCode: _selectedBankCode!,
        bankName: context.read<PayoutProvider>().getBankName(_selectedBankCode!) ?? 'Unknown Bank',
        // purposeCode: _selectedPurposeCode!,
        // purposeDesc: context.read<PayoutProvider>().getPurposeName(_selectedPurposeCode!) ?? '',
        stateCode: _selectedStateCode!,
        stateName: context.read<PayoutProvider>().getStateName(_selectedStateCode!) ?? '',
        paymentMode: _selectedPaymentMode,
      );

      if (_isEdit) {
        // For edit, we need update method in provider
        await context.read<BeneficiaryProvider>().updateBeneficiary(beneficiary);
      } else {
        await context.read<BeneficiaryProvider>().addBeneficiary(beneficiary);
      }
      widget.onSave();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _darkAppBar(_isEdit ? 'Edit Beneficiary' : 'Add Beneficiary'),
      body: Consumer<PayoutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.banks.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: _blue));
          }
          if (provider.errorMessage.isNotEmpty) {
            return Center(child: Text('Error: ${provider.errorMessage}'));
          }

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Account Details'),
                  const SizedBox(height: 12),
                  _label('Account Holder Name *'),
                  const SizedBox(height: 8),
                  _validatedField(_nameCtrl, 'Full name', validator: _notEmpty),
                  const SizedBox(height: 16),
                  _label('Account Number *'),
                  const SizedBox(height: 8),
                  _validatedField(
                    _accCtrl,
                    'Enter account number',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => (v == null || v.length < 9) ? 'Enter valid account number' : null,
                  ),
                  const SizedBox(height: 16),
                  _label('IFSC Code *'),
                  const SizedBox(height: 8),
                  _validatedField(
                    _ifscCtrl,
                    'e.g. SBIN0001234',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: (v) => (v == null || v.length != 11) ? 'IFSC must be 11 characters' : null,
                  ),
                  const SizedBox(height: 16),
                  _label('Mobile Number *'),
                  const SizedBox(height: 8),
                  _validatedField(
                    _mobileCtrl,
                    '10-digit mobile number',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10)
                    ],
                    validator: (v) => (v == null || v.length != 10) ? 'Enter 10 digits' : null,
                  ),
                  const SizedBox(height: 16),

                  _label('Bank *'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedBankCode,
                    decoration: _inputDecoration('Select bank', prefix: null),
                    dropdownColor: _surface,
                    style: const TextStyle(color: _textPrim, fontSize: 14),
                    items: provider.banks.map<DropdownMenuItem<String>>((bank) {
                      return DropdownMenuItem<String>(
                        value: bank['code'] as String?,
                        child: Text(bank['description'] as String? ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedBankCode = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _label('Payment Purpose *'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedPurposeCode,
                    decoration: _inputDecoration('Select purpose', prefix: null),
                    dropdownColor: _surface,
                    style: const TextStyle(color: _textPrim, fontSize: 14),
                    items: provider.purposes.map<DropdownMenuItem<String>>((purpose) {
                      return DropdownMenuItem<String>(
                        value: purpose['code'] as String?,
                        child: Text(purpose['description'] as String? ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedPurposeCode = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _label('State *'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedStateCode,
                    decoration: _inputDecoration('Select state', prefix: null),
                    dropdownColor: _surface,
                    style: const TextStyle(color: _textPrim, fontSize: 14),
                    items: provider.states.map<DropdownMenuItem<String>>((state) {
                      return DropdownMenuItem<String>(
                        value: state['code'] as String?,
                        child: Text(state['description'] as String? ?? ''),
                      );
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedStateCode = v),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  _label('Payment Mode'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _modeChip('IMPS', Icons.bolt_rounded, _selectedPaymentMode, (v) => setState(() => _selectedPaymentMode = v)),
                      const SizedBox(width: 12),
                      _modeChip('NEFT', Icons.account_balance_rounded, _selectedPaymentMode, (v) => setState(() => _selectedPaymentMode = v)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _primaryButton(
                    label: _isEdit ? 'Save Changes' : 'Add Beneficiary',
                    loading: _loading,
                    color: _blue,
                    onTap: _save,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _notEmpty(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  
  Widget _validatedField(
    TextEditingController ctrl,
    String hint, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: _textPrim, fontSize: 14),
      decoration: _inputDecoration(hint),
    );
  }

  Widget _modeChip(String label, IconData icon, String current, Function(String) onSelected) {
    final selected = current == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => onSelected(label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _blue.withOpacity(0.15) : _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _blue : _border, width: selected ? 1.5 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? _blue : _textSec, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _blue : _textSec,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transfer page – now calls initiatePayout with real API
// ─────────────────────────────────────────────────────────────────────────────
class DmtTransferPage extends StatefulWidget {
  final Beneficiary beneficiary;
  final double ppiBalance;

  const DmtTransferPage({
    required this.beneficiary,
    required this.ppiBalance,
    super.key,
  });

  @override
  State<DmtTransferPage> createState() => DmtTransferPageState();
}

class DmtTransferPageState extends State<DmtTransferPage> {
  final _amountCtrl = TextEditingController();
  final _tpinCtrl = TextEditingController();
  bool _obscureTpin = true;
  String _mode = 'IMPS';
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _tpinCtrl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (_amountCtrl.text.isEmpty) {
      _showSnack('Enter amount');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _showSnack('Invalid amount');
      return;
    }
    if (amount < 100) {
      _showSnack('Minimum DMT amount is ₹100');
      return;
    }
    if (amount > 50000) {
      _showSnack('Maximum per transaction is ₹50,000');
      return;
    }
    if (_tpinCtrl.text.length < 4) {
      _showSnack('Enter 4-digit TPIN');
      return;
    }

    final ppiBalance = widget.ppiBalance;

    if (ppiBalance <= 0) {
      _showSnack('PPI wallet is empty. Please add funds first.');
      return;
    }
    if (amount > ppiBalance) {
      _showSnack('Insufficient balance. Available: ₹${ppiBalance.toStringAsFixed(2)}');
      return;
    }

    setState(() => _loading = true);
    try {
      final payoutProvider = context.read<PayoutProvider>();
      final beneficiary = widget.beneficiary;

      // Get userId from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Build DMT payout request matching backend format
      final payoutRequest = {
        'userId': int.parse(userId),
        'amount': amount,
        'mode': _mode,
        'tpin': _tpinCtrl.text.trim(),
        'ip_address': '192.168.1.1',
        'fee': 3,
        'lat': '28.7041',
        'long': '77.1025',
        // Note: Backend gets bank details from agent_bank_accounts table
        // The beneficiary is just for display, backend uses user's own bank
      };

      print('📤 Sending DMT payout request: $payoutRequest');

      final response = await payoutProvider.initiatePayout(payoutRequest);

      if (response['success'] == true) {
        final merchantRefId = response['transactionId'] ?? 
                             response['data']?['merchantRefId'] ?? 
                             response['merchantRefId'];

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PayoutStatusScreen(
                merchantRefId: merchantRefId?.toString() ?? '',
              ),
            ),
          );
        }
      } else {
        _showSnack(response['message'] ?? 'DMT transfer failed');
      }
    } catch (e) {
      print('❌ DMT error: $e');
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? _green : Colors.redAccent,
    ));
  }

  Widget _modeChip(String label, IconData icon) {
    final selected = _mode == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _blue.withOpacity(0.15) : _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _blue : _border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? _blue : _textSec, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _blue : _textSec,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.beneficiary;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _darkAppBar('PPI DMT Transfer'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Beneficiary summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: _blue,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b.name,
                          style: const TextStyle(
                            color: _textPrim,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${b.bankName} • ${b.accountNumber}',
                          style: const TextStyle(color: _textSec, fontSize: 12),
                        ),
                        Text(
                          'IFSC: ${b.ifsc} • ${b.stateName}',
                          style: const TextStyle(color: _textSec, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // PPI Balance Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _green.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: _green, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'PPI Wallet Balance',
                    style: TextStyle(color: _textSec, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '₹${widget.ppiBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _label('Transfer Mode'),
            const SizedBox(height: 10),
            Row(
              children: [
                _modeChip('IMPS', Icons.bolt_rounded),
                const SizedBox(width: 12),
                _modeChip('NEFT', Icons.account_balance_rounded),
              ],
            ),
            const SizedBox(height: 20),

            _label('Amount'),
            const SizedBox(height: 8),
            _inputField(
              controller: _amountCtrl,
              hint: 'Enter amount (Min ₹100)',
              prefix: '₹',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 20),

            _label('Transaction PIN (TPIN)'),
            const SizedBox(height: 8),
            _inputField(
              controller: _tpinCtrl,
              hint: '6-digit TPIN',
              obscure: _obscureTpin,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffix: IconButton(
                icon: Icon(
                  _obscureTpin
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _textSec,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureTpin = !_obscureTpin),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _outlineButton(
                    label: 'Cancel',
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _primaryButton(
                    label: 'Proceed',
                    loading: _loading,
                    color: _blue,
                    onTap: _proceed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// All shared UI helpers remain exactly the same as your original file
// ─────────────────────────────────────────────────────────────────────────────
// (Copy _darkAppBar, _label, _sectionHeader, _infoCard, _inputDecoration,
//  _inputField, _primaryButton, _outlineButton, _slide from your original file)
// ... (keep them unchanged)

// ─────────────────────────────────────────────────────────────────────────────
// Shared UI helpers
// ─────────────────────────────────────────────────────────────────────────────
AppBar _darkAppBar(String title) => AppBar(
  backgroundColor: _surface,
  elevation: 0,
  centerTitle: true,
  title: Text(title,
      style: const TextStyle(color: _textPrim, fontSize: 16,
          fontWeight: FontWeight.w600)),
  iconTheme: const IconThemeData(color: _textPrim),
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(1),
    child: Container(height: 1, color: _border),
  ),
);

Widget _label(String text) => Text(text,
    style: const TextStyle(color: _textSec, fontSize: 12,
        fontWeight: FontWeight.w500, letterSpacing: 0.5));

Widget _sectionHeader(String text) => Row(
  children: [
    Container(width: 3, height: 16,
        decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(text, style: const TextStyle(color: _textPrim, fontSize: 14,
        fontWeight: FontWeight.w600)),
  ],
);

Widget _infoCard({
  required IconData icon, required Color color,
  required String title, required String subtitle,
}) => Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: color.withOpacity(0.08),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: color.withOpacity(0.2)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 13,
                fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: _textSec, fontSize: 12,
                height: 1.4)),
          ],
        ),
      ),
    ],
  ),
);

InputDecoration _inputDecoration(String hint, {
  String? prefix, Widget? suffix,
}) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(color: _textSec, fontSize: 14),
  prefixText: prefix,
  prefixStyle: const TextStyle(color: _textSec, fontSize: 14),
  suffixIcon: suffix,
  filled: true,
  fillColor: _surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _border),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _border),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: _blue, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.redAccent),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
  ),
  counterText: '',
);

Widget _inputField({
  required TextEditingController controller,
  required String hint,
  String? prefix,
  Widget? suffix,
  bool obscure = false,
  int? maxLength,
  TextInputType? keyboardType,
  List<TextInputFormatter>? inputFormatters,
}) => TextField(
  controller: controller,
  obscureText: obscure,
  maxLength: maxLength,
  keyboardType: keyboardType,
  inputFormatters: inputFormatters,
  style: const TextStyle(color: _textPrim, fontSize: 14),
  decoration: _inputDecoration(hint, prefix: prefix, suffix: suffix),
);

Widget _primaryButton({
  required String label,
  required VoidCallback? onTap,
  required Color color,
  bool loading = false,
  IconData? icon,
}) => SizedBox(
  width: double.infinity,
  child: GestureDetector(
    onTap: loading ? null : onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        color: onTap == null ? _textSec.withOpacity(0.2) : color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: onTap == null ? _textSec.withOpacity(0.3) : color.withOpacity(0.5),
        ),
      ),
      child: Center(
        child: loading
            ? SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2, color: color))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: onTap == null ? _textSec : color, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: TextStyle(
                        color: onTap == null ? _textSec : color,
                        fontSize: 15, fontWeight: FontWeight.w600,
                      )),
                ],
              ),
      ),
    ),
  ),
);

Widget _outlineButton({required String label, required VoidCallback onTap}) =>
    SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Center(
            child: Text(label,
                style: const TextStyle(color: _textSec, fontSize: 15,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );

PageRoute _slide(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
  transitionDuration: const Duration(milliseconds: 300),
);

