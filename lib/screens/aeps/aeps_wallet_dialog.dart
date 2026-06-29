// lib/screens/aeps/aeps_wallet_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/providers/beneficiary_provider.dart';
import 'package:my_app/providers/payout_provider.dart';
import 'package:my_app/models/beneficiary_model.dart';
import 'package:my_app/providers/wallet_provider.dart';
import 'package:my_app/screens/payout/payout_status_screen.dart';

// ─── Neofyn Theme Colors ──────────────────────────────────
const Color _bg = Color(0xFF0A0E0A);
const Color _surface = Color(0xFF141914);
const Color _card = Color(0xFF1A1F1A);
const Color _primary = Color(0xFF008169);
const Color _primaryLight = Color(0xFF1AA88A);
const Color _primaryDark = Color(0xFF005F4E);
const Color _border = Color(0xFF2A2A2A);
const Color _textPrim = Colors.white;
const Color _textSec = Color(0xFF888888);
const Color _error = Color(0xFFEF4444);
const Color _success = Color(0xFF2ECC71);

// ─── Entry Point ─────────────────────────────────────────
void showAepsWalletOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: _card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AepsOptionsSheet(),
  );
}

// ─── Options Sheet ───────────────────────────────────────
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
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'AEPS Wallet',
            style: TextStyle(
              color: _textPrim,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose an action',
            style: TextStyle(color: _textPrim.withOpacity(0.5), fontSize: 13),
          ),
          const SizedBox(height: 24),
          _option(
            Icons.account_balance_wallet_rounded,
            _primary,
            'Move to Main Wallet',
            'Transfer balance to main wallet',
                () {
              Navigator.pop(context);
              Navigator.push(context, _slide(const MoveToMainWalletPage()));
            },
          ),
          const SizedBox(height: 12),
          _option(
            Icons.send_rounded,
            _primary,
            'Move Fund',
            'Transfer to beneficiary account',
                () {
              Navigator.pop(context);
              Navigator.push(context, _slide(const MoveFundPage()));
            },
          ),
          const SizedBox(height: 12),
          _option(
            Icons.credit_card_rounded,
            const Color(0xFF8B5CF6),
            'Move to CC Fund',
            'Coming soon',
                () {},
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _option(
      IconData icon,
      Color color,
      String title,
      String subtitle,
      VoidCallback onTap, {
        bool enabled = true,
      }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _textPrim,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: _textPrim.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: _textPrim.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 1. Move to Main Wallet ──────────────────────────────
class MoveToMainWalletPage extends StatefulWidget {
  const MoveToMainWalletPage({super.key});

  @override
  State<MoveToMainWalletPage> createState() => _MoveToMainWalletPageState();
}

class _MoveToMainWalletPageState extends State<MoveToMainWalletPage> {
  final _amountCtrl = TextEditingController();
  final _tpinCtrl = TextEditingController();
  bool _obscureTpin = true;
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _tpinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_amountCtrl.text.isEmpty || _tpinCtrl.text.length != 6) {
      _showSnack('Enter amount and 6-digit TPIN');
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _loading = false);
      _showSnack('Transfer successful!', success: true);
      Navigator.pop(context);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: success ? _success : _error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar('Move to Main Wallet'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(
              Icons.account_balance_wallet_rounded,
              _primary,
              'Transfer to Main Wallet',
              'Funds move instantly to your main wallet.',
            ),
            const SizedBox(height: 20),
            _input(
              'Amount',
              _amountCtrl,
              hint: 'Enter amount',
              prefix: '₹',
              kb: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 14),
            _input(
              'Transaction PIN (TPIN)',
              _tpinCtrl,
              hint: '6-digit TPIN',
              ob: _obscureTpin,
              max: 6,
              kb: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              suf: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _obscureTpin
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _textSec,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureTpin = !_obscureTpin),
              ),
            ),
            const SizedBox(height: 24),
            _btn('Transfer Now', _primary, _submit, loading: _loading),
          ],
        ),
      ),
    );
  }
}

// ─── 2. Move Fund – Phone Entry ─────────────────────────
class MoveFundPage extends StatefulWidget {
  const MoveFundPage({super.key});

