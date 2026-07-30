/*
// lib/screens/aeps/otp_ekyc_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import '../../widgets/custom_button.dart';
import '../../layout/UserHomeScreen.dart';
import 'biometric_service.dart';
import 'aeps_wrapper_screen.dart';

// ─── Device Type Enum ─────────────────────────────────────────
enum DeviceType {
  mantra('Mantra MFS-110', 'Mantra', Icons.fingerprint, 'mantra'),
  morpho('Morpho MSO 1300', 'Morpho', Icons.scanner, 'morpho');

  final String displayName;
  final String shortName;
  final IconData icon;
  final String apiValue;

  const DeviceType(this.displayName, this.shortName, this.icon, this.apiValue);
}

class OtpEkycScreen extends StatefulWidget {
  final String merchantId;
  final String merchantRefId;
  final String pipe;
  final String aadhaarNumber;
  final String phoneNumber;

  const OtpEkycScreen({
    super.key,
    required this.merchantId,
    required this.merchantRefId,
    required this.pipe,
    required this.aadhaarNumber,
    required this.phoneNumber,
  });

  @override
  State<OtpEkycScreen> createState() => _OtpEkycScreenState();
}

class _OtpEkycScreenState extends State<OtpEkycScreen> {
  // ─── Step tracking ──────────────────────────────────────────
  int _currentStep = 1; // 1=OTP, 2=EKYC

  // ─── OTP State ──────────────────────────────────────────────
  final _otpController = TextEditingController();
  bool _isOtpVerified = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;
  Timer? _otpTimer;
  int _otpSecondsRemaining = 30;

  // ─── EKYC State ─────────────────────────────────────────────
  bool _isLoading = false;
  bool _ekycDone = false;
  bool _deviceAvailable = false;
  bool _isCheckingDevice = true;
  DeviceType _selectedDevice = DeviceType.mantra;

  // ─── Aadhaar - Auto-filled ──────────────────────────────────
  late String _aadhaarNumber;
  final _aadhaarController = TextEditingController();

  // Debug
  List<String> _debugLogs = [];
  String _lastPidData = '';
  String _backendResponse = '';

  bool get _isAadhaarValid =>
      _aadhaarNumber.length == 12 && RegExp(r'^\d{12}$').hasMatch(_aadhaarNumber);

  @override
  void initState() {
    super.initState();

    // ✅ Auto-fill Aadhaar from registration
    _aadhaarNumber = widget.aadhaarNumber;
    _aadhaarController.text = widget.aadhaarNumber;

    _addLog('🔄 OTP+EKYC Screen Initialized');
    _addLog('📝 MerchantId: ${widget.merchantId}');
    _addLog('📝 Aadhaar: ${_aadhaarNumber.isNotEmpty ? "${_aadhaarNumber.substring(0,4)}XXXX${_aadhaarNumber.substring(8)}" : "Not provided"}');
    _addLog('📝 Phone: ${widget.phoneNumber}');

    // Start OTP flow automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendOtp();
      _checkDeviceAvailability();
    });
  }

  @override
  void dispose() {
    _otpTimer?.cancel();
    _otpController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }

  void _addLog(String msg) {
    final timestamp = DateTime.now().toIso8601String().split('.').first;
    final logEntry = '$timestamp: $msg';
    setState(() {
      _debugLogs.insert(0, logEntry);
      if (_debugLogs.length > 50) _debugLogs.removeLast();
    });
    print(logEntry);
  }

  // ─── OTP Timer ──────────────────────────────────────────────
  void _startOtpTimer() {
    _otpTimer?.cancel();
    _otpSecondsRemaining = 30;
    _otpTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_otpSecondsRemaining > 0) {
            _otpSecondsRemaining--;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  // ─── SEND OTP ───────────────────────────────────────────────
  Future<void> _sendOtp() async {
    setState(() => _isSendingOtp = true);
    _addLog('📤 Sending OTP to ${widget.phoneNumber}...');

    try {
      final provider = context.read<AepsProvider>();
      final success = await provider.sendOtp(
        widget.merchantId,
        widget.phoneNumber,
        pipe: widget.pipe,
      );

      if (mounted) {
        setState(() => _isSendingOtp = false);

        if (success) {
          _addLog('✅ OTP Sent Successfully');
          _showSuccess('OTP sent to ${widget.phoneNumber}');
          _startOtpTimer();
          _otpController.clear();
        } else {
          _addLog('❌ Failed to send OTP: ${provider.errorMessage}');
          _showError(provider.errorMessage ?? 'Failed to send OTP');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingOtp = false);
        _addLog('❌ OTP Send Exception: $e');
        _showError('Failed to send OTP: $e');
      }
    }
  }

  // ─── VERIFY OTP ─────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      _showError('Please enter complete 6-digit OTP');
      return;
    }

    setState(() => _isVerifyingOtp = true);
    _addLog('🔐 Verifying OTP: ${_otpController.text}');

    try {
      final provider = context.read<AepsProvider>();
      final success = await provider.verifyOtp(
        widget.merchantId,
        _otpController.text,
        widget.merchantRefId,
        pipe: widget.pipe,
      );

      if (mounted) {
        setState(() => _isVerifyingOtp = false);

        if (success) {
          _addLog('✅ OTP Verified Successfully');
          _otpTimer?.cancel();
          setState(() {
            _isOtpVerified = true;
            _currentStep = 2; // Move to EKYC step
          });
          _showSuccess('OTP verified! Now complete EKYC');
        } else {
          _addLog('❌ OTP Verification Failed: ${provider.errorMessage}');
          _showError(provider.errorMessage ?? 'Invalid OTP');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifyingOtp = false);
        _addLog('❌ OTP Verify Exception: $e');
        _showError('Verification failed: $e');
      }
    }
  }

  // ─── CHECK DEVICE ───────────────────────────────────────────
  Future<void> _checkDeviceAvailability() async {
    _addLog('🔍 Checking RD Service for ${_selectedDevice.displayName}...');
    setState(() => _isCheckingDevice = true);
    try {
      final available = await BiometricService.checkDevice();
      _addLog('📱 RD Service: ${available ? "Available" : "Not Available"}');
      if (mounted) {
        setState(() {
          _deviceAvailable = available;
          _isCheckingDevice = false;
        });
      }
    } catch (e) {
      _addLog('❌ Device check error: $e');
      if (mounted) {
        setState(() {
          _deviceAvailable = false;
          _isCheckingDevice = false;
        });
      }
    }
  }

  // ─── INITIATE EKYC ──────────────────────────────────────────
  Future<void> _initiateEKYC() async {
    // ✅ Check OTP verified first
    if (!_isOtpVerified) {
      _showError('Please verify OTP first');
      return;
    }

    if (!_isAadhaarValid) {
      _showError('Please enter valid 12-digit Aadhaar');
      return;
    }

    if (!_deviceAvailable) {
      _showError('RD Service not available');
      return;
    }

    setState(() => _isLoading = true);
    _addLog('🚀 Starting EKYC with ${_selectedDevice.displayName}...');

    try {
      // Capture fingerprint
      _addLog('📤 Capturing fingerprint...');
      String pidData = await BiometricService.capturePid(clientKey: 'NEOFYN');
      _lastPidData = pidData;
      _addLog('✅ PID Captured (${pidData.length} chars)');

      // Send EKYC
      _addLog('📤 Sending EKYC to backend...');
      final provider = context.read<AepsProvider>();
      final success = await provider.startEkyc(
        merchantId: widget.merchantId,
        merchantRefId: widget.merchantRefId,
        pipe: widget.pipe,
        pidData: pidData,
        deviceType: _selectedDevice.apiValue,
        aadhaarNumber: _aadhaarNumber,
        ipAddress: provider.ipAddress,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        if (success) {
          _addLog('✅ EKYC Completed Successfully');
          setState(() => _ekycDone = true);
          _showSuccess('EKYC completed!');

          // Check status and navigate
          final status = await provider.fetchPipeStatus(widget.pipe);
          final regStatus = status?['registrationStatus']?.toString() ?? '';
          _addLog('📊 Registration Status: $regStatus');

          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => regStatus == 'active'
                    ? const AepsWrapperScreen()
                    : const UserHomeScreen(),
              ),
            );
          }
        } else {
          _backendResponse = provider.errorMessage ?? 'EKYC failed';
          _addLog('❌ EKYC Failed: $_backendResponse');

          // ✅ CHECK IF BACKEND ASKS FOR OTP AGAIN
          if (_backendResponse.toLowerCase().contains('otp') ||
              _backendResponse.toLowerCase().contains('verify')) {
            _addLog('⚠️ Backend requires OTP re-verification');
            setState(() {
              _isOtpVerified = false;
              _currentStep = 1;
            });
            _showError('Please verify OTP again before EKYC');
            _sendOtp();
          } else {
            _showError(_backendResponse);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _addLog('❌ EKYC Exception: $e');
        _showError('EKYC failed: $e');
      }
    }
  }

  // ─── UI Helpers ─────────────────────────────────────────────
  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── DEVICE SELECTOR ────────────────────────────────────────
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
              onTap: _isOtpVerified ? () {
                setState(() => _selectedDevice = device);
                _checkDeviceAvailability();
              } : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF2ECC71).withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected ? Border.all(color: const Color(0xFF2ECC71).withOpacity(0.5)) : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(device.icon, color: isSelected ? const Color(0xFF2ECC71) : Colors.white38, size: 24),
                    const SizedBox(height: 6),
                    Text(device.shortName, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12)),
                    Text(device.displayName.split(' ').last, style: TextStyle(color: isSelected ? Colors.white70 : Colors.white30, fontSize: 9)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verification', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          // Step indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStepDot(1, 'OTP'),
                const SizedBox(width: 8),
                Container(height: 2, width: 20, color: _currentStep >= 2 ? const Color(0xFF2ECC71) : Colors.grey),
                const SizedBox(width: 8),
                _buildStepDot(2, 'EKYC'),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // ─── STEP 1: OTP SECTION ──────────────────────
                  _buildOtpSection(),

                  const SizedBox(height: 30),

                  // ─── DIVIDER ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Container(height: 1, color: _currentStep >= 2 ? const Color(0xFF2ECC71) : Colors.grey[800])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          _isOtpVerified ? Icons.check_circle : Icons.arrow_downward,
                          color: _isOtpVerified ? const Color(0xFF2ECC71) : Colors.grey,
                        ),
                      ),
                      Expanded(child: Container(height: 1, color: _currentStep >= 2 ? const Color(0xFF2ECC71) : Colors.grey[800])),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // ─── STEP 2: EKYC SECTION ─────────────────────
                  _buildEkycSection(),
                ],
              ),
            ),
          ),

          // Debug logs
          if (_debugLogs.isNotEmpty)
            Container(
              height: 120,
              color: Colors.black87,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: Colors.grey[900],
                    child: const Row(
                      children: [
                        Icon(Icons.terminal, color: Colors.green, size: 14),
                        SizedBox(width: 8),
                        Text('Logs', style: TextStyle(color: Colors.green, fontSize: 11)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _debugLogs.length,
                      itemBuilder: (_, i) => Text(
                        _debugLogs[i],
                        style: const TextStyle(color: Colors.white54, fontSize: 9, fontFamily: 'monospace'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    final isCompleted = step == 1 && _isOtpVerified;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? const Color(0xFF2ECC71) : (isActive ? const Color(0xFF2ECC71) : Colors.grey),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 14)
                : Text('$step', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: isActive ? Colors.white : Colors.grey, fontSize: 10)),
      ],
    );
  }

  // ─── OTP SECTION ────────────────────────────────────────────
  Widget _buildOtpSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOtpVerified ? const Color(0xFF2ECC71).withOpacity(0.5) : Colors.grey[800]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isOtpVerified ? const Color(0xFF2ECC71).withOpacity(0.1) : Colors.grey[800],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isOtpVerified ? Icons.check_circle : Icons.sms,
                  color: _isOtpVerified ? const Color(0xFF2ECC71) : Colors.white54,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 1: OTP Verification', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    _isOtpVerified ? '✓ Verified' : 'Verify your mobile number',
                    style: TextStyle(color: _isOtpVerified ? const Color(0xFF2ECC71) : Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          if (!_isOtpVerified) ...[
            const SizedBox(height: 20),
            Text(
              'OTP sent to ${widget.phoneNumber}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // OTP Input
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
              ),
              child: TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  hintText: '••••••',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 28, letterSpacing: 12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (value) {
                  if (value.length == 6 && !_isVerifyingOtp) {
                    _verifyOtp();
                  }
                },
              ),
            ),

            const SizedBox(height: 20),

            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_isVerifyingOtp || _otpController.text.length != 6) ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isVerifyingOtp
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Verify OTP', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 16),

            // Resend OTP
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_otpSecondsRemaining > 0)
                  Text('Resend OTP in ${_otpSecondsRemaining}s', style: const TextStyle(color: Colors.white54))
                else
                  GestureDetector(
                    onTap: _isSendingOtp ? null : _sendOtp,
                    child: _isSendingOtp
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Color(0xFF2ECC71), strokeWidth: 2))
                        : const Text('Resend OTP', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── EKYC SECTION ───────────────────────────────────────────
  Widget _buildEkycSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isOtpVerified ? Colors.grey[800]! : Colors.grey[900]!,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isOtpVerified ? Colors.grey[800] : Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.fingerprint,
                  color: _isOtpVerified ? const Color(0xFF2ECC71) : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step 2: EKYC Verification',
                    style: TextStyle(
                      color: _isOtpVerified ? Colors.white : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isOtpVerified ? 'Scan fingerprint' : 'Complete OTP first',
                    style: TextStyle(
                      color: _isOtpVerified ? Colors.white54 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (!_isOtpVerified)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, color: Colors.orange, size: 12),
                      SizedBox(width: 4),
                      Text('Locked', style: TextStyle(color: Colors.orange, fontSize: 10)),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // EKYC content - Only enable if OTP verified
          if (_isOtpVerified) ...[
            // Device Selector
            _buildDeviceSelector(),
            const SizedBox(height: 16),

            // Aadhaar Field (Auto-filled)
            TextField(
              controller: _aadhaarController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey[850],
                hintText: 'Aadhaar Number',
                hintStyle: TextStyle(color: Colors.grey[600]),
                counterStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.credit_card, color: Color(0xFF2ECC71)),
                suffixIcon: _aadhaarNumber.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                  onPressed: () {
                    _aadhaarController.clear();
                    setState(() => _aadhaarNumber = '');
                  },
                )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2)),
              ),
              onChanged: (value) => setState(() => _aadhaarNumber = value),
            ),

            const SizedBox(height: 16),

            // Device Status
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_deviceAvailable ? Icons.check_circle : Icons.error, color: _deviceAvailable ? Colors.green : Colors.red, size: 18),
                const SizedBox(width: 8),
                Text(
                  _deviceAvailable ? 'Device Ready' : 'Device Not Available',
                  style: TextStyle(color: _deviceAvailable ? Colors.green : Colors.red, fontSize: 13),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Scan Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_deviceAvailable && _isAadhaarValid && !_isLoading) ? _initiateEKYC : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _deviceAvailable && _isAadhaarValid ? const Color(0xFF2ECC71) : Colors.grey,
                  disabledBackgroundColor: Colors.grey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 28, width: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, color: Colors.white, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      _deviceAvailable ? 'Scan Fingerprint' : 'Device Unavailable',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Locked message
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.lock_outline, color: Colors.grey, size: 48),
                  SizedBox(height: 12),
                  Text('Verify OTP to unlock EKYC', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}*/
