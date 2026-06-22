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

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // final history = await _payoutService.getTransactionHistory();
      setState(() {
        // _transactions = history;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout History'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchHistory,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _transactions.isEmpty
                  ? const Center(child: Text('No transactions found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final tx = _transactions[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                          elevation: 2,
                          child: ListTile(
                            leading: Icon(
                              tx['status'] == 'SUCCESS'
                                  ? Icons.check_circle
                                  : (tx['status'] == 'FAILED'
                                      ? Icons.error
                                      : Icons.hourglass_empty),
                              color: tx['status'] == 'SUCCESS'
                                  ? Colors.green
                                  : (tx['status'] == 'FAILED' ? Colors.red : Colors.orange),
                            ),
                            title: Text('₹${tx['amount']} → ${tx['beneficiaryName']}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ref: ${tx['merchantRefId']}'),
                                Text('Status: ${tx['status']} | Mode: ${tx['paymentMode']}'),
                                Text(_formatDate(tx['createdAt'])),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              // Navigate to detailed status screen for this transaction
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PayoutStatusScreen(merchantRefId: tx['merchantRefId']),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }
}