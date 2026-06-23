// screens/dmt/dmt_entry_screen.dart
import 'package:flutter/material.dart';
import 'package:my_app/services/storage_service.dart';
import 'package:my_app/screens/dmt1/sender_onboarding_form.dart';
import 'package:my_app/screens/dmt1/sender_lookup_screen.dart';


class DmtEntryScreen extends StatelessWidget {
  const DmtEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if user has completed onboarding
    final hasCompletedOnboarding = StorageService.hasCompletedOnboarding();
    
    if (!hasCompletedOnboarding) {
      // First time - Show Onboarding Form
      return const SenderOnboardingForm();
    } else {
      // Already onboarded - Show Mobile Entry
      return const SenderLookupScreen();
    }
  }
}