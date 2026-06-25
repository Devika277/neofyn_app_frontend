// lib/screens/payout/payout_status_screen.dart

import 'package:flutter/material.dart';
import '../../services/payout/payout_service.dart';
import '../payout/payout_receipt_screen.dart';

class PayoutStatusScreen extends StatefulWidget {
  final String merchantRefId;

  const PayoutStatusScreen({Key? key, required this.merchantRefId}) : super(key: key);

  @override
  State<PayoutStatusScreen> createState() => _PayoutStatusScreenState();
}

class _PayoutStatusScreenState extends State<PayoutStatusScreen> {
  final PayoutService _service = PayoutService();
  Map<String, dynamic>? _transaction;
  bool _loading = true;
  bool _isPolling = true;
  int _attempts = 0;
  static const int _maxAttempts = 2;

  // ─── Theme Colors ─────────────────────────────────────
  static const Color bg = Color(0xFF0A0E0A);
  static const Color card = Color(0xFF1A1F1A);
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _fetchStatusLoop();
  }

  @override
  void dispose() {
    _isPolling = false;
    super.dispose();
  }

  Future<void> _fetchStatusLoop() async {
    _attempts = 0;
    while (_isPolling && mounted && _attempts < _maxAttempts) {
      _attempts++;
      try {
        final response = await _service.getTransactionStatus(widget.merchantRefId);
        if (response['success'] == true) {
          final data = response['data'];
          if (mounted) setState(() { _transaction = data; _loading = false; });
          final status = data?['status']?.toString().toLowerCase() ?? '';
          if (status == 'success' || status == 'failed') {
            _isPolling = false;
            break;
          }
          // ✅ Stop polling if transaction is older than 2 minutes (not 5)
          final createdAt = data?['created_at'];
          if (createdAt != null) {
            final created = DateTime.tryParse(createdAt.toString());
            if (created != null && DateTime.now().difference(created).inMinutes > 2) {
              debugPrint('Status polling stopped: transaction older than 2 minutes');
              _isPolling = false;
              // ✅ Set a message so user knows what happened
              if (mounted) {
                setState(() {
                  _loading = false;
                  _transaction = {
                    'status': 'pending',
                    'message': 'Transaction is pending. Please check later in history.',
                  };
                });
              }
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Status polling error: $e');
        _isPolling = false;  // ✅ Stop polling on error too
      }
      if (_isPolling && _attempts < _maxAttempts) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }
    if (mounted && _loading) {
      setState(() {
        _loading = false;
        _transaction = {
          'status': 'pending',
          'message': 'Status check completed. Please check transaction history for updates.'
        };
      });
    }
  }

  Future<void> _manualRefresh() async {
    setState(() => _loading = true);
    try {
      final response = await _service.getTransactionStatus(widget.merchantRefId);
      if (response['success'] == true && mounted) {
        setState(() { _transaction = response['data']; _loading = false; });
        final status = _transaction?['status']?.toString().toLowerCase() ?? '';
        if (status == 'success' || status == 'failed') _isPolling = false;
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Payout Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70), onPressed: _manualRefresh, tooltip: 'Refresh'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _transaction == null
          ? _buildNotFound()
          : _buildReceipt(),
    );
  }

  Widget _buildNotFound() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 56, color: error)),
      const SizedBox(height: 16),
      const Text('Transaction not found', style: TextStyle(color: Colors.white70, fontSize: 15)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _manualRefresh, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ]));
  }

  Widget _buildReceipt() {
    final tx = _transaction!;
    String g(String k, {String d = ''}) => tx[k]?.toString() ?? d;

    final isSuccess = g('status').toLowerCase() == 'success';
    final isFailed = g('status').toLowerCase() == 'failed';
    final isProcessing = !isSuccess && !isFailed;

    final statusColor = isSuccess ? success : (isFailed ? error : warning);
    final statusIcon = isSuccess ? Icons.check_circle_rounded : (isFailed ? Icons.cancel_rounded : Icons.access_time_rounded);
    final statusTitle = isSuccess ? 'Transaction Successful' : (isFailed ? 'Transaction Failed' : 'Processing');

    // ✅ Parse deduction breakdown values
    final amount = double.tryParse(g('amount')) ?? 0;
    final charge = double.tryParse(g('payout_charge')) ?? 0;
    final totalDeduction = double.tryParse(g('total_deduction')) ?? amount;
    final aepsBalance = double.tryParse(g('aeps_balance')) ?? 0;
    final mainBalance = double.tryParse(g('main_balance')) ?? 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── Status Header Card ──────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: statusColor.withOpacity(0.3))),
          child: Column(children: [
            Container(width: 72, height: 72, decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: statusColor.withOpacity(0.3), width: 2)),
                child: Icon(statusIcon, size: 40, color: statusColor)),
            const SizedBox(height: 16),
            Text(statusTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor)),
            const SizedBox(height: 4),
            Text(isProcessing ? 'Your payout is being processed...' : g('message'), style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12), textAlign: TextAlign.center),
            if (isProcessing) ...[const SizedBox(height: 16), const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: warning))],
          ]),
        ),
        const SizedBox(height: 20),

        // ── View Receipt Button (Success only) ──────────
        if (isSuccess) ...[
          Container(
            width: double.infinity, height: 48,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [primary, primaryLight]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))]),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PayoutReceiptScreen(merchantRefId: widget.merchantRefId))),
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
              label: const Text('View & Download Receipt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ✅ DEDUCTION BREAKDOWN (Show on success or failed)
        if (isSuccess || isFailed) ...[
          _buildCard('Deduction Breakdown', [
            _breakdownRow('Transfer Amount', 'Deducted from AEPS Wallet', amount, const Color(0xFF3B82F6), Icons.account_balance_wallet_rounded),
            const SizedBox(height: 10),
            _breakdownRow('Commission Charge', 'Deducted from Main Wallet', charge, const Color(0xFFF59E0B), Icons.wallet_rounded),
            const SizedBox(height: 10),
            Container(height: 1, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 10),
            _breakdownRow('Total Deduction', 'Combined from both wallets', totalDeduction, primary, Icons.summarize_rounded, isTotal: true),
          ]),
          const SizedBox(height: 12),

          // ✅ CURRENT BALANCES
          _buildCard('Current Wallet Balances', [
            _balanceRow('AEPS Wallet', aepsBalance, const Color(0xFF3B82F6), Icons.account_balance_wallet_rounded),
            const SizedBox(height: 8),
            _balanceRow('Main Wallet', mainBalance, const Color(0xFFF59E0B), Icons.wallet_rounded),
          ]),
          const SizedBox(height: 12),
        ],

        // ── Transaction Details Card ────────────────────
        _buildCard('Transaction Details', [
          _row('Transaction ID', g('id')),
          _row('Reference ID', g('merchantrefid')),
          _row('Amount', '₹${amount.toStringAsFixed(2)}'),
          if (charge > 0) _row('Commission', '₹${charge.toStringAsFixed(2)}'),
          _row('Payment Mode', g('paymentmode')),
          _row('Status', g('status').toUpperCase(), valueColor: statusColor),
          _row('Provider Ref ID', g('providerrefid')),
          _row('Bank Ref No', g('bankrefno')),
          _row('Date & Time', _formatDate(tx['created_at'])),
        ]),
        const SizedBox(height: 12),

        // ── Beneficiary Details Card ────────────────────
        _buildCard('Beneficiary Details', [
          _row('Name', g('beneficiaryname')),
          _row('Account Number', g('beneficiaryaccountnumber')),
          _row('IFSC Code', g('beneficiaryifsc')),
        ]),
        const SizedBox(height: 20),

        // ── Actions ─────────────────────────────────────
        if (isProcessing)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: _manualRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Check Status Now'),
              style: OutlinedButton.styleFrom(foregroundColor: warning, side: const BorderSide(color: warning), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          icon: const Icon(Icons.home_rounded, size: 18),
          label: const Text('Go to Home'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: BorderSide(color: Colors.white.withOpacity(0.2)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ✅ NEW: Breakdown row widget
  Widget _breakdownRow(String label, String source, double amount, Color color, IconData icon, {bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(isTotal ? 0.3 : 0.1)),
      ),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: isTotal ? Colors.white : Colors.white70, fontSize: 13, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500)),
          Text(source, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
        ])),
        Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: isTotal ? 16 : 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ✅ NEW: Balance row widget
  Widget _balanceRow(String label, double balance, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.15))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('₹${balance.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(child: Text(value.isNotEmpty ? value : 'N/A', textAlign: TextAlign.right, style: TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime.toString();
    }
  }
}