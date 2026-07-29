// lib/screens/CardPay/cardpay_receipt_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/cardpay_models.dart';
import '../../providers/cardpay_provider.dart';

class CardPayReceiptScreen extends StatefulWidget {
  final String ref;

  const CardPayReceiptScreen({Key? key, required this.ref}) : super(key: key);

  @override
  State<CardPayReceiptScreen> createState() => _CardPayReceiptScreenState();
}

class _CardPayReceiptScreenState extends State<CardPayReceiptScreen> {
  Map<String, dynamic>? _receipt;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to avoid calling setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReceipt();
    });
  }

  Future<void> _loadReceipt() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<CardPayProvider>(context, listen: false);
      final result = await provider.getReceipt(widget.ref);
      
      if (!mounted) return;
      
      if (result != null && result['receipt'] != null) {
        setState(() {
          _receipt = result['receipt'] as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load receipt';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Receipt'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReceipt,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReceipt,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_receipt == null || _receipt!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No receipt found'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Status
              Center(
                child: Column(
                  children: [
                    Icon(
                      _getStatusIcon(),
                      size: 64,
                      color: _getStatusColor(),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Transaction ID: ${_receipt!['merchant_ref_id'] ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),

              // Transaction Details
              _buildSectionTitle('Transaction Details'),
              _buildDetailRow('Reference ID', _receipt!['merchant_ref_id'] ?? 'N/A'),
              _buildDetailRow('Amount', '₹${_formatAmount(_receipt!['amount'])}'),
              _buildDetailRow('Status', _getStatusText()),
              _buildDetailRow('Status Code', _receipt!['txn_status_code']?.toString() ?? 'N/A'),
              _buildDetailRow('Date', _formatDate(_receipt!['created_at'])),
              
              const Divider(height: 24),
              
              // Card Details
              _buildSectionTitle('Card Details'),
              _buildDetailRow('Card Holder', _receipt!['card_holder_name'] ?? 'N/A'),
              _buildDetailRow('Card Network', _receipt!['card_network']?.toString() ?? 'N/A'),
              _buildDetailRow('Last 4 Digits', _receipt!['card_last_four']?.toString() ?? 'N/A'),
              _buildDetailRow('RRN', _receipt!['rrn']?.toString() ?? 'N/A'),
              _buildDetailRow('Charges', _receipt!['charges'] != null ? '₹${_formatAmount(_receipt!['charges'])}' : 'N/A'),
              
              const Divider(height: 24),
              
              // Customer Details
              _buildSectionTitle('Customer Details'),
              _buildDetailRow('Name', _receipt!['customer_name'] ?? _receipt!['name'] ?? 'N/A'),
              _buildDetailRow('Mobile', _receipt!['customer_mobile'] ?? _receipt!['mobile']?.toString() ?? 'N/A'),
              _buildDetailRow('Email', _receipt!['customer_email'] ?? _receipt!['email'] ?? 'N/A'),

              // Location Details
              if (_receipt!['location'] != null) ...[
                const Divider(height: 24),
                _buildSectionTitle('Location Details'),
                _buildDetailRow('Location', _receipt!['location'] ?? 'N/A'),
                if (_receipt!['latitude'] != null)
                  _buildDetailRow('Latitude', _receipt!['latitude']?.toString() ?? 'N/A'),
                if (_receipt!['longitude'] != null)
                  _buildDetailRow('Longitude', _receipt!['longitude']?.toString() ?? 'N/A'),
              ],

              // Wallet Status
              if (_receipt!['wallet_credited'] == true) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Wallet Credited',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Balance Info
              if (_receipt!['balance_before'] != null || _receipt!['balance_after'] != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Balance Before', '₹${_formatAmount(_receipt!['balance_before'])}'),
                      _buildDetailRow('Balance After', '₹${_formatAmount(_receipt!['balance_after'])}'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Safe amount formatting - handles String, double, int, null
  String _formatAmount(dynamic amount) {
    if (amount == null) return '0.00';
    
    try {
      double value;
      if (amount is double) {
        value = amount;
      } else if (amount is int) {
        value = amount.toDouble();
      } else if (amount is String) {
        // Remove any non-numeric characters except decimal
        final cleaned = amount.replaceAll(RegExp(r'[^0-9.]'), '');
        value = double.tryParse(cleaned) ?? 0.0;
      } else {
        return '0.00';
      }
      return value.toStringAsFixed(2);
    } catch (_) {
      return '0.00';
    }
  }

  String _getStatusText() {
    final status = _receipt!['txn_status'] ?? 'pending';
    return status.toString().toUpperCase();
  }

  Color _getStatusColor() {
    final status = _receipt!['txn_status'] ?? 'pending';
    switch (status.toString().toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    final status = _receipt!['txn_status'] ?? 'pending';
    switch (status.toString().toLowerCase()) {
      case 'success':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.pending_rounded;
      case 'failed':
        return Icons.error_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  String _formatDate(dynamic dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTimeString.toString();
    }
  }
}