  @override
  State<MoveFundPage> createState() => _MoveFundPageState();
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

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      if (userId != null) {
        final wp = context.read<WalletProvider>();
        if (wp.aepsWallet == null) {
          wp.setUserId(userId);
          await Future.doWhile(() async {
            await Future.delayed(const Duration(milliseconds: 200));
            return wp.isLoading;
          });
        }
        if (mounted)
          setState(() {
            _aepsBalance = wp.aepsWallet?.balance ?? 0;
            _loadingBalance = false;
          });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  void _proceed() {
    if (_phoneCtrl.text.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid 10-digit number'),
          backgroundColor: _error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      _slide(
        _BeneficiaryDashboard(
          phone: _phoneCtrl.text.trim(),
          aepsBalance: _aepsBalance,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar('Move Fund'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoCard(
              Icons.send_rounded,
              _primary,
              'Fund Transfer',
              'Transfer to a beneficiary account.',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: _primary,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AEPS Balance',
                    style: TextStyle(color: _textSec, fontSize: 12),
                  ),
                  const Spacer(),
                  _loadingBalance
                      ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _primary,
                    ),
                  )
                      : Text(
                    '₹${_aepsBalance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: _primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _input(
              'Mobile Number',
              _phoneCtrl,
              hint: '10-digit mobile',
              prefix: '+91 ',
              kb: TextInputType.phone,
              max: 10,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 24),
            _btn('Proceed', _primary, _loadingBalance ? () {} : _proceed),
          ],
        ),
      ),
    );
  }
}

// ─── Beneficiary Dashboard ──────────────────────────────
class _BeneficiaryDashboard extends StatefulWidget {
  final String phone;
  final double aepsBalance;

  const _BeneficiaryDashboard({required this.phone, required this.aepsBalance});

  @override
  State<_BeneficiaryDashboard> createState() => _BeneficiaryDashboardState();
}

