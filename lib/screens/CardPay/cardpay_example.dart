// lib/screens/cardpay_example.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cardpay_provider.dart';

class CardPayExampleScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('CardPay Example')),
      body: Consumer<CardPayProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${provider.errorMessage}'),
                  ElevatedButton(
                    onPressed: () => provider.clearError(),
                    child: Text('Dismiss'),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              // Wallet Balance
              Card(
                child: ListTile(
                  title: Text('Wallet Balance'),
                  subtitle: Text('₹${provider.walletBalance.toStringAsFixed(2)}'),
                ),
              ),
              SizedBox(height: 8),
              
              // User Balance
              if (provider.userBalance != null)
                Card(
                  child: ListTile(
                    title: Text('CardPay Balance'),
                    subtitle: Text('₹${provider.userBalance!.balance.toStringAsFixed(2)}'),
                  ),
                ),
              SizedBox(height: 16),

              // Initiate Payment Button
              ElevatedButton(
                onPressed: () => _initiatePayment(context, provider),
                child: Text('Initiate Payment'),
              ),
              SizedBox(height: 8),

              // Move to Main Button
              ElevatedButton(
                onPressed: () => _moveToMain(context, provider),
                child: Text('Move to Main Wallet'),
              ),
              SizedBox(height: 16),

              // Transaction History
              Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              if (provider.transactions.isEmpty)
                Text('No transactions found')
              else
                ...provider.transactions.take(5).map((txn) => ListTile(
                  title: Text('₹${txn.amount.toStringAsFixed(2)}'),
                  subtitle: Text(txn.merchantRefId),
                  trailing: Chip(
                    label: Text(txn.txnStatus.toUpperCase()),
                    backgroundColor: txn.txnStatus == 'success' 
                        ? Colors.green 
                        : txn.txnStatus == 'pending' 
                            ? Colors.orange 
                            : Colors.red,
                  ),
                )),
            ],
          );
        },
      ),
    );
  }

  void _initiatePayment(BuildContext context, CardPayProvider provider) async {
    final result = await provider.initiatePayment(
      amount: 100,
      mobile: '9876543210',
      name: 'John Doe',
      email: 'john@example.com',
      location: 'Delhi',
      lat: '28.6139',
      long: '77.2090',
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment initiated: ${result.merchantRefId}')),
      );
    }
  }

  void _moveToMain(BuildContext context, CardPayProvider provider) async {
    final result = await provider.moveToMain(50);
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Funds moved successfully')),
      );
    }
  }
}