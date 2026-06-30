// lib/screens/history/history_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../screens/aeps/aeps_history_screen.dart';
import '../../screens/payout/payout_history_screen.dart';
import '../BBPS/bbps_history_screen.dart';
import '../dmt/dmt_history_screen.dart';
import '../../screens/recharge/recharge_history_screen.dart';

class HistoryDashboardScreen extends StatefulWidget {
  const HistoryDashboardScreen({Key? key}) : super(key: key);

  @override
  State<HistoryDashboardScreen> createState() => _HistoryDashboardScreenState();
}

class _HistoryDashboardScreenState extends State<HistoryDashboardScreen> {
  static const Color _bg = Color(0xFF0A0E0A);
  static const Color _primary = Color(0xFF008169);
  static const Color _primaryLight = Color(0xFF1AA88A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Transaction History',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // ✅ FIX: Use SingleChildScrollView instead of Column
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 3,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Select Transaction Type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'View your AEPS, DMT, BBPS and Payout transaction history',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),

            // AEPS History Card
            _buildHistoryCard(
              icon: Icons.fingerprint_rounded,
              title: 'AEPS Transactions',
              subtitle: 'Aadhaar Enabled Payment System',
              details: [
                'Cash Withdrawal',
                'Balance Enquiry',
                'Mini Statement',
                'Aadhaar Pay',
              ],
              gradientColors: const [_primary, _primaryLight],
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AepsHistoryScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // DMT History Card
            _buildHistoryCard(
              icon: Icons.swap_horiz_rounded,
              title: 'DMT Transactions',
              subtitle: 'Domestic Money Transfer',
              details: [
                'Money Transfers',
                'Beneficiary Payments',
                'Transaction Status',
              ],
              gradientColors: const [Color(0xFF7B9FE0), Color(0xFF5B7FC0)],
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DmtHistoryScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // ✅ NEW: BBPS History Card
            _buildHistoryCard(
              icon: Icons.receipt_long_rounded,
              title: 'BBPS Transactions',
              subtitle: 'Bharat Bill Payment System',
              details: [
                'Electricity',
                'Gas',
                'Fastag',
                'Water',
                'DTH',
                'Insurance',
              ],
              gradientColors: const [Color(0xFFE07070), Color(0xFFC05050)],
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BbpsHistoryScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // ✅ Recharge History Card
            _buildHistoryCard(
              icon: Icons.phone_android_rounded,
              title: 'Recharge Transactions',
              subtitle: 'Mobile & DTH Recharges',
              details: ['Prepaid', 'Postpaid', 'DTH', 'Data Card'],
              gradientColors: const [Color(0xFF70CBCB), Color(0xFF50A0A0)],
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RechargeHistoryScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // Payout History Card
            _buildHistoryCard(
              icon: Icons.send_rounded,
              title: 'Payout Transactions',
              subtitle: 'Money Transfer via NEFT',
              details: [
                'Fund Transfers',
                'Beneficiary Payments',
                'NEFT Transactions',
              ],
              gradientColors: const [Color(0xFFE67E22), Color(0xFFF59E0B)],
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PayoutHistoryScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> details,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors.map((c) => c.withOpacity(0.15)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gradientColors.first.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: gradientColors.first.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: gradientColors.first, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: gradientColors.first.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: gradientColors.first,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: details.map((detail) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: gradientColors.first.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: gradientColors.first.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    detail,
                    style: TextStyle(
                      color: gradientColors.first,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
