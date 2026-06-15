// screens/recharge_receipt_screen.dart
import 'package:flutter/material.dart';
import 'package:my_app/services/Recharges/recharge_service.dart';

class RechargeReceiptScreen extends StatefulWidget {
  final int transactionId;
  const RechargeReceiptScreen({super.key, required this.transactionId});

  @override
  State<RechargeReceiptScreen> createState() => _RechargeReceiptScreenState();
}

class _RechargeReceiptScreenState extends State<RechargeReceiptScreen> {
  Map<String, dynamic>? receipt;
  bool loading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _fetchReceipt();
  }

Future<void> _fetchReceipt() async {
  try {
    final baseUrl = 'https://api.myneofyn.com'; // your ngrok URL
    final service = RechargeService(baseUrl: baseUrl); // ✅ named parameter provided
    final response = await service.getReceipt(widget.transactionId);
    setState(() {
      receipt = response['data'];
      loading = false;
    });
  } catch (e) {
    setState(() {
      error = e.toString();
      loading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recharge Receipt')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(child: Text('Error: $error'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _infoCard(),
                      const SizedBox(height: 20),
                      _disclaimerCard(),
                    ],
                  ),
                ),
    );
  }

  Widget _infoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Transaction Status', style: TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: receipt!['status'] == 'SUCCESS' ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    receipt!['status'],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildRow('Transaction ID', receipt!['transactionId'].toString()),
            _buildRow('Merchant Ref', receipt!['merchantTransactionId']),
            _buildRow('Operator Ref', receipt!['providerTransactionId']),
            _buildRow('Mobile Number', receipt!['customerMobile']),
            _buildRow('Operator', receipt!['operator']),
            _buildRow('Recharge Amount', '₹${receipt!['amount']}'),
            _buildRow('Date & Time', receipt!['dateTime']),
            const SizedBox(height: 10),
            Text('Merchant: ${receipt!['merchantName']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text('Support: ${receipt!['merchantSupport']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _disclaimerCard() {
    return Card(
      elevation: 1,
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Important Information', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...(receipt!['disclaimers'] as List).map((d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 12)),
                      Expanded(child: Text(d, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                )),
            const SizedBox(height: 4),
            Text(receipt!['policyText'], style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}