// ─────────────────────────────────────────────────────────────────────────────
//  user_home_screen.dart – COMPLETE FIXED VERSION
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
import '../screens/aeps/aeps_history_screen.dart';
import '../screens/dmt1/dmt_home_screen.dart';
import '../screens/account/Profile_screen.dart';
import '../screens/account/supportPage_screen.dart';
import '../services/AEPS/api_service.dart';
import '../screens/aeps/aeps_wrapper_screen.dart';
import '../providers/payout_provider.dart';
import '../screens/payout/payout_home_screen.dart';
import '../providers/wallet_provider.dart';
import '../screens//aeps/aeps_wallet_dialog.dart';
import 'package:my_app/widgets/add_fund_sheet.dart';
import '../screens/recharge/RechargeCategoryScreen.dart';
import '../screens/recharge/recharge_history_screen.dart';
import '../services/AEPS/matm_service.dart';
import '../screens/ppi_dmt/dmt_phone_entry.dart';
import '../../services/session_service.dart';
import '../screens/dmt/dmt_selector_screen.dart';
import '../screens/bbps/onboarding_page.dart';
import '../screens/bbps/bill_payment_page.dart';



// ─────────────────────────────────────────────────────────────────────────────
//  BRAND COLORS
// ─────────────────────────────────────────────────────────────────────────────
class AppColors {
  static const primary = Color(0xFF008169);
  static const primaryLight = Color(0xFF1AA88A);
  static const primaryDark = Color(0xFF005F4E);
  static const white = Colors.white;
  static const grey = Color(0xFF8A9A8A);
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF4CAF50);
  static const bg = Color(0xFF0A0E0A);
  static const card = Color(0xFF0F1A0F);
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
    final name = prefs.getString('name') ?? 'Merchant';  // ✅ ADD THIS LINE

    setState(() {
      _name = name;
      _phone = prefs.getString('phone') ?? '';
      _userId = uid.isNotEmpty ? uid : 'PN8472193';
    });
    if (uid.isNotEmpty) {

      _walletProvider
          .setUserId(uid);
      _walletProvider.setUserName(name);
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
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  // ----------------------------------------------------------------------
  // Micro‑ATM (unchanged)
  // ----------------------------------------------------------------------
  void _onMicroATMTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              _MicroAtmOption(Icons.account_balance_wallet_outlined, 'Balance Enquiry', () async {
                Navigator.pop(ctx);
                final r = await MatmService.balanceEnquiry(_userPhone);
                if (mounted) _showResult(r);
              }),
              _MicroAtmOption(Icons.money_outlined, 'Cash Withdrawal', () {
                Navigator.pop(ctx);
                final ctrl = TextEditingController();
                showDialog(
                  context: context,
                  builder: (dialogCtx) {
                    return _AmountDialog(
                      controller: ctrl,
                      onConfirm: () {
                        Navigator.pop(dialogCtx);
                        _doWithdrawal(ctrl.text.trim());
                      },
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _doWithdrawal(String amount) async {
    if (amount.isEmpty) { _toast('Enter amount', error: true); return; }
    final r = await MatmService.cashWithdrawal(_userPhone, amount);
    if (mounted) _showResult(r);
  }

  void _showResult(Map<String, dynamic> r) {
    showDialog(
      context: context,
      builder: (c) {
        return AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(r['success'] == true ? 'Success' : 'Error', style: TextStyle(color: r['success'] == true ? AppColors.success : AppColors.error)),
          content: Text('${r['data'] ?? r['error']}', style: const TextStyle(color: Colors.white70)),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('OK', style: TextStyle(color: AppColors.primaryLight)))],
        );
      },
    );
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: error ? AppColors.error : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ----------------------------------------------------------------------
  //  SERVICE TAP HANDLER – THE FIX
  // ----------------------------------------------------------------------
  void _onServiceTap(String serviceName) {
    HapticFeedback.selectionClick();

    switch (serviceName) {
      case 'AEPS':
      final aeps = Provider.of<AepsProvider>(context, listen: false);
          // If token is null, try loading from storage again
          if (aeps.authToken == null) {
     aeps.loadFromStorage(); // you must implement this
  }
  final token = aeps.authToken;
  final userId = aeps.userId;
 

        debugPrint('🔐 _onServiceTap -> token: ${token != null ? "${token.substring(0, 20)}..." : "NULL"}');
        debugPrint('🔐 _onServiceTap -> userId: $userId');

        if (token == null || userId == null) {
          _toast('Please login again', error: true);
          return;
        }
      
        // Ensure provider has the latest auth (optional, but safe)
        // aeps.setAuthDetails(token: token, userId: userId, merchantId: '');

        debugPrint('➡️ Navigating to PipeSelectionScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PipeSelectionScreen()),
        );
        break;

      case 'DMT':
Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DMTSelectorScreen(), // UPDATED
        ),
      );        break;
      case 'Payout':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider(
              create: (_) => PayoutProvider(),
              child: const PayoutHomeScreen(),
            ),
          ),
        );
        break;
      case 'mATM':
        _onMicroATMTap();
        break;
      case 'Recharge':
        Navigator.push(context, MaterialPageRoute(builder: (_) => RechargeCategoryScreen()));
        break;
      case 'Bills':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BillPaymentScreen()));
        break;
      case 'PPI DMT':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DmtPhoneEntryPage()));
        break;
         case 'Onboard': // ← ADD THIS CASE
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const OnboardingPage(),
        ),
      );
      break;
      default:
        _toast('Coming soon!', error: false);
        break;
    }
  }

  // ----------------------------------------------------------------------
  //  BUILD
  // ----------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async { SystemNavigator.pop(); return false; },
      child: ChangeNotifierProvider.value(
        value: _walletProvider,
        child: Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A0E0A), Color(0xFF0F1A0F), Color(0xFF050805)])),
            child: SafeArea(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  HomeDashboard(
                    onLogout: _logout,
                    onMicroATMTap: _onMicroATMTap,
                    onServiceTap: _onServiceTap, // ✅ now defined
                  ),
                  const ServicesPage(),
                  // const HistoryPage(),
                  AepsHistoryScreen(),
                  ProfilePage(onLogout: _logout),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildNavBar(),
        ),
      ),
    );
  }

  Widget _buildNavBar() => Container(
    margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)]),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        selectedItemColor: AppColors.primaryLight,
        unselectedItemColor: Colors.white38,
        currentIndex: _selectedIndex,
        onTap: (i) { HapticFeedback.selectionClick(); setState(() => _selectedIndex = i); },
        elevation: 0,
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

