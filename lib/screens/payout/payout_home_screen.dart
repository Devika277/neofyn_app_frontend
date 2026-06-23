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
  bool _dataLoadTriggered = false;

  static const Color bg = Color(0xFF0A0E0A);
  static const Color primary = Color(0xFF008169);
  static const Color error = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
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
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Payout Transfer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white70),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayoutHistoryScreen())),
            tooltip: 'History',
          ),
        ],
      ),
      body: Consumer<PayoutProvider>(builder: (context, provider, _) {
        if (provider.isLoading && provider.banks.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: primary));
        }
        if (provider.errorMessage.isNotEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 56, color: error)),
            const SizedBox(height: 16),
            Text(provider.errorMessage, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () { provider.clearError(); provider.loadMasterData(); },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ]));
        }
        return const PayoutFormScreen();
      }),
    );
  }
}