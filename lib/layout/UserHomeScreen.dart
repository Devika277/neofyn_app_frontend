// ─────────────────────────────────────────────────────────────────────────────
//  user_home_screen.dart – PROFESSIONAL FINTECH UI WITH BANNER SLIDER
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:my_app/models/wallet_models.dart';
import 'package:my_app/providers/aeps_provider.dart';
import 'package:my_app/screens/aeps/pipe_selection_screen.dart';
import 'package:my_app/services/Recharges/rechargeFragment.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/screens/account/login_screen.dart';
import '../screens/dmt1/dmt_home_screen.dart';
import '../screens/account/Profile_screen.dart';
import '../screens/history/history_dashboard_screen.dart';
import '../services/AEPS/api_service.dart';
import '../providers/wallet_provider.dart';
import '../screens//aeps/aeps_wallet_dialog.dart';
import 'package:my_app/widgets/add_fund_sheet.dart';
import '../screens/recharge/RechargeCategoryScreen.dart';
import '../services/AEPS/matm_service.dart';
import '../screens/ppi_dmt/dmt_phone_entry.dart';
import '../../services/session_service.dart';
import '../screens/dmt/dmt_selector_screen.dart';
import '../screens/bbps/onboarding_page.dart';
import '../screens/bbps/bill_payment_page.dart';
import '../screens/recharge/recharge_screen.dart';
import '../screens/commission/commission_history_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  BRAND COLORS - Cohesive Green & Dark Theme
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFF008169);
  static const primaryLight = Color(0xFF1AA88A);
  static const primaryDark = Color(0xFF005F4E);
  static const accent = Color(0xFF00C897);
  static const white = Colors.white;
  static const error = Color(0xFFFF5252);
  static const success = Color(0xFF00E676);
  static const warning = Color(0xFFFFB74D);
  static const bg = Color(0xFF0A0E0A);
  static const surface = Color(0xFF151915);
  static const card = Color(0xFF1A1F1A);
  static const textSecondary = Color(0xFF9CA3AF);
  static const textHint = Color(0xFF6B7280);
  static const border = Color(0xFF2A342A);
}