class _BeneficiaryDashboardState extends State<_BeneficiaryDashboard> {
  static const int _max = 3;
  int? _selectedPrimaryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<BeneficiaryProvider>().loadBeneficiaries();
    });
  }

  void _add() => Navigator.push(
    context,
    _slide(
      _AddBeneficiaryPage(
        phone: widget.phone,
        onSave: () => context.read<BeneficiaryProvider>().loadBeneficiaries(),
      ),
    ),
  );

  void _edit(Beneficiary b) => Navigator.push(
    context,
    _slide(
      _AddBeneficiaryPage(
        phone: widget.phone,
        existing: b,
        onSave: () => context.read<BeneficiaryProvider>().loadBeneficiaries(),
      ),
    ),
  );

  void _transfer(Beneficiary b) => Navigator.push(
    context,
    _slide(_TransferPage(beneficiary: b, aepsBalance: widget.aepsBalance)),
  );

  void _delete(Beneficiary b) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Delete Beneficiary',
          style: TextStyle(color: _textPrim, fontSize: 16),
        ),
        content: Text(
          'Remove ${b.name}?',
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
                b.id?.toString() ?? '',
              );
            },
            child: const Text('Delete', style: TextStyle(color: _error)),
          ),
        ],
      ),
    );
  }

  Future<void> _setAsPrimary(Beneficiary beneficiary) async {
    if (beneficiary.isPrimary) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('This is already your primary account', style: TextStyle(fontSize: 12)),
          backgroundColor: _primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.star_rounded, color: _primary, size: 18),
            ),
            const SizedBox(width: 10),
            const Text('Set Primary Account', style: TextStyle(color: _textPrim, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Do you want to set this as your primary account?', style: TextStyle(color: _textSec, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(beneficiary.name, style: const TextStyle(color: _textPrim, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${beneficiary.bankName} • ${beneficiary.accountNumber}', style: TextStyle(color: _textPrim.withOpacity(0.4), fontSize: 11)),
                  const SizedBox(height: 2),
                  Text('IFSC: ${beneficiary.ifsc}', style: TextStyle(color: _textPrim.withOpacity(0.3), fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('This will be used as your default account for all payouts.', style: TextStyle(color: _textPrim.withOpacity(0.4), fontSize: 11, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _textSec))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Set as Primary', style: TextStyle(color: _primary, fontWeight: FontWeight.w600))),
        ],
      ),
    );

    if (confirm == true && beneficiary.id != null) {
      setState(() => _selectedPrimaryId = beneficiary.id);

      try {
        final success = await context.read<PayoutProvider>().setDefaultBankAccount(
          beneficiary.id.toString(),
        );

        if (success && mounted) {
          await context.read<BeneficiaryProvider>().loadBeneficiaries();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${beneficiary.name} set as primary account', style: const TextStyle(fontSize: 12)),
              backgroundColor: _success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.all(16),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to set primary account', style: TextStyle(fontSize: 12)),
              backgroundColor: _error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}', style: const TextStyle(fontSize: 12)),
            backgroundColor: _error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } finally {
        if (mounted) setState(() => _selectedPrimaryId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BeneficiaryProvider>(
      builder: (context, provider, _) {
        final list = provider.beneficiaries;
        return Scaffold(
          backgroundColor: _bg,
          appBar: _appBar('Beneficiaries'),
          body: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.phone_android_rounded,
                      color: _primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+91 ${widget.phone}',
                      style: const TextStyle(
                        color: _textPrim,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${list.length}/$_max',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: provider.isLoading
                    ? const Center(
                  child: CircularProgressIndicator(color: _primary),
                )
                    : list.isEmpty
                    ? _empty()
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _benCard(
                    list[i],
                    onTap: () => _transfer(list[i]),
                    onEdit: () => _edit(list[i]),
                    onDelete: () => _delete(list[i]),
                    onSetPrimary: () => _setAsPrimary(list[i]),
                    isLoading: _selectedPrimaryId == list[i].id,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                child: _btn(
                  list.length < _max ? 'Add Beneficiary' : 'Max 3 accounts',
                  list.length < _max ? _primary : _textSec,
                  list.length < _max ? _add : () {},
                  icon: list.length < _max
                      ? Icons.add_rounded
                      : Icons.block_rounded,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.account_balance_rounded,
          size: 48,
          color: _textPrim.withOpacity(0.15),
        ),
        const SizedBox(height: 12),
        const Text(
          'No beneficiaries',
          style: TextStyle(color: _textSec, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap below to add',
          style: TextStyle(color: _textPrim.withOpacity(0.3), fontSize: 11),
        ),
      ],
    ),
  );

  Widget _benCard(
      Beneficiary b, {
        required VoidCallback onTap,
        required VoidCallback onEdit,
        required VoidCallback onDelete,
        required VoidCallback onSetPrimary,
        bool isLoading = false,
      }) {
    final isPrimary = b.isPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isPrimary ? _primary.withOpacity(0.05) : _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? _primary.withOpacity(0.3) : Colors.white.withOpacity(0.04),
            width: isPrimary ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isPrimary ? _primary.withOpacity(0.2) : _primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                b.name[0].toUpperCase(),
                style: TextStyle(
                  color: isPrimary ? _primaryLight : _primary,
                  fontSize: 16, fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(b.name, style: const TextStyle(color: _textPrim, fontSize: 13, fontWeight: FontWeight.w500))),
                if (isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, color: _primary, size: 10),
                        SizedBox(width: 2),
                        Text('PRIMARY', style: TextStyle(color: _primary, fontSize: 8, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ]),
              Text('${b.bankName} • ${b.accountNumber}', style: TextStyle(color: _textPrim.withOpacity(0.35), fontSize: 10)),
            ]),
          ),
          isLoading
              ? const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _primary)),
          )
              : IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              isPrimary ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              color: isPrimary ? _primary : _textSec.withOpacity(0.5),
              size: 20,
            ),
            onPressed: onSetPrimary,
            tooltip: 'Set as primary account',
          ),
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.edit_rounded, color: _textSec, size: 16), onPressed: onEdit),
          IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.delete_rounded, color: _error, size: 16), onPressed: onDelete),
        ]),
      ),
    );
  }
}

