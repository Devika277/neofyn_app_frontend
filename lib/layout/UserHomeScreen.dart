import 'package:flutter/material.dart';
import 'package:my_app/models/wallet_models.dart';
import 'package:my_app/providers/aeps_provider.dart';
import 'package:my_app/services/Recharges/rechargeFragment.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_app/screens/account/login_screen.dart';
import '../screens/dmt/dmt_home_screen.dart';
import '../screens/account/Profile_screen.dart';
import '../screens/account/supportPage_screen.dart';
import '../services/AEPS/api_service.dart';
import '../screens/aeps/aeps_wrapper_screen.dart';
import '../providers/payout_provider.dart';
import '../screens/payout/payout_home_screen.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/wallet_provider.dart';
import '../screens//aeps/aeps_wallet_dialog.dart';
import 'package:my_app/widgets/add_fund_sheet.dart';
import '../screens/BBPS/RechargeCategoryScreen.dart';
import '../screens/BBPS/recharge_history_screen.dart';
import '../services/AEPS/matm_service.dart';
import '../screens/ppi_dmt/dmt_phone_entry.dart';
import '../layout/neofyn_fab.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


// ─────────────────────────────────────────────────────────────────────────────
//  BRAND TOKENS
// ─────────────────────────────────────────────────────────────────────────────
class _N {
  static const bg        = Color(0xFF1C0F06);
  static const surface   = Color(0xFF120A03);
  static const card      = Color(0xFF0A0603);
  static const caramel   = Color(0xFFC8956C);
  static const glassFg   = Color(0x0DFFFFFF);
  static const glassBd   = Color(0x1AFFFFFF);
  static const white     = Colors.white;
  static const sub       = Color(0xFF8A7060);
  static const error     = Color(0xFFE06060);

  // service tint helpers
  static Color svcBg(Color c) => c.withOpacity(0.13);
}

// ─────────────────────────────────────────────────────────────────────────────
//  USER HOME SCREEN  (scaffold + bottom nav)
// ─────────────────────────────────────────────────────────────────────────────
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int    _selectedIndex = 0;
  String _name  = 'Devika M S';
  String _phone = '+91 98765 43210';
  String _userId = '';


  String get _userPhone => _phone.replaceAll(RegExp(r'\s+'), '').replaceAll('+91', '').trim();


  late final WalletProvider _walletProvider = WalletProvider();
  late final List<Widget>   _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeDashboardContent(
        onLogout:      _logout,
        onMicroATMTap: _onMatmIconTap,
      ),
      ServicesGridContent(onMicroATMTap: _onMatmIconTap),
      ProfilePage(onLogout: _logout),
      SupportPage(),
    ];
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid   = prefs.getString('userId') ?? '';
    setState(() {
      _name   = prefs.getString('name')  ?? 'Devika M S';
      _phone  = prefs.getString('phone') ?? '+91 98765 43210';
      _userId = uid;
    });
    if (uid.isNotEmpty) _walletProvider.setUserId(uid);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await ApiService.clearUser();
    if (!mounted) return;
    final aeps = Provider.of<AepsProvider>(context, listen: false);
    await aeps.clearMerchantData();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (r) => false,
      );
    }
  }

  // ── MicroATM bottom sheet (original logic) ────────────────────────────────
  void _onMatmIconTap() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A1407),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(color: _N.glassBd, borderRadius: BorderRadius.circular(2))),
            _MatmTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Balance enquiry',
              // ── Balance Enquiry tile onTap ─────────────────────────────────────────────
              onTap: () async {
                Navigator.pop(ctx);
                final r = await MatmService.balanceEnquiry(_userPhone);  // ← add _userPhone
                if (mounted) _showResultDialog(r);
              },
            ),
            _MatmTile(
              icon: Icons.money_outlined,
              label: 'Cash withdrawal',
              onTap: () async {
                Navigator.pop(ctx);
                final ctrl = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (d) => _AmountDialog(controller: ctrl,
                    onConfirm: () { Navigator.pop(d); _doWithdrawal(ctrl.text.trim()); }),
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }


 // ── New: FAB menu that replaces bottom navigation ────────────────────────
  void _showNavigationMenu() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (ctx) => _NavMenuSheet(
        currentIndex: _selectedIndex,
        onSelect: (index) {
          Navigator.pop(ctx);
          setState(() => _selectedIndex = index);
        },
      ),
    );
  }



  // ── _doWithdrawal ──────────────────────────────────────────────────────────
