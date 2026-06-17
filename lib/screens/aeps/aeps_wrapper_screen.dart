import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import 'merchant_registration_screen.dart';
import 'aeps_dashboard_screen.dart';
import 'two_factor_auth_screen.dart';  // import the 2FA screen

class AepsWrapperScreen extends StatelessWidget {
  const AepsWrapperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AepsProvider>();
    debugPrint('🔍 merchantId in wrapper: ${provider.merchantId}');
    debugPrint('🔍 needs2FA: ${provider.needs2FA()}');

    // 1. Loading
    if (provider.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2. No merchant → register
    if (provider.merchantId == null || provider.merchantId!.isEmpty) {
      return const MerchantRegistrationScreen();
    }

    // 3. Merchant exists but needs daily 2FA → verify
    if (provider.needs2FA()) {
      return const TwoFactorAuthScreen();
    }

    // 4. All good → dashboard
    return const AepsDashboardScreen();
  }
}