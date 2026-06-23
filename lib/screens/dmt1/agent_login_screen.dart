import 'package:flutter/material.dart';
import '../../services/DMT/dmt_service.dart';
import '../../services/storage_service.dart';
import 'agent_registration_screen.dart';
import 'sender_lookup_screen.dart';

class AgentLoginScreen extends StatefulWidget {
  const AgentLoginScreen({super.key});

  @override
  State<AgentLoginScreen> createState() => _AgentLoginScreenState();
}

class _AgentLoginScreenState extends State<AgentLoginScreen> {
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _panCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late DMTService _dmtService;

  @override
  void initState() {
    super.initState();
    _dmtService = DMTService('https://your-ngrok-url');
    _checkIfAlreadyLoggedIn();
  }

  Future<void> _checkIfAlreadyLoggedIn() async {
    final agentCode = await StorageService.getAgentCode();
    if (agentCode != null && mounted) {
      Navigator.pushReplacementNamed(context, '/dmt/sender-lookup');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final response = await _dmtService.agentLogin(
        _mobileCtrl.text.trim(),
        _panCtrl.text.trim().toUpperCase(),
      );
      if (response['success'] == true && response['agentCode'] != null) {
        await StorageService.saveAgentCode(response['agentCode']);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SenderLookupScreen()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent not found. Please register.')),
        );
        // Optionally navigate to registration screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Agent Login', style: TextStyle(color: Colors.white))),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTextField(_mobileCtrl, 'Registered Mobile Number', Icons.phone,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    _buildTextField(_panCtrl, 'PAN Number', Icons.credit_card, toUpperCase: true),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _login,
                        child: const Text('Login', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
                        );
                      },
                      child: const Text('New Agent? Register', style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text, bool toUpperCase = false}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      onChanged: toUpperCase ? (v) => c.value = c.value.copyWith(text: v.toUpperCase()) : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
      validator: (v) => v?.isEmpty == true ? 'Enter $label' : null,
    );
  }
}