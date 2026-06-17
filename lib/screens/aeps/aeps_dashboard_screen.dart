import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import 'aeps_transaction_screen.dart';
import 'bank_list_screen.dart';
import 'transaction_status_screen.dart';
import 'aeps_history_screen.dart';

class AepsDashboardScreen extends StatelessWidget {
  const AepsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AepsProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'AEPS Services',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              provider.clearMerchantData();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Merchant Info Card (unchanged)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.store, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Merchant Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'ID: ${provider.merchantId ?? "N/A"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Text(
                  'Mobile: ${provider.mobileNo ?? "N/A"}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Service Buttons Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1, // slightly taller to fit text
              children: [
                // Transaction History (already existed)
                _buildServiceCard(
                  title: 'Transaction History',
                  icon: Icons.history,
                  color: const Color(0xFF1ABC9C),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AepsHistoryScreen()),
                  ),
                ),
                // Cash Withdrawal
                _buildServiceCard(
                  title: 'Cash Withdrawal',
                  icon: Icons.money,
                  color: const Color(0xFF2ECC71),
                  onTap: () => _navigateToTransaction(context, 'CW'),
                ),
                // Balance Enquiry
                _buildServiceCard(
                  title: 'Balance Enquiry',
                  icon: Icons.account_balance_wallet,
                  color: const Color(0xFF3498DB),
                  onTap: () => _navigateToTransaction(context, 'BE'),
                ),
                // Mini Statement
                _buildServiceCard(
                  title: 'Mini Statement',
                  icon: Icons.receipt,
                  color: const Color(0xFFE67E22),
                  onTap: () => _navigateToTransaction(context, 'MS'),
                ),
                // ✅ NEW: Aadhaar Pay
                _buildServiceCard(
                  title: 'Aadhaar Pay',
                  icon: Icons.credit_card,
                  color: const Color(0xFF9B59B6),
                  onTap: () => _navigateToTransaction(context, 'AP'),
                ),
                // ✅ NEW: Cash Deposit
                _buildServiceCard(
                  title: 'Cash Deposit',
                  icon: Icons.attach_money,
                  color: const Color(0xFF16A085),
                  onTap: () => _navigateToTransaction(context, 'CD'),
                ),
                // Bank List (existing)
                _buildServiceCard(
                  title: 'Bank List',
                  icon: Icons.account_balance,
                  color: const Color(0xFF9B59B6),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BankListScreen()),
                  ),
                ),
                // Transaction Status (existing)
                _buildServiceCard(
                  title: 'Transaction Status',
                  icon: Icons.history,
                  color: const Color(0xFF1ABC9C),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionStatusScreen()),
                  ),
                ),
                // Help (existing)
                _buildServiceCard(
                  title: 'Help',
                  icon: Icons.help_outline,
                  color: const Color(0xFFE74C3C),
                  onTap: () => _showHelpDialog(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      color: const Color(0xFF1A1A1A),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToTransaction(BuildContext context, String serviceType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AepsTransactionScreen(serviceType: serviceType),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('AEPS Help', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('• Cash Withdrawal: Withdraw money using Aadhaar',
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('• Balance Enquiry: Check account balance',
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('• Mini Statement: Get last 5-10 transactions',
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('• Aadhaar Pay: Customer pays merchant (debit from customer)',
                style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('• Cash Deposit: Deposit cash into own bank account using Aadhaar',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF2ECC71))),
          ),
        ],
      ),
    );
  }
}