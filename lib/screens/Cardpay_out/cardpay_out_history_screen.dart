// lib/screens/CardPayOut/cardpay_out_history_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cardpay_out_provider.dart';
import '../../models/cardpay_out_models.dart';

class CardPayOutHistoryScreen extends StatefulWidget {
  const CardPayOutHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CardPayOutHistoryScreen> createState() => _CardPayOutHistoryScreenState();
}

class _CardPayOutHistoryScreenState extends State<CardPayOutHistoryScreen> {
  String? _selectedStatus;
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final provider = Provider.of<CardPayOutProvider>(context, listen: false);
    await provider.fetchHistory(
      status: _selectedStatus,
      from: _startDate?.toIso8601String().split('T').first,
      to: _endDate?.toIso8601String().split('T').first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdrawal History'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Consumer<CardPayOutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.transactions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No Withdrawal History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your withdrawal transactions will appear here',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter summary
              if (_selectedStatus != null || _startDate != null || _endDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.grey.shade100,
                  child: Row(
                    children: [
                      const Text('Filters: '),
                      if (_selectedStatus != null)
                        Chip(
                          label: Text(_selectedStatus!.toUpperCase()),
                          onDeleted: () {
                            setState(() {
                              _selectedStatus = null;
                              _loadHistory();
                            });
                          },
                        ),
                      if (_startDate != null)
                        Chip(
                          label: Text('From: ${_formatDateFromDateTime(_startDate!)}'),
                          onDeleted: () {
                            setState(() {
                              _startDate = null;
                              _loadHistory();
                            });
                          },
                        ),
                      if (_endDate != null)
                        Chip(
                          label: Text('To: ${_formatDateFromDateTime(_endDate!)}'),
                          onDeleted: () {
                            setState(() {
                              _endDate = null;
                              _loadHistory();
                            });
                          },
                        ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.transactions.length + 1,
                    itemBuilder: (context, index) {
                      if (index == provider.transactions.length) {
                        if (provider.transactions.length >= _pageSize) {
                          return _buildLoadMore();
                        }
                        return const SizedBox.shrink();
                      }
                      return _buildTransactionItem(provider.transactions[index]);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTransactionItem(CardPayOutTransaction txn) {
    // ✅ FIX: Use 'status' instead of 'txnStatus'
    final isSuccess = txn.status == 'success';
    final isPending = txn.status == 'pending';
    final statusColor = isSuccess ? Colors.green : (isPending ? Colors.orange : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showTransactionDetails(txn),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '₹${txn.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      txn.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.account_balance_rounded, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    txn.mode,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.credit_card_rounded, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    txn.merchantRefId,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    txn.accountHolderName ?? 'N/A',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    _formatDateFromString(txn.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
              if (txn.utr != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.qr_code_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      'UTR: ${txn.utr}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
              if (txn.failureReason != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 14, color: Colors.red),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        txn.failureReason!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMore() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _currentPage++;
              _loadHistory();
            });
          },
          child: const Text('Load More'),
        ),
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
                        ? 'From: ${_formatDateFromDateTime(_startDate!)}'
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
                        ? 'To: ${_formatDateFromDateTime(_endDate!)}'
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

  void _showTransactionDetails(CardPayOutTransaction txn) {
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
                  child: Column(
                    children: [
                      Icon(
                        txn.status == 'success' ? Icons.check_circle_rounded :
                        txn.status == 'pending' ? Icons.pending_rounded :
                        Icons.error_rounded,
                        size: 48,
                        color: txn.status == 'success' ? Colors.green :
                               txn.status == 'pending' ? Colors.orange : Colors.red,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        txn.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: txn.status == 'success' ? Colors.green :
                                 txn.status == 'pending' ? Colors.orange : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 32),
                _buildDetailRow('Reference ID', txn.merchantRefId),
                _buildDetailRow('Amount', '₹${txn.amount.toStringAsFixed(2)}'),
                _buildDetailRow('Mode', txn.mode),
                _buildDetailRow('UTR', txn.utr ?? 'N/A'),
                _buildDetailRow('Charges', '₹${txn.charges.toStringAsFixed(2)}'),
                if (txn.accountHolderName != null) ...[
                  const Divider(height: 24),
                  _buildSectionTitle('Beneficiary Details'),
                  _buildDetailRow('Name', txn.accountHolderName ?? 'N/A'),
                  _buildDetailRow('Account', txn.accountNumber ?? 'N/A'),
                ],
                const Divider(height: 24),
                _buildDetailRow('Date', _formatDateTime(txn.createdAt)),
                if (txn.processedAt != null)
                  _buildDetailRow('Processed At', _formatDateTime(txn.processedAt!)),
                if (txn.failureReason != null)
                  _buildDetailRow('Failure Reason', txn.failureReason!),
              ],
            ),
          );
        },
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

  String _formatDateFromString(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (_) {
      return dateTimeString;
    }
  }

  String _formatDateFromDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTimeString;
    }
  }
}