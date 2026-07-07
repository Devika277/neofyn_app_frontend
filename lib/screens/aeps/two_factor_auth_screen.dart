// lib/screens/aeps/two_factor_auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import 'aeps_dashboard_screen.dart';
import 'biometric_service.dart';

// ─── DEVICE TYPE ENUM ─────────────────────────────────────────
enum DeviceType {
  mantra('Mantra MFS-110', 'Mantra', Icons.fingerprint, 'mantra'),
  morpho('Morpho MSO 1300', 'Morpho', Icons.scanner, 'morpho');

  final String displayName;
  final String shortName;
  final IconData icon;
  final String apiValue;

  const DeviceType(this.displayName, this.shortName, this.icon, this.apiValue);
}

// ─────────────────────────────────────────────────────────────────────────────
// TwoFactorAuthScreen
// ─────────────────────────────────────────────────────────────────────────────

class TwoFactorAuthScreen extends StatefulWidget {
  final String? merchantId;
  final String? merchantRefId;
  final String? pipe;
  final String? aadhaarNumber;

  const TwoFactorAuthScreen({
    super.key,
    this.merchantId,
    this.merchantRefId,
    this.pipe,
    this.aadhaarNumber,
  });

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

  // ─── DEVICE SELECTION ───────────────────────────────────────
  DeviceType _selectedDevice = DeviceType.mantra;

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

    final provider = context.read<AepsProvider>();

    // ✅ Use passed aadhaar number, or fallback to provider's stored one
    if (widget.aadhaarNumber?.isNotEmpty == true) {
      _aadhaarController.text = widget.aadhaarNumber!;
    } else if (provider.aadhaarNo?.isNotEmpty == true) {
      _aadhaarController.text = provider.aadhaarNo!;
    }

    // ✅ Set the active pipe if provided
    if (widget.pipe != null && widget.pipe!.isNotEmpty) {
      provider.setActivePipe(widget.pipe!);
    }

    // ✅ Check if 2FA already done for this pipe today
    _checkPipe2FAStatus();

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

