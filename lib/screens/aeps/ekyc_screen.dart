// lib/screens/aeps/ekyc_screen.dart
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import '../../widgets/custom_button.dart';
import '../../screens/aeps/biometric_service.dart';
import '../../layout/UserHomeScreen.dart';
import 'aeps_wrapper_screen.dart';

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
  bool _deviceAvailable = false;
  bool _isCheckingDevice = true;

  // ─── DEVICE SELECTION ───────────────────────────────────────
  DeviceType _selectedDevice = DeviceType.mantra;

  // Debug state
  String _lastPidData = '';
  String _extractedWadh = '';
  String _backendResponse = '';
  bool _useSampleWadh = false;
  bool _skipEkyc = false;
  List<String> _debugLogs = [];
  final TextEditingController _aadhaarController = TextEditingController();
  String _aadhaarNumber = '';

  // ─── Debug logging ──────────────────────────────────────────

  void _addDebugLog(String msg) {
    final timestamp = DateTime.now().toIso8601String().split('.').first;
    final logEntry = '$timestamp: $msg';
    setState(() {
      _debugLogs.insert(0, logEntry);
      if (_debugLogs.length > 50) _debugLogs.removeLast();
    });
    print(logEntry);
  }

  void _clearLogs() {
    setState(() => _debugLogs.clear());
  }

  // ─── Lifecycle ──────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _aadhaarNumber = widget.aadhaarNumber;
    _aadhaarController.text = widget.aadhaarNumber;
    _addDebugLog('🔄 EKYC screen initialized');
    _addDebugLog(
      '📝 Initial Aadhaar: ${_aadhaarNumber.isNotEmpty ? "${_aadhaarNumber.substring(0, _aadhaarNumber.length > 4 ? 4 : _aadhaarNumber.length)}XXXX" : "Not provided"}',
    );
    _checkDeviceAvailability();
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    super.dispose();
  }

  bool get _isAadhaarValid =>
      _aadhaarNumber.length == 12 &&
          RegExp(r'^\d{12}$').hasMatch(_aadhaarNumber);

  Future<void> _checkDeviceAvailability() async {
    _addDebugLog('🔍 Checking RD Service availability for ${_selectedDevice.displayName}...');
    setState(() => _isCheckingDevice = true);
    try {
      final available = await BiometricService.checkDevice();
      _addDebugLog('📱 RD Service check result: $available');
      setState(() {
        _deviceAvailable = available;
        _isCheckingDevice = false;
      });
      if (!available) {
        _addDebugLog('❌ ${_selectedDevice.displayName} RD Service not reachable');
        _showError(
          '${_selectedDevice.displayName} RD Service not reachable. Please ensure the app is installed and running.',
        );
      } else {
        _addDebugLog('✅ ${_selectedDevice.displayName} RD Service is reachable');
      }
    } catch (e) {
      _addDebugLog('❌ Error checking RD Service: $e');
      setState(() {
        _deviceAvailable = false;
        _isCheckingDevice = false;
      });
      _showError('Error checking RD Service: $e');
    }
  }

  // ─── EKYC flow ──────────────────────────────────────────────

  Future<void> _initiateEKYC() async {
    _addDebugLog('🚀 Starting EKYC flow with ${_selectedDevice.displayName}...');
    _clearLogs();

    if (!_isAadhaarValid) {
      _addDebugLog('❌ Invalid Aadhaar: ${_aadhaarNumber.length} digits');
      _showError('Please enter a valid 12-digit Aadhaar number');
      return;
    }

    final maskedAadhaar = _aadhaarNumber.substring(0, 4) + 'XXXX' + _aadhaarNumber.substring(8);
    _addDebugLog('📝 Aadhaar validated: $maskedAadhaar');

    if (kDebugMode && _skipEkyc) {
      _addDebugLog('⏭️ SKIP EKYC enabled – bypassing EKYC call');
      _addDebugLog('✅ Simulated EKYC success');
      setState(() => _ekycDone = true);
      _showSuccess('EKYC skipped (debug mode)');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
      );
      return;
    }

    if (!_deviceAvailable) {
      _addDebugLog('❌ ${_selectedDevice.displayName} not available. Aborting.');
      _showError('RD Service not available. Please check your ${_selectedDevice.displayName} device.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      _addDebugLog('📤 Capturing fingerprint from ${_selectedDevice.displayName} device...');
      String pidData = await BiometricService.capturePid(clientKey: 'NEOFYN');
      _lastPidData = pidData;
      _addDebugLog('✅ PID captured successfully (${pidData.length} chars)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      _extractedWadh = _extractWadh(pidData);
      if (_extractedWadh.isNotEmpty) {
        _addDebugLog(
          '🔍 Extracted WADH: ${_extractedWadh.substring(0, _extractedWadh.length > 10 ? 10 : _extractedWadh.length)}... (length: ${_extractedWadh.length})',
        );
      } else {
        _addDebugLog('⚠️ No WADH found in PID response');
      }
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      if (kDebugMode && _useSampleWadh) {
        const sampleWadh = "E0jzJ/P8UopUHAieZn8CKqS4WPMi5ZSYXgfnlfkWjrc=";
        _addDebugLog('🛠️ Injecting sample WADH (debug mode)');
        if (_extractedWadh.isNotEmpty) {
          pidData = pidData.replaceFirst(
            RegExp(r'wadh="[^"]*"'),
            'wadh="$sampleWadh"',
          );
        } else {
          pidData = pidData.replaceFirst(
            '<PidData',
            '<PidData wadh="$sampleWadh"',
          );
        }
        _extractedWadh = sampleWadh;
        _addDebugLog('✅ Sample WADH injected: $sampleWadh');
      }

      _addDebugLog(
        '📦 Final PID (first 500 chars): ${pidData.substring(0, pidData.length > 500 ? 500 : pidData.length)}...',
      );

      _addDebugLog('📤 Sending EKYC request to backend...');
      final provider = context.read<AepsProvider>();
      _addDebugLog(
        '🔑 Auth token: ${provider.authToken != null ? "present" : "MISSING"}',
      );
      _addDebugLog('📦 Merchant ID: ${widget.merchantId}');
      _addDebugLog('📦 Merchant Ref: ${widget.merchantRefId}');
      _addDebugLog('📦 Pipe: ${widget.pipe}');
      _addDebugLog('📦 Device: ${_selectedDevice.apiValue}');
      _addDebugLog('📦 Aadhaar: $maskedAadhaar');
      _addDebugLog('📦 IP: ${provider.ipAddress}');

      print('🔍 Aadhaar Number from provider: ${provider.aadhaarNo}');

      // ✅ Using selected device type
      final success = await provider.startEkyc(
        merchantId: widget.merchantId,
        merchantRefId: widget.merchantRefId,
        pipe: widget.pipe,
        pidData: pidData,
        deviceType: _selectedDevice.apiValue, // ✅ Dynamic device type
        aadhaarNumber: _aadhaarNumber,
        ipAddress: provider.ipAddress,
      );

      _addDebugLog(
        '📥 Backend response status: ${success ? "SUCCESS" : "FAILED"}',
      );
      if (success) {
        _backendResponse = 'Success (status: 000)';
      } else {
        _backendResponse = provider.errorMessage ?? 'Unknown error';
        _addDebugLog('❌ Backend error: $_backendResponse');
      }

      if (success) {
        _addDebugLog('✅ EKYC completed successfully!');
        setState(() => _ekycDone = true);
        _showSuccess('EKYC completed successfully!');

        _addDebugLog('📊 Fetching updated merchant status...');
        final status = await provider.fetchPipeStatus(widget.pipe);
        final regStatus = status?['registrationStatus'] ?? '';
        _addDebugLog('📊 New registration status: $regStatus');

        if (regStatus == 'active') {
          _addDebugLog('➡️ Navigating to AEPS wrapper');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
          );
        } else {
          _addDebugLog('➡️ Navigating to Home (status: $regStatus)');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const UserHomeScreen()),
          );
        }
      } else {
        _addDebugLog('❌ EKYC failed: $_backendResponse');
        _showError(provider.errorMessage ?? 'EKYC failed');
      }
    } on Exception catch (e) {
      _addDebugLog('❌ Exception: $e');
      _backendResponse = e.toString();
      _showError(e.toString());
      await _checkDeviceAvailability();
    } catch (e) {
      _addDebugLog('❌ Unexpected error: $e');
      _backendResponse = e.toString();
      _showError('Unexpected error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _addDebugLog('🏁 EKYC flow completed');
    }
  }

  String _extractWadh(String pidData) {
    RegExp wadhRegex = RegExp(r'<PidData[^>]*wadh="([^"]*)"');
    final match = wadhRegex.firstMatch(pidData);
    if (match != null && match.group(1)!.isNotEmpty) {
      return match.group(1)!;
    }
    RegExp altRegex = RegExp(r'wadh="([^"]*)"');
    final altMatch = altRegex.firstMatch(pidData);
    return altMatch?.group(1) ?? '';
  }

  // ─── UI helpers ─────────────────────────────────────────────

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
                });
                _checkDeviceAvailability();
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
                        fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
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
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report, color: Colors.orange),
              onPressed: _showDebugDialog,
            ),
          if (kDebugMode && _debugLogs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              onPressed: _clearLogs,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
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

                      // ─── DEVICE SELECTOR (NEW) ────────────────────
                      if (!_ekycDone && !_isCheckingDevice) ...[
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
                      if (!_ekycDone && !_isCheckingDevice) ...[
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
                              TextField(
                                controller: _aadhaarController,
                                keyboardType: TextInputType.number,
                                maxLength: 12,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  letterSpacing: 2,
                                ),
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
                                  if (value.length == 12) {
                                    _addDebugLog('📝 Aadhaar entered: ${value.substring(0, 4)}XXXX${value.substring(8)}');
                                  }
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

                        // Device Status
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
                              _deviceAvailable
                                  ? '${_selectedDevice.displayName} RD Service connected'
                                  : '${_selectedDevice.displayName} RD Service unavailable',
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
                            child: const Text(
                              'Retry connection',
                              style: TextStyle(color: Color(0xFF2ECC71)),
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
                              _showError('Please enter a valid 12-digit Aadhaar number');
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

                      // Debug info panel
                      if (kDebugMode && _lastPidData.isNotEmpty) ...[
                        const Divider(color: Colors.grey, height: 30),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                                  const SizedBox(width: 8),
                                  const Text('Debug Info',
                                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'WADH: ${_extractedWadh.isNotEmpty ? _extractedWadh.substring(0, _extractedWadh.length > 10 ? 10 : _extractedWadh.length) + "..." : "❌ NOT FOUND"}',
                                style: TextStyle(
                                    color: _extractedWadh.isNotEmpty ? Colors.green : Colors.red),
                              ),
                              Text('Backend: $_backendResponse',
                                  style: const TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _showFullPidDialog,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: const Text('📄 Tap to view full PID data',
                                      style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Debug logs
          if (kDebugMode && _debugLogs.isNotEmpty) ...[
            Container(
              height: 150,
              color: Colors.black87,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    color: Colors.grey[900],
                    child: Row(
                      children: [
                        const Icon(Icons.terminal, color: Colors.green, size: 16),
                        const SizedBox(width: 8),
                        const Text('Debug Logs', style: TextStyle(color: Colors.green, fontSize: 12)),
                        const Spacer(),
                        Text('${_debugLogs.length} entries',
                            style: const TextStyle(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: _debugLogs.length,
                      itemBuilder: (context, index) {
                        final log = _debugLogs[index];
                        Color color;
                        if (log.contains('✅') || log.contains('SUCCESS'))
                          color = Colors.green;
                        else if (log.contains('❌') || log.contains('FAILED') || log.contains('error'))
                          color = Colors.red;
                        else if (log.contains('⚠️'))
                          color = Colors.orange;
                        else if (log.contains('🔍') || log.contains('📤') || log.contains('📥'))
                          color = Colors.cyan;
                        else
                          color = Colors.white70;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            log,
                            style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Debug Dialog ──────────────────────────────────────────

  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Debug Settings', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Checkbox(
                  value: _useSampleWadh,
                  onChanged: (val) => setState(() => _useSampleWadh = val ?? false),
                  activeColor: const Color(0xFF2ECC71),
                ),
                const Text('Inject sample WADH', style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _skipEkyc,
                  onChanged: (val) => setState(() => _skipEkyc = val ?? false),
                  activeColor: const Color(0xFF2ECC71),
                ),
                const Text('Skip EKYC (force success)', style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Current Device:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(_selectedDevice.displayName,
                      style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Current Aadhaar:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    _isAadhaarValid
                        ? '${_aadhaarNumber.substring(0, 4)} XXXX ${_aadhaarNumber.substring(8)}'
                        : _aadhaarNumber.isEmpty
                        ? 'Not entered'
                        : 'Invalid (${_aadhaarNumber.length} digits)',
                    style: TextStyle(
                        color: _isAadhaarValid ? Colors.green : Colors.orange,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _initiateEKYC();
              },
              child: const Text('Retry EKYC with current settings'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  void _showFullPidDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Full PID Data', style: TextStyle(color: Colors.white)),
        content: Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: SingleChildScrollView(
            child: SelectableText(
              _lastPidData,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }
}