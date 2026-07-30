// lib/screens/CardPayOut/cardpay_out_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/cardpay_out_provider.dart';
import '../../models/cardpay_out_models.dart';
import 'cardpay_out_initiate_screen.dart';
import 'cardpay_out_beneficiaries_screen.dart';
import 'cardpay_out_history_screen.dart';

class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);
  static const Color textDarkHint = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color processing = Color(0xFF8B5CF6);
  static const Color borderDark = Color(0xFF2A342A);
}

class CardPayOutDashboardScreen extends StatefulWidget {
  const CardPayOutDashboardScreen({Key? key}) : super(key: key);

  @override
  State<CardPayOutDashboardScreen> createState() => _CardPayOutDashboardScreenState();
}

class _CardPayOutDashboardScreenState extends State<CardPayOutDashboardScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isRefreshing = true);
      final provider = Provider.of<CardPayOutProvider>(context, listen: false);
      await Future.wait([
        provider.initializeCardPayOut(),
        provider.fetchHistory(),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  String _formatCurrency(double amount) {
    final format = NumberFormat.currency(symbol: '₹', decimalDigits: 2);
    return format.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'Withdraw to Bank',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 16 : 18,
            color: AppColors.textWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isRefreshing ? Iconsax.timer_1 : Iconsax.refresh,
              color: AppColors.textDarkSecondary,
              size: 20,
            ),
            onPressed: _isRefreshing ? null : _loadData,
          ),
        ],
      ),
      body: Consumer<CardPayOutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && !_isRefreshing) {
            return _buildLoadingState();
          }

          if (provider.errorMessage != null && !_isRefreshing) {
            return _buildErrorState(provider);
          }

          return RefreshIndicator(
            onRefresh: _loadData,
            color: AppColors.primary,
            backgroundColor: AppColors.darkSurface,
            displacement: 40,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Balance Card
                      _buildBalanceCard(provider),
                      SizedBox(height: isSmallScreen ? 16 : 20),

                      // Quick Actions
                      _buildSectionHeader('Quick Actions', Iconsax.flash_1, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 10 : 12),
                      _buildQuickActions(context, provider, isSmallScreen),
                      SizedBox(height: isSmallScreen ? 20 : 24),

                      // Limits Info
                      if (provider.limits != null) ...[
                        _buildSectionHeader('Withdrawal Limits', Iconsax.chart_2, isSmallScreen),
                        SizedBox(height: isSmallScreen ? 10 : 12),
                        _buildLimitsCard(provider.limits!),
                        SizedBox(height: isSmallScreen ? 20 : 24),
                      ],

                      // Recent Transactions Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('Recent Withdrawals', Iconsax.receipt_1, isSmallScreen),
                          if (provider.transactions.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const CardPayOutHistoryScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 8 : 12,
                                  vertical: isSmallScreen ? 4 : 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'View All',
                                      style: GoogleFonts.poppins(
                                        fontSize: isSmallScreen ? 10 : 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primaryLight,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Iconsax.arrow_right_3,
                                      size: isSmallScreen ? 12 : 14,
                                      color: AppColors.primaryLight,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: isSmallScreen ? 10 : 12),

                      // Transaction List
                      _buildTransactionList(provider, isSmallScreen),

                      SizedBox(height: isSmallScreen ? 20 : 32),
                    ]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(CardPayOutProvider provider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CardPay Wallet',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatCurrency(provider.balance),
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Iconsax.bank,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Available for withdrawal badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.tick_circle, size: 12, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  'Available for withdrawal',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context, CardPayOutProvider provider, bool isSmallScreen) {
    final actions = [
      {
        'title': 'Withdraw',
        'icon': Iconsax.money_send,
        'color': AppColors.primaryLight,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CardPayOutInitiateScreen()),
          ).then((_) => _loadData());
        },
      },
      {
        'title': 'Beneficiaries',
        'icon': Iconsax.people,
        'color': AppColors.processing,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CardPayOutBeneficiariesScreen()),
          ).then((_) => _loadData());
        },
      },
      {
        'title': 'History',
        'icon': Iconsax.clock,
        'color': AppColors.warning,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CardPayOutHistoryScreen()),
          );
        },
      },
    ];

    return Row(
      children: actions.map((action) {
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 3 : 5),
            child: GestureDetector(
              onTap: action['onTap'] as VoidCallback,
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 14 : 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                      decoration: BoxDecoration(
                        color: (action['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        action['icon'] as IconData,
                        color: action['color'] as Color,
                        size: isSmallScreen ? 18 : 20,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 8 : 10),
                    Text(
                      action['title'] as String,
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDarkSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLimitsCard(CardPayOutLimits limits) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily & Monthly Limits
          Row(
            children: [
              Expanded(
                child: _buildLimitItem(
                  'Daily Used',
                  limits.dailyUsed,
                  limits.dailyLimit,
                  AppColors.processing,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLimitItem(
                  'Monthly Used',
                  limits.monthlyUsed,
                  limits.monthlyLimit,
                  AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Min & Max Amount
          Row(
            children: [
              Expanded(
                child: _buildAmountLimit(
                  'Min Amount',
                  100,
                  AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildAmountLimit(
                  'Max Amount',
                  50000,
                  AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitItem(String label, double used, double limit, Color color) {
    final percentage = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textDarkHint,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '₹${used.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.borderDark,
              color: percentage > 0.8 ? AppColors.error : color,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Limit: ₹${limit.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: AppColors.textDarkHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountLimit(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: AppColors.textDarkHint,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                label.contains('Min') ? Iconsax.arrow_down_2 : Iconsax.arrow_up_2,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 4),
              Text(
                '₹${amount.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(CardPayOutProvider provider, bool isSmallScreen) {
    if (provider.transactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: [
            Icon(
              Iconsax.receipt_1,
              size: 48,
              color: AppColors.textDarkHint.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No withdrawal transactions',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDarkHint,
              ),
            ),
          ],
        ),
      );
    }

    final recentTransactions = provider.transactions.take(5).toList();

    return Column(
      children: recentTransactions.map((txn) {
        final isSuccess = txn.status.toLowerCase() == 'success';
        final isPending = txn.status.toLowerCase() == 'pending';
        final statusColor = isSuccess
            ? AppColors.success
            : (isPending ? AppColors.warning : AppColors.error);
        final statusIcon = isSuccess
            ? Iconsax.tick_circle
            : (isPending ? Iconsax.timer_1 : Iconsax.close_circle);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: isSmallScreen ? 16 : 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₹${txn.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            txn.mode,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ref: ${txn.merchantRefId.length > 16 ? '${txn.merchantRefId.substring(0, 16)}...' : txn.merchantRefId}',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: AppColors.textDarkHint,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      txn.status.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 7,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Iconsax.calendar, size: 10, color: AppColors.textDarkHint),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(txn.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          color: AppColors.textDarkHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Iconsax.arrow_right_3, size: 14, color: AppColors.textDarkHint),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isSmall) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Icon(icon, size: isSmall ? 16 : 18, color: AppColors.primaryLight),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: isSmall ? 15 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textWhite,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dateTime);

      if (diff.inDays == 0) {
        return 'Today';
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return DateFormat('dd MMM').format(dateTime);
      }
    } catch (_) {
      return dateTimeString;
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Loading dashboard...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textDarkSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(CardPayOutProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.warning_2,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Something went wrong',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textWhite,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                provider.errorMessage ?? 'An unexpected error occurred',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textDarkSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    provider.clearError();
                    _loadData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.refresh, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Retry',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
}