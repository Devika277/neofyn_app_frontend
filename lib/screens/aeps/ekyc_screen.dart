import 'package:flutter/foundation.dart' show kDebugMode;
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

  // Debug state
  String _lastPidData = '';
  String _extractedWadh = '';
  String _backendResponse = '';
  bool _useSampleWadh = false;
  bool _skipEkyc = false; // NEW: bypass EKYC for testing
  List<String> _debugLogs = [];

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
    _addDebugLog('🔄 EKYC screen initialized');
    _checkDeviceAvailability();
  }

  Future<void> _checkDeviceAvailability() async {
    _addDebugLog('🔍 Checking RD Service availability...');
    setState(() => _isCheckingDevice = true);
    try {
      final available = await BiometricService.checkDevice();
      _addDebugLog('📱 RD Service check result: $available');
      setState(() {
        _deviceAvailable = available;
        _isCheckingDevice = false;
      });
      if (!available) {
        _addDebugLog('❌ RD Service not reachable');
        _showError('Mantra RD Service not reachable. Please ensure the app is installed and running.');
      } else {
        _addDebugLog('✅ RD Service is reachable');
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
    _addDebugLog('🚀 Starting EKYC flow...');
    _clearLogs();

    // 🟢 SKIP EKYC if debug toggle is ON
    if (kDebugMode && _skipEkyc) {
      _addDebugLog('⏭️ SKIP EKYC enabled – bypassing EKYC call');
      _addDebugLog('✅ Simulated EKYC success');
      setState(() => _ekycDone = true);
      _showSuccess('EKYC skipped (debug mode)');
      // Navigate to AEPS directly
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
      );
      return;
    }
    /*void _printFull(String label, String data) {
      const int chunkSize = 4000; // Bigger chunks
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📦 $label (Total: ${data.length} chars)');
      print('📦 First 200: ${data.substring(0, 200)}');
      print('📦 Last 200: ${data.substring(data.length - 200)}');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Print in 4000 char chunks
      for (int i = 0; i < data.length; i += chunkSize) {
        final end = (i + chunkSize < data.length) ? i + chunkSize : data.length;
        print('[CHUNK ${i~/chunkSize + 1}] ${data.substring(i, end)}');
      }
    }*/
    if (!_deviceAvailable) {
      _addDebugLog('❌ Device not available. Aborting.');
      _showError('RD Service not available. Please check your Mantra device.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Capture PID
      _addDebugLog('📤 Capturing fingerprint from Mantra device...');
      String pidData = await BiometricService.capturePid(clientKey: 'NEOFYN');
      _lastPidData = pidData;
      _addDebugLog('✅ PID captured successfully (${pidData.length} chars)');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // print('📦 FULL PID RESPONSE:');
      // _printFull('FULL PID RESPONSE:',pidData);
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // _printFull('📏 PID Length: ',${pidData.length} );


      // 2. Extract WADH
      _extractedWadh = _extractWadh(pidData);
      if (_extractedWadh.isNotEmpty) {
        _addDebugLog('🔍 Extracted WADH: ${_extractedWadh.substring(0, _extractedWadh.length > 10 ? 10 : _extractedWadh.length)}... (length: ${_extractedWadh.length})');
      } else {
        _addDebugLog('⚠️ No WADH found in PID response');
      }
// ✅ Print FULL WADH (no truncation)
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // print('📦 FULL WADH DATA:');
      // print(_extractedWadh);
      // _printFull('EXTRACTED WADH', _extractedWadh);

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // 3. Optionally inject sample WADH
      if (kDebugMode && _useSampleWadh) {
        const sampleWadh = "E0jzJ/P8UopUHAieZn8CKqS4WPMi5ZSYXgfnlfkWjrc=";
        _addDebugLog('🛠️ Injecting sample WADH (debug mode)');
        // Replace the wadh attribute if it exists, or add it if missing
        if (_extractedWadh.isNotEmpty) {
          pidData = pidData.replaceFirst(
            RegExp(r'wadh="[^"]*"'),
            'wadh="$sampleWadh"',
          );
        } else {
          // Insert wadh into the root PidData tag
          pidData = pidData.replaceFirst(
            '<PidData',
            '<PidData wadh="$sampleWadh"',
          );
        }
        _extractedWadh = sampleWadh;
        _addDebugLog('✅ Sample WADH injected: $sampleWadh');
      }

      // 4. Log the final PID being sent (truncated)
      _addDebugLog('📦 Final PID (first 500 chars): ${pidData.substring(0, pidData.length > 500 ? 500 : pidData.length)}...');

      // 5. Call backend
      _addDebugLog('📤 Sending EKYC request to backend...');
      final provider = context.read<AepsProvider>();
      _addDebugLog('🔑 Auth token: ${provider.authToken != null ? "present" : "MISSING"}');
      _addDebugLog('📦 Merchant ID: ${widget.merchantId}');
      _addDebugLog('📦 Merchant Ref: ${widget.merchantRefId}');
      _addDebugLog('📦 Pipe: ${widget.pipe}');
      print('🔍 Aadhaar Number from provider: ${provider.aadhaarNo}');
      final success = await provider.startEkyc(
        merchantId: widget.merchantId,
        merchantRefId: widget.merchantRefId,
        pipe: widget.pipe,
        pidData: pidData,
        deviceType: 'mantra',
        aadhaarNumber: '812936347028',
        ipAddress: provider.ipAddress,
      );

      _addDebugLog('📥 Backend response status: ${success ? "SUCCESS" : "FAILED"}');
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

        // 5. Fetch final status
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
    // Try to find wadh in root tag
    RegExp wadhRegex = RegExp(r'<PidData[^>]*wadh="([^"]*)"');
    final match = wadhRegex.firstMatch(pidData);
    if (match != null && match.group(1)!.isNotEmpty) {
      return match.group(1)!;
    }
    // If not found, try inside Resp or Opts tags
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

  // ─── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('EKYC Verification', style: TextStyle(color: Colors.white)),
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
          // Main content
          Expanded(
            child: Center(
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
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _ekycDone
                          ? 'You can now perform AEPS transactions.'
                          : 'Please place your finger on the Mantra scanner to capture PID data.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 20),
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
                        onPressed: _deviceAvailable ? _initiateEKYC : () {},
                        isLoading: _isLoading,
                        backgroundColor: _deviceAvailable ? const Color(0xFF2ECC71) : Colors.grey,
                        textColor: Colors.black,
                      ),
                    const SizedBox(height: 20),
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
                                const Text('Debug Info', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'WADH: ${_extractedWadh.isNotEmpty ? _extractedWadh.substring(0, _extractedWadh.length > 10 ? 10 : _extractedWadh.length) + "..." : "❌ NOT FOUND"}',
                              style: TextStyle(color: _extractedWadh.isNotEmpty ? Colors.green : Colors.red),
                            ),
                            Text(
                              'Backend: $_backendResponse',
                              style: const TextStyle(color: Colors.white70),
                            ),
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
                        Text('${_debugLogs.length} entries', style: const TextStyle(color: Colors.white54, fontSize: 10)),
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
                        if (log.contains('✅') || log.contains('SUCCESS')) color = Colors.green;
                        else if (log.contains('❌') || log.contains('FAILED') || log.contains('error')) color = Colors.red;
                        else if (log.contains('⚠️')) color = Colors.orange;
                        else if (log.contains('🔍') || log.contains('📤') || log.contains('📥')) color = Colors.cyan;
                        else color = Colors.white70;
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