Future<void> _doWithdrawal(String amount) async {
  if (amount.isEmpty) {
    _toast('Please enter an amount', error: true);
    return;
  }
  final r = await MatmService.cashWithdrawal(_userPhone, amount);  // ← add _userPhone
  if (mounted) _showResultDialog(r);
}

  void _showResultDialog(Map<String, dynamic> result) {
    final ok = result['success'] == true;
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF2A1407),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(ok ? 'Success' : 'Error',
            style: TextStyle(color: ok ? _N.caramel : _N.error, fontWeight: FontWeight.w700)),
        content: Text(ok ? '${result['data']}' : '${result['error']}',
            style: const TextStyle(color: Colors.white70)),
        actions: [TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('OK', style: TextStyle(color: _N.caramel, fontWeight: FontWeight.w700)),
        )],
      ),
    );
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: error ? _N.error : _N.caramel,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _walletProvider,
      child: Scaffold(
        backgroundColor: _N.bg,
        body: SafeArea(
          child: IndexedStack(index: _selectedIndex, children: _pages),
        ),
          // Remove bottomNavigationBar – no longer used
        floatingActionButton: FloatingActionButton(
          onPressed: _showNavigationMenu,
          elevation: 0,
          backgroundColor: _N.caramel,
          shape: const CircleBorder(),
          child: const Icon(Icons.menu_rounded, color: Color(0xFF1C0F06), size: 28),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOTTOM SHEET NAVIGATION MENU (glassmorphism style)
// ─────────────────────────────────────────────────────────────────────────────
class _NavMenuSheet extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onSelect;
  const _NavMenuSheet({required this.currentIndex, required this.onSelect});

  static const List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.home_rounded,        'label': 'Home',     'index': 0},
    {'icon': Icons.widgets_rounded,     'label': 'Services', 'index': 1},
    {'icon': Icons.person_rounded,      'label': 'Profile',  'index': 2},
    {'icon': Icons.support_agent_rounded,'label': 'Support',  'index': 3},
  ];

 @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1407),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0x1AFFFFFF), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0x30FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ..._menuItems.map((item) => ListTile(
            leading: Icon(item['icon'], color: currentIndex == item['index'] ? _N.caramel : const Color(0x80FFFFFF)),
            title: Text(item['label'],
              style: TextStyle(
                color: currentIndex == item['index'] ? _N.caramel : Colors.white,
                fontWeight: currentIndex == item['index'] ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            trailing: currentIndex == item['index']
                ? const Icon(Icons.check_rounded, color: _N.caramel, size: 20)
                : null,
            onTap: () => onSelect(item['index']),
          )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}  

// ─────────────────────────────────────────────────────────────────────────────
//  HOME DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────
class HomeDashboardContent extends StatelessWidget {
  final VoidCallback  onLogout;
  final VoidCallback? onMicroATMTap;
  const HomeDashboardContent({super.key, required this.onLogout, this.onMicroATMTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(builder: (_, wp, __) {
      if (wp.isLoading && wp.mainWallet == null) {
        return const Center(child: CircularProgressIndicator(color: _N.caramel));
      }
      if (wp.error != null) {
        return Center(child: Text('Error: ${wp.error}',
            style: const TextStyle(color: Colors.white70)));
      }
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(children: [
          _Header(onLogout: onLogout),
          const SizedBox(height: 14),

          // ── Balance hero card ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _BalanceHeroCard(wp: wp),
          ),
          const SizedBox(height: 14),

          // ── Quick stats row ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _StatsRow(stats: wp.stats),
          ),
          const SizedBox(height: 18),

          // ── Quick actions horizontal scroll ───────────────────────────
          const _SectionHeader(title: 'Quick actions', padding: EdgeInsets.fromLTRB(18, 0, 18, 12)),
          _ActionsRow(wp: wp, context: context),
          const SizedBox(height: 18),

          // ── Services grid ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(children: [
              _SectionHeader(
                title: 'Services',
                trailing: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('View all', style: TextStyle(color: _N.caramel, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              ServicesGridContent(onMicroATMTap: onMicroATMTap),
            ]),
          ),
          const SizedBox(height: 18),

          // ── Recent transactions ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(children: [
              _SectionHeader(
                title: 'Recent transactions',
                trailing: TextButton(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RechargeHistoryScreen())),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                  child: const Text('See all', style: TextStyle(color: _N.caramel, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              const _RecentTxns(),
            ]),
          ),
        ]),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VoidCallback onLogout;
  const _Header({required this.onLogout});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0x20C8956C),
              border: Border.all(color: const Color(0x35C8956C), width: 1.5),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.person_rounded, color: _N.caramel, size: 22),
          ),
          const SizedBox(width: 11),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Welcome back,',
              style: TextStyle(fontSize: 11, color: Color(0x55FFFFFF), fontWeight: FontWeight.w500)),
            const SizedBox(height: 1),
            Consumer<WalletProvider>(builder: (_, wp, __) =>
              Text(wp.userName ?? 'Devika M S',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _N.white))),
          ]),
        ]),
        Row(children: [
          _IconBtn(
            icon: Icons.notifications_none_rounded,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _IconBtn(
            icon: Icons.logout_rounded,
            iconColor: _N.error,
            onTap: () => _showLogoutDialog(context, onLogout),
          ),
        ]),
      ],
    ),
  );

  static void _showLogoutDialog(BuildContext context, VoidCallback onLogout) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF2A1407),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: Colors.white60)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel', style: TextStyle(color: _N.caramel)),
          ),
          TextButton(
            onPressed: () { Navigator.pop(c); onLogout(); },
            child: const Text('Log out', style: TextStyle(color: Color(0xFFE06060), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BALANCE HERO CARD
// ─────────────────────────────────────────────────────────────────────────────
class _BalanceHeroCard extends StatelessWidget {
  final WalletProvider wp;
  const _BalanceHeroCard({required this.wp});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _N.glassFg,
      border: Border.all(color: _N.glassBd),
      borderRadius: BorderRadius.circular(22),
    ),
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('TOTAL BALANCE',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0x55FFFFFF), letterSpacing: 1.2)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x14C8956C),
            border: Border.all(color: const Color(0x28C8956C)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(children: [
            Icon(Icons.verified_user_outlined, color: _N.caramel, size: 11),
            SizedBox(width: 4),
            Text('Secured', style: TextStyle(color: _N.caramel, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      RichText(
        text: TextSpan(
          style: const TextStyle(color: _N.white),
          children: [
            const TextSpan(text: '₹ ',
              style: TextStyle(fontSize: 18, color: Color(0x70FFFFFF), fontWeight: FontWeight.w400)),
            TextSpan(
              text: (wp.totalBalance).toStringAsFixed(2),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _WalletMini(
          label: 'Main Wallet',
          icon: Icons.account_balance_wallet_outlined,
          amount: wp.mainWallet?.balance ?? 0,
          iconColor: _N.caramel,
          onTap: () => showAddFundSheet(context, wp.userId),
        )),
        const SizedBox(width: 10),
        Expanded(child: _WalletMini(
          label: 'AEPS Wallet',
          icon: Icons.fingerprint_rounded,
          amount: wp.aepsWallet?.balance ?? 0,
          iconColor: const Color(0xFF7B9FE0),
          onTap: () => showAepsWalletOptions(context),
        )),
      ]),
    ]),
  );
}

class _WalletMini extends StatelessWidget {
  final String     label;
  final IconData   icon;
  final double     amount;
  final Color      iconColor;
  final VoidCallback onTap;
  const _WalletMini({
    required this.label, required this.icon, required this.amount,
    required this.iconColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x14000000),
        border: Border.all(color: const Color(0x12FFFFFF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: iconColor, size: 13),
          const SizedBox(width: 5),
          Expanded(child: Text(label.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                color: iconColor, letterSpacing: 0.8))),
        ]),
        const SizedBox(height: 6),
        RichText(text: TextSpan(
          style: const TextStyle(color: _N.white),
          children: [
            const TextSpan(text: '₹ ',
              style: TextStyle(fontSize: 11, color: Color(0x60FFFFFF))),
            TextSpan(text: amount.toStringAsFixed(2),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        )),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  STATS ROW
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final WalletStats? stats;
  const _StatsRow({this.stats});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: _StatCard('Rewards',    stats?.rewards    ?? 0)),
    const SizedBox(width: 8),
    Expanded(child: _StatCard('Commission', stats?.commission ?? 0)),
    const SizedBox(width: 8),
    Expanded(child: _StatCard('CC Balance', stats?.ccBalance  ?? 0)),
  ]);
}

class _StatCard extends StatelessWidget {
  final String label;
  final double value;
  const _StatCard(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    decoration: BoxDecoration(
      color: _N.glassFg,
      border: Border.all(color: _N.glassBd),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: Color(0x55FFFFFF), letterSpacing: 0.8)),
      const SizedBox(height: 5),
      RichText(text: TextSpan(
        style: const TextStyle(color: _N.white),
        children: [
          const TextSpan(text: '₹ ', style: TextStyle(fontSize: 10, color: Color(0x55FFFFFF))),
          TextSpan(text: value.toStringAsFixed(0),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      )),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  QUICK ACTIONS SCROLL
// ─────────────────────────────────────────────────────────────────────────────
class _ActionsRow extends StatelessWidget {
  final WalletProvider wp;
  final BuildContext context;
  const _ActionsRow({required this.wp, required this.context});

  @override
  Widget build(BuildContext ctx) {
    final actions = [
      _ActionData('Top Up',   Icons.add_circle_outline_rounded, const Color(0xFFC8956C),
        () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => RechargeCategoryScreen(isRechargeOnly: true)))),
      _ActionData('Pay Bills', Icons.receipt_long_outlined, const Color(0xFF7B9FE0),
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => BillPaymentScreen()))),
      _ActionData('History',   Icons.history_rounded, const Color(0xFFB58FDB),
        () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RechargeHistoryScreen()))),
      _ActionData('Send',      Icons.send_rounded, const Color(0xFF7DC97D), null),
      _ActionData('Move',      Icons.swap_horiz_rounded, const Color(0xFFC8956C), null),
      _ActionData('Stats',     Icons.bar_chart_rounded, const Color(0xFFE08080), null),
    ];
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _ActionChip(data: actions[i]),
      ),
    );
  }
}

