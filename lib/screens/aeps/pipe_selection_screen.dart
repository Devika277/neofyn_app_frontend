// lib/screens/aeps/pipe_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:my_app/layout/UserHomeScreen.dart';
import 'package:my_app/screens/aeps/two_factor_auth_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import 'aeps_wrapper_screen.dart';
import 'merchant_registration_screen.dart';
import 'ekyc_screen.dart';

// ─── NEOFYN BRAND TOKENS ──────────────────────────────────────
class PipeColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color background = Color(0xFF0A0E0A);
  static const Color cardColor = Color(0xFF1A1F1A);
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color pipePending = Color(0xFFF39C12);
  static const Color twoFARequired = Color(0xFFE74C3C); // ✅ New
}

class PipeSelectionScreen extends StatefulWidget {
  const PipeSelectionScreen({super.key});

  @override
  State<PipeSelectionScreen> createState() => _PipeSelectionScreenState();
}

class _PipeSelectionScreenState extends State<PipeSelectionScreen> {
  // final List<String> pipes = ['1', '2', '3'];
  final List<String> pipes = ['1', '2'];
  Map<String, Map<String, dynamic>?> pipeStatus = {};
  Map<String, bool> pipe2FAStatus = {}; // ✅ 2FA status per pipe
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    final provider = context.read<AepsProvider>();
    final userId = provider.userId;

    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

    setState(() => isLoading = true);

