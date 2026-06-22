// ─────────────────────────────────────────────────────────────────────────────
// aeps_wallet_dialog.dart – fully integrated with backend payout APIs
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'package:my_app/providers/beneficiary_provider.dart';
import 'package:my_app/providers/payout_provider.dart';
import 'package:my_app/models/beneficiary_model.dart';
import 'package:my_app/providers/wallet_provider.dart';
import 'package:my_app/screens/payout/payout_status_screen.dart';

// Import your providers and models (adjust paths as needed)
// import '../../providers/payout_provider.dart';     // if file is at lib/providers/
// import '../../providers/beneficiary_provider.dart';
// import '../../models/beneficiary_model.dart';         // your Beneficiary class


// import '../../models/payout_request.dart';             // if needed for request

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
// Entry point – call this on AEPS wallet card tap
// ─────────────────────────────────────────────────────────────────────────────
void showAepsWalletOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: _surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AepsOptionsSheet(),
  );
}

// ... (keep _AepsOptionsSheet and _OptionTile exactly as they were, unchanged) ...
// (omitted for brevity – copy from your original file)


class _AepsOptionsSheet extends StatelessWidget {
  const _AepsOptionsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _border, borderRadius: BorderRadius.circular(2)),
          ),
          const Text('AEPS Wallet',
              style: TextStyle(color: _textPrim, fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Choose an action',
              style: TextStyle(color: _textSec, fontSize: 13)),
          const SizedBox(height: 24),
          _OptionTile(
            icon: Icons.account_balance_wallet_rounded,
            color: _green,
            title: 'Move to Main Wallet',
            subtitle: 'Transfer balance to your main wallet',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, _slide(const MoveToMainWalletPage()));
            },
          ),
          const SizedBox(height: 12),
          _OptionTile(
            icon: Icons.send_rounded,
            color: _blue,
            title: 'Move Fund',
            subtitle: 'Transfer to a beneficiary account',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, _slide(const MoveFundPage()));
            },
          ),
          const SizedBox(height: 12),
          _OptionTile(
            icon: Icons.credit_card_rounded,
            color: const Color(0xFF8B5CF6),
            title: 'Move to CC Fund',
            subtitle: 'Coming soon',
            enabled: false,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;

  const _OptionTile({
    required this.icon, required this.color, required this.title,
    required this.subtitle, required this.onTap, this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(color: _textPrim,
                            fontSize: 15, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: _textSec, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _textSec),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Move to Main Wallet – you can integrate later; keep as is
// ─────────────────────────────────────────────────────────────────────────────
class MoveToMainWalletPage extends StatefulWidget {
  const MoveToMainWalletPage({super.key});
  @override State<MoveToMainWalletPage> createState() => _MoveToMainWalletPageState();
}

class _MoveToMainWalletPageState extends State<MoveToMainWalletPage> {
  final _amountCtrl = TextEditingController();
  final _tpinCtrl   = TextEditingController();
  bool _obscureTpin = true;
  bool _loading     = false;

  @override
  void dispose() {
    _amountCtrl.dispose(); _tpinCtrl.dispose(); super.dispose();
  }

  Future<void> _submit() async {
    if (_amountCtrl.text.isEmpty || _tpinCtrl.text.length < 4) {
      _showSnack('Please enter amount and 4-digit TPIN');
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2)); // replace with API call
    setState(() => _loading = false);
    if (mounted) {
      _showSnack('Transfer successful!', success: true);
      Navigator.pop(context);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? _green : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _darkAppBar('Move to Main Wallet'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(
              icon: Icons.account_balance_wallet_rounded,
              color: _green,
              title: 'Transfer to Main Wallet',
              subtitle: 'Funds will be moved from AEPS wallet to your main wallet instantly.',
            ),
            const SizedBox(height: 28),
            _label('Amount'),
            const SizedBox(height: 8),
            _inputField(
              controller: _amountCtrl,
              hint: 'Enter amount',
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
                  _obscureTpin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: _textSec, size: 20,
                ),
                onPressed: () => setState(() => _obscureTpin = !_obscureTpin),
              ),
            ),
            const SizedBox(height: 32),
            _primaryButton(
              label: 'Transfer Now',
              loading: _loading,
              color: _green,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}// ... keep original code ...

// ─────────────────────────────────────────────────────────────────────────────
// 2. Move Fund — phone entry
// ─────────────────────────────────────────────────────────────────────────────
class MoveFundPage extends StatefulWidget {
  const MoveFundPage({super.key});
  @override State<MoveFundPage> createState() => _MoveFundPageState();
}

class _MoveFundPageState extends State<MoveFundPage> {
  final _phoneCtrl = TextEditingController();
  double _aepsBalance = 0;
  bool _loadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance(); // add import
      final userId = prefs.getString('userId');
      if (userId != null) {
        final walletProvider = context.read<WalletProvider>();
        if (walletProvider.aepsWallet == null) {
          walletProvider.setUserId(userId); // triggers fetch
          // wait for it
          await Future.doWhile(() async {
            await Future.delayed(const Duration(milliseconds: 200));
            return walletProvider.isLoading;
          });
        }
        setState(() {
          _aepsBalance = walletProvider.aepsWallet?.balance ?? 0;
          _loadingBalance = false;
        });
      }
    } catch (e) {
      setState(() => _loadingBalance = false);
    }
  }

  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  void _proceed() {
    if (_phoneCtrl.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter a valid 10-digit mobile number'),
        backgroundColor: Colors.redAccent,
      ));
      return;
    }

    
    Navigator.push(context, _slide(
      _BeneficiaryDashboard(
        phone: _phoneCtrl.text.trim(),
        aepsBalance: _aepsBalance,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _darkAppBar('Move Fund'),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(
              icon: Icons.send_rounded,
              color: _blue,
              title: 'Fund Transfer',
              subtitle: 'Transfer to a beneficiary account.',
            ),
            const SizedBox(height: 16),

            // Balance display
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
                  const Text('AEPS Balance',
                      style: TextStyle(color: _textSec, fontSize: 13)),
                  const Spacer(),
                  _loadingBalance
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: _green))
                      : Text(
                          '₹${_aepsBalance.toStringAsFixed(2)}',
                          style: const TextStyle(color: _green, fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            _label('Mobile Number'),
            const SizedBox(height: 8),
            _inputField(
              controller: _phoneCtrl,
              hint: 'Enter 10-digit mobile number',
              prefix: '+91 ',
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 32),
            _primaryButton(
              label: 'Proceed',
              color: _blue,
              onTap: _loadingBalance ? null : _proceed,
            ),
          ],
        ),
      ),
    );
  }
}// ... keep original code ...

