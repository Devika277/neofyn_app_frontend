// lib/screens/payout/payout_history_screen.dart

import 'package:flutter/material.dart';
import '../../services/Payout/payout_service.dart';
import 'payout_status_screen.dart';

class PayoutHistoryScreen extends StatefulWidget {
  const PayoutHistoryScreen({Key? key}) : super(key: key);

  @override
  State<PayoutHistoryScreen> createState() => _PayoutHistoryScreenState();
}

class _PayoutHistoryScreenState extends State<PayoutHistoryScreen> {
  final PayoutService _payoutService = PayoutService();
  List<dynamic> _transactions = [];
  bool _loading = true;
  String? _error;

  static const Color bg = Color(0xFF0A0E0A);
  static const Color card = Color(0xFF1A1F1A);
  static const Color primary = Color(0xFF008169);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() { _loading = true; _error = null; });
    try {
      // final history = await _payoutService.getTransactionHistory();
      setState(() {
        // _transactions = history;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Payout History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: bg, foregroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white70), onPressed: _fetchHistory),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _error != null
          ? _buildError()
          : _transactions.isEmpty
          ? _buildEmpty()
          : ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _transactions.length,
        itemBuilder: (_, i) => _buildTxCard(_transactions[i]),
      ),
    );
  }

  Widget _buildError() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 56, color: error)),
      const SizedBox(height: 16),
      Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _fetchHistory, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ]));
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), shape: BoxShape.circle), child: Icon(Icons.receipt_long_rounded, size: 56, color: Colors.white.withOpacity(0.15))),
      const SizedBox(height: 16),
      const Text('No transactions found', style: TextStyle(color: Colors.white54, fontSize: 15)),
      const SizedBox(height: 4),
      Text('Your payout history will appear here', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
    ]));
  }

  Widget _buildTxCard(dynamic tx) {
    final status = tx['status']?.toString().toUpperCase() ?? '';
    final isSuccess = status == 'SUCCESS';
    final isFailed = status == 'FAILED';
    final statusColor = isSuccess ? success : (isFailed ? error : warning);
    final statusIcon = isSuccess ? Icons.check_circle_rounded : (isFailed ? Icons.cancel_rounded : Icons.access_time_rounded);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PayoutStatusScreen(merchantRefId: tx['merchantRefId'] ?? ''))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.05))),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(statusIcon, color: statusColor, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('₹${tx['amount']} → ${tx['beneficiaryName'] ?? 'N/A'}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Ref: ${tx['merchantRefId'] ?? 'N/A'}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 2),
            Row(children: [
              _badge(status, statusColor),
              const SizedBox(width: 8),
              Text('Mode: ${tx['paymentMode'] ?? 'N/A'}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
              const Spacer(),
              Text(_formatDate(tx['createdAt']), style: const TextStyle(color: Colors.white24, fontSize: 10)),
            ]),
          ])),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
        ]),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return dateTime.toString();
    }
  }
}