class _ActionData {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback? onTap;
  const _ActionData(this.label, this.icon, this.color, this.onTap);
}

class _ActionChip extends StatelessWidget {
  final _ActionData data;
  const _ActionChip({required this.data});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); data.onTap?.call(); },
    child: Column(children: [
      Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: data.color.withOpacity(0.13),
          border: Border.all(color: data.color.withOpacity(0.28)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(data.icon, color: data.color, size: 24),
      ),
      const SizedBox(height: 7),
      Text(data.label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: Color(0x88FFFFFF))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String          title;
  final Widget?         trailing;
  final EdgeInsets      padding;
  const _SectionHeader({required this.title, this.trailing, this.padding = EdgeInsets.zero});

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
          color: Color(0xDDFFFFFF))),
      if (trailing != null) trailing!,
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  SERVICES GRID
// ─────────────────────────────────────────────────────────────────────────────
class ServicesGridContent extends StatelessWidget {
  final VoidCallback? onMicroATMTap;
  const ServicesGridContent({super.key, this.onMicroATMTap});

  static final List<_SvcData> _services = [
    _SvcData('AEPS',     Icons.fingerprint_rounded,              const Color(0xFFC8956C)),
    _SvcData('DMT',      Icons.compare_arrows_rounded,           const Color(0xFF7B9FE0)),
    _SvcData('Payout',   Icons.payments_outlined,                const Color(0xFFB58FDB)),
    _SvcData('MicroATM', Icons.point_of_sale_outlined,           const Color(0xFFE08060)),
    _SvcData('CC Pay',   Icons.credit_card_outlined,             const Color(0xFF70CBCB)),
    _SvcData('Mobile',   Icons.smartphone_outlined,              const Color(0xFFCCCC60)),
    _SvcData('PPI DMT',  Icons.currency_exchange_rounded,        const Color(0xFF70C070)),
    _SvcData('Bills',    Icons.electric_bolt_outlined,           const Color(0xFFE07070)),
  ];

