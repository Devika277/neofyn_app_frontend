// lib/screens/CardPayOut/cardpay_out_beneficiaries_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cardpay_out_provider.dart';
import '../../models/cardpay_out_models.dart';

class CardPayOutBeneficiariesScreen extends StatefulWidget {
  const CardPayOutBeneficiariesScreen({Key? key}) : super(key: key);

  @override
  State<CardPayOutBeneficiariesScreen> createState() => _CardPayOutBeneficiariesScreenState();
}

class _CardPayOutBeneficiariesScreenState extends State<CardPayOutBeneficiariesScreen> {
  bool _showAddForm = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _mobileController = TextEditingController();
  
  String? _selectedBankCode;
  String? _selectedBankName;
  String? _selectedState;
  
  // Store the full bank list for reference
  List<Map<String, dynamic>> _bankList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<CardPayOutProvider>(context, listen: false);
    await provider.fetchBeneficiaries();
    await provider.fetchBanks();
    await provider.fetchStates();
    
    // Store bank list for reference
    setState(() {
      _bankList = provider.banks;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beneficiaries'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showAddForm ? Icons.close_rounded : Icons.add_rounded),
            onPressed: () {
              setState(() {
                _showAddForm = !_showAddForm;
                if (!_showAddForm) {
                  _clearControllers();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Consumer<CardPayOutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.beneficiaries.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              if (_showAddForm) _buildAddForm(provider),
              Expanded(
                child: provider.beneficiaries.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.beneficiaries.length,
                        itemBuilder: (context, index) {
                          return _buildBeneficiaryCard(
                            provider.beneficiaries[index],
                            provider,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAddForm(CardPayOutProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add Beneficiary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Account Holder Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Account Holder Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account holder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Account Number
              TextFormField(
                controller: _accountController,
                decoration: const InputDecoration(
                  labelText: 'Account Number *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter account number';
                  }
                  if (value.length < 9) {
                    return 'Enter valid account number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // IFSC Code
              TextFormField(
                controller: _ifscController,
                decoration: const InputDecoration(
                  labelText: 'IFSC Code *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter 11-character IFSC code',
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter IFSC code';
                  }
                  if (value.length != 11) {
                    return 'Enter valid 11-character IFSC code';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // ✅ Bank Name Dropdown (from provider)
              DropdownButtonFormField<String>(
                value: _selectedBankCode,
                decoration: const InputDecoration(
                  labelText: 'Bank Name *',
                  border: OutlineInputBorder(),
                  hintText: 'Select your bank',
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select Bank'),
                  ),
                  ...provider.banks.map((bank) {
                    final bankName = bank['name'] ?? 
                                    bank['bank_name'] ?? 
                                    bank['description'] ?? 
                                    bank.toString();
                    final bankCode = bank['code'] ?? 
                                    bank['bank_code'] ?? 
                                    bank['id']?.toString() ?? 
                                    bankName;
                    return DropdownMenuItem(
                      value: bankCode.toString(),
                      child: Text(bankName.toString()),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBankCode = value;
                    // Find and store the bank name
                    final selectedBank = provider.banks.firstWhere(
                      (bank) => (bank['code']?.toString() ?? bank['bank_code']?.toString() ?? bank['id']?.toString()) == value,
                      orElse: () => {},
                    );
                    _selectedBankName = selectedBank['name']?.toString() ?? 
                                      selectedBank['bank_name']?.toString() ?? 
                                      selectedBank['description']?.toString() ?? 
                                      value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a bank';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              // Optional: Mobile Number
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number (Optional)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),

              // Optional: State Dropdown
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(
                  labelText: 'State (Optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select State'),
                  ),
                  ...provider.states.map((state) {
                    final stateName = state['name'] ?? 
                                     state['state'] ?? 
                                     state['description'] ?? 
                                     state.toString();
                    final stateCode = state['code'] ?? 
                                     state['stateCode'] ?? 
                                     state['id']?.toString() ?? 
                                     stateName;
                    return DropdownMenuItem(
                      value: stateCode.toString(),
                      child: Text(stateName.toString()),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedState = value;
                  });
                },
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : () => _addBeneficiary(provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Add Beneficiary'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showAddForm = false;
                          _clearControllers();
                        });
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addBeneficiary(CardPayOutProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    // Validate bank selection
    if (_selectedBankCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a bank'), backgroundColor: Colors.red),
      );
      return;
    }

    try {
      final request = CardPayOutBeneficiaryRequest(
        accountHolderName: _nameController.text.trim(),
        accountNumber: _accountController.text.trim(),
        ifscCode: _ifscController.text.trim().toUpperCase(),
        bankName: _selectedBankName ?? 'Unknown Bank',
        mobileNumber: _mobileController.text.trim().isNotEmpty ? _mobileController.text.trim() : null,
        stateCode: _selectedState,
        vimopayBankCode: _selectedBankCode,
      );

      await provider.addBeneficiary(request);

      if (!mounted) return;

      setState(() {
        _showAddForm = false;
        _clearControllers();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beneficiary added successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _clearControllers() {
    _nameController.clear();
    _accountController.clear();
    _ifscController.clear();
    _mobileController.clear();
    setState(() {
      _selectedBankCode = null;
      _selectedBankName = null;
      _selectedState = null;
    });
  }

  Widget _buildBeneficiaryCard(CardPayOutBeneficiary beneficiary, CardPayOutProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            beneficiary.accountHolderName[0].toUpperCase(),
            style: TextStyle(color: Colors.blue.shade700),
          ),
        ),
        title: Text(beneficiary.accountHolderName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${beneficiary.bankName} - ${beneficiary.accountNumber}'),
            Text(
              'IFSC: ${beneficiary.ifscCode}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            if (beneficiary.mobileNumber != null)
              Text(
                'Mobile: ${beneficiary.mobileNumber}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          onPressed: () => _confirmDelete(context, beneficiary.id, provider),
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No Beneficiaries',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a beneficiary to start withdrawing',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showAddForm = true;
              });
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Beneficiary'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, int id, CardPayOutProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Beneficiary'),
        content: const Text('Are you sure you want to delete this beneficiary?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await provider.deleteBeneficiary(id);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Beneficiary deleted')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _mobileController.dispose();
    super.dispose();
  }
}