// ─────────────────────────────────────────────────────────────────────────────
//  HOME DASHBOARD (must accept onServiceTap)
// ─────────────────────────────────────────────────────────────────────────────
class HomeDashboard extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback? onMicroATMTap;
  final void Function(String serviceName) onServiceTap;

  const HomeDashboard({
    super.key,
    required this.onLogout,
    this.onMicroATMTap,
    required this.onServiceTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (ctx, wp, child) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              _buildHeader(ctx, wp),
              const SizedBox(height: 16),
              _buildBalanceCard(wp, ctx),
              const SizedBox(height: 16),
              const _BannerSlider(),
              const SizedBox(height: 20),
              _buildServicesGrid(ctx),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, WalletProvider wp) {
    // Get the first letter of the name dynamically
    String initial = '?';
    final userName = wp.userName ?? 'Devika M S';
    if (userName.isNotEmpty) {
      initial = userName[0].toUpperCase();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight]
                ),
                borderRadius: BorderRadius.circular(16)
            ),
            child: Center(
                child: Text(
                    initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold
                    )
                )
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Welcome Back 👋',
                    style: TextStyle(fontSize: 11, color: Colors.white54)
                ),
                const SizedBox(height: 2),
                Text(
                    userName,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white
                    )
                ),
              ],
            ),
          ),
          _HeaderIcon(Icons.notifications_outlined, () {}),
          const SizedBox(width: 8),
          _HeaderIcon(Icons.qr_code_scanner_rounded, () {}),
          const SizedBox(width: 8),
          _HeaderIcon(
              Icons.logout_rounded,
                  () => _showLogout(context, onLogout),
              color: AppColors.error
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(WalletProvider wp, BuildContext context) {
    final mainBalance = wp.mainWallet?.balance ?? 0;
    final aepsBalance = wp.aepsWallet?.balance ?? 0;
    final totalBalance = mainBalance + aepsBalance;
    final rewards = wp.stats?.rewards ?? 0;
    final commission = wp.stats?.commission ?? 0;
    final ccBalance = wp.stats?.ccBalance ?? 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Text('Total Balance', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.verified_user_outlined, color: Colors.white, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    flex: 3,
                    child: Text('₹ ${totalBalance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => showAddFundSheet(context, wp.userId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Expanded(child: Text('₹ ${mainBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                              const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => showAepsWalletOptions(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                            child: Row(children: [
                              const Icon(Icons.fingerprint_rounded, color: Color(0xFF7B9FE0), size: 14),
                              const SizedBox(width: 6),
                              Expanded(child: Text('₹ ${aepsBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
                              const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
                            ]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatCircle('🎁', 'Rewards', rewards, AppColors.primaryLight),
            _StatCircle('💰', 'Commission', commission, const Color(0xFF7B9FE0)),
            _StatCircle('💳', 'CC Balance', ccBalance, const Color(0xFFB58FDB)),
          ],
        ),
      ],
    );
  }

  Widget _StatCircle(String emoji, String label, double value, Color color) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
          child: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 2),
              Text('₹ ${value.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildServicesGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.85,
          ),
          itemCount: _svcList.length,
          itemBuilder: (_, i) {
            final service = _svcList[i];
            return _ServiceItem(
              service,
              () {
                HapticFeedback.selectionClick();
                onServiceTap(service['name'] as String); // ✅ uses callback
              },
            );
          },
        ),
      ],
    );
  }

  static const _svcList = [
    {'name': 'AEPS', 'icon': Icons.fingerprint, 'color': AppColors.primaryLight},
    {'name': 'DMT', 'icon': Icons.swap_horiz, 'color': Color(0xFF7B9FE0)},
    {'name': 'Payout', 'icon': Icons.payments, 'color': Color(0xFFB58FDB)},
    {'name': 'mATM', 'icon': Icons.atm, 'color': Color(0xFFE08060)},
    {'name': 'Recharge', 'icon': Icons.phone_android, 'color': Color(0xFF70CBCB)},
    {'name': 'Bills', 'icon': Icons.description, 'color': Color(0xFFE07070)},
    {'name': 'PPI DMT', 'icon': Icons.account_balance, 'color': Color(0xFF70C070)},
    {'name': 'Onboard', 'icon': Icons.app_registration, 'color': Color(0xFFFF9800)}, // ← ADD THIS

    {'name': 'More', 'icon': Icons.more_horiz, 'color': Color(0xFFA0A0A0)},
  ];

  static void _showLogout(BuildContext context, VoidCallback onLogout) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure?', style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel', style: TextStyle(color: AppColors.primaryLight))),
          TextButton(onPressed: () { Navigator.pop(c); onLogout(); }, child: const Text('Logout', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
//  Reusable widgets (unchanged, just copied for completeness)
// ─────────────────────────────────────────────────────────────────────────────
class _BannerSlider extends StatefulWidget {
  const _BannerSlider();
  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  final List<Map<String, dynamic>> _banners = [
    {'title': 'Get 5% Cashback', 'subtitle': 'On all AEPS transactions', 'color': AppColors.primaryLight, 'icon': Icons.percent_rounded},
    {'title': 'Refer & Earn ₹100', 'subtitle': 'Invite your friends today', 'color': const Color(0xFF7B9FE0), 'icon': Icons.share_rounded},
    {'title': 'Zero Fee DMT', 'subtitle': 'Unlimited money transfers', 'color': const Color(0xFFB58FDB), 'icon': Icons.currency_rupee_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      if (_currentPage < _banners.length - 1) _currentPage++;
      else _currentPage = 0;
      if (_pageController.hasClients) {
        _pageController.animateToPage(_currentPage, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
          height: 100,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _banners.length,
            itemBuilder: (_, index) {
              final banner = _banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [(banner['color'] as Color).withOpacity(0.3), (banner['color'] as Color).withOpacity(0.1)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (banner['color'] as Color).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Container(width: 48, height: 48,
                        decoration: BoxDecoration(color: (banner['color'] as Color).withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                        child: Icon(banner['icon'] as IconData, color: banner['color'] as Color, size: 24)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(banner['title'] as String, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(banner['subtitle'] as String, style: const TextStyle(fontSize: 11, color: Colors.white60)),
                      ]),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentPage == index ? AppColors.primaryLight : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ServiceItem extends StatelessWidget {
  final Map<String, dynamic> data; final VoidCallback onTap;
  const _ServiceItem(this.data, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(width: 54, height: 54,
          decoration: BoxDecoration(color: (data['color'] as Color).withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
          child: Icon(data['icon'] as IconData, color: data['color'] as Color, size: 26)),
      const SizedBox(height: 6),
      Text(data['name'] as String, style: const TextStyle(fontSize: 10, color: Colors.white60)),
    ]),
  );
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon; final VoidCallback onTap; final Color? color;
  const _HeaderIcon(this.icon, this.onTap, {this.color});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 38, height: 38,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color ?? Colors.white54, size: 20)),
  );
}

class _MicroAtmOption extends StatelessWidget {
  final IconData icon; final String label; final VoidCallback onTap;
  const _MicroAtmOption(this.icon, this.label, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(width: 44, height: 44,
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, color: AppColors.primaryLight)),
    title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
    onTap: onTap,
  );
}

class _AmountDialog extends StatelessWidget {
  final TextEditingController controller; final VoidCallback onConfirm;
  const _AmountDialog({required this.controller, required this.onConfirm});
  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('Enter Amount', style: TextStyle(color: Colors.white)),
    content: TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white, fontSize: 24),
      decoration: InputDecoration(
        hintText: '₹ 0',
        hintStyle: const TextStyle(color: Colors.white24),
        border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryLight)),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
      TextButton(onPressed: onConfirm, child: Text('Proceed', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w700))),
    ],
  );
}

class _StatCircle extends StatelessWidget {
  final String emoji; final String label; final double value; final Color color;
  const _StatCircle(this.emoji, this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12), border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
        child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 2),
          Text('₹ ${value.toStringAsFixed(0)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ])),
      ),
      const SizedBox(height: 6),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w500)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  PLACEHOLDER PAGES
// ─────────────────────────────────────────────────────────────────────────────
class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Services', style: TextStyle(color: Colors.white54)));
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('History', style: TextStyle(color: Colors.white54)));
}

// class BillPaymentScreen extends StatelessWidget {
//   const BillPaymentScreen({super.key});
//   @override
//   Widget build(BuildContext context) => Scaffold(
//     backgroundColor: AppColors.bg,
//     appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Pay Bills', style: TextStyle(color: Colors.white))),
//     body: const Center(child: Text('Bills', style: TextStyle(color: Colors.white54))),
//   );
// }