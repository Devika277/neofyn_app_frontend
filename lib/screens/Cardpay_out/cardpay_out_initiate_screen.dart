// lib/screens/CardPayOut/cardpay_out_initiate_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../providers/cardpay_out_provider.dart';
import '../../models/cardpay_out_models.dart';
import 'cardpay_out_beneficiaries_screen.dart';
import 'cardpay_out_receipt_screen.dart';

class CardPayOutInitiateScreen extends StatefulWidget {
  const CardPayOutInitiateScreen({Key? key}) : super(key: key);

  @override
  State<CardPayOutInitiateScreen> createState() => _CardPayOutInitiateScreenState();
}

class _CardPayOutInitiateScreenState extends State<CardPayOutInitiateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _tpinController = TextEditingController();
  final _remarkController = TextEditingController();  // ✅ Added back
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  
  int? _selectedBeneficiaryId;
  String? _selectedMode;
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _loadData();
    _getCurrentLocation();
  }

  Future<void> _loadData() async {
    final provider = Provider.of<CardPayOutProvider>(context, listen: false);
    await provider.fetchBeneficiaries();
    await provider.fetchLimits();
  }

  // Auto-fetch current location
  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isFetchingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission denied. Please enter manually.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isFetchingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission permanently denied. Please enter manually.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _longController.text = position.longitude.toStringAsFixed(6);
        _isFetchingLocation = false;
      });

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          setState(() {
            _currentAddress = '${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
          });
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Location fetched successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isFetchingLocation = false);
      debugPrint('Error getting location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not fetch location: $e. Please enter manually.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Withdraw to Bank'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFetchingLocation ? Icons.location_searching : Icons.my_location),
            onPressed: _isFetchingLocation ? null : _getCurrentLocation,
            tooltip: 'Get Current Location',
          ),
        ],
      ),
      body: Consumer<CardPayOutProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Status
                  if (_isFetchingLocation)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: const [
                          SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('Fetching your location...'),
                        ],
                      ),
                    ),
                  
                  // Current Address
                  if (_currentAddress != null && !_isFetchingLocation)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _currentAddress!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Balance Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available Balance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.teal,
                                ),
                              ),
                              Text(
                                '₹${provider.balance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹ ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter amount';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Enter valid amount';
                      }
                      if (provider.limits != null) {
                        if (amount < 100) {
                          return 'Minimum amount is ₹100';
                        }
                        if (amount > 50000) {
                          return 'Maximum amount is ₹50,000';
                        }
                      }
                      if (amount > provider.balance) {
                        return 'Insufficient balance';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Beneficiary Dropdown
                  DropdownButtonFormField<int>(
                    value: _selectedBeneficiaryId,
                    decoration: const InputDecoration(
                      labelText: 'Select Beneficiary',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Select a beneficiary'),
                      ),
                      ...provider.beneficiaries.map((b) {
                        return DropdownMenuItem(
                          value: b.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.accountHolderName),
                              Text(
                                '${b.bankName} - ${b.accountNumber}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedBeneficiaryId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a beneficiary';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Add Beneficiary Button
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CardPayOutBeneficiariesScreen()),
                      ).then((_) => _loadData());
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add New Beneficiary'),
                  ),
                  const SizedBox(height: 16),

                  // Mode Selection
                  DropdownButtonFormField<String>(
                    value: _selectedMode,
                    decoration: const InputDecoration(
                      labelText: 'Transfer Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'IMPS',
                        child: Text('IMPS (Instant)'),
                      ),
                      DropdownMenuItem(
                        value: 'NEFT',
                        child: Text('NEFT (1-2 hours)'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedMode = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select transfer mode';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // TPIN Field
                  TextFormField(
                    controller: _tpinController,
                    decoration: const InputDecoration(
                      labelText: 'TPIN',
                      border: OutlineInputBorder(),
                      hintText: 'Enter your 6-digit TPIN',
                    ),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your TPIN';
                      }
                      if (value.length != 6) {
                        return 'TPIN must be 6 digits';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // ✅ Remark Field (Optional)
                  TextFormField(
                    controller: _remarkController,
                    decoration: const InputDecoration(
                      labelText: 'Remark (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Add a note for this withdrawal',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // Lat/Long fields
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latController,
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                            border: OutlineInputBorder(),
                            hintText: 'Auto-fetched',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _longController,
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                            border: OutlineInputBorder(),
                            hintText: 'Auto-fetched',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    '📍 Tap the location icon in the app bar to auto-fetch coordinates',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitWithdrawal,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Withdraw Now',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitWithdrawal() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<CardPayOutProvider>(context, listen: false);
      
      final request = CardPayOutInitiateRequest(
        amount: double.parse(_amountController.text),
        beneficiaryId: _selectedBeneficiaryId!,
        mode: _selectedMode!,
        tpin: _tpinController.text,
        lat: _latController.text,
        long: _longController.text,
        remarks: _remarkController.text.isNotEmpty ? _remarkController.text : null,  // ✅ Pass remark
      );

      final result = await provider.initiatePayout(request);
      
      if (!mounted) return;
      
      // Navigate to receipt screen with the reference ID
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CardPayOutReceiptScreen(ref: result.merchantRefId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tpinController.dispose();
    _remarkController.dispose();  // ✅ Dispose remark controller
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }
}