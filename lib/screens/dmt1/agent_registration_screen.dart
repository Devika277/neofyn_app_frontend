import 'package:flutter/material.dart';
import '../../services/DMT/dmt_service.dart';
import '../../services/storage_service.dart';
import 'sender_lookup_screen.dart';


class AgentRegistrationScreen extends StatefulWidget {
  const AgentRegistrationScreen({super.key});

  @override
  State<AgentRegistrationScreen> createState() => _AgentRegistrationScreenState();
}

class _AgentRegistrationScreenState extends State<AgentRegistrationScreen> {
  late DMTService _dmtService;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _mobileCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  String? _gender; // 'Male' or 'Female'
  final _shopNameCtrl = TextEditingController();
  String? _selectedStateCode;
  String? _selectedCityCode;

  List<dynamic> _states = [];
  List<dynamic> _cities = [];

  // final _cityCodeCtrl = TextEditingController();






  @override
  void initState() {
    super.initState();
    _dmtService = DMTService('https://api.myneofyn.com'); // replace with env
    _checkExistingAgent();  // ← skip if already registered
    _loadStates();
  }





  /// Skip registration if agent already exists
  Future<void> _checkExistingAgent() async {
    final existingCode = await StorageService.getAgentCode();
    if (existingCode != null && mounted) {
      // Already registered – go directly to sender lookup
      Navigator.pushReplacementNamed(context, '/dmt/sender-lookup');
    }
  }
Future<void> _loadStates() async {
  try {
    print('📡 Fetching states...');
    final response = await _dmtService.fetchStates();
    print('✅ Full response: $response');
    print('🔍 Response type: ${response.runtimeType}');
    
    // Check if response is a Map
    if (response is Map<String, dynamic>) {
      print('📦 Response keys: ${response.keys}');
      final data = response['data'];
      print('📊 Data type: ${data.runtimeType}');
      print('📋 Data: $data');
      
      if (data is List && data.isNotEmpty) {
        print('🟢 First item: ${data[0]}');
        print('🔑 First item keys: ${data[0].keys}');
      }
      
      setState(() {
        _states = data ?? [];
        if (_states.isNotEmpty) {
          // Try different possible key names
          final firstState = _states[0];
          if (firstState.containsKey('stateCode')) {
            _selectedStateCode = firstState['stateCode'].toString();
          } else if (firstState.containsKey('code')) {
            _selectedStateCode = firstState['code'].toString();
          }
          _loadCities(_selectedStateCode!);
        }
      });
    } else {
      print('❌ Response is not a Map');
    }
  } catch (e) {
    print('❌ State load error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to load states: $e')),
    );
  }
}