    try {
      // ✅ Load both pipe statuses AND 2FA status in parallel
      final results = await Future.wait([
        _loadPipeStatuses(provider),
        _load2FAStatus(provider, userId),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadPipeStatuses(AepsProvider provider) async {
    try {
      final futures = pipes.map((pipe) async {
        try {
          final status = await provider.fetchPipeStatus(pipe);
          return MapEntry(pipe, status);
        } catch (e) {
          return MapEntry(pipe, null);
        }
      }).toList();

      final results = await Future.wait(futures);
      if (mounted) {
        setState(() {
          for (final entry in results) {
            pipeStatus[entry.key] = entry.value;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading pipe statuses: $e');
    }
  }

  Future<void> _load2FAStatus(AepsProvider provider, String userId) async {
    try {
      await provider.fetch2FAStatus(userId);
      if (mounted) {
        setState(() {
          pipe2FAStatus = {
            '1': provider.is2FADoneForPipe('1'),
            '2': provider.is2FADoneForPipe('2'),
            '3': provider.is2FADoneForPipe('3'),
          };
        });
      }
      debugPrint('✅ 2FA Status loaded: $pipe2FAStatus');
    } catch (e) {
      debugPrint('Error loading 2FA status: $e');
    }
  }

  // 🔄 Navigate to registration and refresh on return
  Future<void> _navigateToRegistration(String pipe) async {
    final provider = context.read<AepsProvider>();
    provider.setActivePipe(pipe);

    final needsRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantRegistrationScreen(pipe: pipe),
      ),
    );

    if (needsRefresh == true && mounted) {
      _loadAllData();
    }
  }

  // ✅ NEW: Navigate based on pipe status + 2FA status
  Future<void> _navigateBasedOnStatus(String pipe, Map<String, dynamic>? status) async {
    final provider = context.read<AepsProvider>();
    provider.setActivePipe(pipe);
    final aadhaarNumber = provider.aadhaarNo ?? '';
    final is2FADone = pipe2FAStatus[pipe] ?? false;

    // ── Case 1: Not registered → Registration Screen ──
    if (status == null || status['merchantId'] == null) {
      final needsRefresh = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MerchantRegistrationScreen(pipe: pipe),
        ),
      );
      if (needsRefresh == true && mounted) _loadAllData();
      return;
    }

    // ── Merchant exists, set merchant data ──
    provider.setMerchantData({
      'merchantId': status['merchantId'],
      'merchantRefId': status['merchantRefId'],
      'phone': provider.mobileNo,
      'aadhaarNo': aadhaarNumber,
      'pipe': pipe,
    });

    final regStatus = status['registrationStatus'] ?? '';

    // ── Case 2: Registration incomplete states ──
    switch (regStatus) {
      case 'otp_pending':
        final needsRefresh = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MerchantRegistrationScreen(
              isOtpPending: true,
              merchantData: status,
              pipe: pipe,
              phone: provider.mobileNo,
            ),
          ),
        );
        if (needsRefresh == true && mounted) _loadAllData();
        return;

      case 'otp_verified':
        final needsRefresh = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => EKYC_Screen(
              merchantId: status['merchantId'],
              merchantRefId: status['merchantRefId'],
              pipe: pipe,
              aadhaarNumber: aadhaarNumber,
            ),
          ),
        );
        if (needsRefresh == true && mounted) _loadAllData();
        return;

      case 'active':
      // ── Case 3: Active but 2FA NOT done today → 2FA Screen ──
        if (!is2FADone) {
          debugPrint('🔴 Pipe $pipe: Active but 2FA NOT done today → Navigating to 2FA');
          final needsRefresh = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => TwoFactorAuthScreen(
                merchantId: status['merchantId'],
                merchantRefId: status['merchantRefId'],
                pipe: pipe,
                aadhaarNumber: aadhaarNumber,
              ),
            ),
          );
          if (needsRefresh == true && mounted) _loadAllData();
          return;
        }

        // ── Case 4: Active + 2FA done → Transaction Screen ──
        debugPrint('🟢 Pipe $pipe: Active + 2FA done → Navigating to AEPS');
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
        );
        // Refresh on return
        if (mounted) _loadAllData();
        return;

      default:
        final needsRefresh = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MerchantRegistrationScreen(pipe: pipe),
          ),
        );
        if (needsRefresh == true && mounted) _loadAllData();
    }
  }

  String _getStatusText(String pipe, Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return 'Not Registered';
    final regStatus = status['registrationStatus'] ?? 'active';

    // ✅ If active but 2FA not done, show "2FA Required"
    if (regStatus == 'active' && !(pipe2FAStatus[pipe] ?? false)) {
      return '2FA Required';
    }

    switch (regStatus) {
      case 'active': return 'Active';
      case 'otp_pending': return 'OTP Pending';
      case 'otp_verified': return 'KYC Pending';
      default: return regStatus.toUpperCase();
    }
  }

  Color _getStatusColor(String pipe, Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return PipeColors.warning;
    final regStatus = status['registrationStatus'] ?? 'active';

    // ✅ If active but 2FA not done, show red
    if (regStatus == 'active' && !(pipe2FAStatus[pipe] ?? false)) {
      return PipeColors.twoFARequired;
    }

    switch (regStatus) {
      case 'active': return PipeColors.success;
      case 'otp_pending': return PipeColors.pipePending;
      case 'otp_verified': return PipeColors.primaryLight;
      default: return PipeColors.warning;
    }
  }

  IconData _getStatusIcon(String pipe, Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return Icons.add_circle_outline;
    final regStatus = status['registrationStatus'] ?? 'active';

    // ✅ If active but 2FA not done, show fingerprint icon
    if (regStatus == 'active' && !(pipe2FAStatus[pipe] ?? false)) {
      return Icons.fingerprint;
    }

    switch (regStatus) {
      case 'active': return Icons.check_circle;
      case 'otp_pending': return Icons.sms;
      case 'otp_verified': return Icons.fingerprint;
      default: return Icons.info_outline;
    }
  }

  String _getActionText(String pipe, Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return 'Register';
    final regStatus = status['registrationStatus'] ?? 'active';

    if (regStatus == 'active' && !(pipe2FAStatus[pipe] ?? false)) {
      return 'Do 2FA';
    }

    switch (regStatus) {
      case 'active': return 'Proceed';
      case 'otp_pending': return 'Verify OTP';
      case 'otp_verified': return 'Do KYC';
      default: return 'Register';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E0A), Color(0xFF0F1A0F), Color(0xFF0A0E0A), Color(0xFF050805)],
            stops: [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const UserHomeScreen()),
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Select Pipe',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                      onPressed: () => _loadAllData(),
                    ),
                  ],
                ),
              ),

              // ✅ 2FA Summary Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: PipeColors.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.white54, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '2FA resets daily. Complete fingerprint auth to use AEPS.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Content
              Expanded(
                child: isLoading
                    ? const Center(
                  child: CircularProgressIndicator(color: PipeColors.primary),
                )
                    : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: pipes.length,
                  itemBuilder: (context, index) {
                    final pipe = pipes[index];
                    final status = pipeStatus[pipe];
                    return _buildPipeCard(pipe, status);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPipeCard(String pipe, Map<String, dynamic>? status) {
    final statusText = _getStatusText(pipe, status);
    final statusColor = _getStatusColor(pipe, status);
    final statusIcon = _getStatusIcon(pipe, status);
    final actionText = _getActionText(pipe, status);
    final isRegistered = status != null && status['merchantId'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PipeColors.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRegistered ? statusColor.withOpacity(0.2) : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => _navigateBasedOnStatus(pipe, status),
          borderRadius: BorderRadius.circular(14),
          splashColor: statusColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Status Icon with colored background
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 24),
                ),

                const SizedBox(width: 14),

                // Pipe Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Pipe $pipe',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: statusColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow & Action
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withOpacity(0.3),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      actionText,
                      style: TextStyle(
                        color: statusColor.withOpacity(0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}