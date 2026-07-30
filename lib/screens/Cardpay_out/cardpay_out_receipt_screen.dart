// lib/screens/CardPayOut/cardpay_out_receipt_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/cardpay_out_provider.dart';
import '../../models/cardpay_out_models.dart';

class CardPayOutReceiptScreen extends StatefulWidget {
  final String ref;

  const CardPayOutReceiptScreen({Key? key, required this.ref}) : super(key: key);

  @override
  State<CardPayOutReceiptScreen> createState() => _CardPayOutReceiptScreenState();
}

class _CardPayOutReceiptScreenState extends State<CardPayOutReceiptScreen> {
  bool _isLoading = true;
  String? _error;
  CardPayOutTransaction? _transaction;
  CardPayOutStatus? _status;

  @override
  void initState() {
    super.initState();
    _loadReceipt();
  }

  Future<void> _loadReceipt() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<CardPayOutProvider>(context, listen: false);
      
      // Get receipt data
      final receiptResult = await provider.getReceipt(widget.ref);
      if (receiptResult != null && receiptResult['receipt'] != null) {
        _transaction = CardPayOutTransaction.fromJson(receiptResult['receipt']);
      }
      
      // Get status
      final status = await provider.getStatus(widget.ref);
      _status = status;
      
      setState(() => _isLoading = false);
    } catch (e) {
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
        title: const Text('Withdrawal Receipt'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReceipt,
            tooltip: 'Refresh Status',
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
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadReceipt,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_transaction == null) {
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

    final isSuccess = _transaction?.status == 'success' || _status?.status == 'success';
    final isPending = _transaction?.status == 'pending' || _status?.status == 'pending';
    final isFailed = _transaction?.status == 'failed' || _status?.status == 'failed';
    final statusColor = isSuccess ? Colors.green : (isPending ? Colors.orange : Colors.red);

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
              // Status Header
              Center(
                child: Column(
                  children: [
                    Icon(
                      isSuccess ? Icons.check_circle_rounded : 
                      (isPending ? Icons.pending_rounded : Icons.error_rounded),
                      size: 64,
                      color: statusColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isSuccess ? 'SUCCESS' : 
                      (isPending ? 'PENDING' : 'FAILED'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reference: ${_transaction?.merchantRefId ?? widget.ref}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (isPending)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: const Text(
                          'Processing... Please wait',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 32),

              // Transaction Details
              _buildSectionTitle('Transaction Details'),
              _buildDetailRow('Reference ID', _transaction?.merchantRefId ?? 'N/A'),
              _buildDetailRow('Amount', '₹${_transaction?.amount.toStringAsFixed(2) ?? '0.00'}'),
              _buildDetailRow('Mode', _transaction?.mode ?? 'N/A'),
              _buildDetailRow('Status', _transaction?.status?.toUpperCase() ?? 'N/A'),
              if (_status?.utr != null)
                _buildDetailRow('UTR', _status!.utr!),
              if (_status?.failureReason != null)
                _buildDetailRow('Failure Reason', _status!.failureReason!),
              _buildDetailRow('Date', _formatDateTime(_transaction?.createdAt ?? '')),
              
              const Divider(height: 24),

              // Beneficiary Details
              if (_transaction?.accountHolderName != null) ...[
                _buildSectionTitle('Beneficiary Details'),
                _buildDetailRow('Name', _transaction!.accountHolderName!),
                _buildDetailRow('Account', _transaction!.accountNumber ?? 'N/A'),
              ],

              const SizedBox(height: 16),

              // Refresh Button for Pending Status
              if (isPending)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _loadReceipt,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Check Status'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
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
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          Flexible(
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

  String _formatDateTime(String dateTimeString) {
    if (dateTimeString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTimeString;
    }
  }
}