// ─────────────────────────────────────────────────────────────────────────────
// Beneficiary Dashboard – now uses BeneficiaryProvider
// ─────────────────────────────────────────────────────────────────────────────
class _BeneficiaryDashboard extends StatefulWidget {
  final String phone;
  final double aepsBalance;

  const _BeneficiaryDashboard({required this.phone, required this.aepsBalance});
  
  @override
  State<_BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<_BeneficiaryDashboard> {
  static const int _maxBeneficiaries = 3;

  @override
  void initState() {
    super.initState();
    // Load beneficiaries from local storage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<BeneficiaryProvider>().loadBeneficiaries();
        } catch (e) {
          print('Error loading beneficiaries: $e');
        }
      }
    });
  }

  void _openAdd() {
    Navigator.push(
      context, 
      _slide(
        _AddBeneficiaryPage(
          phone: widget.phone,
          onSave: () => context.read<BeneficiaryProvider>().loadBeneficiaries(),
        )
      )
    );
  }

  void _openEdit(Beneficiary beneficiary) {
    Navigator.push(
      context, 
      _slide(
        _AddBeneficiaryPage(
          phone: widget.phone,
          existing: beneficiary,
          onSave: () => context.read<BeneficiaryProvider>().loadBeneficiaries(),
        )
      )
    );
  }

  void _openTransfer(Beneficiary beneficiary) {
    Navigator.push(
      context, 
      _slide(
        _TransferPage(
          beneficiary: beneficiary, 
          aepsBalance: widget.aepsBalance,
        )
      )
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
              await context.read<BeneficiaryProvider>().deleteBeneficiary(
                beneficiary.id?.toString() ?? ''
              );
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
              // Header strip
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
                      '+91 ${widget.phone}',
                      style: const TextStyle(
                        color: _textPrim,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
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

// Add this button to view the last transaction
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PayoutStatusScreen(
          merchantRefId: '17821251429405351', // ✅ Use the actual merchant_ref_id
        ),
      ),
    );
  },
  child: const Text('View Last Transaction'),
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
        Icon(
          Icons.account_balance_rounded,
          size: 56, 
          color: _textSec.withOpacity(0.3)
        ),
        const SizedBox(height: 16),
        const Text(
          'No beneficiaries added',
          style: TextStyle(color: _textSec, fontSize: 15),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap "Add Beneficiary" to get started',
          style: TextStyle(color: _textSec, fontSize: 12),
        ),
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
                      Text(
                        beneficiary.bankName.isNotEmpty ? beneficiary.bankName : 'Unknown Bank',
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
                _chip(
                  Icons.location_on_rounded,
                  beneficiary.stateName.isNotEmpty ? beneficiary.stateName : 'Unknown',
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
// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Beneficiary Page – with OTP Flow
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Beneficiary Page – No OTP Flow
// ─────────────────────────────────────────────────────────────────────────────
// In aeps_wallet_dialog.dart - Updated _AddBeneficiaryPage

// In aeps_wallet_dialog.dart - Complete _AddBeneficiaryPage

// In aeps_wallet_dialog.dart - Complete _AddBeneficiaryPage

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
  final _nameCtrl = TextEditingController();
  final _accCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  
  String? _selectedBankCode;
  String? _selectedStateCode;
  String _selectedPaymentMode = 'IMPS';
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e.name;
      _accCtrl.text = e.accountNumber;
      _ifscCtrl.text = e.ifsc;
      _mobileCtrl.text = e.mobile;
      _selectedBankCode = e.bankCode;
      _selectedStateCode = e.stateCode;
      _selectedPaymentMode = e.paymentMode;
    }
    
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

  Future<void> _saveBeneficiary() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBankCode == null) {
      _showSnack('Please select a bank');
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
        stateCode: _selectedStateCode!,
        stateName: context.read<PayoutProvider>().getStateName(_selectedStateCode!) ?? '',
        paymentMode: _selectedPaymentMode,
      );

      await context.read<BeneficiaryProvider>().addBeneficiary(beneficiary);
      
      widget.onSave();
      if (mounted) {
        _showSnack('Beneficiary added successfully!', isSuccess: true);
        Navigator.pop(context);
      }
      
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isSuccess ? Colors.green : Colors.redAccent,
    ));
  }

  String? _notEmpty(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  
  Widget _validatedField(TextEditingController ctrl, String hint, {
    String? Function(String?)? validator, 
    TextInputType? keyboardType, 
    List<TextInputFormatter>? inputFormatters
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
                  fontSize: 14
                )
              ),
            ],
          ),
        ),
      ),
    );
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
                    validator: (v) => (v == null || v.length < 9) ? 'Enter valid account number' : null
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
                    validator: (v) => (v == null || v.length != 11) ? 'IFSC must be 11 characters' : null
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
                    validator: (v) => (v == null || v.length != 10) ? 'Enter 10 digits' : null
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
                    label: _isEdit ? 'Update Beneficiary' : 'Add Beneficiary',
                    loading: _loading,
                    color: _blue,
                    onTap: _saveBeneficiary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Transfer page – now calls initiatePayout with real API
