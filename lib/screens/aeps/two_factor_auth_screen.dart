import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import 'aeps_dashboard_screen.dart';
import 'biometric_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TwoFactorAuthScreen
// ─────────────────────────────────────────────────────────────────────────────

class TwoFactorAuthScreen extends StatefulWidget {
  const TwoFactorAuthScreen({super.key});

  @override
  State<TwoFactorAuthScreen> createState() => _TwoFactorAuthScreenState();
}

class _TwoFactorAuthScreenState extends State<TwoFactorAuthScreen>
    with SingleTickerProviderStateMixin {
  // ── Form ──────────────────────────────────────────────────────────────────
  final _aadhaarController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // ── Device ────────────────────────────────────────────────────────────────
  _DeviceState _deviceState = _DeviceState.unknown;
  String _deviceStatusMsg = 'Tap "Check Device" to detect scanner';

  // ── Capture ───────────────────────────────────────────────────────────────
  String? _pidXml;
  bool _isCaptured = false;
  bool _isCapturing = false;

  // ── Submit ────────────────────────────────────────────────────────────────
  bool _isVerifying = false;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // ═══════════════════════════════════════════════════════════════════════════
  // Lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  @override
 void initState() {
    super.initState();

    // Load saved Aadhaar if available
    final provider = context.read<AepsProvider>();
    if (provider.aadhaarNo?.isNotEmpty == true) {
      _aadhaarController.text = provider.aadhaarNo!;
    }

    // Check if already verified today
    _checkDailyVerificationStatus();

    // Setup pulse animation
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════════════
  // Check Daily Verification Status
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _checkDailyVerificationStatus() async {
    final provider = context.read<AepsProvider>();
    
    // Check if already verified today using the correct getter
    // Use needs2FA() - returns false if already verified today
    if (!provider.needs2FA()) {
      print('✅ Already verified today - redirecting to dashboard');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AepsDashboardScreen()),
        );
      }
    }
  }

  // ── Check Device Connection ─────────────────────────────────────────────

  Future<void> _checkDeviceConnection() async {
    if (_deviceState == _DeviceState.checking || 
        _deviceState == _DeviceState.connected) return;
    
    setState(() {
      _deviceState = _DeviceState.checking;
      _deviceStatusMsg = 'Checking RD Service...';
    });

    try {
      final connected = await BiometricService.checkDevice();
      if (!mounted) return;

      if (connected) {
        setState(() {
          _deviceState = _DeviceState.connected;
          _deviceStatusMsg = 'Mantra RD Service ready.';
        });
      } else {
        setState(() {
          _deviceState = _DeviceState.notConnected;
          _deviceStatusMsg = 'RD Service not running. Install Mantra RD Service APK.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deviceState = _DeviceState.error;
        _deviceStatusMsg = 'Error: $e';
      });
    }
  }

  // ── Capture Fingerprint ──────────────────────────────────────────────────

  Future<void> _captureFingerprint() async {
    if (_deviceState != _DeviceState.connected) {
      _showSnackBar('Connect device first.', isError: true);
      return;
    }

    setState(() {
      _isCapturing = true;
      _deviceStatusMsg = 'Place finger on scanner...';
    });

    try {
      // final pidXml = await BiometricService.capturePid(isFor2FA: true);
      // ✅ NEW - 2FA needs WADH, so skipWadh: false
    /*  final pidXml = await BiometricService.capturePid(
        clientKey: 'NEOFYN',
        skipWadh: false,  // 2FA requires WADH
        pipe: '1',
      );*/
      final provider = context.read<AepsProvider>();
      final currentPipe = provider.pipe ?? '1';

      final pidXml = await BiometricService.capturePid(
        clientKey: 'NEOFYN',
        skipWadh: true,    // 2FA requires WADH
        pipe: currentPipe,
      );
      print('✅ PID captured: ${pidXml?.substring(0, 100)}...');   // add this
      print('✅ PID captured for 2FA: ${pidXml?.substring(0, 100)}...');

      setState(() {
        _pidXml = pidXml;
        _isCaptured = true;
        _deviceStatusMsg = '✓ Fingerprint captured successfully';
      });
      _showSnackBar('Captured! Tap Verify Now.', isError: false);
    } catch (e) {
      setState(() {
        _deviceStatusMsg = 'Capture failed: ${e.toString()}';
        _isCaptured = false;
      });
      _showSnackBar(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  // ── Submit Verification ─────────────────────────────────────────────────

  Future<void> _startVerification() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_deviceState != _DeviceState.connected) {
      _showSnackBar('Scanner not connected.', isError: true);
      return;
    }
    if (!_isCaptured || _pidXml == null) {
      _showSnackBar('Capture fingerprint first.', isError: true);
      return;
    }

    setState(() => _isVerifying = true);

    final provider = context.read<AepsProvider>();
    final aadhaar = _aadhaarController.text.trim();
    // final merchantRefId = '2FA_${DateTime.now().millisecondsSinceEpoch}';
    // final merchantRefId = provider.getMerchantRefIdForPipe('1') ??
    //     'NEO_${provider.userId}_${DateTime.now().millisecondsSinceEpoch}';

    final currentPipe = provider.pipe ?? '1';
    final merchantRefId = provider.getMerchantRefIdForPipe(currentPipe);

    // ✅ If merchantRefId is null, use the one from registration
    final refId = merchantRefId ?? provider.merchantRefId ??
        'NEO_${provider.userId}_${DateTime.now().millisecondsSinceEpoch}';
    print('🔵 Using merchantRefId: $refId');
    print('🔵 For pipe: $currentPipe');
    print('🔵 Merchant ID: ${provider.merchantId}');
    try {
      final bool success = await provider.performDaily2FA(
        _pidXml!,
        deviceType: 'mantra',
        aadhaarNumber: aadhaar,
        merchantRefId: refId,
      );

      if (!mounted) return;

      if (success) {
        _showSnackBar('Verification successful!', isError: false);
        
        // Small delay for user to see success message
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AepsDashboardScreen()),
          );
        }
      } else {
        _showSnackBar(
          provider.errorMessage ?? 'Verification failed.',
          isError: true,
        );
        setState(() {
          _isCaptured = false;
          _pidXml = null;
          _deviceStatusMsg = 'Mantra RD Service ready. Try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI Helpers
  // ═══════════════════════════════════════════════════════════════════════════

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Color get _statusColor {
    switch (_deviceState) {
      case _DeviceState.connected:
        return _isCaptured ? const Color(0xFF2ECC71) : Colors.lightBlue;
      case _DeviceState.notConnected:
      case _DeviceState.permissionDenied:
      case _DeviceState.error:
        return Colors.redAccent;
      case _DeviceState.checking:
        return Colors.amber;
      case _DeviceState.unknown:
        return Colors.grey;
    }
  }

  IconData get _statusIcon {
    switch (_deviceState) {
      case _DeviceState.connected:
        return _isCaptured ? Icons.fingerprint : Icons.usb;
      case _DeviceState.notConnected:
      case _DeviceState.permissionDenied:
        return Icons.error_outline;
      case _DeviceState.error:
        return Icons.error_outline;
      case _DeviceState.checking:
        return Icons.search;
      case _DeviceState.unknown:
        return Icons.device_unknown;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool busy = _isCapturing || _isVerifying;
    final bool canCapture = _deviceState == _DeviceState.connected && !busy;
    final bool canVerify = _deviceState == _DeviceState.connected && _isCaptured && !busy;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Daily Biometric Verification',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Step 1: Aadhaar ──────────────────────────────────────────
              _stepLabel('Step 1 – Enter Aadhaar'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _aadhaarController,
                keyboardType: TextInputType.number,
                maxLength: 12,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(color: Colors.white, fontSize: 16),
                enabled: !busy,
                decoration: _inputDecoration('Aadhaar Number', Icons.credit_card),
                validator: (v) {
                  final val = v?.trim() ?? '';
                  if (val.isEmpty) return 'Aadhaar number is required';
                  if (val.length != 12) return 'Must be exactly 12 digits';
                  return null;
                },
              ),
              const SizedBox(height: 28),

              // ── Step 2: Connect & Capture ────────────────────────────────
              _stepLabel('Step 2 – Connect & Capture'),
              const SizedBox(height: 10),

              // Device chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.devices, color: Colors.white54, size: 18),
                    SizedBox(width: 10),
                    Text('Device: ',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text('Mantra MFS‑100',
                        style: TextStyle(
                            color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Check device button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[700]!),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _deviceState == _DeviceState.connected 
                    ? null 
                    : _checkDeviceConnection,
                icon: _deviceState == _DeviceState.checking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _deviceState == _DeviceState.connected 
                            ? Icons.check_circle 
                            : Icons.usb, 
                        size: 20),
                label: Text(
                  _deviceState == _DeviceState.checking
                      ? 'Detecting…'
                      : _deviceState == _DeviceState.connected
                          ? 'Device Connected'
                          : 'Check Device Connection',
                ),
              ),
              const SizedBox(height: 12),

              // Status card
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    _isCaptured
                        ? AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (_, child) => Transform.scale(
                                scale: _pulseAnim.value, child: child),
                            child: Icon(_statusIcon, color: _statusColor, size: 26),
                          )
                        : Icon(_statusIcon, color: _statusColor, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _deviceStatusMsg,
                        style: TextStyle(
                          color: _statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Capture button
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canCapture
                        ? (_isCaptured
                            ? Colors.blueGrey[700]
                            : Colors.lightBlue[700])
                        : Colors.grey[850],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: canCapture ? _captureFingerprint : null,
                  icon: _isCapturing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(
                          _isCaptured ? Icons.refresh : Icons.fingerprint,
                          size: 22),
                  label: Text(
                    _isCapturing
                        ? 'Scanning…'
                        : (_isCaptured
                            ? 'Recapture Fingerprint'
                            : 'Capture Fingerprint'),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Step 3: Verify ───────────────────────────────────────────
              _stepLabel('Step 3 – Verify'),
              const SizedBox(height: 10),

              if (_isCaptured) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2B1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF2ECC71).withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle,
                          color: Color(0xFF2ECC71), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Biometric data ready. Tap Verify Now to authenticate.',
                          style: TextStyle(
                              color: Color(0xFF2ECC71), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canVerify
                        ? const Color(0xFF2ECC71)
                        : Colors.grey[800],
                    foregroundColor:
                        canVerify ? Colors.black : Colors.grey[600],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: canVerify ? 4 : 0,
                  ),
                  onPressed: canVerify ? _startVerification : null,
                  child: _isVerifying
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Verify Now',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 20),
              const Text(
                'Biometric verification is required once per day before '
                'performing any AePS transaction.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // ── Small widget helpers ──────────────────────────────────────────────────

  Widget _stepLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Color(0xFF2ECC71),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
        ),
      );

  InputDecoration _inputDecoration(String label, IconData icon) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38),
        counterStyle: const TextStyle(color: Colors.white38),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[800]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[800]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF2ECC71), width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.5)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 2)),
        errorStyle: const TextStyle(color: Colors.redAccent),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
enum _DeviceState {
  unknown,
  checking,
  connected,
  notConnected,
  permissionDenied,
  error,
}