import 'package:flutter/material.dart';
import 'package:my_app/debug_overlay.dart';
import 'OnboardingScreen.dart';
import 'services/storage_service.dart';


import 'package:provider/provider.dart';

import 'providers/aeps_provider.dart';
import 'providers/payout_provider.dart';
import 'providers/beneficiary_provider.dart';
import 'providers/wallet_provider.dart';
import 'services/storage_service.dart'; // adjust path
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
        ChangeNotifierProvider(create: (_) => RemitterProvider()), // add this
        ChangeNotifierProvider(create: (_) => AuthProvider()), 

      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NeoFyn',
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF000000),
          primaryColor: const Color(0xFF2ECC71),
          // You may also want to add:
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2ECC71),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const OnboardingScreen(),
        builder: (context, child) {
          // DebugOverlay is placed correctly here – it will wrap all screens
          return DebugOverlay(child: child ?? const SizedBox.shrink());
        },
      ),
    );
  }
}
