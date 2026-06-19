import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import 'aeps_transaction_screen.dart';
import 'bank_list_screen.dart';
import 'transaction_status_screen.dart';
import 'aeps_history_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NEOFYN BRAND TOKENS
// ─────────────────────────────────────────────────────────────────────────────
class AePSColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color background = Color(0xFF0A0E0A);
  static const Color cardColor = Color(0xFF1A1F1A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF008169);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderFocus = Color(0xFF008169);

  // Service card colors
  static const Color withdrawal = Color(0xFF2ECC71);
  static const Color balance = Color(0xFF3498DB);
  static const Color statement = Color(0xFFE67E22);
  static const Color aadhaarPay = Color(0xFF9B59B6);
  static const Color deposit = Color(0xFF16A085);
  static const Color history = Color(0xFF1ABC9C);
  static const Color bankList = Color(0xFF9B59B6);
  static const Color txnStatus = Color(0xFF1ABC9C);
  static const Color help = Color(0xFFE74C3C);
}

class AepsDashboardScreen extends StatelessWidget {
  const AepsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AepsProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E0A),
              Color(0xFF0F1A0F),
              Color(0xFF0A0E0A),
              Color(0xFF050805),
            ],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'AEPS Services',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 20),
                      onPressed: () async {
                        provider.clearMerchantData();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Merchant Info Card
                      _buildMerchantCard(provider),
                      const SizedBox(height: 20),

                      // Pipe Info
                      _buildPipeInfo(provider),
                      const SizedBox(height: 20),

                      // Service Buttons Grid
                      _buildServicesGrid(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMerchantCard(AepsProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AePSColors.primary, AePSColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AePSColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.store_rounded, color: Colors.white, size: 22),
              SizedBox(width: 10),
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
          const SizedBox(height: 16),
          _merchantInfoRow('Merchant ID', provider.merchantId ?? 'N/A'),
          const SizedBox(height: 8),
          _merchantInfoRow('Mobile', provider.mobileNo ?? 'N/A'),
          const SizedBox(height: 8),
         /* _merchantInfoRow('Aadhaar', provider.aadhaarNo != null
              ? 'XXXX XXXX ${provider.aadhaarNo!.substring(provider.aadhaarNo!.length - 4)}'
              : 'N/A'),*/
          _merchantInfoRow('Aadhaar', _safeMaskAadhaar(provider.aadhaarNo)),

        ],
      ),
    );
  }
  String _safeMaskAadhaar(String? aadhaar) {
    if (aadhaar == null || aadhaar.isEmpty) return 'N/A';
    if (aadhaar.length < 4) return aadhaar;
    return 'XXXX XXXX ${aadhaar.substring(aadhaar.length - 4)}';
  }
  Widget _merchantInfoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPipeInfo(AepsProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AePSColors.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AePSColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.settings_input_component_rounded,
                color: AePSColors.success, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Active Pipe',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Ready for transactions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AePSColors.success, AePSColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Pipe ${provider.pipe ?? "1"}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServicesGrid(BuildContext context) {
    final services = [
      _ServiceItem('Cash\nWithdrawal', Icons.money_rounded, AePSColors.withdrawal, 'CW'),
      _ServiceItem('Balance\nEnquiry', Icons.account_balance_wallet_rounded, AePSColors.balance, 'BE'),
      _ServiceItem('Mini\nStatement', Icons.receipt_long_rounded, AePSColors.statement, 'MS'),
      _ServiceItem('Aadhaar\nPay', Icons.credit_card_rounded, AePSColors.aadhaarPay, 'AP'),
      _ServiceItem('Cash\nDeposit', Icons.attach_money_rounded, AePSColors.deposit, 'CD'),
      _ServiceItem('Bank\nList', Icons.account_balance_rounded, AePSColors.bankList, 'BANKS'),
      _ServiceItem('Transaction\nHistory', Icons.history_rounded, AePSColors.history, 'HISTORY'),
      _ServiceItem('Txn\nStatus', Icons.track_changes_rounded, AePSColors.txnStatus, 'STATUS'),
      _ServiceItem('Help', Icons.help_outline_rounded, AePSColors.help, 'HELP'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final service = services[index];
        return _buildServiceCard(
          context: context,
          title: service.title,
          icon: service.icon,
          color: service.color,
          type: service.type,
        );
      },
    );
  }

  Widget _buildServiceCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required String type,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleServiceTap(context, type),
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.1),
        highlightColor: color.withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AePSColors.cardColor,
                AePSColors.cardColor.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Icon(icon, size: 22, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleServiceTap(BuildContext context, String type) {
    switch (type) {
      case 'CW':
      case 'BE':
      case 'MS':
      case 'AP':
      case 'CD':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AepsTransactionScreen(serviceType: type),
          ),
        );
        break;
      case 'BANKS':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BankListScreen()),
        );
        break;
      case 'HISTORY':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AepsHistoryScreen()),
        );
        break;
      case 'STATUS':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TransactionStatusScreen()),
        );
        break;
      case 'HELP':
        _showHelpDialog(context);
        break;
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AePSColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AePSColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.help_outline_rounded,
                  color: AePSColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'AEPS Help',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _helpItem(Icons.money_rounded, 'Cash Withdrawal',
                'Withdraw money using Aadhaar'),
            const SizedBox(height: 12),
            _helpItem(Icons.account_balance_wallet_rounded, 'Balance Enquiry',
                'Check account balance'),
            const SizedBox(height: 12),
            _helpItem(Icons.receipt_long_rounded, 'Mini Statement',
                'Get last 5-10 transactions'),
            const SizedBox(height: 12),
            _helpItem(Icons.credit_card_rounded, 'Aadhaar Pay',
                'Customer pays merchant via Aadhaar'),
            const SizedBox(height: 12),
            _helpItem(Icons.attach_money_rounded, 'Cash Deposit',
                'Deposit cash into bank account'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: AePSColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpItem(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AePSColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: AePSColors.primaryLight, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceItem {
  final String title;
  final IconData icon;
  final Color color;
  final String type;

  _ServiceItem(this.title, this.icon, this.color, this.type);
}