// lib/screens/fund_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fund_provider.dart';

class FundRequestsScreen extends StatefulWidget {
  const FundRequestsScreen({super.key});

  @override
  State<FundRequestsScreen> createState() => _FundRequestsScreenState();
}

class _FundRequestsScreenState extends State<FundRequestsScreen> {
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    // Load requests once when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    final fundProvider = context.read<FundProvider>();
    await fundProvider.getMyRequests();
    setState(() {
      _isInitialLoad = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fundProvider = context.watch<FundProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Fund Requests',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0A0E0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadRequests,
          ),
        ],
      ),
      backgroundColor: const Color(0xFF0A0E0A),
      body: _buildBody(fundProvider),
    );
  }

  Widget _buildBody(FundProvider fundProvider) {
    // Show loading only on initial load
    if (_isInitialLoad && fundProvider.isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00FF9D),
        ),
      );
    }

    // Show error
    if (fundProvider.requestsError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error: ${fundProvider.requestsError}',
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRequests,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00FF9D),
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show empty state
    if (fundProvider.myRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              color: Colors.white24,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'No fund requests found',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Submit a fund request from the wallet',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Show list of requests
    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: const Color(0xFF00FF9D),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: fundProvider.myRequests.length,
        itemBuilder: (context, index) {
          final request = fundProvider.myRequests[index];
          return _buildRequestCard(request, fundProvider);
        },
      ),
    );
  }

  Widget _buildRequestCard(dynamic request, FundProvider fundProvider) {
    final status = request['status'] ?? 'pending';
    final amount = request['amount'] ?? '0';
    final bankName = request['bank_name'] ?? 'N/A';
    final paymentMode = request['payment_mode'] ?? 'N/A';
    final referenceNumber = request['reference_number'] ?? 'N/A';
    final remark = request['remark'] ?? '';
    final createdAt = request['created_at'] ?? '';

    Color statusColor;
    String statusLabel;

    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusLabel = '✅ Approved';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusLabel = '❌ Rejected';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusLabel = '⛔ Cancelled';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = '⏳ Pending';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Amount + Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? amount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Details
          _buildDetailRow('Bank', bankName),
          _buildDetailRow('Payment Mode', paymentMode),
          _buildDetailRow('Reference', referenceNumber),
          if (remark.isNotEmpty) _buildDetailRow('Remark', remark),
          _buildDetailRow('Date', _formatDate(createdAt)),

          // Cancel button (only for pending requests)
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: fundProvider.isCancelling
                    ? null
                    : () async {
                        final success = await fundProvider.cancelRequest(
                          request['id'],
                        );
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                fundProvider.cancelError ??
                                    'Failed to cancel request',
                              ),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.15),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.red.withOpacity(0.3)),
                  ),
                ),
                child: fundProvider.isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : const Text(
                        'Cancel Request',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}