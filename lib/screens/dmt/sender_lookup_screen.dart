import 'package:flutter/material.dart';
import '../../services/DMT/dmt_service.dart';
import '../../services/storage_service.dart';
import 'sender_registration_form.dart';
import 'sender_dashboard_screen.dart';
import 'agent_registration_screen.dart';
import 'sender_otp_screen.dart';

class SenderLookupScreen extends StatefulWidget {
  const SenderLookupScreen({super.key});

  @override
  State<SenderLookupScreen> createState() => _SenderLookupScreenState();
}

class _SenderLookupScreenState extends State<SenderLookupScreen> {
  final TextEditingController _mobileController = TextEditingController();
  late DMTService _dmtService;
  bool _isLoading = false;
  String? _error;
  final String _baseUrl = 'https://neofyn-app-backend.onrender.com';




  @override
  void initState() {
    super.initState();
    _dmtService = DMTService(_baseUrl);
    _checkAgentAndRedirect(); // ✅ Check agent on screen load
  }

  /// If no agent is registered, redirect to agent registration screen
  Future<void> _checkAgentAndRedirect() async {
    final agentCode = await StorageService.getAgentCode();
    if (agentCode == null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
      );
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _lookupSender() async {
    final mobile = _mobileController.text.trim();
    debugPrint('========== LOOKUP SENDER START ==========');
    debugPrint('Mobile number entered: $mobile');

    if (mobile.isEmpty) {
      setState(() => _error = 'Please enter mobile number');
      return;
    }
    if (mobile.length != 10) {
      setState(() => _error = 'Please enter valid 10-digit mobile number');
      return;
    }

   setState(() {
    _isLoading = true;
    _error = null;
  });

  try {
    final result = await _dmtService.checkSender(mobile);
    debugPrint('checkSender result: $result');

    if (!mounted) return;

    final registeredValue = result['senderRegistered'];
    final bool isFullyRegistered = registeredValue.toString() == '1';

    if (isFullyRegistered) {
      // Sender already fully registered → go to dashboard
      final senderName = await StorageService.getSenderName() ?? 'Sender';
      final accountNumber = await StorageService.getSenderAccountNumber() ?? 'Not added';
      final ifscCode = await StorageService.getSenderIfsc() ?? 'Not added';
      final monthlyLimit = await StorageService.getMonthlyLimit() ?? 25000.0;
      final monthlyUsed = await StorageService.getMonthlyUsed() ?? 0.0;




      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SenderDashboardScreen(
            mobileNumber: mobile,
            senderId: mobile,
            senderName: senderName,
            accountNumber: accountNumber,
            ifscCode: ifscCode,
            monthlyLimit: monthlyLimit,
            monthlyUsed: monthlyUsed,
          ),
        ),
      );
    } else {
      // Sender not fully registered – might be pending OTP verification.
      // Try to send OTP (or retrigger) to see if registration data exists.
      
      final pendingMobile = result['senderMobile'] ?? mobile;
      final pendingName = result['senderName'] ?? '';
      
      final name = result['senderName'] ?? ''; // API may return name if already started
      final otpResult = await _dmtService.sendOTP(mobile, name);
      
      if (otpResult['successStatus'] == true || otpResult['txnStatus'] == 'SUCCESS') {
        // OTP sent successfully → navigate to verification screen
        final otpLen = int.tryParse(otpResult['otpLen']?.toString() ?? '4') ?? 4;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SenderOtpScreen(
              mobileNumber: mobile,
              // senderName: name.isNotEmpty ? name : 'Sender',
              senderName: pendingName.isNotEmpty ? pendingName : 'Sender',

              otpLength: otpLen,
            ),
          ),
        );
      } else {
        // No pending registration → go to full registration form
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SenderRegistrationForm(mobileNumber: mobile),
          ),
        ).then((_) => setState(() => _isLoading = false));
      }
    }
  } catch (e) {
    debugPrint('Lookup error: $e');
    setState(() {
      _error = e.toString();
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2ECC71)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sender Lookup',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.info_outline, color: Color(0xFF2ECC71), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Enter the mobile number to view sender dashboard.\nIf not registered, you can register them.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text('Sender Mobile Number', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextField(
                controller: _mobileController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: InputDecoration(
                  hintText: '9876543210',
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.phone_android, color: Colors.grey),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[700]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2ECC71))),
                  filled: true,
                  fillColor: const Color(0xFF1A1A1A),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _lookupSender,
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const Spacer(),
              Center(
                child: TextButton.icon(
                  onPressed: () => _showHelpDialog(),
                  icon: const Icon(Icons.help_outline, color: Colors.grey, size: 16),
                  label: const Text('Need help?', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Sender Registration', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('What is a Sender?', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold)),
            SizedBox(height: 5),
            Text('A sender is the person who wants to send money through DMT.', style: TextStyle(color: Colors.white70)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Color(0xFF2ECC71)))),
        ],
      ),
    );
  }
}