  @override
  Widget build(BuildContext context) => GridView.builder(
    physics: const NeverScrollableScrollPhysics(),
    shrinkWrap: true,
    itemCount: _services.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.9),
    itemBuilder: (_, i) => _SvcTile(
      data: _services[i],
      onTap: () => _handleTap(context, _services[i].name),
    ),
  );

  void _handleTap(BuildContext context, String name) {
    HapticFeedback.selectionClick();
    switch (name) {
      case 'AEPS':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const AepsWrapperScreen())); break;
      case 'DMT':
        Navigator.push(context, MaterialPageRoute(builder: (_) => DmtHomeScreen())); break;
      case 'PPI DMT':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const DmtPhoneEntryPage())); break;
      case 'Mobile':
        Navigator.push(context, MaterialPageRoute(builder: (_) => RechargeCategoryScreen())); break;
      case 'Bills':
        Navigator.push(context, MaterialPageRoute(builder: (_) => BillPaymentScreen())); break;
      case 'Payout':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => PayoutProvider(), child: PayoutHomeScreen()))); break;
      case 'MicroATM':
        onMicroATMTap != null
          ? onMicroATMTap!()
          : ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('MicroATM not configured'))); break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name coming soon!'),
          backgroundColor: const Color(0xFF2A1407),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.all(16),
        ));
    }
  }
}

