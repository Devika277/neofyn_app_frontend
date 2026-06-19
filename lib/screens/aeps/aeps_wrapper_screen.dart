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

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final provider = context.read<AepsProvider>();

    // Ensure persisted data is loaded
    await provider.init();

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while initializing
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF008169)),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    final provider = context.watch<AepsProvider>();

    debugPrint('🔍 Wrapper Check:');
    debugPrint('   merchantId: ${provider.merchantId}');
    debugPrint('   pipe: ${provider.pipe}');
    debugPrint('   needs2FA: ${provider.needs2FA()}');
    debugPrint('   last2FADate: ${provider.last2FADate}');
    debugPrint('   is2FAVerifiedToday: ${provider.is2FAVerifiedToday}');

    // 1. Loading
    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. No merchant → register
    if (provider.merchantId == null || provider.merchantId!.isEmpty) {
      debugPrint('➡️ Redirecting to Registration');
      return const MerchantRegistrationScreen();
    }

    // 3. Merchant exists but needs daily 2FA → verify
    if (provider.needs2FA()) {
      debugPrint('➡️ Redirecting to 2FA');
      return const TwoFactorAuthScreen();
    }

    // 4. All good → dashboard
    debugPrint('➡️ Redirecting to Dashboard');
    return const AepsDashboardScreen();
  }
}