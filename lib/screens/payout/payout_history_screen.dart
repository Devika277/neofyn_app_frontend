import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_app/providers/payout_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/screens/payout/payout_status_screen.dart';

class PayoutHistoryScreen extends StatefulWidget {
  const PayoutHistoryScreen({super.key});

  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  static const Color _bg = Color(0xFF0A0E0A);
  static const Color _card = Color(0xFF1A1F1A);
  static const Color _primary = Color(0xFF008169);
  static const Color _success = Color(0xFF2ECC71);
  static const Color _error = Color(0xFFEF4444);
  static const Color _pending = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PayoutProvider>().loadTransactionHistory();
    });
  }

  void _viewTransactionDetail(Map<String, dynamic> txn) {
    final refId = txn['merchant_ref_id']?.toString() ?? '';
    print('📤 Navigating to status with refId: $refId');
    if (refId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PayoutStatusScreen(merchantRefId: refId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: const Text('Payout History', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<PayoutProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: _primary));
          }

          final transactions = provider.transactions;

          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_rounded, size: 48, color: Colors.white.withOpacity(0.15)),
                  const SizedBox(height: 12),
                  const Text('No payout transactions yet', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Your money transfers will appear here', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: _primary,
            onRefresh: () => provider.loadTransactionHistory(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              itemBuilder: (_, i) {
                final txn = transactions[i] as Map<String, dynamic>;
                return _buildTransactionCard(txn);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> txn) {
    final status = txn['status']?.toString() ?? 'unknown';
    final amount = double.tryParse(txn['amount']?.toString() ?? '0') ?? 0;
    final date = txn['created_at']?.toString().substring(0, 10) ?? '';
    final time = txn['created_at']?.toString().substring(11, 19) ?? '';
    final refId = txn['merchant_ref_id']?.toString() ?? '';
    final mode = txn['transfer_mode']?.toString() ?? 'NEFT';
    final bankRef = txn['bank_ref_no']?.toString() ?? '';

    Color statusColor;
    IconData statusIcon;
    switch (status.toLowerCase()) {
      case 'success':
        statusColor = _success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'failed':
        statusColor = _error;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = _pending;
        statusIcon = Icons.access_time_rounded;
    }

    return GestureDetector(
      onTap: () => _viewTransactionDetail(txn),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Status icon
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                const SizedBox(width: 12),

                // Amount & mode
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${amount.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'via $mode',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                      ),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Details row
            Row(
              children: [
                Icon(Icons.receipt_rounded, color: Colors.white.withOpacity(0.3), size: 12),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Ref: $refId',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            if (bankRef.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.account_balance_rounded, color: Colors.white.withOpacity(0.3), size: 12),
                  const SizedBox(width: 4),
                  Text(
                    'Bank Ref: $bankRef',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 8),

            // Date & time
            Row(
              children: [
                Icon(Icons.access_time_rounded, color: Colors.white.withOpacity(0.2), size: 12),
                const SizedBox(width: 4),
                Text(
                  '$date at $time',
                  style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10),
                ),
                const Spacer(),
                Text(
                  'Tap for details',
                  style: TextStyle(color: _primary.withOpacity(0.4), fontSize: 9),
                ),
                const SizedBox(width: 2),
                Icon(Icons.arrow_forward_ios_rounded, color: _primary.withOpacity(0.3), size: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}