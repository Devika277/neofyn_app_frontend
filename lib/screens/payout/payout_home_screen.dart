// lib/screens/payout/payout_home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/payout_provider.dart';
import '../../screens/payout/payout_form.dart';
import '../payout/payout_history_screen.dart';

class PayoutHomeScreen extends StatefulWidget {
  const PayoutHomeScreen({Key? key}) : super(key: key);
  
  @override
  State<PayoutHomeScreen> createState() => _PayoutHomeScreenState();
}

class _PayoutHomeScreenState extends State<PayoutHomeScreen> {
  // Track if master data has been loaded to avoid multiple calls
  bool _dataLoadTriggered = false;

  @override
  void initState() {
    super.initState();
    // Load master data exactly once when screen first appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_dataLoadTriggered && mounted) {
        _dataLoadTriggered = true;
        context.read<PayoutProvider>().loadMasterData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Transfer'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // Navigate to transaction history
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PayoutHistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<PayoutProvider>(
        builder: (context, provider, child) {
          // Show loader while master data is loading AND no data yet
          if (provider.isLoading && provider.banks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Show error with retry button
          if (provider.errorMessage.isNotEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // ✅ Fixed: Clear error and reload instead of calling reset()
                      provider.clearError();
                      provider.loadMasterData();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          // Once data is loaded, render the form
          return const PayoutFormScreen();
        },
      ),
    );
  }
}