Future<void> _loadCities(String stateCode) async {
  print('📍 Loading cities for stateCode: $stateCode');
  try {
    final response = await _dmtService.fetchCities(stateCode);
    print('✅ Cities raw response: $response');
    
    // Standard response shape: { success: true, data: [...] }
    if (response is Map<String, dynamic>) {
      final success = response['success'] ?? false;
      if (!success) {
        print('❌ API returned success=false: ${response['error']}');
        setState(() => _cities = []);
        return;
      }
      
      final data = response['data'];
      print('📊 Cities data type: ${data.runtimeType}');
      
      if (data is List) {
        setState(() {
          _cities = data;
          if (_cities.isNotEmpty) {
            // Try both possible key names
            final firstCity = _cities[0];
            if (firstCity.containsKey('cityCode')) {
              _selectedCityCode = firstCity['cityCode'].toString();
            } else if (firstCity.containsKey('code')) {
              _selectedCityCode = firstCity['code'].toString();
            }
          }
        });
      } else {
        print('⚠️ Data is not a List: $data');
        setState(() => _cities = []);
      }
    } else {
      print('❌ Response is not a Map: ${response.runtimeType}');
      setState(() => _cities = []);
    }
  } catch (e) {
    print('❌ City load error: $e');
    setState(() => _cities = []);
  }
}
  
  /// Register agent using dropdown selections for state and city
  Future<void> _registerAgent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedStateCode == null) {
      _showError('Please select a state');
      return;
    }
    if (_selectedCityCode == null) {
      _showError('Please select a city');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        'agentMobile': _mobileCtrl.text.trim(),
        'agentName': _nameCtrl.text.trim(),
        'agentPan': _panCtrl.text.trim().toUpperCase(),
        'agentDob': _formatDob(_dobCtrl.text.trim()),
        'agentGender': _gender,
        'agentShopName': _shopNameCtrl.text.trim(),
        'agentState': _selectedStateCode,
        'agentCity': _selectedCityCode,
      };

      final result = await _dmtService.registerAgent(payload);
      print('🔍 Full registration response: $result');


      if (result['agentCode'] != null) {
        await StorageService.saveAgentCode(result['agentCode']);
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SenderLookupScreen()),
          );
        }
      } else {
        throw Exception(result['message'] ?? 'Registration failed');
      }
    } catch (e) {
      _showError('Registration error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDob(String input) {
    if (input.length == 8) {
      final day = input.substring(0, 2);
      final month = input.substring(2, 4);
      final year = input.substring(4, 8);
      return '$year-$month-$day';
    }
    return input;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Agent Registration', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(_mobileCtrl, 'Mobile Number', Icons.phone,
                        keyboardType: TextInputType.phone),
                    _buildTextField(_nameCtrl, 'Full Name', Icons.person),
                    _buildTextField(_panCtrl, 'PAN Number', Icons.credit_card,
                        toUpperCase: true),
                    _buildTextField(_dobCtrl, 'Date of Birth (DDMMYYYY)', Icons.cake,
                        keyboardType: TextInputType.number,
                        helperText: 'Example: 15051990'),
                  // State Dropdown - SAFE VERSION
                 
               // State Dropdown
DropdownButtonFormField<String>(
  value: _states.any((s) => s['code']?.toString().trim() == _selectedStateCode)
      ? _selectedStateCode
      : null,
  items: _states.map<DropdownMenuItem<String>>((state) {
    final code = state['code']?.toString().trim() ?? '';
    final name = state['description']?.toString().trim() ?? code;
    return DropdownMenuItem<String>(
      value: code,
      child: Text(name),
    );
  }).toList(),
  onChanged: _states.isEmpty
      ? null
      : (value) {
          if (value != null) {
            setState(() {
              _selectedStateCode = value;
              _selectedCityCode = null;  // ✅ reset city on state change
              _cities = [];
            });
            _loadCities(value);
          }
        },
  decoration: const InputDecoration(labelText: 'State'),
  validator: (v) => v == null ? 'Select state' : null,
),

// City Dropdown
DropdownButtonFormField<String>(
  value: _cities.any((c) => c['code']?.toString().trim() == _selectedCityCode)
      ? _selectedCityCode
      : null,                           // ✅ null if not found in list
  items: _cities.map<DropdownMenuItem<String>>((city) {
    final code = city['code']?.toString().trim() ?? '';        // ✅ 'code' not 'cityCode'
    final name = city['description']?.toString().trim() ?? code; // ✅ 'description' not 'cityName'
    return DropdownMenuItem<String>(
      value: code,
      child: Text(name),
    );
  }).toList(),
  onChanged: (_selectedStateCode == null || _cities.isEmpty)
      ? null
      : (value) => setState(() => _selectedCityCode = value),
  decoration: const InputDecoration(labelText: 'City'),
  validator: (v) => v == null ? 'Select city' : null,
),
                  
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _registerAgent,
                        child: const Text('Register Agent', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController c, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text,
      bool toUpperCase = false,
      String? helperText}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      onChanged: toUpperCase
          ? (v) => c.value = c.value.copyWith(text: v.toUpperCase())
          : null,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon, color: Colors.grey),
      ),
      validator: (v) => v?.isEmpty == true ? 'Enter $label' : null,
    );
  }
}