// ─── Add/Edit Beneficiary Page ──────────────────────────
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
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _acc = TextEditingController(),
      _ifsc = TextEditingController(),
      _mobile = TextEditingController();
  String? _bank, _state;
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _name.text = e.name;
      _acc.text = e.accountNumber;
      _ifsc.text = e.ifsc;
      _mobile.text = e.mobile;
      _bank = e.bankCode;
      _state = e.stateCode;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<PayoutProvider>();
      if (p.banks.isEmpty && !p.isLoading) p.loadMasterData();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _acc.dispose();
    _ifsc.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_bank == null) {
      _snack('Select a bank');
      return;
    }
    if (_state == null) {
      _snack('Select a state');
      return;
    }
    setState(() => _loading = true);
    try {
      final b = Beneficiary(
        id: widget.existing?.id,
        name: _name.text.trim(),
        accountNumber: _acc.text.trim(),
        ifsc: _ifsc.text.trim().toUpperCase(),
        mobile: _mobile.text.trim(),
        bankCode: _bank!,
        bankName: context.read<PayoutProvider>().getBankName(_bank!) ?? '',
        stateCode: _state!,
        stateName: context.read<PayoutProvider>().getStateName(_state!) ?? '',
        paymentMode: 'NEFT', // Default payment mode
      );
      await context.read<BeneficiaryProvider>().addBeneficiary(b);
      widget.onSave();
      if (mounted) {
        _snack('Beneficiary saved!', ok: true);
        Navigator.pop(context);
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: ok ? _success : _error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(_isEdit ? 'Edit Beneficiary' : 'Add Beneficiary'),
      body: Consumer<PayoutProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.banks.isEmpty)
            return const Center(
              child: CircularProgressIndicator(color: _primary),
            );
          return Form(
            key: _form,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _input(
                    'Account Holder Name *',
                    _name,
                    hint: 'Full name',
                    v: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Account Number *',
                    _acc,
                    hint: 'Enter account number',
                    kb: TextInputType.number,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    v: (v) => v == null || v.length < 9 ? 'Min 9 digits' : null,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'IFSC Code *',
                    _ifsc,
                    hint: 'e.g. SBIN0001234',
                    formatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(11),
                    ],
                    v: (v) => v == null || v.length != 11
                        ? '11 chars required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _input(
                    'Mobile Number *',
                    _mobile,
                    hint: '10-digit number',
                    kb: TextInputType.phone,
                    max: 10,
                    formatters: [FilteringTextInputFormatter.digitsOnly],
                    v: (v) => v == null || v.length != 10
                        ? '10 digits required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _dropdown(
                    context,
                    'Bank *',
                    _bank,
                    provider.banks
                        .map(
                          (b) => DropdownMenuItem(
                        value: b['code']?.toString(),
                        child: Text(
                          b['description']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList(),
                        (v) => setState(() => _bank = v),
                  ),
                  const SizedBox(height: 14),
                  _dropdown(
                    context,
                    'State *',
                    _state,
                    provider.states
                        .map(
                          (s) => DropdownMenuItem(
                        value: s['code']?.toString(),
                        child: Text(
                          s['description']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList(),
                        (v) => setState(() => _state = v),
                  ),
                  const SizedBox(height: 24),
                  _btn(
                    _isEdit ? 'Update' : 'Add Beneficiary',
                    _primary,
                    _save,
                    loading: _loading,
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

// ─── Transfer Page ───────────────────────────────────────
class _TransferPage extends StatefulWidget {
  final Beneficiary beneficiary;
  final double aepsBalance;

  const _TransferPage({required this.beneficiary, required this.aepsBalance});

  @override
  State<_TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<_TransferPage> {
  final _amountCtrl = TextEditingController(),
      _tpinCtrl = TextEditingController();
  bool _obscureTpin = true, _loading = false;
  String _mode = 'NEFT'; // Default to NEFT

  @override
  void dispose() {
    _amountCtrl.dispose();
    _tpinCtrl.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    if (_amountCtrl.text.isEmpty) {
      _snack('Enter amount');
      return;
    }
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      _snack('Invalid amount');
      return;
    }
    if (amount < 100) {
      _snack('Min ₹100');
      return;
    }
    if (amount > 50000) {
      _snack('Max ₹50,000');
      return;
    }
    if (_tpinCtrl.text.length != 6) {
      _snack('Enter 6-digit TPIN');
      return;
    }
    if (widget.aepsBalance <= 0) {
      _snack('Wallet empty');
      return;
    }
    if (amount > widget.aepsBalance) {
      _snack('Insufficient balance');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await context.read<PayoutProvider>().initiatePayout({
        'amount': amount,
        'mode': _mode,
        'tpin': _tpinCtrl.text.trim(),
        'ip_address': '192.168.1.1',
        'fee': 3,
        'lat': '28.7041',
        'long': '77.1025',
      });

      if (response['success'] == true) {
        if (mounted) {
          context.read<WalletProvider>().fetchAllWalletData();
        }

        final refId = response['merchantRefId']?.toString() ?? '';

        print('✅ Payout success! merchantRefId: $refId');

        if (refId.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_payout_ref_id', refId);
          print('✅ Saved last transaction ref: $refId');
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => PayoutStatusScreen(merchantRefId: refId)
            ),
          );
        }
      } else {
        _snack(response['message'] ?? 'Failed');
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 12)),
      backgroundColor: _error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final b = widget.beneficiary;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar('Fund Transfer'),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        b.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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
                          b.name,
                          style: const TextStyle(
                            color: _textPrim,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${b.bankName} • ${b.accountNumber}',
                          style: TextStyle(
                            color: _textPrim.withOpacity(0.4),
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'IFSC: ${b.ifsc}',
                          style: TextStyle(
                            color: _textPrim.withOpacity(0.3),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // AEPS Wallet Balance
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: _primary, size: 16),
                  const SizedBox(width: 6),
                  const Text('AEPS Balance', style: TextStyle(color: _textSec, fontSize: 12)),
                  const Spacer(),
                  Text(
                    '₹${widget.aepsBalance.toStringAsFixed(2)}',
                    style: const TextStyle(color: _primary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Main Wallet Balance (for commission)
            Consumer<WalletProvider>(
              builder: (context, wp, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wallet_rounded, color: Color(0xFFF59E0B), size: 16),
                      const SizedBox(width: 6),
                      const Text('Main Wallet (for charges)', style: TextStyle(color: _textSec, fontSize: 12)),
                      const Spacer(),
                      Text(
                        '₹${(wp.mainWallet?.balance ?? 0).toStringAsFixed(2)}',
                        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            // Payment Mode Selection
            const Text(
              'Payment Mode',
              style: TextStyle(
                color: _textSec,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _modeChip('NEFT', Icons.account_balance_rounded),
                const SizedBox(width: 10),
                _modeChip('IMPS', Icons.speed_rounded),
              ],
            ),
            const SizedBox(height: 16),
            _input(
              'Amount',
              _amountCtrl,
              hint: 'Min ₹100',
              prefix: '₹',
              kb: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 12),
            _input(
              'TPIN',
              _tpinCtrl,
              hint: '6-digit TPIN',
              ob: _obscureTpin,
              max: 6,
              kb: TextInputType.number,
              formatters: [FilteringTextInputFormatter.digitsOnly],
              suf: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _obscureTpin
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _textSec,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscureTpin = !_obscureTpin),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _outlineBtn('Cancel', () => Navigator.pop(context)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _btn('Proceed', _primary, _proceed, loading: _loading),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeChip(String label, IconData icon) {
    final sel = _mode == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? _primary.withOpacity(0.12) : _card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? _primary : Colors.white.withOpacity(0.06),
              width: sel ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: sel ? _primary : _textSec, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: sel ? _primary : _textSec,
                  fontSize: 13,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared UI Helpers ───────────────────────────────────
AppBar _appBar(String title) => AppBar(
  backgroundColor: _bg,
  elevation: 0,
  centerTitle: true,
  title: Text(
    title,
    style: const TextStyle(
      color: _textPrim,
      fontSize: 16,
      fontWeight: FontWeight.w600,
    ),
  ),
  iconTheme: const IconThemeData(color: _textPrim),
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(1),
    child: Container(height: 1, color: Colors.white.withOpacity(0.05)),
  ),
);

Widget _input(
    String label,
    TextEditingController ctrl, {
      String? hint,
      String? prefix,
      Widget? suf,
      bool ob = false,
      int? max,
      TextInputType? kb,
      List<TextInputFormatter>? formatters,
      String? Function(String?)? v,
    }) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _textSec,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl,
        obscureText: ob,
        maxLength: max,
        keyboardType: kb,
        inputFormatters: formatters,
        validator: v,
        style: const TextStyle(color: _textPrim, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: _textPrim.withOpacity(0.25),
            fontSize: 12,
          ),
          prefixText: prefix,
          prefixStyle: TextStyle(color: _textSec, fontSize: 13),
          suffixIcon: suf,
          filled: true,
          fillColor: _surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          counterText: '',
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
            borderSide: BorderSide(
              color: _primary.withOpacity(0.5),
              width: 1.5,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: _error.withOpacity(0.6)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _error, width: 1.5),
          ),
          errorStyle: const TextStyle(color: _error, fontSize: 10),
        ),
      ),
    ],
  );
}

// ─── Searchable Dropdown ─────────────────────────────────
Widget _dropdown(
    BuildContext context,
    String label,
    String? val,
    List<DropdownMenuItem<String>> items,
    void Function(String?) onCh,
    ) {
  String displayText = 'Select';
  if (val != null) {
    final selectedItem = items.where((i) => i.value == val).firstOrNull;
    if (selectedItem != null && selectedItem.child is Text) {
      displayText = (selectedItem.child as Text).data ?? 'Select';
    }
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _textSec,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 5),
      GestureDetector(
        onTap: () =>
            _showSearchablePicker(context, items, val, onCh, 'Search...'),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  displayText,
                  style: TextStyle(
                    color: val != null
                        ? _textPrim
                        : _textPrim.withOpacity(0.25),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _textSec,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

void _showSearchablePicker(
    BuildContext context,
    List<DropdownMenuItem<String>> items,
    String? currentValue,
    void Function(String?) onCh,
    String searchHint,
    ) {
  final searchController = TextEditingController();
  List<DropdownMenuItem<String>> filteredItems = List.from(items);
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => Container(
        height: MediaQuery.of(ctx).size.height * 0.55,
        decoration: const BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: _textPrim, fontSize: 14),
                decoration: InputDecoration(
                  hintText: searchHint,
                  hintStyle: TextStyle(
                    color: _textPrim.withOpacity(0.3),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _textSec,
                    size: 20,
                  ),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: _textSec,
                      size: 18,
                    ),
                    onPressed: () {
                      searchController.clear();
                      setSheetState(
                            () => filteredItems = List.from(items),
                      );
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: _card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (q) => setSheetState(
                      () => filteredItems = items.where((i) {
                    final t = i.child is Text
                        ? (i.child as Text).data ?? ''
                        : '';
                    return t.toLowerCase().contains(q.toLowerCase());
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filteredItems.isEmpty
                  ? const Center(
                child: Text(
                  'No results found',
                  style: TextStyle(color: _textSec, fontSize: 13),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: filteredItems.length,
                itemBuilder: (_, i) {
                  final item = filteredItems[i];
                  final text = item.child is Text
                      ? (item.child as Text).data ?? ''
                      : '';
                  final isSelected = item.value == currentValue;
                  return ListTile(
                    dense: true,
                    title: Text(
                      text,
                      style: TextStyle(
                        color: isSelected ? _primaryLight : _textPrim,
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                      Icons.check_rounded,
                      color: _primaryLight,
                      size: 20,
                    )
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    tileColor: isSelected
                        ? _primary.withOpacity(0.1)
                        : null,
                    onTap: () {
                      onCh(item.value);
                      Navigator.pop(ctx);
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

Widget _infoCard(IconData icon, Color color, String title, String subtitle) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: _textPrim.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _btn(
    String label,
    Color color,
    VoidCallback? onTap, {
      bool loading = false,
      IconData? icon,
    }) {
  return SizedBox(
    width: double.infinity,
    child: GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: onTap == null
              ? _textSec.withOpacity(0.1)
              : color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: onTap == null
                ? _textSec.withOpacity(0.2)
                : color.withOpacity(0.4),
          ),
        ),
        child: Center(
          child: loading
              ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: color,
            ),
          )
              : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: onTap == null ? _textSec : color,
                  size: 16,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: onTap == null ? _textSec : color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _outlineBtn(String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 44,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: _textSec,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}

PageRoute _slide(Widget page) => PageRouteBuilder(
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (_, anim, __, child) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
    child: child,
  ),
  transitionDuration: const Duration(milliseconds: 300),
);