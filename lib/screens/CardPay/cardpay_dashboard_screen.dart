// lib/screens/cardpay/cardpay_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cardpay_provider.dart';
import 'cardpay_balance_card.dart';
import 'cardpay_transaction_list.dart';
import 'cardpay_quick_actions.dart';
import 'cardpay_initiate_screen.dart';
import 'cardpay_ledger_screen.dart';
import 'cardpay_history_screen.dart';

class CardPayDashboardScreen extends StatefulWidget {
  const CardPayDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CardPayDashboardScreen> createState() => _CardPayDashboardScreenState();
}

class _CardPayDashboardScreenState extends State<CardPayDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<CardPayProvider>(context, listen: false);
    await provider.initializeCardPay();
    await provider.fetchUserHistory(limit: 10);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Card Services'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Consumer<CardPayProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline_rounded, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      provider.clearError();
                      _loadData();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Balance Card
                  CardPayBalanceCard(
                    balance: provider.walletBalance,
                    userBalance: provider.userBalance,
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions
                  CardPayQuickActions(
                    onInitiatePayment: () => _navigateToInitiatePayment(context),
                    onMoveToMain: () => _showMoveToMainDialog(context, provider),
                    onViewLedger: () => _navigateToLedger(context),
                  ),
                  const SizedBox(height: 16),

                  // Recent Transactions
                  CardPayTransactionList(
                    transactions: provider.transactions,
                    onRefresh: _loadData,
                    onViewAll: () => _navigateToHistory(context),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToInitiatePayment(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CardPayInitiateScreen()),
    ).then((_) => _loadData());
  }

  void _showMoveToMainDialog(BuildContext context, CardPayProvider provider) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Main Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available balance: ₹${provider.walletBalance.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter valid amount')),
                );
                return;
              }

              if (amount > provider.walletBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Insufficient balance')),
                );
                return;
              }

              Navigator.pop(context);
              final result = await provider.moveToMain(amount);
              if (result != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result['message'] ?? 'Funds moved successfully')),
                );
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }

  void _navigateToLedger(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CardPayLedgerScreen()),
    );
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CardPayHistoryScreen()),
    );
  }
}