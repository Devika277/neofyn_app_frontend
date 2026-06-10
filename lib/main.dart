import 'package:flutter/material.dart';
import 'package:my_app/debug_overlay.dart';
import 'IntroScreen.dart';
import 'services/storage_service.dart';
import 'services/session_service.dart';
import 'services/mpin_service.dart';
import 'screens/account/login_screen.dart';
import 'screens/account/set_mpin_screen.dart';
import 'screens/account/mpin_verify_screen.dart';

import 'package:provider/provider.dart';

import 'providers/aeps_provider.dart';
import 'providers/payout_provider.dart';
import 'providers/beneficiary_provider.dart';
import 'providers/wallet_provider.dart';
import 'services/storage_service.dart';
import 'providers/remitter_provider.dart';
import 'providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init(); // Initialize StorageService
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AepsProvider()),
        ChangeNotifierProvider(create: (_) => PayoutProvider()),
        ChangeNotifierProvider(create: (_) => BeneficiaryProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => RemitterProvider()),        ChangeNotifierProvider(create: (_) => AuthProvider()), 

      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NeoFyn',
        theme: ThemeData(
          fontFamily: 'Poppins',
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF000000),
          primaryColor: const Color(0xFF2ECC71),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2ECC71),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const AppRouter(), // ✅ Changed from IntroScreen to AppRouter
        builder: (context, child) {
          return DebugOverlay(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}

// ✅ App Router - Decides initial screen based on session
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - update last active time
      SessionService.updateLastActiveTime();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _getInitialScreen(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF008169)),
            ),
          );
        }
        return snapshot.data ?? const LoginScreen();
      },
    );
  }

  Future<Widget> _getInitialScreen() async {
    // Check if user is logged in
    final isLoggedIn = await SessionService.isLoggedIn();

    if (!isLoggedIn) {
      // First time or logged out - show intro
      return const IntroScreen();
    }

    // Check if session is still valid (24 hours)
    final isSessionValid = await SessionService.isSessionValid();

    if (!isSessionValid) {
      // Session expired - clear and show login
      await SessionService.clearSession();
      return const LoginScreen();
    }

    // Session valid - check if MPIN needs re-verification (5 min idle)
    final needsMpin = await SessionService.needsMpinVerification();
    final isMpinSet = await MpinService.isMpinSet();
    final token = await SessionService.getToken();
    final userId = await SessionService.getUserId();

    if (needsMpin && isMpinSet && token != null && userId != null) {
      // Need MPIN re-verification
      return MpinVerifyScreen(userId: userId, token: token);
    } else if (!isMpinSet && token != null && userId != null) {
      // MPIN not set
      return SetMpinScreen(userId: userId, token: token);
    } else if (!needsMpin && isMpinSet) {
      // Session valid, MPIN set, within 5 minutes - go to home directly
      // Import UserHomeScreen if needed
      // return const UserHomeScreen();
    }

    // Default fallback
    return const IntroScreen();
  }
}
