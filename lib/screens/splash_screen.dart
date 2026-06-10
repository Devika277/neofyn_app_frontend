import 'dart:async';
import 'package:flutter/material.dart';
import 'account/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    // Simulate loading (e.g., checking token, API, etc.)
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
      );
    });
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      width: double.infinity,
      color: const Color.fromARGB(255, 241, 240, 240),

      // color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/images/logo_white.png',
            width: 150,
          ),
          SizedBox(height: 20),
          // Text(
          //   "My App",
          //   style: TextStyle(
          //     fontSize: 24,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
        ],
      ),
    ),
  );
}

}
