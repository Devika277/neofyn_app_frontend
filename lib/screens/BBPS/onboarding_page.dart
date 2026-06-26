import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bbps_provider.dart';
import '../../models/bbps_models.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _shopAddressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _selectedState;
  String? _selectedCity;
  String? _businessType;

  @override
  void initState() {
    super.initState();
    final provider = context.read<BBPSProvider>();
    provider.loadStates();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopAddressCtrl.dispose();
    _pincodeCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final request = MerchantOnboardingRequest(
      firstName: _firstNameCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim().isEmpty ? null : _middleNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      dob: _dobCtrl.text.trim(),
      shopName: _shopNameCtrl.text.trim(),
      shopAddress: _shopAddressCtrl.text.trim(),
      shopState: _selectedState!,
      shopCity: _selectedCity!,
      pincode: _pincodeCtrl.text.trim(),
      mobile: _mobileCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      businessType: _businessType!,
      // Add additional fields as needed
    );

    await context.read<BBPSProvider>().onboardMerchant(request);
    if (mounted) {
      final response = context.read<BBPSProvider>().onboardingResponse;
      if (response != null && response.success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Onboarding successful!')));
        Navigator.pop(context);
      } else {
        final error = context.read<BBPSProvider>().onboardingError ?? 'Onboarding failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Onboarding')),
      body: Consumer<BBPSProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Personal Details
                  TextFormField(controller: _firstNameCtrl, decoration: const InputDecoration(labelText: 'First Name *'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(controller: _middleNameCtrl, decoration: const InputDecoration(labelText: 'Middle Name')),
                  TextFormField(controller: _lastNameCtrl, decoration: const InputDecoration(labelText: 'Last Name *'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(controller: _dobCtrl, decoration: const InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD) *'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  // Shop Details
                  TextFormField(controller: _shopNameCtrl, decoration: const InputDecoration(labelText: 'Shop Name (alphanumeric) *'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(controller: _shopAddressCtrl, decoration: const InputDecoration(labelText: 'Shop Address *'), maxLines: 2, validator: (v) => v!.isEmpty ? 'Required' : null),
                  // State dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    items: provider.states.map((s) => DropdownMenuItem(value: s.stateCode, child: Text(s.stateName))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedState = val;
                        _selectedCity = null;
                      });
                      if (val != null) provider.loadCities(val);
                    },
                    decoration: const InputDecoration(labelText: 'State *'),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  // City dropdown
                  if (provider.loadingCities) const CircularProgressIndicator(),
                  if (provider.cities.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedCity,
                      items: provider.cities.map((c) => DropdownMenuItem(value: c.cityCode, child: Text(c.cityName))).toList(),
                      onChanged: (val) => setState(() => _selectedCity = val),
                      decoration: const InputDecoration(labelText: 'City *'),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  TextFormField(controller: _pincodeCtrl, decoration: const InputDecoration(labelText: 'Pincode *'), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(controller: _mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile *'), keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Required' : null),
                  TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email *'), keyboardType: TextInputType.emailAddress, validator: (v) => v!.isEmpty ? 'Required' : null),
                  // Business type
                  DropdownButtonFormField<String>(
                    value: _businessType,
                    items: ['Retail', 'Wholesale', 'Services', 'other'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) => setState(() => _businessType = val),
                    decoration: const InputDecoration(labelText: 'Business Type *'),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),
                  if (provider.onboardingLoading)
                    const CircularProgressIndicator()
                  else
                    ElevatedButton(onPressed: _submit, child: const Text('Submit Onboarding')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}