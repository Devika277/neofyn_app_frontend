import 'package:flutter/material.dart';
import '../../services/DMT/dmt_service.dart';
import '../../services/storage_service.dart';
import '../../screens/dmt/sender_otp_screen.dart';
import '../dmt/agent_registration_screen.dart';

class SenderRegistrationForm extends StatefulWidget {
  final String mobileNumber;

  const SenderRegistrationForm({super.key, required this.mobileNumber});

  @override
  State<SenderRegistrationForm> createState() => _SenderRegistrationFormState();
}

class _SenderRegistrationFormState extends State<SenderRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  late DMTService _dmtService;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Dropdowns
  String? _selectedStateCode;
  String? _selectedCityCode;
  List<Map<String, String>> _states = [];
  List<Map<String, String>> _cities = [];

  bool _isLoading = false;
  String? _agentCode;

  @override
  void initState() {
    super.initState();
    _dmtService = DMTService('https://api.myneofyn.com');
    _loadAgentCodeAndProceed();
  }

  Future<void> _loadAgentCodeAndProceed() async {
    final code = await StorageService.getAgentCode();
    if (code == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Agent not registered. Redirecting to agent registration...')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
        );
      }
      return;
    }
    setState(() => _agentCode = code);
    await _loadStates();
  }

  /// Load states (decrypted) and normalise to {code, description}
  Future<void> _loadStates() async {
    try {
      final response = await _dmtService.fetchStates();
      if (response is Map<String, dynamic> && response['data'] is List) {
        final rawStates = response['data'] as List;
        final normalised = rawStates.map((state) {
          final code = (state['stateCode'] ?? state['code'] ?? '').toString();
          final description = (state['stateName'] ?? state['description'] ?? code).toString();
          return {'code': code, 'description': description};
        }).toList().cast<Map<String, String>>();

        setState(() {
          _states = normalised;
          if (_states.isNotEmpty) _selectedStateCode = _states.first['code'];
        });
      } else {
        throw Exception('Invalid state response format');
      }
    } catch (e) {
      _showError('Failed to load states: $e');
    }
  }

  /// Load cities for given state code (decrypted)
  Future<void> _loadCities(String stateCode) async {
    setState(() {
      _selectedCityCode = null;
      _cities = [];
    });
    try {
      final response = await _dmtService.fetchCities(stateCode);
      if (response is Map<String, dynamic> && response['data'] is List) {
        final rawCities = response['data'] as List;
        final normalised = rawCities.map((city) {
          final code = (city['cityCode'] ?? city['code'] ?? '').toString();
          final description = (city['cityName'] ?? city['description'] ?? code).toString();
          return {'code': code, 'description': description};
        }).toList().cast<Map<String, String>>();

        setState(() => _cities = normalised);
      } else {
        setState(() => _cities = []);
        throw Exception('Invalid city response format');
      }
    } catch (e) {
      _showError('Failed to load cities: $e');
      setState(() => _cities = []);
    }
  }

//   Future<void> _registerSender() async {
//     if (!_formKey.currentState!.validate()) return;
//     if (_agentCode == null) {
//       _showError('Agent code missing. Please restart the app.');
//       return;
//     }
//     if (_selectedStateCode == null) {
//       _showError('Please select a state');
//       return;
//     }
//     if (_selectedCityCode == null) {
//       _showError('Please select a city');
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//     final payload = {
//       'senderMobile': widget.mobileNumber,
//       'senderName': _nameController.text.trim(),
//       'senderState': _selectedStateCode,
//       'senderCity': _selectedCityCode,
//       'agentCode': _agentCode,
//       'address': _addressController.text.trim(),
//       'aadhaar': _aadhaarController.text.trim(),
//       'pinCode': _pincodeController.text.trim(),
//       'pidData': '<?xml version="1.0" encoding="UTF-8"?><PidOptions ver="1.0"><Opts fCount="1" fType="0" format="0" pidVer="2.0" timeout="10000" otp="" posh="UNKNOWN" env="P" wadh=""/></PidOptions>',
//     };

//     final result = await _dmtService.registerSender(payload);

//     if (!mounted) return;

//     // Check if registration succeeded
//     final bool success = (result['txnStatus'] == 'SUCCESS' ||
//                           result['successStatus'] == true ||
//                           result['message']?.toString().toLowerCase().contains('verify the otp') == true);

//     if (!success) {
//       _showError(result['message'] ?? 'Sender registration failed');
//       return;
//     }

//     // ✅ Use returned data (API may return different mobile/name)
//     final actualMobile = result['senderMobile']?.toString() ?? widget.mobileNumber;
//     final actualName = result['senderName']?.toString() ?? _nameController.text.trim();
//     final otpLen = int.tryParse(result['otpLen']?.toString() ?? '4') ?? 4;