  // ═══════════════════════════════════════════════════════════════════════════
  // Check if 2FA already done for this pipe today
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _checkPipe2FAStatus() async {
    final provider = context.read<AepsProvider>();
    final currentPipe = widget.pipe ?? provider.pipe ?? '1';

    // ✅ NEW: Check per-pipe 2FA status
    if (provider.is2FADoneForPipe(currentPipe)) {
      print('✅ Pipe $currentPipe: 2FA already done today → Redirecting to dashboard');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AepsDashboardScreen()),
        );
      }
      return;
    }

    // Fallback to old check
    if (!provider.needs2FA()) {
      print('✅ Already verified today (legacy check) → Redirecting to dashboard');
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
    if (_deviceState == _DeviceState.checking || _deviceState == _DeviceState.connected) return;

    setState(() {
      _deviceState = _DeviceState.checking;
      _deviceStatusMsg = 'Checking ${_selectedDevice.displayName} RD Service...';
    });

    try {
      final connected = await BiometricService.checkDevice();
      if (!mounted) return;

      if (connected) {
        setState(() {
          _deviceState = _DeviceState.connected;
          _deviceStatusMsg = '${_selectedDevice.displayName} RD Service ready.';
        });
      } else {
        setState(() {
          _deviceState = _DeviceState.notConnected;
          _deviceStatusMsg = '${_selectedDevice.displayName} RD Service not running. Install RD Service APK.';
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
      _deviceStatusMsg = 'Place finger on ${_selectedDevice.shortName} scanner...';
    });

    try {
      final provider = context.read<AepsProvider>();
      final currentPipe = widget.pipe ?? provider.pipe ?? '1';

      final pidXml = await BiometricService.capturePid(
        clientKey: 'NEOFYN',
        skipWadh: true,
        pipe: currentPipe,
      );
      print('✅ PID captured for 2FA (Pipe $currentPipe): ${pidXml?.substring(0, 100)}...');

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

    final currentPipe = widget.pipe ?? provider.pipe ?? '1';
    final merchantIdToUse = widget.merchantId ?? provider.getMerchantIdForPipe(currentPipe) ?? provider.merchantId;
    final merchantRefIdToUse = widget.merchantRefId ?? provider.getMerchantRefIdForPipe(currentPipe) ?? provider.merchantRefId;
    final refId = merchantRefIdToUse ?? 'NEO_${provider.userId}_${DateTime.now().millisecondsSinceEpoch}';

    print('🔵 [2FA] Pipe: $currentPipe');
    print('🔵 [2FA] MerchantId: $merchantIdToUse');
    print('🔵 [2FA] MerchantRefId: $refId');
    print('🔵 [2FA] Device: ${_selectedDevice.apiValue}');

    try {
      // ✅ Use perform2FA with explicit pipe parameter
      final bool success = await provider.perform2FA(
        merchantId: merchantIdToUse!,
        merchantRefId: refId,
        pipe: currentPipe,
        aadhaarNumber: aadhaar,
        pidData: _pidXml!,
        deviceType: _selectedDevice.apiValue,
      );

      if (!mounted) return;

      if (success) {
        // ✅ 2FA status is already updated in provider's set2FADoneForPipe()
        print('✅ [2FA] Pipe $currentPipe: Verification successful!');
        _showSnackBar('Verification successful for Pipe $currentPipe!', isError: false);
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
          _deviceStatusMsg = '${_selectedDevice.displayName} RD Service ready. Try again.';
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

  // ─── DEVICE SELECTOR WIDGET ─────────────────────────────────
  Widget _buildDeviceSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: DeviceType.values.map((device) {
          final isSelected = _selectedDevice == device;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDevice = device;
                  _deviceState = _DeviceState.unknown;
                  _deviceStatusMsg = 'Tap "Check Device" to detect scanner';
                  _isCaptured = false;
                  _pidXml = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2ECC71).withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(
                      color: const Color(0xFF2ECC71).withOpacity(0.5),
                      width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      device.icon,
                      color: isSelected ? const Color(0xFF2ECC71) : Colors.white38,
                      size: 24,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      device.shortName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.displayName.split(' ').last,
                      style: TextStyle(
                        color: isSelected ? Colors.white.withOpacity(0.7) : Colors.white30,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Build
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final bool busy = _isCapturing || _isVerifying;
    final bool canCapture = _deviceState == _DeviceState.connected && !busy;
    final bool canVerify = _deviceState == _DeviceState.connected && _isCaptured && !busy;
    final currentPipe = widget.pipe ?? context.read<AepsProvider>().pipe ?? '1';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          '2FA - Pipe $currentPipe',
          style: const TextStyle(color: Colors.white, fontSize: 17),
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
              // ✅ Pipe indicator banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFF2ECC71), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Authenticating for Pipe $currentPipe',
                      style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Step 1: Select Device ──────────────────────────────────
              _stepLabel('Step 1 – Select Device'),
              const SizedBox(height: 10),
              _buildDeviceSelector(),
              const SizedBox(height: 28),

              // ── Step 2: Aadhaar ──────────────────────────────────────────
              _stepLabel('Step 2 – Enter Aadhaar'),
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

              // ── Step 3: Connect & Capture ────────────────────────────────
              _stepLabel('Step 3 – Connect & Capture'),
              const SizedBox(height: 10),

              // Device chip - DYNAMIC
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: Row(
                  children: [
                    Icon(_selectedDevice.icon, color: Colors.white54, size: 18),
                    const SizedBox(width: 10),
                    const Text('Device: ',
                        style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text(_selectedDevice.displayName,
                        style: const TextStyle(
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _deviceState == _DeviceState.connected ? null : _checkDeviceConnection,
                icon: _deviceState == _DeviceState.checking
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Icon(
                    _deviceState == _DeviceState.connected ? Icons.check_circle : Icons.usb,
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
                      builder: (_, child) =>
                          Transform.scale(scale: _pulseAnim.value, child: child),
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
                        ? (_isCaptured ? Colors.blueGrey[700] : Colors.lightBlue[700])
                        : Colors.grey[850],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: canCapture ? _captureFingerprint : null,
                  icon: _isCapturing
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Icon(_isCaptured ? Icons.refresh : Icons.fingerprint, size: 22),
                  label: Text(
                    _isCapturing
                        ? 'Scanning…'
                        : (_isCaptured ? 'Recapture Fingerprint' : 'Capture Fingerprint'),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── Step 4: Verify ───────────────────────────────────────────
              _stepLabel('Step 4 – Verify'),
              const SizedBox(height: 10),

              if (_isCaptured) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D2B1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Biometric data ready. Tap Verify Now to authenticate.',
                          style: TextStyle(color: Color(0xFF2ECC71), fontSize: 13),
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
                    backgroundColor: canVerify ? const Color(0xFF2ECC71) : Colors.grey[800],
                    foregroundColor: canVerify ? Colors.black : Colors.grey[600],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: canVerify ? 4 : 0,
                  ),
                  onPressed: canVerify ? _startVerification : null,
                  child: _isVerifying
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2.5),
                  )
                      : const Text('Verify Now',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 20),
              Text(
                'Biometric verification is required once per day per pipe before performing any AePS transaction.',
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

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
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
        borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
    focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
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