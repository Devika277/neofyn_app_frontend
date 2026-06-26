// lib/screens/aeps/pipe_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:my_app/layout/UserHomeScreen.dart';
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
}

class PipeSelectionScreen extends StatefulWidget {
  const PipeSelectionScreen({super.key});

  @override
  State<PipeSelectionScreen> createState() => _PipeSelectionScreenState();
}

class _PipeSelectionScreenState extends State<PipeSelectionScreen> {
  final List<String> pipes = ['1', '2', '3', '4'];
  Map<String, Map<String, dynamic>?> pipeStatus = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPipeStatuses();
  }

  Future<void> _loadPipeStatuses() async {
    final provider = context.read<AepsProvider>();
    final userId = provider.userId;

    if (userId == null) {
      setState(() => isLoading = false);
      return;
    }

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
      final map = <String, Map<String, dynamic>?>{};
      for (final entry in results) {
        map[entry.key] = entry.value;
      }

      if (mounted) {
        setState(() {
          pipeStatus = map;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // 🔄 Navigate to registration and refresh on return
  Future<void> _navigateToRegistration(String pipe) async {
    final provider = context.read<AepsProvider>();
    provider.setActivePipe(pipe);

    // Navigate and wait for result
    final needsRefresh = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MerchantRegistrationScreen(pipe: pipe),
      ),
    );

    // If returned with true (registration complete or verify later), refresh statuses
    if (needsRefresh == true && mounted) {
      setState(() => isLoading = true);
      _loadPipeStatuses();
    }
  }

  // 🔄 Navigate based on pipe status and refresh on return
  Future<void> _navigateBasedOnStatus(String pipe, Map<String, dynamic>? status) async {
    final provider = context.read<AepsProvider>();
    provider.setActivePipe(pipe);
    final aadhaarNumber = provider.aadhaarNo ?? '';

    if (status != null && status['merchantId'] != null) {
      provider.setMerchantData({
        'merchantId': status['merchantId'],
        'merchantRefId': status['merchantRefId'],
        'phone': provider.mobileNo,
        'aadhaarNo': aadhaarNumber,
        'pipe': pipe,
      });

      final regStatus = status['registrationStatus'] ?? '';
      bool? needsRefresh;

      switch (regStatus) {
        case 'active':
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
          );
          break;
        case 'otp_pending':
          needsRefresh = await Navigator.push<bool>(
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
          break;
        case 'otp_verified':
          await Navigator.push(
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
          break;
        default:
          needsRefresh = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => MerchantRegistrationScreen(pipe: pipe),
            ),
          );
      }

      // Refresh if needed
      if (needsRefresh == true && mounted) {
        setState(() => isLoading = true);
        _loadPipeStatuses();
      }
    } else {
      // No merchant data, navigate to registration
      final needsRefresh = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MerchantRegistrationScreen(pipe: pipe),
        ),
      );

      if (needsRefresh == true && mounted) {
        setState(() => isLoading = true);
        _loadPipeStatuses();
      }
    }
  }

  String _getStatusText(Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return 'Not Registered';
    final regStatus = status['registrationStatus'] ?? 'active';
    switch (regStatus) {
      case 'active': return 'Active';
      case 'otp_pending': return 'OTP Pending';
      case 'otp_verified': return 'KYC Pending';
      default: return regStatus.toUpperCase();
    }
  }

  Color _getStatusColor(Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return PipeColors.warning;
    final regStatus = status['registrationStatus'] ?? 'active';
    switch (regStatus) {
      case 'active': return PipeColors.success;
      case 'otp_pending': return PipeColors.pipePending;
      case 'otp_verified': return PipeColors.primaryLight;
      default: return PipeColors.warning;
    }
  }

  IconData _getStatusIcon(Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return Icons.add_circle_outline;
    final regStatus = status['registrationStatus'] ?? 'active';
    switch (regStatus) {
      case 'active': return Icons.check_circle;
      case 'otp_pending': return Icons.sms;
      case 'otp_verified': return Icons.fingerprint;
      default: return Icons.info_outline;
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
                      onPressed: () {
                        setState(() => isLoading = true);
                        _loadPipeStatuses();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

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
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
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

                // Arrow & Status
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
                      isRegistered ? 'Proceed' : 'Register',
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