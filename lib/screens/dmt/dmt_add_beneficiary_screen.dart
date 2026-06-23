// lib/screens/dmt/dmt_add_beneficiary_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../services/dmt/api_service.dart';

class DMTAddBeneficiaryScreen extends StatefulWidget {
  final int remitterId;

  const DMTAddBeneficiaryScreen({
    Key? key,
    required this.remitterId,
  }) : super(key: key);

  @override
  State<DMTAddBeneficiaryScreen> createState() => _DMTAddBeneficiaryScreenState();
}

class _DMTAddBeneficiaryScreenState extends State<DMTAddBeneficiaryScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankController = TextEditingController();
  final _mobileController = TextEditingController();
  
  String? _selectedState;
  String? _selectedCity;
  List<Map<String, String>> _states = [];
  List<Map<String, String>> _cities = [];
  List<Map<String, String>> _banks = [];
  
  bool _isLoading = false;
  bool _loadingStates = true;
  bool _loadingBanks = true;
  bool _loadingCities = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _bankController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      // Load states and banks in parallel
      final results = await Future.wait([
        _apiService.getStateList(),
        _apiService.getBankList(),
      ]);
      
      final states = results[0] as List<Map<String, String>>;
      final banks = results[1] as List<Map<String, String>>;
      
      setState(() {
        _states = states;
        _banks = banks;
        _loadingStates = false;
        _loadingBanks = false;
      });
    } catch (e) {
      setState(() {
        _loadingStates = false;
        _loadingBanks = false;
        _errorMessage = 'Failed to load data. Please check your connection.';
      });
    }
  }

  Future<void> _loadCities(String stateCode) async {
    setState(() {
      _cities = [];
      _selectedCity = null;
      _loadingCities = true;
      _errorMessage = null;
    });

    try {
      final cities = await _apiService.getCityList(stateCode);
      // Ensure type safety for analyzer
      final List<Map<String, String>> cityList = cities
          .map((e) => {
                'code': e['code']?.toString() ?? '',
                'name': e['name']?.toString() ?? '',
              })
          .toList();

      setState(() {
        _cities = cityList;
        _loadingCities = false;
      });
    } catch (e) {
      setState(() {
        _cities = [];
        _loadingCities = false;
        _errorMessage = 'Failed to load cities for this state';
      });
    }
  }

  Future<void> _addBeneficiary() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedState == null) {
      setState(() {
        _errorMessage = 'Please select a state';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.addBeneficiary(
        remitterId: widget.remitterId,
        accountHolderName: _nameController.text.trim(),
        accountNumber: _accountController.text.trim(),
        ifscCode: _ifscController.text.trim().toUpperCase(),
        bankName: _bankController.text.trim(),
        stateCode: _selectedState,
        cityCode: _selectedCity,
        beneficiaryMobile: _mobileController.text.trim().isEmpty 
            ? null 
            : _mobileController.text.trim(),
      );

      if (response.containsKey('id')) {
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Beneficiary added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Add Beneficiary',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue[100]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.info_circle, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'A fee of ₹3 will be charged for adding a beneficiary',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Beneficiary Details',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Account Holder Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Account Holder Name',
                    hintText: 'Enter full name',
                    prefixIcon: const Icon(Iconsax.user),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter account holder name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Account Number
                TextFormField(
                  controller: _accountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Account Number',
                    hintText: 'Enter account number',
                    prefixIcon: const Icon(Iconsax.card),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter account number';
                    }
                    if (value.length < 9) {
                      return 'Account number must be at least 9 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // IFSC Code
                TextFormField(
                  controller: _ifscController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'IFSC Code',
                    hintText: 'Enter IFSC code',
                    prefixIcon: const Icon(Iconsax.buildings),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter IFSC code';
                    }
                    if (value.length != 11) {
                      return 'IFSC code must be 11 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Bank Name
                DropdownButtonFormField<String>(
                  value: _bankController.text.isNotEmpty ? _bankController.text : null,
                  decoration: InputDecoration(
                    labelText: 'Bank Name',
                    prefixIcon: const Icon(Iconsax.bank),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _loadingBanks
                      ? [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Loading banks...'),
                          ),
                        ]
                      : _banks.map((bank) {
                          return DropdownMenuItem<String>(
                            value: bank['name'] ?? '',
                            child: Text(bank['name'] ?? ''),
                          );
                        }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _bankController.text = value ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a bank';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // State
                DropdownButtonFormField<String>(
                  value: _selectedState,
                  decoration: InputDecoration(
                    labelText: 'State',
                    prefixIcon: const Icon(Iconsax.location),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _loadingStates
                      ? [
                          const DropdownMenuItem<String>(
                            value: '',
                            child: Text('Loading states...'),
                          ),
                        ]
                      : _states.map((state) {
                          return DropdownMenuItem<String>(
                            value: state['code'] ?? '',
                            child: Text(state['name'] ?? ''),
                          );
                        }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedState = value;
                      _selectedCity = null;
                      _cities = [];
                      if (value != null && value.isNotEmpty) {
                        _loadCities(value);
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a state';
                    }
                    return null;
                  },
                ),
                
                // Cities Dropdown - shows loading indicator or cities list
                if (_loadingCities) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Loading cities...',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_cities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCity,
                    decoration: InputDecoration(
                      labelText: 'City (Optional)',
                      prefixIcon: const Icon(Iconsax.buildings),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _cities.map((city) {
                      return DropdownMenuItem<String>(
                        value: city['code'] ?? '',
                        child: Text(city['name'] ?? ''),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCity = value;
                      });
                    },
                  ),
                ] else if (_selectedState != null && !_loadingStates && !_loadingCities) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'No cities available for this state',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Beneficiary Mobile
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    labelText: 'Beneficiary Mobile (Optional)',
                    hintText: 'Enter 10-digit mobile',
                    prefixIcon: const Icon(Iconsax.mobile),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    counterText: '',
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      if (value.length != 10) {
                        return 'Please enter a valid 10-digit number';
                      }
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Iconsax.danger, color: Colors.red),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.poppins(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addBeneficiary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Add Beneficiary',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}