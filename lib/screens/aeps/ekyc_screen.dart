// lib/screens/aeps/ekyc_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import '../../widgets/custom_button.dart';
import '../../screens/aeps/biometric_service.dart';
import '../../layout/UserHomeScreen.dart';
import 'aeps_wrapper_screen.dart';

// ─── DEVICE TYPE ENUM ─────────────────────────────────────────
enum DeviceType {
  mantra('Mantra MFS-110', 'Mantra', Icons.fingerprint, 'mantra'),
  morpho('Morpho MSO 1300', 'Morpho', Icons.scanner, 'morpho'),
  startek('Startek FM220', 'Startek', Icons.fingerprint, 'startek');
  final String displayName;
  final String shortName;
  final IconData icon;
  final String apiValue;

  const DeviceType(this.displayName, this.shortName, this.icon, this.apiValue);
}

// ─── DEVICE STATE ENUM ───────────────────────────────────────
enum _DeviceState {
  unknown,
  checking,
  connected,
  notConnected,
  permissionDenied,
  error,
}

class EKYC_Screen extends StatefulWidget {
  final String merchantId;
  final String merchantRefId;
  final String pipe;
  final String aadhaarNumber;

  const EKYC_Screen({
    super.key,
    required this.merchantId,
    required this.merchantRefId,
    required this.pipe,
    required this.aadhaarNumber,
  });

  @override
  State<EKYC_Screen> createState() => _EKYC_ScreenState();
}

class _EKYC_ScreenState extends State<EKYC_Screen> {
  bool _isLoading = false;
  bool _ekycDone = false;

  // ─── DEVICE STATE MANAGEMENT ───────────────────────────────
  _DeviceState _deviceState = _DeviceState.unknown;
  String _deviceStatusMsg = 'Checking device connection...';
  bool _usbConnected = false;

  // ─── DEVICE SELECTION ───────────────────────────────────────
  DeviceType _selectedDevice = DeviceType.mantra;

  final TextEditingController _aadhaarController = TextEditingController();
  String _aadhaarNumber = '';

  // ─── COMPUTED PROPERTIES ────────────────────────────────────
  bool get _deviceAvailable => _deviceState == _DeviceState.connected;
  bool get _isCheckingDevice => _deviceState == _DeviceState.checking;