// ─────────────────────────────────────────────────────────────────────────────
//  USER HOME SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});
  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedIndex = 0;
  String _name = '';
  String _phone = '';
  String _userId = '';
  bool _isBBPSOnboarded = false;
  bool _isCheckingBBPS = false;
  bool _isAEPSOnboarded = false;
  bool _isCheckingAEPS = false;
  String get _userPhone => _phone.replaceAll(RegExp(r'\s+'), '').replaceAll('+91', '').trim();
  late final WalletProvider _walletProvider = WalletProvider();

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('userId') ?? '';
    final name = prefs.getString('name') ?? 'Merchant';

    setState(() {
      _name = name;
      _phone = prefs.getString('phone') ?? '';
      _userId = uid.isNotEmpty ? uid : 'PN8472193';
    });

    if (uid.isNotEmpty) {
      _walletProvider.setUserId(uid);
      _walletProvider.setUserName(name);
      _checkBBPSStatus();
      _checkAEPSStatus();
    }
  }

  Future<void> _checkAEPSStatus() async {
    if (_isCheckingAEPS) return;
    setState(() => _isCheckingAEPS = true);

    try {
      final isOnboarded = await ApiService().checkBBPSOnboardingStatus(_userId);

      if (mounted) {
        setState(() => _isAEPSOnboarded = isOnboarded);
      }
    } catch (e) {
      debugPrint('❌ [AEPS] Status check error: $e');
    } finally {
      if (mounted) setState(() => _isCheckingAEPS = false);
    }
  }

  void _handleProfileNavigation() {
    if (_isAEPSOnboarded) {
      setState(() => _selectedIndex = 3);
    } else {
      _showProfileBlockedDialog();
    }
  }

  void _showProfileBlockedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [AppColors.warning, Colors.orange]),
              ),
              child: const Icon(Icons.person_off_rounded, color: Colors.white, size: 32),
            ),
            const SizedBox(height: 20),
            const Text(
              'Profile Access Restricted',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Please complete the AEPS merchant onboarding first to access your profile.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkBBPSStatus() async {
    if (_isCheckingBBPS) return;
    setState(() => _isCheckingBBPS = true);

    try {
      final isOnboarded = await ApiService().checkBBPSOnboardingStatus(_userId);

      if (mounted) {
        setState(() => _isBBPSOnboarded = isOnboarded);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isBBPSOnboarded', isOnboarded);
      }
    } catch (e) {
      debugPrint('❌ [BBPS] Error: $e');
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        setState(() => _isBBPSOnboarded = prefs.getBool('isBBPSOnboarded') ?? false);
      }
    } finally {
      if (mounted) setState(() => _isCheckingBBPS = false);
    }
  }

  Future<void> _logout() async {
    await SessionService.clearSession();
    await SharedPreferences.getInstance().then((p) => p.clear());
    await ApiService.clearUser();
    if (!mounted) return;
    Provider.of<AepsProvider>(context, listen: false).clearMerchantData();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false,
      );
    }
  }

  void _onMicroATMTap() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('Micro ATM', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 20),
              _AtmOption(Icons.account_balance_outlined, 'Balance Enquiry', () async {
                Navigator.pop(ctx);
                final r = await MatmService.balanceEnquiry(_userPhone);
                if (mounted) _showResult(r);
              }),
              const SizedBox(height: 12),
              _AtmOption(Icons.payments_outlined, 'Cash Withdrawal', () {
                Navigator.pop(ctx);
                final ctrl = TextEditingController();
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Enter Amount', style: TextStyle(color: Colors.white)),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: '₹ 0',
                        hintStyle: TextStyle(color: Colors.white24),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent, width: 2)),
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () { Navigator.pop(c); _doWithdrawal(ctrl.text.trim()); },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Proceed'),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doWithdrawal(String amount) async {
    if (amount.isEmpty) { _showToast('Enter amount', isError: true); return; }
    final r = await MatmService.cashWithdrawal(_userPhone, amount);
    if (mounted) _showResult(r);
  }

  void _showResult(Map<String, dynamic> r) {
    if (!mounted) return;
    final isSuccess = r['success'] == true;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isSuccess ? 'Success' : 'Error', style: TextStyle(color: isSuccess ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700)),
        content: Text('${r['data'] ?? r['error']}', style: const TextStyle(color: Colors.white70)),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? AppColors.error : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  void _onServiceTap(String serviceName) {
    HapticFeedback.lightImpact();
    switch (serviceName) {
      case 'AEPS': _navigateToAEPS(); break;
      case 'DMT': Navigator.push(context, MaterialPageRoute(builder: (_) => const DMTSelectorScreen())); break;
      case 'Recharge': Navigator.push(context, MaterialPageRoute(builder: (_) => RechargePage())); break;
      case 'Bills': _handleBillsNavigation(); break;
      // case 'PPI DMT': Navigator.push(context, MaterialPageRoute(builder: (_) => const DmtPhoneEntryPage())); break;
      default: _showToast('Coming soon!');
    }
  }

  void _navigateToAEPS() {
    final aeps = Provider.of<AepsProvider>(context, listen: false);
    if (aeps.authToken == null) aeps.loadFromStorage();
    if (aeps.authToken == null || aeps.userId == null) { _showToast('Please login again', isError: true); return; }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PipeSelectionScreen()));
  }

  void _handleBillsNavigation() {
    if (_isCheckingBBPS) { _showToast('Checking status...'); return; }
    if (_isBBPSOnboarded) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BillPaymentScreen()));
    } else {
      _showOnboardingDialog();
    }
  }

  void _navigateToOnboarding() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => OnboardingPage(onOnboardingComplete: () { _checkBBPSStatus(); _showToast('Onboarding completed! 🎉'); })));
  }

  void _showOnboardingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent])),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('BBPS Onboarding Required', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Complete onboarding to access bill payments.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60, fontSize: 14)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Later', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _navigateToOnboarding(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Start Onboarding', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) SystemNavigator.pop(); },
      child: ChangeNotifierProvider.value(
        value: _walletProvider,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                HomeDashboard(onLogout: _logout, onServiceTap: _onServiceTap, isBBPSOnboarded: _isBBPSOnboarded, isCheckingBBPS: _isCheckingBBPS),
                ServicesFullPage(onServiceTap: _onServiceTap),
                HistoryDashboardScreen(),
                ProfilePage(onLogout: _logout),
              ],
            ),
          ),
          bottomNavigationBar: _buildNavBar(),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: AppColors.textHint,
          currentIndex: _selectedIndex,
          onTap: (i) {
            HapticFeedback.selectionClick();
            if (i == 3) {
              _handleProfileNavigation();
            } else {
              setState(() => _selectedIndex = i);
            }
          },
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Services'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HOME DASHBOARD WITH BANNER SLIDER
// ─────────────────────────────────────────────────────────────────────────────
class HomeDashboard extends StatelessWidget {
  final VoidCallback onLogout;
  final void Function(String) onServiceTap;
  final bool isBBPSOnboarded;
  final bool isCheckingBBPS;

