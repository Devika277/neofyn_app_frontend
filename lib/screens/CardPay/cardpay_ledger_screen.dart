// lib/screens/cardpay/cardpay_ledger_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cardpay_provider.dart';
import '../../models/cardpay_models.dart';

class CardPayLedgerScreen extends StatefulWidget {
  const CardPayLedgerScreen({Key? key}) : super(key: key);

  @override
  State<CardPayLedgerScreen> createState() => _CardPayLedgerScreenState();
}

class _CardPayLedgerScreenState extends State<CardPayLedgerScreen> {
  int _limit = 20;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadLedger();
  }

  Future<void> _loadLedger({bool loadMore = false}) async {
    if (_isLoadingMore) return;

    if (loadMore) {
      setState(() => _isLoadingMore = true);
    }

    try {
      final provider = Provider.of<CardPayProvider>(context, listen: false);
      await provider.fetchLedger(
        limit: _limit,
        offset: loadMore ? _offset : 0,
      );

      if (loadMore && provider.ledgerEntries.length < _limit) {
        setState(() => _hasMore = false);
      }

      if (loadMore) {
        setState(() => _offset += _limit);
      } else {
        setState(() => _offset = _limit);
      }
    } catch (e) {
      debugPrint('Error loading ledger: $e');
    } finally {
      if (loadMore && mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CardPay Ledger'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadLedger(),
          ),
        ],
      ),
      body: Consumer<CardPayProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.ledgerEntries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.ledgerEntries.isEmpty) {
            return const Center(
              child: Text('No ledger entries found'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.ledgerEntries.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == provider.ledgerEntries.length) {
                return _buildLoadingMore();
              }
              return _buildLedgerItem(provider.ledgerEntries[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildLedgerItem(CardPayWalletLedger entry) {
    final isCredit = entry.amount > 0;
    final color = isCredit ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isCredit ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCredit ? 'Credited' : 'Debited',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.remarks != null)
                  Text(
                    entry.remarks!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                Text(
                  _formatDate(entry.createdAt),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : ''}${entry.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'Balance: ${entry.balanceAfter.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMore() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  String _formatDate(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
    } catch (_) {
      return dateTimeString;
    }
  }
}