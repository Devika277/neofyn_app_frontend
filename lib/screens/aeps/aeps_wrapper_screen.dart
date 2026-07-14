import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import 'merchant_registration_screen.dart';
import 'aeps_dashboard_screen.dart';
import 'two_factor_auth_screen.dart';

class AepsWrapperScreen extends StatefulWidget {
  const AepsWrapperScreen({super.key});

  @override
  State<AepsWrapperScreen> createState() => _AepsWrapperScreenState();
}

class _AepsWrapperScreenState extends State<AepsWrapperScreen> {
  bool _isInitializing = true;
  Widget? _currentScreen;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final provider = context.read<AepsProvider>();
    await provider.init();

    if (!mounted) return;

    // ✅ Determine screen AFTER build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _determineScreen();
    });
  }

  void _determineScreen() {
    final provider = context.read<AepsProvider>();

    // 1. No merchant → register
    if (provider.merchantId == null || provider.merchantId!.isEmpty) {
      setState(() => _currentScreen = const MerchantRegistrationScreen());
      return;
    }

    // 2. Check 2FA - use per-pipe check instead of old needs2FA()
    final currentPipe = provider.pipe ?? '1';
    final is2FADone = provider.is2FADoneForPipe(currentPipe);

    if (!is2FADone && provider.merchantId != null && provider.merchantId!.isNotEmpty) {
      // Fetch 2FA status first, then decide
      _check2FAAndNavigate();
    } else {
      // All good → dashboard
      setState(() => _currentScreen = AepsDashboardScreen(pipe: currentPipe));
    }
  }

  Future<void> _check2FAAndNavigate() async {
    final provider = context.read<AepsProvider>();
    final userId = provider.userId;

    if (userId != null) {
      await provider.fetch2FAStatus(userId);
    }

    if (!mounted) return;

    final currentPipe = provider.pipe ?? '1';
    final is2FADone = provider.is2FADoneForPipe(currentPipe);

    if (is2FADone) {
      // 2FA already done → dashboard
      setState(() => _currentScreen = AepsDashboardScreen(pipe: currentPipe));
    } else {
      // 2FA needed → show 2FA screen
      setState(() => _currentScreen = TwoFactorAuthScreen(
        pipe: currentPipe,
        merchantId: provider.getMerchantIdForPipe(currentPipe) ?? provider.merchantId,
        merchantRefId: provider.getMerchantRefIdForPipe(currentPipe) ?? provider.merchantRefId,
        aadhaarNumber: provider.aadhaarNo,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (_isInitializing || _currentScreen == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF008169)),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    return _currentScreen!;
  }
}