  const HomeDashboard({
    super.key, required this.onLogout,
    required this.onServiceTap, this.isBBPSOnboarded = false, this.isCheckingBBPS = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (_, wp, __) {
        return RefreshIndicator(
          onRefresh: () async { await wp.fetchWalletData(); },
          color: AppColors.accent,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildHeader(wp),
              const SizedBox(height: 24),
              _buildBalanceCard(wp, context),
              const SizedBox(height: 20),
              const BannerSlider(), // ✅ BANNER SLIDER ADDED HERE
              const SizedBox(height: 24),
              _buildServicesGrid(),
              const SizedBox(height: 24),
              _buildQuickActions(),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildHeader(WalletProvider wp) {
    final initial = (wp.userName ?? 'M')[0].toUpperCase();
    return Row(children: [
      Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.accent]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700))),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Good Morning 👋', style: TextStyle(fontSize: 11, color: AppColors.textHint)),
          const SizedBox(height: 2),
          Text(wp.userName ?? 'Merchant', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ]),
      ),
      if (isCheckingBBPS) const Padding(padding: EdgeInsets.only(right: 8), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight))),
      if (!isCheckingBBPS && isBBPSOnboarded) const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.verified, color: AppColors.success, size: 18)),
      _IconBtn(Icons.notifications_outlined, () {}),
      const SizedBox(width: 6),
      _IconBtn(Icons.logout_rounded, onLogout, destructive: true),
    ]);
  }

  Widget _buildBalanceCard(WalletProvider wp, BuildContext context) {
    final total = (wp.mainWallet?.balance ?? 0) + (wp.aepsWallet?.balance ?? 0);
    final commission = wp.commissionBalance;
    final rewards = wp.stats?.rewards ?? 0;

    return Column(children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF005F4E), Color(0xFF008169), Color(0xFF00C897)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.visibility_rounded, color: Colors.white70, size: 18),
          ]),
          const SizedBox(height: 16),
          Text('₹ ${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => showAddFundSheet(context, wp.userId),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('₹ ${(wp.mainWallet?.balance ?? 0).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => showAepsWalletOptions(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.fingerprint, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text('₹ ${(wp.aepsWallet?.balance ?? 0).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Row(children: [
        _InfoCard(Icons.card_giftcard_rounded, 'Rewards', '₹ ${rewards.toStringAsFixed(2)}'),
        const SizedBox(width: 10),
        _InfoCard(Icons.account_balance_rounded, 'Commission', '₹ ${commission.toStringAsFixed(2)}', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CommissionHistoryScreen()))),
        const SizedBox(width: 10),
        _InfoCard(Icons.credit_card_rounded, 'CC Balance', '₹ 0.00'),
      ]),
    ]);
  }

  Widget _buildServicesGrid() {
    final services = [
      {'name': 'AEPS', 'icon': Icons.fingerprint},
      {'name': 'DMT', 'icon': Icons.swap_horiz},
      {'name': 'Recharge', 'icon': Icons.phone_android},
      {'name': 'Bills', 'icon': Icons.description},
      // {'name': 'PPI DMT', 'icon': Icons.account_balance_wallet},
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Text('Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.9),
        itemCount: services.length,
        itemBuilder: (_, i) {
          final s = services[i];
          return GestureDetector(
            onTap: () => onServiceTap(s['name'] as String),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Icon(s['icon'] as IconData, color: AppColors.accent, size: 24),
              ),
              const SizedBox(height: 8),
              Text(s['name'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textHint), textAlign: TextAlign.center),
            ]),
          );
        },
      ),
    ]);
  }

  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      Row(children: [
        Expanded(child: _ActionCard(Icons.qr_code_scanner_rounded, 'Scan & Pay', () {})),
        const SizedBox(width: 10),
        Expanded(child: _ActionCard(Icons.people_rounded, 'Refer & Earn', () {})),
        const SizedBox(width: 10),
        Expanded(child: _ActionCard(Icons.support_agent_rounded, 'Support', () {})),
      ]),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BANNER SLIDER WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class BannerSlider extends StatefulWidget {
  const BannerSlider({super.key});

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _banners = [
    {
      'title': 'Get 5% Cashback',
      'subtitle': 'On all AEPS transactions',
      'color': AppColors.primaryLight,
      'icon': Icons.percent_rounded,
      'gradient': const [Color(0xFF008169), Color(0xFF00C897)],
    },
    {
      'title': 'Refer & Earn ₹100',
      'subtitle': 'Invite your friends today',
      'color': const Color(0xFF7B9FE0),
      'icon': Icons.share_rounded,
      'gradient': const [Color(0xFF4A6FA5), Color(0xFF7B9FE0)],
    },
    {
      'title': 'Zero Fee DMT',
      'subtitle': 'Unlimited money transfers',
      'color': const Color(0xFFB58FDB),
      'icon': Icons.currency_rupee_rounded,
      'gradient': const [Color(0xFF7B4FDB), Color(0xFFB58FDB)],
    },
    {
      'title': 'Instant Recharge',
      'subtitle': 'Mobile & DTH recharges',
      'color': const Color(0xFF70CBCB),
      'icon': Icons.flash_on_rounded,
      'gradient': const [Color(0xFF00897B), Color(0xFF70CBCB)],
    },
    {
      'title': '24/7 Support',
      'subtitle': 'We are here to help you',
      'color': const Color(0xFFFFB74D),
      'icon': Icons.support_agent_rounded,
      'gradient': const [Color(0xFFFF6F00), Color(0xFFFFB74D)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;
      if (_currentPage < _banners.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              if (mounted) {
                setState(() => _currentPage = index);
              }
            },
            itemCount: _banners.length,
            itemBuilder: (_, index) {
              final banner = _banners[index];
              final gradientColors = banner['gradient'] as List<Color>;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      gradientColors[0].withOpacity(0.8),
                      gradientColors[1].withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: gradientColors[1].withOpacity(0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // Handle banner tap if needed
                      HapticFeedback.lightImpact();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          // Icon Container
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              banner['icon'] as IconData,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Text Content
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  banner['title'] as String,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  banner['subtitle'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Progress indicator within banner
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Arrow indicator
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.2),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppColors.accent
                    : AppColors.textHint.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
                boxShadow: _currentPage == index
                    ? [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SERVICES FULL PAGE
// ─────────────────────────────────────────────────────────────────────────────
class ServicesFullPage extends StatelessWidget {
  final void Function(String) onServiceTap;
  const ServicesFullPage({super.key, required this.onServiceTap});

  @override
  Widget build(BuildContext context) {
    final services = const [
      {'name': 'AEPS', 'icon': Icons.fingerprint, 'desc': 'Aadhaar Enabled Payment System'},
      {'name': 'DMT', 'icon': Icons.swap_horiz, 'desc': 'Domestic Money Transfer'},
      {'name': 'Recharge', 'icon': Icons.phone_android, 'desc': 'Mobile & DTH Recharge'},
      {'name': 'Bills', 'icon': Icons.description, 'desc': 'Bill Payments (BBPS)'},
      // {'name': 'PPI DMT', 'icon': Icons.account_balance_wallet, 'desc': 'PPI Money Transfer'},
    ];

    return Container(
      color: AppColors.bg,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('All Services', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          const Text('Manage your financial services', style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: services.length,
            itemBuilder: (_, i) {
              final s = services[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(s['icon'] as IconData, color: AppColors.accent, size: 22),
                  ),
                  title: Text(s['name'] as String, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  subtitle: Text(s['desc'] as String, style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
                  onTap: () => onServiceTap(s['name'] as String),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;
  const _IconBtn(this.icon, this.onTap, {this.destructive = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: destructive ? AppColors.error.withOpacity(0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: destructive ? AppColors.error.withOpacity(0.2) : AppColors.border, width: 0.5),
        ),
        child: Icon(icon, color: destructive ? AppColors.error : AppColors.textHint, size: 18),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoCard(this.icon, this.label, this.value, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border, width: 0.5)),
          child: Column(children: [
            Icon(icon, color: AppColors.accent, size: 18),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ]),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border, width: 0.5)),
        child: Column(children: [
          Icon(icon, color: AppColors.accent, size: 24),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _AtmOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AtmOption(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.accent, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint, size: 18),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}