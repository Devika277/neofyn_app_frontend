// lib/screens/history/history_dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/screens/payout/payout_status_screen.dart';
import '../../screens/aeps/aeps_history_screen.dart';
import '../../screens/payout/payout_history_screen.dart';

class HistoryDashboardScreen extends StatefulWidget {
  const HistoryDashboardScreen({Key? key}) : super(key: key);

  @override
  State<HistoryDashboardScreen> createState() => _HistoryDashboardScreenState();
}

class _HistoryDashboardScreenState extends State<HistoryDashboardScreen> {
  static const Color _bg = Color(0xFF0A0E0A);
  static const Color _card = Color(0xFF1A1F1A);
  static const Color _primary = Color(0xFF008169);
  static const Color _primaryLight = Color(0xFF1AA88A);

  String? _lastPayoutRefId;
  bool _loadingRefId = true;

  @override
  void initState() {
    super.initState();
    _loadLastTransactionRef();
  }

  // ✅ Load the last transaction reference ID
  Future<void> _loadLastTransactionRef() async {
    print('📜 [HISTORY DASHBOARD] Loading last payout ref ID...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final refId = prefs.getString('last_payout_ref_id');
      print('📜 [HISTORY DASHBOARD] Last ref ID: $refId');
      if (mounted) {
        setState(() {
          _lastPayoutRefId = refId;
          _loadingRefId = false;
        });
      }
    } catch (e) {
      print('❌ [HISTORY DASHBOARD] Error loading ref ID: $e');
      if (mounted) {
        setState(() => _loadingRefId = false);
      }
    }
  }

  // ✅ Navigate to last payout status
  /*void _viewLastPayout() async {
    print('📜 [HISTORY DASHBOARD] View last payout tapped');

    // Reload fresh from storage
    final prefs = await SharedPreferences.getInstance();
    final refId = prefs.getString('last_payout_ref_id');

    print('📜 [HISTORY DASHBOARD] Current ref ID: $refId');

    if (refId != null && refId.isNotEmpty) {
      print('✅ [HISTORY DASHBOARD] Navigating to PayoutStatusScreen');
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PayoutStatusScreen(merchantRefId: refId),
          ),
        );
      }
    } else {
      print('⚠️ [HISTORY DASHBOARD] No recent payout found');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No recent payout transactions found', style: TextStyle(fontSize: 12)),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }*/

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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Header
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
              'View your AEPS and Payout transaction history',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 28),

            // AEPS History Card
            _buildHistoryCard(
              context,
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
                print('🔄 [HISTORY DASHBOARD] AEPS History tapped');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AepsHistoryScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Payout History Card
            _buildHistoryCard(
              context,
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
                print('🔄 [HISTORY DASHBOARD] Payout History tapped');
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PayoutHistoryScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // ✅ Show current last transaction info
            if (_loadingRefId)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: CircularProgressIndicator(color: _primary, strokeWidth: 2),
              )
            else if (_lastPayoutRefId != null && _lastPayoutRefId!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: _primary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last transaction: $_lastPayoutRefId',
                        style: const TextStyle(color: _primary, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
      BuildContext context, {
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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors.map((c) => c.withOpacity(0.15)).toList(),
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradientColors.first.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: gradientColors.first.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: gradientColors.first, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: gradientColors.first.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: gradientColors.first,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: details.map((detail) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: gradientColors.first.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: gradientColors.first.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    detail,
                    style: TextStyle(
                      color: gradientColors.first,
                      fontSize: 11,
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