//     debugPrint('Registration success. OTP will be sent to: $actualMobile ($actualName)');

//     // OTP is sent automatically by the registration API.
//     // Navigate directly to OTP verification screen.
//     if (mounted) {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (_) => SenderOtpScreen(
//             mobileNumber: actualMobile,
//             senderName: actualName,
//             otpLength: otpLen,
//           ),
//         ),
//       );
//     }
//   } catch (e) {
//     _showError('Registration error: $e');
//   } finally {
//     if (mounted) setState(() => _isLoading = false);
//   }
// }



Future<void> _registerSender() async {
  if (!_formKey.currentState!.validate()) return;
  if (_agentCode == null) { _showError('Agent code missing'); return; }
  if (_selectedStateCode == null) { _showError('Select state'); return; }
  if (_selectedCityCode == null) { _showError('Select city'); return; }

  setState(() => _isLoading = true);

  try {
    final payload = {
      'senderMobile': widget.mobileNumber,
      'senderName': _nameController.text.trim(),
      'senderState': _selectedStateCode,
      'senderCity': _selectedCityCode,
      'agentCode': _agentCode,
      'address': _addressController.text.trim(),
      'aadhaar': _aadhaarController.text.trim(),
      'pinCode': _pincodeController.text.trim(),
      'pidData': '<?xml version="1.0" encoding="UTF-8"?><PidOptions ver="1.0"><Opts fCount="1" fType="0" format="0" pidVer="2.0" timeout="10000" otp="" posh="UNKNOWN" env="P" wadh=""/></PidOptions>',
    };
;
    final result = await _dmtService.registerSender(payload);
    if (!mounted) return;

    final bool success = (result['txnStatus'] == 'SUCCESS' ||
                          result['successStatus'] == true ||
                          result['message']?.toString().toLowerCase().contains('verify the otp') == true);

    if (!success) {
      _showError(result['message'] ?? 'Registration failed');
      return;
    }

    // Use the mobile number returned by API (critical!)
    final actualMobile = result['senderMobile']?.toString() ?? widget.mobileNumber;
    final actualName = result['senderName']?.toString() ?? _nameController.text.trim();
    final otpLen = int.tryParse(result['otpLen']?.toString() ?? '4') ?? 4;

    // ✅ OTP already sent – navigate directly to OTP screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SenderOtpScreen(
            mobileNumber: actualMobile,
            senderName: actualName,
            otpLength: otpLen,
          ),
        ),
      );
    }
  } catch (e) {
    _showError('Registration error: $e');
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
        title: const Text('Register Sender', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Mobile number preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.phone, color: Color(0xFF2ECC71)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Mobile Number', style: TextStyle(color: Colors.grey, fontSize: 12)),
                              Text('+91 ${widget.mobileNumber}', style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildTextField(_nameController, 'Full Name', Icons.person, validator: true),
                    const SizedBox(height: 16),
                    _buildTextField(_aadhaarController, 'Aadhaar Number', Icons.credit_card,
                        keyboardType: TextInputType.number, validator: true),
                    const SizedBox(height: 16),
                    _buildTextField(_pincodeController, 'Pincode', Icons.location_city,
                        keyboardType: TextInputType.number, validator: true),
                    const SizedBox(height: 16),
                    _buildTextField(_addressController, 'Address', Icons.home, maxLines: 2, validator: true),
                    const SizedBox(height: 16),

                    // State Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedStateCode,
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('State', Icons.map),
                      items: _states.map((state) {
                        return DropdownMenuItem<String>(
                          value: state['code'],
                          child: Text(state['description'] ?? state['code']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedStateCode = value);
                          _loadCities(value);
                        }
                      },
                      validator: (v) => v == null ? 'Select state' : null,
                    ),
                    const SizedBox(height: 16),

                    // City Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCityCode,
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('City', Icons.location_city),
                      items: _cities.map((city) {
                        return DropdownMenuItem<String>(
                          value: city['code'],
                          child: Text(city['description'] ?? city['code']!),
                        );
                      }).toList(),
                      onChanged: (_selectedStateCode == null || _cities.isEmpty)
                          ? null
                          : (value) => setState(() => _selectedCityCode = value),
                      validator: (v) => v == null ? 'Select city' : null,
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
                        onPressed: _registerSender,
                        child: const Text('Register & Continue',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[700]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2ECC71)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text,
      int maxLines = 1,
      bool validator = false}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: _inputDecoration(label, icon),
      validator: validator ? (value) => value?.isEmpty == true ? 'Enter $label' : null : null,
    );
  }
}