// ─────────────────────────────────────────────────────────────────────────────
class _TransferPage extends StatefulWidget {
  final Beneficiary beneficiary;
  final double aepsBalance;

  const _TransferPage({required this.beneficiary, required this.aepsBalance});
  
  @override
  State<_TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<_TransferPage> {
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
    // Validate Amount
    if (_amountCtrl.text.isEmpty) {
      _showSnack('Please enter amount');
      return;
    }
    
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _showSnack('Please enter a valid amount');
      return;
    }
    if (amount < 100) {
      _showSnack('Minimum payout amount is ₹100');
      return;
    }
    if (amount > 50000) {
      _showSnack('Maximum per transaction is ₹50,000');
      return;
    }

    // ✅ Validate 6-digit TPIN
    final tpin = _tpinCtrl.text.trim();
    if (tpin.length != 6) {
      _showSnack('Please enter a 6-digit TPIN');
      return;
    }

    // Check AEPS Balance
    final aepsBalance = widget.aepsBalance;
    if (aepsBalance <= 0) {
      _showSnack('AEPS wallet is empty. Please add funds first.');
      return;
    }
    if (amount > aepsBalance) {
      _showSnack('Insufficient balance. Available: ₹${aepsBalance.toStringAsFixed(2)}');
      return;
    }

    setState(() => _loading = true);
    
   try {
    final payoutProvider = context.read<PayoutProvider>();
    
    final payoutRequest = {
      'amount': amount,
      'mode': _mode,
      'tpin': tpin,
      'ip_address': '192.168.1.1',
      'fee': 3,
      'lat': '28.7041',
      'long': '77.1025',
    };

    print('📤 Sending payout request: $payoutRequest');

    final response = await payoutProvider.initiatePayout(payoutRequest);

    if (response['success'] == true) {
      // ✅ FIX: Use the correct merchant_ref_id from response
      // The backend returns merchantRefId in the response
      final merchantRefId = response['merchantRefId'] ?? 
                           response['data']?['merchantRefId'] ?? 
                           response['data']?['merchant_ref_id'] ?? 
                           response['transactionId']?.toString();

      print('✅ Merchant Ref ID: $merchantRefId');

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
      _showSnack(response['message'] ?? 'Payout failed');
    }
  } catch (e) {
    print('❌ Payout error: $e');
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
      appBar: _darkAppBar('Fund Transfer'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Beneficiary Details Card (Shows all details)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person, color: _blue, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Beneficiary Details',
                        style: TextStyle(
                          color: _textPrim,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: _border, height: 16),
                  Row(
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${b.bankName} • ${b.accountNumber}',
                              style: const TextStyle(color: _textSec, fontSize: 13),
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
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // ✅ AEPS Balance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _green.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: _green, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'AEPS Balance',
                    style: TextStyle(color: _textSec, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    '₹${widget.aepsBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _green,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // ✅ Transfer Mode
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
            
            // ✅ Amount
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
            
            // ✅ TPIN (6-digit)
            _label('Transaction PIN (TPIN)'),
            const SizedBox(height: 8),
            _inputField(
              controller: _tpinCtrl,
              hint: 'Enter 6-digit TPIN',
              obscure: _obscureTpin,
              maxLength: 6,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              suffix: IconButton(
                icon: Icon(
                  _obscureTpin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: _textSec,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureTpin = !_obscureTpin),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // ✅ Buttons
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
                  flex: 2,
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

