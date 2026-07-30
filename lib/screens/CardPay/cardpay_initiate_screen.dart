// lib/screens/CardPay/cardpay_initiate_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../providers/cardpay_provider.dart';
import '../../services/cardpay/card_pay_service.dart';
import '../../models/cardpay_models.dart';

class CardPayInitiateScreen extends StatefulWidget {
  const CardPayInitiateScreen({Key? key}) : super(key: key);

  @override
  State<CardPayInitiateScreen> createState() => _CardPayInitiateScreenState();
}

class _CardPayInitiateScreenState extends State<CardPayInitiateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _mobileController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _latController = TextEditingController();
  final _longController = TextEditingController();
  
  bool _isLoading = false;
  bool _isFetchingLocation = false;
  String? _selectedState;
  List<String> _states = [];
  String? _currentAddress;

  @override
  void initState() {
    super.initState();
    _loadStates();
    _getCurrentLocation();
  }

  Future<void> _loadStates() async {
    try {
      final provider = Provider.of<CardPayProvider>(context, listen: false);
      if (provider.states.isNotEmpty) {
        setState(() {
          _states = provider.states;
          if (_states.isNotEmpty && _selectedState == null) {
            _selectedState = _states.first;
          }
        });
      } else {
        final service = CardPayService();
        final states = await service.getStateList();
        setState(() {
          _states = states;
          if (_states.isNotEmpty && _selectedState == null) {
            _selectedState = _states.first;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading states: $e');
    }
  }

  // ✅ Auto-fetch current location
  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      // Check permissions
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

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Update lat/long fields
      setState(() {
        _latController.text = position.latitude.toStringAsFixed(6);
        _longController.text = position.longitude.toStringAsFixed(6);
        _isFetchingLocation = false;
      });

      // Get address from coordinates
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final state = place.administrativeArea ?? place.locality ?? '';
          setState(() {
            _currentAddress = '${place.locality ?? ''}, ${place.administrativeArea ?? ''}, ${place.country ?? ''}';
            // Auto-select state if available
            if (state.isNotEmpty && _states.contains(state)) {
              _selectedState = state;
            }
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
        title: const Text('Initiate Card Payment'),
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
      body: SingleChildScrollView(
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
              
              // Current Address (if available)
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
                  if (amount >= 100000) {
                    return 'Amount must be below ₹1,00,000';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Mobile
              TextFormField(
                controller: _mobileController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter mobile number';
                  }
                  if (value.length != 10) {
                    return 'Enter valid 10-digit mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter email';
                  }
                  if (!CardPayService.isValidEmail(value)) {
                    return 'Enter valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Location (State) Dropdown
              DropdownButtonFormField<String>(
                value: _selectedState,
                decoration: const InputDecoration(
                  labelText: 'State *',
                  border: OutlineInputBorder(),
                ),
                items: _states.map((state) {
                  return DropdownMenuItem(
                    value: state,
                    child: Text(state),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedState = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a state';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Latitude & Longitude (Row) with Auto-fetch button
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 28.6139',
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
                        labelText: 'Longitude *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., 77.2090',
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
              
              // Manual entry hint
              Text(
                '📍 Tap the location icon in the app bar to auto-fetch, or enter manually',
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
                  onPressed: _isLoading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                          'Pay Now',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<CardPayProvider>(context, listen: false);
      final result = await provider.initiatePayment(
        amount: double.parse(_amountController.text),
        mobile: _mobileController.text,
        name: _nameController.text,
        email: _emailController.text,
        location: _selectedState!,
        lat: _latController.text,
        long: _longController.text,
      );

      if (result != null) {
        if (!mounted) return;
        _showSuccessDialog(result);
      }
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

  void _showSuccessDialog(CardPayInitiateResponse result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Payment Initiated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your payment has been initiated successfully.'),
            const SizedBox(height: 12),
            const Text('Reference ID:'),
            Text(
              result.merchantRefId,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('Transaction ID:'),
            Text(
              result.txnId.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('Please use the payment link to complete the transaction:'),
            const SizedBox(height: 8),
            // Clickable Payment Link
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: InkWell(
                onTap: () => _launchPaymentLink(result.paymentLink),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.paymentLink,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap the link above to open in browser',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () => _launchPaymentLink(result.paymentLink),
            icon: const Icon(Icons.open_in_browser_rounded, size: 18),
            label: const Text('Open Link'),
          ),
        ],
      ),
    );
  }

  // Launch the payment link
  Future<void> _launchPaymentLink(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _mobileController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }
}