// screens/payout/payout_status_screen.dart

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
  static const int _maxAttempts = 20;

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
        print('📥 Status response: $response');
        
        if (response['success'] == true) {
          final data = response['data'];
          if (mounted) {
            setState(() {
              _transaction = data;
              _loading = false;
            });
          }
          
          final status = data?['status']?.toString().toLowerCase() ?? '';
          print('📊 Transaction status: $status');
          
          if (status == 'success' || status == 'failed') {
            _isPolling = false;
            break;
          }
        } else {
          print('⏳ Transaction still processing... (attempt ${_attempts}/$_maxAttempts)');
        }
      } catch (e) {
        print('⚠️ Status polling error: $e');
      }
      
      if (_isPolling && _attempts < _maxAttempts) {
        await Future.delayed(const Duration(seconds: 3));
      }
    }
    
    if (mounted && _attempts >= _maxAttempts && _loading) {
      setState(() {
        _loading = false;
        _transaction = {
          'status': 'pending',
          'message': 'Transaction is taking longer than expected. Please check later.',
        };
      });
    }
  }

  Future<void> _manualRefresh() async {
    setState(() => _loading = true);
    try {
      final response = await _service.getTransactionStatus(widget.merchantRefId);
      if (response['success'] == true) {
        setState(() {
          _transaction = response['data'];
          _loading = false;
        });
        final status = _transaction?['status']?.toString().toLowerCase() ?? '';
        if (status == 'success' || status == 'failed') {
          _isPolling = false;
        }
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Status'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _manualRefresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _transaction == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Transaction not found'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _manualRefresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildReceipt(),
    );
  }

  Widget _buildReceipt() {
    final tx = _transaction!;
    
    // ✅ Safe getter with null handling
    String getString(String key, {String defaultValue = ''}) {
      return tx[key]?.toString() ?? defaultValue;
    }

    final isSuccess = getString('status').toLowerCase() == 'success';
    final isFailed = getString('status').toLowerCase() == 'failed';
    final isProcessing = !isSuccess && !isFailed;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Status Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle : (isFailed ? Icons.error : Icons.hourglass_empty),
                    size: 64,
                    color: isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isSuccess ? '✅ TRANSACTION SUCCESS' : (isFailed ? '❌ TRANSACTION FAILED' : '⏳ PROCESSING'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isSuccess ? Colors.green : (isFailed ? Colors.red : Colors.orange),
                    ),
                  ),
                  if (isProcessing) ...[
                    const SizedBox(height: 8),
                    const Text('Your payout is being processed. Please wait or refresh.'),
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // View Receipt Button
          if (isSuccess) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PayoutReceiptScreen(
                        merchantRefId: widget.merchantRefId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.receipt_long, color: Colors.white),
                label: const Text(
                  'VIEW & PRINT RECEIPT',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Transaction Details Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _detailRow('Transaction ID', getString('id')),
                  _detailRow('Reference ID', getString('merchantrefid')),
                  _detailRow('Amount', '₹${getString('amount')}'),
                  _detailRow('Payment Mode', getString('paymentmode')),
                  _detailRow('Status', getString('status').toUpperCase()),
                  _detailRow('Provider Ref ID', getString('providerrefid')),
                  _detailRow('Bank Ref No', getString('bankrefno')),
                  _detailRow('Date & Time', _formatDate(tx['created_at'])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Beneficiary Details Card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Beneficiary Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  _detailRow('Name', getString('beneficiaryname')),
                  _detailRow('Account Number', getString('beneficiaryaccountnumber')),
                  _detailRow('IFSC Code', getString('beneficiaryifsc')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Refresh Button (only visible while processing)
          if (isProcessing)
            ElevatedButton.icon(
              onPressed: _manualRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Check Status Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          const SizedBox(height: 20),

          // Back to Home Button
          ElevatedButton.icon(
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
            icon: const Icon(Icons.home),
            label: const Text('Go to Home'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }
}