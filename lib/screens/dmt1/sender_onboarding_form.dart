// screens/dmt/sender_onboarding_form.dart
import 'package:flutter/material.dart';
import '../../services/DMT/dmt_service.dart' ;
import '../../services/storage_service.dart';
import 'sender_lookup_screen.dart';

class SenderOnboardingForm extends StatefulWidget {
  const SenderOnboardingForm({super.key});

  @override
  State<SenderOnboardingForm> createState() => _SenderOnboardingFormState();
}

class _SenderOnboardingFormState extends State<SenderOnboardingForm> {
  final _formKey = GlobalKey<FormState>();
  late DMTService _dmtService;
  
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  bool _isLoading = false;
  bool _isAgreed = false;

  @override
  void initState() {
    super.initState();
    _dmtService = DMTService('http://192.168.2.151:3000');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isAgreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to terms and conditions')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _dmtService.registerSender({
        'fullName': _fullNameController.text.trim(),
        'mobileNumber': _mobileController.text.trim(),
        'aadhaarNumber': _aadhaarController.text.trim(),
        'panNumber': _panController.text.trim(),
        'accountNumber': _accountNumberController.text.trim(),
        'ifscCode': _ifscController.text.trim().toUpperCase(),
        'pincode': _pincodeController.text.trim(),
        'address': _addressController.text.trim(),
      });

      if (!mounted) return;

      if (result['success'] == true) {
        // Save onboarding completion status
        await StorageService.setOnboardingCompleted(true);
        await StorageService.saveSenderMobile(_mobileController.text.trim());
        
        // Navigate to mobile entry (which will then go to dashboard)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const SenderLookupScreen(),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Registration failed')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Sender Onboarding', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.person_add, color: Color(0xFF2ECC71), size: 50),
                          SizedBox(height: 12),
                          Text(
                            'Complete Your Profile',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'One-time registration to start using DMT',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Personal Information
                    const Text('Personal Details', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTextField(_fullNameController, 'Full Name', Icons.person, 'Enter your full name'),
                    const SizedBox(height: 16),
                    _buildTextField(_mobileController, 'Mobile Number', Icons.phone, 'Enter 10-digit mobile', keyboardType: TextInputType.phone, maxLength: 10),
                    const SizedBox(height: 16),
                    _buildTextField(_aadhaarController, 'Aadhaar Number', Icons.credit_card, 'Enter 12-digit Aadhaar', keyboardType: TextInputType.number, maxLength: 12),
                    const SizedBox(height: 16),
                    _buildTextField(_panController, 'PAN Number', Icons.description, 'Enter PAN number', toUpperCase: true),
                    
                    const SizedBox(height: 24),
                    const Text('Bank Details', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTextField(_accountNumberController, 'Account Number', Icons.account_balance, 'Enter bank account number', keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    _buildTextField(_ifscController, 'IFSC Code', Icons.code, 'Enter IFSC code', toUpperCase: true),
                    
                    const SizedBox(height: 24),
                    const Text('Address Details', style: TextStyle(color: Color(0xFF2ECC71), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildTextField(_addressController, 'Address', Icons.location_on, 'Enter your address', maxLines: 2),
                    const SizedBox(height: 16),
                    _buildTextField(_pincodeController, 'Pincode', Icons.location_city, 'Enter 6-digit pincode', keyboardType: TextInputType.number, maxLength: 6),
                    
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Checkbox(
                          value: _isAgreed,
                          onChanged: (value) => setState(() => _isAgreed = value!),
                          activeColor: const Color(0xFF2ECC71),
                        ),
                        const Expanded(
                          child: Text(
                            'I confirm that the information is correct',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _submitOnboarding,
                        child: const Text('Complete Registration', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    bool toUpperCase = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: toUpperCase
          ? (value) => controller.value = controller.value.copyWith(text: value.toUpperCase())
          : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder:  OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF2ECC71)),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Enter $label';
        if (label == 'Mobile Number' && value.length != 10) return 'Enter 10-digit mobile';
        if (label == 'Aadhaar Number' && value.length != 12) return 'Enter 12-digit Aadhaar';
        if (label == 'Pincode' && value.length != 6) return 'Enter 6-digit pincode';
        return null;
      },
    );
  }
}