  Color get _statusColor {
    switch (_deviceState) {
      case _DeviceState.connected:
        return const Color(0xFF2ECC71);
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
        return Icons.check_circle;
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

  // ─── Lifecycle ──────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _aadhaarNumber = widget.aadhaarNumber;
    _aadhaarController.text = widget.aadhaarNumber;

    // Initialize biometric service first
    _initializeBiometricService();
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    super.dispose();
  }

  bool get _isAadhaarValid =>
      _aadhaarNumber.length == 12 &&
          RegExp(r'^\d{12}$').hasMatch(_aadhaarNumber);

  // ─── INITIALIZE BIOMETRIC SERVICE ──────────────────────────
  Future<void> _initializeBiometricService() async {
    setState(() {
      _deviceState = _DeviceState.unknown;
      _deviceStatusMsg = 'Initializing biometric service...';
    });

    try {
      await BiometricService.initialize();
      print('✅ Biometric Service initialized');

      // Check USB connection status
      _usbConnected = BiometricService.isUsbConnected;
      print('📱 USB Connected: $_usbConnected');

      if (_usbConnected) {
        setState(() {
          _deviceState = _DeviceState.unknown;
          _deviceStatusMsg = 'USB device detected. Checking RD Service...';
        });
        // Auto-check device if USB is connected
        await _checkDeviceAvailability();
      } else {
        setState(() {
          _deviceState = _DeviceState.notConnected;
          _deviceStatusMsg = 'No USB device detected. Please connect your ${_selectedDevice.shortName} device.';
        });
      }
    } catch (e) {
      print('❌ Biometric Service initialization error: $e');
      setState(() {
        _deviceState = _DeviceState.error;
        _deviceStatusMsg = 'Error initializing service: $e';
      });
    }
  }

  // ─── CHECK DEVICE AVAILABILITY ─────────────────────────────
  Future<void> _checkDeviceAvailability() async {
    if (_deviceState == _DeviceState.checking) return;

    print('🔍 Checking RD Service availability for ${_selectedDevice.displayName}...');

    setState(() {
      _deviceState = _DeviceState.checking;
      _deviceStatusMsg = 'Checking ${_selectedDevice.displayName} RD Service...';
    });

    try {
      // First check USB connection
      _usbConnected = BiometricService.isUsbConnected;

      if (!_usbConnected) {
        print('❌ USB device not connected');
        setState(() {
          _deviceState = _DeviceState.notConnected;
          _deviceStatusMsg = 'USB device not connected. Please connect your ${_selectedDevice.shortName} device.';
        });
        _showSnackBar('Please connect your ${_selectedDevice.shortName} device via USB', isError: true);
        return;
      }

      // Check RD Service
      final available = await BiometricService.checkDevice(
        deviceType: _selectedDevice.apiValue,
      );

      print('📱 RD Service check result: $available');

      if (!mounted) return;

      if (available) {
        setState(() {
          _deviceState = _DeviceState.connected;
          _deviceStatusMsg = '${_selectedDevice.displayName} RD Service ready.';
        });
        print('✅ ${_selectedDevice.displayName} RD Service is reachable');
        _showSnackBar('${_selectedDevice.shortName} device connected successfully!', isError: false);
      } else {
        setState(() {
          _deviceState = _DeviceState.notConnected;
          _deviceStatusMsg = '${_selectedDevice.displayName} RD Service not running.\n'
              'Please ensure the RD Service app is installed and running.';
        });
        print('❌ ${_selectedDevice.displayName} RD Service not reachable');
        _showSnackBar(
          '${_selectedDevice.displayName} RD Service not reachable. Please ensure the app is installed and running.',
          isError: true,
        );
      }
    } catch (e) {
      print('❌ Error checking RD Service: $e');
      if (!mounted) return;
      setState(() {
        _deviceState = _DeviceState.error;
        _deviceStatusMsg = 'Error checking device: ${e.toString()}';
      });
      _showSnackBar('Error checking RD Service: $e', isError: true);
    }
  }

  // ─── EKYC flow ──────────────────────────────────────────────
  Future<void> _initiateEKYC() async {
    print('🚀 Starting EKYC flow with ${_selectedDevice.displayName}...');

    if (!_isAadhaarValid) {
      _showSnackBar('Please enter a valid 12-digit Aadhaar number', isError: true);
      return;
    }

    if (_deviceState != _DeviceState.connected) {
      _showSnackBar('RD Service not available. Please check your ${_selectedDevice.displayName} device.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      print('📤 Capturing fingerprint from ${_selectedDevice.displayName} device...');
      String pidData = await BiometricService.capturePid(
        clientKey: 'NEOFYN',
        deviceType: _selectedDevice.apiValue,
      );
      print('✅ PID captured successfully (${pidData.length} chars)');

      print('📤 Sending EKYC request to backend...');
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

      print('📥 Backend response status: ${success ? "SUCCESS" : "FAILED"}');

      if (success) {
        print('✅ EKYC completed successfully!');
        setState(() => _ekycDone = true);
        _showSnackBar('EKYC completed successfully!', isError: false);

        print('📊 Fetching updated merchant status...');
        final status = await provider.fetchPipeStatus(widget.pipe);
        final regStatus = status?['registrationStatus'] ?? '';
        print('📊 New registration status: $regStatus');

        if (regStatus == 'active') {
          print('➡️ Navigating to AEPS wrapper');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
            );
          }
        } else {
          print('➡️ Navigating to Home (status: $regStatus)');
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const UserHomeScreen()),
            );
          }
        }
      } else {
        print('❌ EKYC failed: ${provider.errorMessage}');
        _showSnackBar(provider.errorMessage ?? 'EKYC failed', isError: true);
      }
    } on Exception catch (e) {
      print('❌ Exception: $e');
      _showSnackBar(e.toString(), isError: true);
      await _checkDeviceAvailability();
    } catch (e) {
      print('❌ Unexpected error: $e');
      _showSnackBar('Unexpected error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
      print('🏁 EKYC flow completed');
    }
  }

  // ─── UI helpers ─────────────────────────────────────────────
  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
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
                  _deviceStatusMsg = 'Checking device connection...';
                  _usbConnected = false;
                });
                // Reinitialize for new device type
                _initializeBiometricService();
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
                      color: isSelected
                          ? const Color(0xFF2ECC71)
                          : Colors.white38,
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
                        color: isSelected
                            ? Colors.white.withOpacity(0.7)
                            : Colors.white30,
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

  // ─── DEVICE STATUS CARD ─────────────────────────────────────
  Widget _buildDeviceStatusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          if (_deviceState == _DeviceState.checking)
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.amber,
              ),
            )
          else
            Icon(_statusIcon, color: _statusColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _deviceStatusMsg.split('\n').first,
                  style: TextStyle(
                    color: _statusColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                if (_deviceStatusMsg.contains('\n'))
                  Text(
                    _deviceStatusMsg.split('\n').last,
                    style: TextStyle(
                      color: _statusColor.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'EKYC Verification',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // USB Status Indicator
          IconButton(
            icon: Icon(
              _usbConnected ? Icons.usb : Icons.usb_off,
              color: _usbConnected ? Colors.green : Colors.red,
            ),
            onPressed: _checkDeviceAvailability,
            tooltip: _usbConnected ? 'USB Connected' : 'USB Not Connected',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _ekycDone ? Icons.verified : Icons.fingerprint,
                size: 80,
                color: _ekycDone ? Colors.green : const Color(0xFF2ECC71),
              ),
              const SizedBox(height: 24),
              Text(
                _ekycDone ? 'EKYC Completed' : 'Complete your EKYC',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _ekycDone
                    ? 'You can now perform AEPS transactions.'
                    : 'Please select your device, enter Aadhaar number and place your finger on the scanner.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),

              // ─── DEVICE SELECTOR ────────────────────
              if (!_ekycDone) ...[
                const Text(
                  'Select Device',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDeviceSelector(),
                const SizedBox(height: 16),
              ],

              // Aadhaar Input Field
              if (!_ekycDone) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aadhaar Number',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _aadhaarController,
                        keyboardType: TextInputType.number,
                        maxLength: 12,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          letterSpacing: 2,
                        ),
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[850],
                          hintText: 'Enter 12-digit Aadhaar number',
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 16,
                          ),
                          counterStyle: const TextStyle(
                            color: Colors.white54,
                          ),
                          prefixIcon: const Icon(
                            Icons.credit_card,
                            color: Color(0xFF2ECC71),
                          ),
                          suffixIcon: _aadhaarNumber.isNotEmpty
                              ? IconButton(
                            icon: const Icon(
                              Icons.clear,
                              color: Colors.white54,
                              size: 20,
                            ),
                            onPressed: () {
                              _aadhaarController.clear();
                              setState(() => _aadhaarNumber = '');
                            },
                          )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF2ECC71),
                              width: 2,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 1,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _aadhaarNumber = value;
                          });
                        },
                      ),
                      if (_aadhaarNumber.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        if (_aadhaarNumber.length < 12)
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                '${12 - _aadhaarNumber.length} more digits required',
                                style: const TextStyle(color: Colors.orange, fontSize: 12),
                              ),
                            ],
                          )
                        else if (_isAadhaarValid)
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 6),
                              const Text('Valid Aadhaar number',
                                  style: TextStyle(color: Colors.green, fontSize: 12)),
                            ],
                          )
                        else
                          Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 16),
                              const SizedBox(width: 6),
                              const Text('Please enter only digits (0-9)',
                                  style: TextStyle(color: Colors.red, fontSize: 12)),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Device Status Card
                _buildDeviceStatusCard(),

                const SizedBox(height: 12),

                // Check Device Button
                if (_deviceState != _DeviceState.connected)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.grey[700]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _checkDeviceAvailability,
                      icon: _deviceState == _DeviceState.checking
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.refresh, size: 20),
                      label: Text(
                        _deviceState == _DeviceState.checking
                            ? 'Detecting...'
                            : 'Check Device Connection',
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 32),

              // Action Button
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
                const Column(
                  children: [
                    CircularProgressIndicator(color: Color(0xFF2ECC71)),
                    SizedBox(height: 12),
                    Text('Checking device...', style: TextStyle(color: Colors.white70)),
                  ],
                )
              else
                CustomButton(
                  text: _deviceAvailable
                      ? (_isAadhaarValid
                      ? 'Scan Fingerprint & Start EKYC'
                      : _aadhaarNumber.isEmpty
                      ? 'Enter Aadhaar Number First'
                      : 'Enter Valid 12-digit Aadhaar')
                      : '${_selectedDevice.shortName} RD Service Unavailable',
                  onPressed: (_deviceAvailable && _isAadhaarValid)
                      ? _initiateEKYC
                      : () {
                    if (!_isAadhaarValid && _aadhaarNumber.isNotEmpty) {
                      _showSnackBar('Please enter a valid 12-digit Aadhaar number', isError: true);
                    }
                  },
                  isLoading: _isLoading,
                  backgroundColor: (_deviceAvailable && _isAadhaarValid)
                      ? const Color(0xFF2ECC71)
                      : Colors.grey,
                  textColor: Colors.black,
                ),

              const SizedBox(height: 20),

              if (!_isLoading)
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