import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';
import 'aeps_wrapper_screen.dart';      // existing wrapper
import 'merchant_registration_screen.dart';  // for new registration
import 'ekyc_screen.dart';

class PipeSelectionScreen extends StatefulWidget {
  const PipeSelectionScreen({super.key});

  @override
  State<PipeSelectionScreen> createState() => _PipeSelectionScreenState();
}

class _PipeSelectionScreenState extends State<PipeSelectionScreen> {
  final List<String> pipes = ['1', '2', '3'];
  Map<String, Map<String, dynamic>?> pipeStatus = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPipeStatuses();
  }


Future<void> _loadPipeStatuses() async {
  debugPrint('🔄 _loadPipeStatuses started');
  final provider = context.read<AepsProvider>();
  final userId = provider.userId;
  debugPrint('🔍 userId from provider: $userId');
  if (userId == null) {
    debugPrint('❌ userId is null, cannot fetch pipe statuses');
    setState(() => isLoading = false);
    return;
  }

  // Check token as well
  final token = provider.authToken;
  debugPrint('🔍 authToken from provider: ${token != null ? "present (first 20 chars: ${token.substring(0, 20)}...)" : "null"}');

  final futures = pipes.map((pipe) async {
    debugPrint('⏳ Fetching status for pipe $pipe...');
    try {
      final status = await provider.fetchPipeStatus(pipe);
      debugPrint('📦 Pipe $pipe returned: $status');
      return MapEntry(pipe, status);
    } catch (e) {
      debugPrint('❌ Error fetching pipe $pipe: $e');
      return MapEntry(pipe, null);
    }
  }).toList();

  final results = await Future.wait(futures);
  debugPrint('✅ All pipe statuses fetched: $results');

  final map = <String, Map<String, dynamic>?>{};
  for (final entry in results) {
    map[entry.key] = entry.value;
  }

  setState(() {
    pipeStatus = map;
    isLoading = false;
  });
  debugPrint('📊 Final pipeStatus map: $pipeStatus');
}

  void _onPipeSelected(String pipe, Map<String, dynamic>? status) {
  final provider = context.read<AepsProvider>();
  provider.setActivePipe(pipe);

  if (status != null && status['merchantId'] != null) {
    provider.setMerchantData({
      'merchantId': status['merchantId'],
      'merchantRefId': status['merchantRefId'],
      'phone': provider.mobileNo,
      'aadhaarNo': provider.aadhaarNo,
      'pipe': pipe,
    });

    final regStatus = status['registrationStatus'] ?? '';

    if (regStatus == 'active') {
      // ✅ Active – go to AEPS (2FA handled inside)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AepsWrapperScreen()),
      );
    } else if (regStatus == 'otp_pending') {
      // ⚠️ OTP pending – go to OTP verification screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MerchantRegistrationScreen(
            isOtpPending: true,
            merchantData: status,
            pipe: pipe, // pass pipe for later status check
            phone: provider.mobileNo,
          ),
        ),
      );
    } else if (regStatus == 'otp_verified') {
      // 🔐 EKYC pending – go to EKYC screen directly
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EKYC_Screen(
            merchantId: status['merchantId'],
            merchantRefId: status['merchantRefId'],
            pipe: pipe,
          ),
        ),
      );
    } else {
      // Full registration (for other statuses)
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MerchantRegistrationScreen()),
      );
    }
  } else {
    // No merchant – full registration
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantRegistrationScreen()),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Select AEPS Pipe'),
        backgroundColor: const Color(0xFF1A1A1A),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: pipes.length,
              itemBuilder: (context, index) {
                final pipe = pipes[index];
                final status = pipeStatus[pipe];
final isRegistered = status != null && status['merchantId'] != null && status['merchantId'].toString().isNotEmpty;                return Card(
                  color: const Color(0xFF1A1A1A),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          isRegistered ? Colors.green : Colors.orange,
                      child: Text(
                        pipe,
                        style: const TextStyle(color: Colors.black),
                      ),
                    ),
                    title: Text(
                      'Pipe $pipe',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      isRegistered
                          ? 'Status: ${status?['registrationStatus'] ?? 'active'}'
                          : 'Not registered',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRegistered
                            ? const Color(0xFF2ECC71)
                            : Colors.orange,
                      ),
                      child: Text(
                        isRegistered ? 'Proceed' : 'Register',
                        style: const TextStyle(color: Colors.black),
                      ),
                      onPressed: () => _onPipeSelected(pipe, status),
                    ),
                  ),
                );
              },
            ),
    );
  }
}