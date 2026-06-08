import 'package:flutter/material.dart';
import '../../services/DMT/dmt_service.dart';
import '../../services/storage_service.dart';
import '../dmt/agent_registration_screen.dart';

class AddBeneficiaryScreen extends StatefulWidget {
  final String senderMobile;
  final VoidCallback onBeneficiaryAdded;

  const AddBeneficiaryScreen({
    super.key,
    required this.senderMobile,
    required this.onBeneficiaryAdded,
  });

  @override
  State<AddBeneficiaryScreen> createState() => _AddBeneficiaryScreenState();
}

class _AddBeneficiaryScreenState extends State<AddBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  late DMTService _dmtService;

  // Controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();

  // Manual city fallback
  bool _isLoadingCities = false;
  bool _citiesFailed = false;
  final _manualCityNameCtrl = TextEditingController();
  final _manualCityCodeCtrl = TextEditingController();

  // Dropdown values
  String? _selectedAccountType; // 'SAVING' or 'CURRENT'
  String? _selectedBankCode;
  String? _selectedStateCode;
  String? _selectedCityCode;

  // Dropdown data
  List<Map<String, dynamic>> _banks = [];
  List<Map<String, dynamic>> _states = [];
  List<Map<String, dynamic>> _cities = [];

  bool _isLoading = false;
  String? _agentCode;

  @override
  void initState() {
    super.initState();
    _dmtService = DMTService('https://neofyn-app-backend.onrender.com');
    _checkAgentAndRedirect();
    _loadBanks();
    _loadStates();
  }

  Future<void> _checkAgentAndRedirect() async {
    final code = await StorageService.getAgentCode();
    if (code == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agent not registered. Please register first.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
      );
    } else {
      setState(() => _agentCode = code);
    }
  }

  Future<void> _loadBanks() async {
    try {
      final response = await _dmtService.fetchBanks();
      if (response['success'] == true && response['data'] is List) {
        final List rawList = response['data'];
        // Normalise to {code, name}
        final List<Map<String, dynamic>> bankList = rawList.map((item) {
          return {
            'code': (item['code'] ?? item['bankCode'] ?? '').toString(),
            'name': (item['name'] ?? item['bankName'] ?? item['description'] ?? 'Unknown').toString(),
          };
        }).toList();
        setState(() {
          _banks = bankList;
          _selectedBankCode = null;
        });
      }
    } catch (e) {
      debugPrint('Bank load error: $e');
    }
  }

  Future<void> _loadStates() async {
    try {
      final data = await _dmtService.fetchStates();
      final List rawStates = (data['data'] ?? data['states'] ?? []) as List;
      final List<Map<String, dynamic>> stateList = rawStates.map((state) {
        return {
          'code': (state['code'] ?? state['stateCode'] ?? '').toString(),
          'name': (state['name'] ?? state['description'] ?? state['stateName'] ?? 'Unknown').toString(),
        };
      }).toList();
      setState(() {
        _states = stateList;
        _selectedStateCode = null;
        _selectedCityCode = null;
      });
    } catch (e) {
      debugPrint('State load error: $e');
    }
  }

  Future<void> _loadCities(String stateCode) async {
    setState(() => _isLoadingCities = true);
    try {
      final data = await _dmtService.fetchCities(stateCode);
      final List rawCities = (data['data'] ?? []) as List;
      final List<Map<String, dynamic>> cityList = rawCities.map((city) {
        return {
          'code': (city['cityCode'] ?? city['code'] ?? '').toString(),
          'name': (city['cityName'] ?? city['name'] ?? city['description'] ?? 'Unknown').toString(),
        };
      }).toList();
      setState(() {
        _cities = cityList;
        _citiesFailed = false;
        _isLoadingCities = false;
      });
    } catch (e) {
      debugPrint('City API failed: $e');
      setState(() {
        _citiesFailed = true;
        _isLoadingCities = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Add Beneficiary', style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildTextField(_nameController, 'Beneficiary Name', Icons.person, validator: true),
                    const SizedBox(height: 16),
                    _buildTextField(_mobileController, 'Beneficiary Mobile', Icons.phone,
                        keyboardType: TextInputType.phone, validator: true),
                    const SizedBox(height: 16),
                    _buildTextField(_accountController, 'Account Number', Icons.account_balance,
                        keyboardType: TextInputType.number, validator: true),
                    const SizedBox(height: 16),
                    _buildTextField(_ifscController, 'IFSC Code', Icons.code,
                        toUpperCase: true, validator: true),
                    const SizedBox(height: 16),

                    // Account Type Dropdown
                    DropdownButtonFormField<String>(
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Account Type', Icons.account_balance_wallet),
                      items: const [
                        DropdownMenuItem(value: 'SAVING', child: Text('Savings')),
                        DropdownMenuItem(value: 'CURRENT', child: Text('Current')),
                      ],
                      onChanged: (v) => setState(() => _selectedAccountType = v),
                      validator: (v) => v == null ? 'Select account type' : null,
                    ),
                    const SizedBox(height: 16),

                    // Bank Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedBankCode,
                      dropdownColor: const Color(0xFF1A1A1A),
                      style: const TextStyle(color: Colors.white),
                      decoration: _inputDecoration('Bank', Icons.account_balance),
                      items: _banks.map((bank) {
                        return DropdownMenuItem<String>(
                          value: bank['code'],
                          child: Text(bank['name']),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedBankCode = value),
                      validator: (value) => value == null ? 'Select bank' : null,
                    ),
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
                          child: Text(state['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedStateCode = value;
                            _selectedCityCode = null;
                            _cities = [];
                            _citiesFailed = false;
                          });
                          _loadCities(value);
                        }
                      },
                      validator: (value) => value == null ? 'Select state' : null,
                    ),
                    const SizedBox(height: 16),

                    // City Section (API fallback)
                    if (_isLoadingCities)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
                      )
                    else if (_citiesFailed)
                      Column(
                        children: [
                          _buildTextField(_manualCityCodeCtrl, 'City Code (e.g., DEL)', Icons.code,
                              toUpperCase: true, validator: true),
                          const SizedBox(height: 8),
                          _buildTextField(_manualCityNameCtrl, 'City Name (e.g., Delhi)', Icons.location_city,
                              validator: true),
                        ],
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedCityCode,
                        dropdownColor: const Color(0xFF1A1A1A),
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('City', Icons.location_city),
                        items: _cities.map((city) {
                          return DropdownMenuItem<String>(
                            value: city['code'],
                            child: Text(city['name']),
                          );
                        }).toList(),
                        onChanged: (_selectedStateCode == null || _cities.isEmpty)
                            ? null
                            : (value) => setState(() => _selectedCityCode = value),
                        validator: (value) => value == null ? 'Select city' : null,
                      ),
                    const SizedBox(height: 30),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _addBeneficiary,
                        child: const Text('Add & Verify Beneficiary',
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

  Widget _buildTextField(TextEditingController c, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text,
      bool toUpperCase = false,
      bool validator = false}) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      onChanged: toUpperCase
          ? (v) => c.value = c.value.copyWith(text: v.toUpperCase())
          : null,
      decoration: _inputDecoration(label, icon),
      validator: validator
          ? (value) => value?.isEmpty == true ? 'Enter $label' : null
          : null,
    );
  }

 Future<void> _addBeneficiary() async {
  if (!_formKey.currentState!.validate()) return;

  final agentCode = await StorageService.getAgentCode();
  if (agentCode == null) {
    _showSnack('Agent not registered. Redirecting...');
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AgentRegistrationScreen()),
      );
    }
    return;
  }
  setState(() => _agentCode = agentCode);

  if (_selectedBankCode == null) { _showSnack('Please select bank'); return; }
  if (_selectedStateCode == null) { _showSnack('Please select state'); return; }
  if (_selectedAccountType == null) { _showSnack('Please select account type'); return; }

  String beneCityCode;
  if (_citiesFailed) {
    beneCityCode = _manualCityCodeCtrl.text.trim().toUpperCase();
    if (beneCityCode.isEmpty) { _showSnack('Please enter city code'); return; }
  } else {
    if (_selectedCityCode == null) { _showSnack('Please select city'); return; }
    beneCityCode = _selectedCityCode!;
  }

  setState(() => _isLoading = true);

  try {
    // 1. Penny Drop (validates account)
    print('⚡ Calling Penny Drop...');
    final pennyRes = await _dmtService.performPennyDrop(
      _accountController.text.trim(),
      _ifscController.text.trim().toUpperCase(),
    );
    print('Penny Drop response: $pennyRes');

    final bool isPennySuccess = pennyRes['successStatus'] == true && pennyRes['responseCode'] == '000';
    if (!isPennySuccess) {
      throw Exception(pennyRes['message'] ?? 'Penny drop failed');
    }
    final String beneAccId = (pennyRes['txnId'] ?? pennyRes['beneAccId']).toString();
    if (beneAccId.isEmpty) {
      throw Exception('Penny drop succeeded but no account ID returned');
    }

    // 2. Beneficiary Registration (external API)
    print('⚡ Registering Beneficiary externally...');
    final regRes = await _dmtService.registerBeneficiary({
      'beneName': _nameController.text.trim(),
      'beneMobile': _mobileController.text.trim(),
      'accountNo': _accountController.text.trim(),
      'ifsc': _ifscController.text.trim().toUpperCase(),
      'accountType': _selectedAccountType,
      'bankName': _selectedBankCode,
      'beneState': _selectedStateCode,
      'beneCity': beneCityCode,
      'agentCode': _agentCode,
    });
    print('Registration response: $regRes');

    final bool isRegSuccess = regRes['txnStatusCode'] == '000' || regRes['responseCode'] == '000';
    if (!isRegSuccess) {
      throw Exception(regRes['message'] ?? 'Beneficiary registration failed');
    }

    final String beneCode = regRes['beneCode'];
    if (beneCode.isEmpty) {
      throw Exception('Beneficiary registration succeeded but no beneCode returned');
    }

    // Store the mapping between beneCode and beneAccId (required for transaction OTP)
    await StorageService.saveBeneAccId(beneCode, beneAccId);

    // 3. Sync with your local PostgreSQL database
    print('⚡ Syncing with local database...');
    final localSyncRes = await _dmtService.syncBeneficiaryWithLocalDb({
      'remitterId': widget.senderMobile,  // sender's mobile number
      'accountHolderName': _nameController.text.trim(),
      'accountNumber': _accountController.text.trim(),
      'ifscCode': _ifscController.text.trim().toUpperCase(),
      'bankName': _selectedBankCode,
      'beneCode': beneCode,
      'accountType': _selectedAccountType,
      'cityCode': beneCityCode,
      'pennyDropName': _nameController.text.trim(), // or any value
      'beneCity': beneCityCode,
      'beneState': _selectedStateCode,
    });
    print('Local sync response: $localSyncRes');

    if (localSyncRes['success'] != true) {
      throw Exception(localSyncRes['message'] ?? 'Local DB sync failed');
    }

    // 4. Notify parent and close screen
    widget.onBeneficiaryAdded();

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beneficiary added & verified successfully!'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context);
      });
    }
  } catch (e) {
    print('❌ Error: $e');
    _showSnack(e.toString().replaceAll('Exception: ', ''));
    setState(() => _isLoading = false);
  }
}

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _manualCityNameCtrl.dispose();
    _manualCityCodeCtrl.dispose();
    super.dispose();
  }
}