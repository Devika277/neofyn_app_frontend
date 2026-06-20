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
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color background = Color(0xFF0A0E0A);
  static const Color cardColor = Color(0xFF1A1F1A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF008169);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderFocus = Color(0xFF008169);

  // Pipe-specific colors
  static const Color pipeActive = Color(0xFF2ECC71);
  static const Color pipeInactive = Color(0xFFE67E22);
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
  String? _selectedPipe;

  @override
  void initState() {
    super.initState();
    _loadPipeStatuses();
  }

  Future<void> _loadPipeStatuses() async {
    debugPrint('🔄 Loading pipe statuses...');
    final provider = context.read<AepsProvider>();
    final userId = provider.userId;

    if (userId == null) {
      debugPrint('❌ userId is null, cannot fetch pipe statuses');
      setState(() => isLoading = false);
      return;
    }

    try {
      final futures = pipes.map((pipe) async {
        try {
          final status = await provider.fetchPipeStatus(pipe);
          return MapEntry(pipe, status);
        } catch (e) {
          debugPrint('❌ Error fetching pipe $pipe: $e');
          return MapEntry(pipe, null);
        }
      }).toList();

      final results = await Future.wait(futures);

      final map = <String, Map<String, dynamic>?>{};
      for (final entry in results) {
        map[entry.key] = entry.value;
      }

      setState(() {
        pipeStatus = map;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading pipe statuses: $e');
      setState(() => isLoading = false);
    }
  }

  void _onPipeSelected(String pipe, Map<String, dynamic>? status) {
    setState(() => _selectedPipe = pipe);

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

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;

        switch (regStatus) {
          case 'active':
            Navigator.push(
              context,
              _createRoute(const AepsWrapperScreen()),
            );
            break;
          case 'otp_pending':
            Navigator.push(
              context,
              _createRoute(MerchantRegistrationScreen(
                isOtpPending: true,
                merchantData: status,
                pipe: pipe,
                phone: provider.mobileNo,
              )),
            );
            break;
          case 'otp_verified':
            Navigator.push(
              context,
              _createRoute(EKYC_Screen(
                merchantId: status['merchantId'],
                merchantRefId: status['merchantRefId'],
                pipe: pipe,
                aadhaarNumber: aadhaarNumber,
              )),
            );
            break;
          default:
            Navigator.push(
              context,
              _createRoute(MerchantRegistrationScreen(
                pipe: pipe,
              )),
            );
        }
      });
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.push(
          context,
          _createRoute(MerchantRegistrationScreen(
            pipe: pipe,
          )),
        );
      });
    }
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  String _getStatusText(Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return 'Not Registered';

    final regStatus = status['registrationStatus'] ?? 'active';
    switch (regStatus) {
      case 'active':
        return 'Active';
      case 'otp_pending':
        return 'OTP Pending';
      case 'otp_verified':
        return 'KYC Pending';
      default:
        return regStatus.toUpperCase();
    }
  }

  Color _getStatusColor(Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return PipeColors.warning;

    final regStatus = status['registrationStatus'] ?? 'active';
    switch (regStatus) {
      case 'active':
        return PipeColors.success;
      case 'otp_pending':
        return PipeColors.pipePending;
      case 'otp_verified':
        return PipeColors.primaryLight;
      default:
        return PipeColors.warning;
    }
  }

  IconData _getStatusIcon(Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return Icons.edit_note;

    final regStatus = status['registrationStatus'] ?? 'active';
    switch (regStatus) {
      case 'active':
        return Icons.check_circle;
      case 'otp_pending':
        return Icons.sms_failed;
      case 'otp_verified':
        return Icons.fingerprint;
      default:
        return Icons.info;
    }
  }

  String _getButtonText(Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return 'Register Now';

    final regStatus = status['registrationStatus'] ?? 'active';
    switch (regStatus) {
      case 'active':
        return 'Proceed';
      case 'otp_pending':
        return 'Verify OTP';
      case 'otp_verified':
        return 'Complete KYC';
      default:
        return 'Continue';
    }
  }

  Color _getButtonColor(Map<String, dynamic>? status) {
    if (status == null || status['merchantId'] == null) return PipeColors.warning;

    final regStatus = status['registrationStatus'] ?? 'active';
    switch (regStatus) {
      case 'active':
        return PipeColors.success;
      case 'otp_pending':
        return PipeColors.pipePending;
      case 'otp_verified':
        return PipeColors.primaryLight;
      default:
        return PipeColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Navigate to home screen instead of closing app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const UserHomeScreen()),
        );
        return false; // Prevent default back behavior
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0A0E0A),
                Color(0xFF0F1A0F),
                Color(0xFF0A0E0A),
                Color(0xFF050805),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white70,
                          size: 20,
                        ),
                        onPressed: (){
                          // Navigate to home instead of popping
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
                          );
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Select AEPS Pipe',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),

                Expanded(
                  child: isLoading
                      ? _buildLoadingState()
                      : _buildPipeList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [PipeColors.primary, PipeColors.primaryLight],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: PipeColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const SizedBox(
              height: 40,
              width: 40,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Loading Pipes...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fetching your AEPS pipe status',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPipeList() {
    return Column(
      children: [
        // Header Section
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [PipeColors.primary, PipeColors.primaryLight],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PipeColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Choose Your Pipe',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Pipe List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pipes.length,
            itemBuilder: (context, index) {
              final pipe = pipes[index];
              final status = pipeStatus[pipe];
              final isRegistered = status != null &&
                  status['merchantId'] != null &&
                  status['merchantId'].toString().isNotEmpty;

              return _buildPipeCard(pipe, status, isRegistered);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPipeCard(String pipe, Map<String, dynamic>? status, bool isRegistered) {
    final statusText = _getStatusText(status);
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);
    final buttonText = _getButtonText(status);
    final buttonColor = _getButtonColor(status);
    final isSelected = _selectedPipe == pipe;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 50 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PipeColors.cardColor,
              PipeColors.cardColor.withOpacity(0.8),
            ],
          ),
          border: Border.all(
            color: isSelected
                ? PipeColors.primary.withOpacity(0.5)
                : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? PipeColors.primary.withOpacity(0.2)
                  : Colors.black.withOpacity(0.2),
              blurRadius: isSelected ? 15 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onPipeSelected(pipe, status),
            borderRadius: BorderRadius.circular(16),
            splashColor: PipeColors.primary.withOpacity(0.1),
            highlightColor: PipeColors.primary.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      // Pipe Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.settings_input_component_rounded,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Pipe Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pipe $pipe',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    statusIcon,
                                    size: 12,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Arrow Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? PipeColors.primary.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: isSelected ? PipeColors.primary : Colors.white38,
                          size: 16,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Status Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildStatusDot(isRegistered),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isRegistered
                                ? 'Pipe $pipe is $statusText'
                                : 'Pipe $pipe needs registration',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            buttonColor,
                            buttonColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: buttonColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _onPipeSelected(pipe, status),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isRegistered ? Icons.login : Icons.app_registration,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              buttonText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusDot(bool isRegistered) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRegistered ? PipeColors.success : PipeColors.warning,
        boxShadow: [
          BoxShadow(
            color: (isRegistered ? PipeColors.success : PipeColors.warning)
                .withOpacity(0.5),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}