// lib/screens/cardpay/cardpay_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cardpay_provider.dart';

class CardPayHistoryScreen extends StatefulWidget {
  const CardPayHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CardPayHistoryScreen> createState() => _CardPayHistoryScreenState();
}

class _CardPayHistoryScreenState extends State<CardPayHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final provider = Provider.of<CardPayProvider>(context, listen: false);
    await provider.fetchUserHistory(
      status: _selectedStatus,
      startDate: _startDate?.toIso8601String().split('T').first,
      endDate: _endDate?.toIso8601String().split('T').first,
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by reference ID...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    _searchController.clear();
                    _loadHistory();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onSubmitted: (_) => _loadHistory(),
            ),
          ),
          Consumer<CardPayProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading && provider.transactions.isEmpty) {
                return const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (provider.transactions.isEmpty) {
                return const Expanded(
                  child: Center(
                    child: Text('No transactions found'),
                  ),
                );
              }

              return Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.transactions.length,
                    itemBuilder: (context, index) {
                      final txn = provider.transactions[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(txn.txnStatus).withOpacity(0.1),
                            child: Icon(
                              _getStatusIcon(txn.txnStatus),
                              color: _getStatusColor(txn.txnStatus),
                              size: 20,
                            ),
                          ),
                          title: Text(_formatAmount(txn.amount)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(txn.merchantRefId),
                              Text(
                                _formatDate(txn.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(txn.txnStatus).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              txn.txnStatus.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _getStatusColor(txn.txnStatus),
                              ),
                            ),
                          ),
                          onTap: () => _showTransactionDetails(context, txn),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'success', child: Text('Success')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'failed', child: Text('Failed')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _startDate = date);
                      }
                    },
                    child: Text(_startDate != null
                        ? 'From: ${_formatDateForDisplay(_startDate!)}'
                        : 'Start Date'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (date != null) {
                        setState(() => _endDate = date);
                      }
                    },
                    child: Text(_endDate != null
                        ? 'To: ${_formatDateForDisplay(_endDate!)}'
                        : 'End Date'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = null;
                _startDate = null;
                _endDate = null;
                _searchController.clear();
              });
              Navigator.pop(context);
              _loadHistory();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadHistory();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, dynamic txn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Icon(
                    _getStatusIcon(txn.txnStatus),
                    size: 48,
                    color: _getStatusColor(txn.txnStatus),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    txn.txnStatus.toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(txn.txnStatus),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow('Amount', '₹${txn.amount.toStringAsFixed(2)}'),
                _buildDetailRow('Reference ID', txn.merchantRefId),
                if (txn.cardLastFour != null)
                  _buildDetailRow('Card', '****${txn.cardLastFour}'),
                if (txn.cardNetwork != null)
                  _buildDetailRow('Network', txn.cardNetwork!),
                if (txn.rrn != null)
                  _buildDetailRow('RRN', txn.rrn!),
                if (txn.charges != null)
                  _buildDetailRow('Charges', '₹${txn.charges!.toStringAsFixed(2)}'),
                if (txn.customerName != null)
                  _buildDetailRow('Customer', txn.customerName!),
                if (txn.customerMobile != null)
                  _buildDetailRow('Mobile', txn.customerMobile!),
                if (txn.customerEmail != null)
                  _buildDetailRow('Email', txn.customerEmail!),
                _buildDetailRow('Date', _formatDate(txn.createdAt)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'success':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.pending_rounded;
      default:
        return Icons.error_rounded;
    }
  }

  String _formatDate(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTimeString;
    }
  }

  String _formatAmount(double amount) {
  try {
    return '₹${amount.toStringAsFixed(2)}';
  } catch (_) {
    return '₹0.00';
  }
}

  String _formatDateForDisplay(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}