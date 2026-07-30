// lib/screens/CardPay/cardpay_transaction_list.dart
import 'package:flutter/material.dart';
import '../../models/cardpay_models.dart';

class CardPayTransactionList extends StatelessWidget {
  final List<CardPayTransaction> transactions;
  final VoidCallback onRefresh;
  final VoidCallback onViewAll;
  final Function(String) onTransactionTap;  // Add this

  const CardPayTransactionList({
    Key? key,
    required this.transactions,
    required this.onRefresh,
    required this.onViewAll,
    required this.onTransactionTap,  // Required parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Transactions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('No transactions found'),
              ),
            )
          else
            ...transactions.take(5).map((txn) => _buildTransactionItem(context, txn)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, CardPayTransaction txn) {
    final isSuccess = txn.txnStatus == 'success';
    final isPending = txn.txnStatus == 'pending';
    final statusColor = isSuccess ? Colors.green : (isPending ? Colors.orange : Colors.red);

    return GestureDetector(
      onTap: () => onTransactionTap(txn.merchantRefId),  // Navigate to receipt
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isSuccess ? Icons.check_circle_rounded : (isPending ? Icons.pending_rounded : Icons.error_rounded),
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                  _formatAmount(txn.amount),  // Use the formatter
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                  Text(
                    txn.merchantRefId,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    txn.txnStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(txn.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (_) {
      return dateTimeString;
    }
  }

  // Add this helper method at the bottom:
String _formatAmount(double amount) {
  try {
    return '₹${amount.toStringAsFixed(2)}';
  } catch (_) {
    return '₹0.00';
  }
}
}