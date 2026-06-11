import 'package:flutter/material.dart';
import 'package:my_app/debug_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'IntroScreen.dart';
import 'services/storage_service.dart';
import 'services/session_service.dart';
import 'services/mpin_service.dart';
import 'screens/account/login_screen.dart';
import 'screens/set_mpin_screen.dart';
import 'screens/mpin_verify_screen.dart';

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

  // In main.dart, find this method and replace it:
  Future<Widget> _getInitialScreen() async {
    final prefs = await SharedPreferences.getInstance(); // ✅ Add this

    // ✅ Check if intro has been shown before
    final hasSeenIntro = prefs.getBool('has_seen_intro') ?? false;

    // Check if user is logged in
    final isLoggedIn = await SessionService.isLoggedIn();

    // ✅ FIRST TIME - Show intro and mark as seen
    if (!hasSeenIntro) {
      await prefs.setBool('has_seen_intro', true); // Mark intro as seen
      return const IntroScreen();
    }

    // ✅ RETURNING USER - Skip intro
    if (!isLoggedIn) {
      return const LoginScreen(); // Direct to login
    }

    // Check if session is still valid (24 hours)
    final isSessionValid = await SessionService.isSessionValid();

    if (!isSessionValid) {
      await SessionService.clearSession();
      return const LoginScreen();
    }

    // Session valid - check MPIN
    final needsMpin = await SessionService.needsMpinVerification();
    final isMpinSet = await MpinService.isMpinSet();
    final token = await SessionService.getToken();
    final userId = await SessionService.getUserId();

    if (needsMpin && isMpinSet && token != null && userId != null) {
      return MpinVerifyScreen(userId: userId, token: token);
    } else if (!isMpinSet && token != null && userId != null) {
      return SetMpinScreen(userId: userId, token: token);
    }

    // Default fallback
    return const LoginScreen();
  }
}