class _SvcData {
  final String   name;
  final IconData icon;
  final Color    color;
  const _SvcData(this.name, this.icon, this.color);
}

class _SvcTile extends StatelessWidget {
  final _SvcData     data;
  final VoidCallback onTap;
  const _SvcTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(
        width: 54, height: 54,
        decoration: BoxDecoration(
          color: data.color.withOpacity(0.13),
          border: Border.all(color: data.color.withOpacity(0.22)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(data.icon, color: data.color, size: 24),
      ),
      const SizedBox(height: 7),
      Text(data.name,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
            color: Color(0x88FFFFFF))),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECENT TRANSACTIONS  (static placeholder — replace with real data)
// ─────────────────────────────────────────────────────────────────────────────
class _RecentTxns extends StatelessWidget {
  const _RecentTxns();

  static const _txns = [
    _TxnData('AEPS Cash Withdrawal', 'Today, 10:32 AM',   '+₹500',  true,  Icons.arrow_downward_rounded, Color(0xFF7DC97D)),
    _TxnData('Mobile Recharge',      'Yesterday, 6:14 PM', '-₹239', false, Icons.smartphone_outlined,    Color(0xFFC8956C)),
    _TxnData('DMT Transfer',         '25 May, 2:00 PM',   '-₹2,000',false, Icons.compare_arrows_rounded, Color(0xFF7B9FE0)),
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: _txns.map((t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: _N.glassFg,
          border: Border.all(color: _N.glassBd),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: t.iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(t.icon, color: t.iconColor, size: 17),
          ),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _N.white)),
            const SizedBox(height: 2),
            Text(t.sub, style: const TextStyle(fontSize: 10, color: Color(0x55FFFFFF))),
          ])),
          Text(t.amount, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: t.isCredit ? const Color(0xFF7DC97D) : const Color(0xFFE08080))),
        ]),
      ),
    )).toList(),
  );
}

class _TxnData {
  final String   title, sub, amount;
  final bool     isCredit;
  final IconData icon;
  final Color    iconColor;
  const _TxnData(this.title, this.sub, this.amount, this.isCredit, this.icon, this.iconColor);
}

// ─────────────────────────────────────────────────────────────────────────────
//  SMALL SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final Color?   iconColor;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: _N.glassFg,
        border: Border.all(color: _N.glassBd),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: iconColor ?? const Color(0xBBFFFFFF), size: 20),
    ),
  );
}

class _MatmTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final VoidCallback onTap;
  const _MatmTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: const Color(0x20C8956C),
        borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: _N.caramel, size: 20),
    ),
    title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
    onTap: onTap,
  );
}

class _AmountDialog extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback          onConfirm;
  const _AmountDialog({required this.controller, required this.onConfirm});

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF2A1407),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: const Text('Enter amount', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    content: TextField(
      controller:  controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'e.g. 500',
        hintStyle: const TextStyle(color: Color(0x55FFFFFF)),
        filled: true, fillColor: const Color(0x10FFFFFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _N.caramel, width: 1.5)),
        prefixText: '₹ ',
        prefixStyle: const TextStyle(color: _N.caramel, fontWeight: FontWeight.w700),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
      TextButton(onPressed: onConfirm,
        child: const Text('Withdraw', style: TextStyle(color: _N.caramel, fontWeight: FontWeight.w700))),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  AMBIENT BACKGROUND  (shared)
// ─────────────────────────────────────────────────────────────────────────────
class _AmbientBg extends StatelessWidget {
  const _AmbientBg();
  @override
  Widget build(BuildContext context) => Stack(children: [
    Positioned(top: -70, right: -70,
      child: Container(width: 220, height: 220,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x16B46E32)))),
    Positioned(top: 220, left: -60,
      child: Container(width: 170, height: 170,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x108C4B19)))),
  ]);
}