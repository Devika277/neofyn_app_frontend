// lib/screens/CardPay/cardpay_quick_actions.dart
import 'package:flutter/material.dart';

class CardPayQuickActions extends StatelessWidget {
  final VoidCallback onInitiatePayment;
  final VoidCallback onMoveToMain;
  final VoidCallback onViewLedger;
  final VoidCallback onWithdrawToBank; // ✅ Added new callback

  const CardPayQuickActions({
    Key? key,
    required this.onInitiatePayment,
    required this.onMoveToMain,
    required this.onViewLedger,
    required this.onWithdrawToBank, // ✅ Required parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.add_card_rounded,
            label: 'Pay with Card',
            color: Colors.blue,
            onTap: onInitiatePayment,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.account_balance_wallet_rounded,
            label: 'Move to Main',
            color: Colors.green,
            onTap: onMoveToMain,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.history_rounded,
            label: 'Ledger',
            color: Colors.orange,
            onTap: onViewLedger,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionCard(
            context,
            icon: Icons.currency_rupee_rounded,
            label: 'Withdraw',
            color: Colors.teal,
            onTap: onWithdrawToBank, // ✅ New action
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}