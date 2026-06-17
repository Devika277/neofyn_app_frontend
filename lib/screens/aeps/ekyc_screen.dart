import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import '../../widgets/custom_button.dart';
import '../../screens/aeps/biometric_service.dart';
import '../../layout/UserHomeScreen.dart';
import 'aeps_wrapper_screen.dart';

class EKYC_Screen extends StatefulWidget {
  final String merchantId;
  final String merchantRefId;
  final String pipe;

  const EKYC_Screen({
    super.key,
    required this.merchantId,
    required this.merchantRefId,
    required this.pipe,
  });

  @override
  State<EKYC_Screen> createState() => _EKYC_ScreenState();
}

class _EKYC_ScreenState extends State<EKYC_Screen> {
  bool _isLoading = false;
  bool _ekycDone = false;
  bool _deviceAvailable = false;
  bool _isCheckingDevice = true;

  @override
  void initState() {
    super.initState();
    _checkDeviceAvailability();
  }

  /// Check if the RD Service is reachable
  Future<void> _checkDeviceAvailability() async {
    setState(() => _isCheckingDevice = true);
    try {
      final available = await BiometricService.checkDevice();
      setState(() {
        _deviceAvailable = available;
        _isCheckingDevice = false;
      });
      if (!available) {
        _showError('Mantra RD Service not reachable. Please ensure the app is installed and running.');
      }
    } catch (e) {
      setState(() {
        _deviceAvailable = false;
        _isCheckingDevice = false;
      });
      _showError('Error checking RD Service: $e');
    }
  }

  /// Initiate E‑KYC with real fingerprint capture
  Future<void> _initiateEKYC() async {
    // Check device availability first
    if (!_deviceAvailable) {
      _showError('RD Service not available. Please check your Mantra device.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Capture the fingerprint PID from the Mantra device
      final String pidData = await BiometricService.capturePid(
        clientKey: 'NEOFYN', // Use your client key
      );
      print('🔍 REAL PID DATA:\n$pidData');

      // 2. Call the provider's EKYC method with the real PID
      final provider = context.read<AepsProvider>();
      final success = await provider.startEkyc(
        merchantId: widget.merchantId,
        merchantRefId: widget.merchantRefId,
        pipe: widget.pipe,
        pidData: pidData,
        deviceType: 'mantra',
        aadhaarNumber: provider.aadhaarNo,
        ipAddress: provider.ipAddress,
      );

      if (success) {
        setState(() => _ekycDone = true);
        _showSuccess('EKYC completed successfully!');

        // 3. Fetch final status and navigate
        final status = await provider.fetchPipeStatus(widget.pipe);
        final regStatus = status?['registrationStatus'] ?? '';

        if (regStatus == 'active') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
          );
        }
      } else {
        _showError(provider.errorMessage ?? 'EKYC failed');
      }
    } on Exception catch (e) {
      // Handle specific errors from BiometricService
      final errorMsg = e.toString();
      if (errorMsg.contains('RD Service not reachable')) {
        _showError('Please ensure the Mantra RD Service is installed and running.');
        // Optionally retry device check
        await _checkDeviceAvailability();
      } else if (errorMsg.contains('timeout')) {
        _showError('Fingerprint capture timed out. Please ensure your device is connected and try again.');
      } else if (errorMsg.contains('errCode')) {
        _showError('Fingerprint capture error: $errorMsg');
      } else {
        _showError(errorMsg);
      }
    } catch (e) {
      _showError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('EKYC Verification', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status icon
              Icon(
                _ekycDone ? Icons.verified : Icons.fingerprint,
                size: 80,
                color: _ekycDone ? Colors.green : const Color(0xFF2ECC71),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                _ekycDone ? 'EKYC Completed' : 'Complete your EKYC',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                _ekycDone
                    ? 'You can now perform AEPS transactions.'
                    : 'Please place your finger on the Mantra scanner to capture PID data.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),

              // Device status
              if (!_ekycDone && !_isCheckingDevice) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _deviceAvailable ? Icons.check_circle : Icons.error,
                      color: _deviceAvailable ? Colors.green : Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _deviceAvailable ? 'RD Service connected' : 'RD Service unavailable',
                      style: TextStyle(
                        color: _deviceAvailable ? Colors.green : Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (!_deviceAvailable)
                  TextButton(
                    onPressed: _checkDeviceAvailability,
                    child: const Text('Retry connection', style: TextStyle(color: Color(0xFF2ECC71))),
                  ),
              ],

              const SizedBox(height: 40),

              // Action buttons
              if (_ekycDone)
                CustomButton(
                  text: 'Go to AEPS',
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
                    );
                  },
                  backgroundColor: const Color(0xFF2ECC71),
                  textColor: Colors.black,
                )
              else if (_isCheckingDevice)
                const Center(child: CircularProgressIndicator())
              else
                CustomButton(
                  text: _deviceAvailable ? 'Scan Fingerprint & Start EKYC' : 'RD Service Unavailable',
                  onPressed: () {
                    if (_deviceAvailable) {
                      _initiateEKYC();
                    }
                    // Do nothing if device not available
                  },
                  isLoading: _isLoading,
                  backgroundColor: _deviceAvailable ? const Color(0xFF2ECC71) : Colors.grey,
                  textColor: Colors.black,
                ),
              const SizedBox(height: 20),

              // Skip button (optional)
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const UserHomeScreen()),
                  );
                },
                child: const Text('Skip for now', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}