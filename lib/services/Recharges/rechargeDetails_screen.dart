// lib/services/Recharges/rechargeDetails_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../../screens/account/login_screen.dart';
import 'package:my_app/screens/BBPS/recharge_receipt_screen.dart';

const String _baseUrl = 'https://api.myneofyn.com';

class OperatorItem {
  final String code;
  final String description;
  const OperatorItem({required this.code, required this.description});
}

class RechargeDetailsScreen extends StatefulWidget {
  final String mobile;
  const RechargeDetailsScreen({Key? key, required this.mobile})
      : super(key: key);

  @override
  State<RechargeDetailsScreen> createState() => _RechargeDetailsScreenState();
}

class _RechargeDetailsScreenState extends State<RechargeDetailsScreen> {
  bool _loadingOperators = false;
  bool _processingPayment = false;
  String? _errorMessage;

  List<OperatorItem> _operators = [];
  OperatorItem? _selectedOperator;
  final String _serviceType = 'MBL';

  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchOperators();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<String?> _getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    if (token == null || token.isEmpty) {
      if (mounted) {
        _showSnack('Session expired. Please login again.', isError: true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginScreen()),
        );
      }
      return null;
    }
    return token;
  }

  Future<void> _fetchOperators() async {
    setState(() {
      _loadingOperators = true;
      _errorMessage = null;
    });

    try {
      final token = await _getValidToken();
      if (token == null) {
        setState(() {
          _loadingOperators = false;
          _errorMessage = 'Session expired. Please login again.';
        });
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/recharge/operators'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'serviceType': _serviceType}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] is List) {
          final List<dynamic> raw = body['data'];
          final fetched = raw
              .map((o) => OperatorItem(
                    code: o['code']?.toString() ?? '',
                    description: o['description']?.toString() ?? '',
                  ))
              .where((o) => o.code.isNotEmpty)
              .toList();

          if (fetched.isNotEmpty) {
            setState(() {
              _operators = fetched;
              _selectedOperator = fetched.first;
              _loadingOperators = false;
            });
            return;
          } else {
            throw Exception('Operator list is empty from server.');
          }
        } else {
          throw Exception(body['message'] ?? 'Failed to fetch operators.');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _loadingOperators = false;
      });
    }
  }

  Future<Map<String, String>> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return {'lat': '0.0', 'long': '0.0'};

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return {'lat': '0.0', 'long': '0.0'};
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return {'lat': '0.0', 'long': '0.0'};
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      return {
        'lat': position.latitude.toString(),
        'long': position.longitude.toString(),
      };
    } catch (_) {
      return {'lat': '0.0', 'long': '0.0'};
    }
  }

  Future<void> _processRecharge() async {
    if (_selectedOperator == null) {
      _showSnack('Please select an operator', isError: true);
      return;
    }

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnack('Please enter an amount', isError: true);
      return;
    }

    final double? amount = double.tryParse(amountText);
    if (amount == null || amount < 10 || amount > 10000) {
      _showSnack('Amount must be between ₹10 and ₹10,000', isError: true);
      return;
    }

    setState(() => _processingPayment = true);

    try {
      final token = await _getValidToken();
      if (token == null) {
        _showSnack('Session expired. Please login again.', isError: true);
        setState(() => _processingPayment = false);
        return;
      }

      final location = await _getLocation();
      final idempotencyKey = const Uuid().v4();

      final requestBody = {
        'mobile': widget.mobile,
        'operator': _selectedOperator!.code,
        'serviceType': _serviceType,
        'amount': amount,
        'idempotencyKey': idempotencyKey,
        'lat': location['lat'],
        'long': location['long'],
      };

      debugPrint('📡 Recharge request: ${jsonEncode(requestBody)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/api/recharge'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      final Map<String, dynamic> respBody = jsonDecode(response.body);
      debugPrint('📩 Recharge response: ${jsonEncode(respBody)}');

      if (respBody['success'] == true) {
        final data = respBody['data'] as Map<String, dynamic>? ?? {};
        final int? transactionId = data['transactionId'];

        if (transactionId != null && transactionId > 0) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => RechargeReceiptScreen(transactionId: transactionId),
              ),
            );
          }
        } else {
          // Fallback when transactionId is missing (should not happen)
          _showSnack(
            'Recharge ${data['refunded'] == true ? 'failed' : 'processed'}! '
            '₹${data['amount'] ?? amount} for ${widget.mobile}',
            isError: data['refunded'] == true,
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context);
        }
      } else {
        final errorCode = respBody['errorCode']?.toString() ?? '';
        String userMessage;
        switch (errorCode) {
          case 'INSUFFICIENT_BALANCE':
            userMessage = 'Insufficient wallet balance. Please add money first.';
            break;
          case 'PROVIDER_FAILED':
            userMessage = 'Recharge failed. Please try again.';
            break;
          default:
            userMessage = respBody['message']?.toString() ??
                'Recharge failed. Please try again.';
        }
        _showSnack(userMessage, isError: true);
      }
    } catch (e) {
      debugPrint('❌ Recharge error: $e');
      _showSnack('Network error. Please check connection and try again.',
          isError: true);
    } finally {
      if (mounted) setState(() => _processingPayment = false);
    }
  }

  void _showSnack(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mobile Recharge'), elevation: 0),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loadingOperators) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 16),
              Text(
                'Failed to load operators',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchOperators,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildMobileHeader(),
        _buildOperatorDropdown(),
        const Divider(height: 1),
        _buildAmountInput(),
        const SizedBox(height: 24),
        _buildRechargeButton(),
        const Spacer(),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.phone_android, size: 20),
          const SizedBox(width: 10),
          Text(
            widget.mobile,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DropdownButtonFormField<OperatorItem>(
        value: _selectedOperator,
        decoration: const InputDecoration(
          labelText: 'Select Operator',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: _operators
            .map((op) => DropdownMenuItem<OperatorItem>(
                  value: op,
                  child: Text(op.description),
                ))
            .toList(),
        onChanged: (val) => setState(() => _selectedOperator = val),
      ),
    );
  }

  Widget _buildAmountInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _amountController,
        focusNode: _amountFocusNode,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Enter Amount (₹)',
          hintText: 'e.g., 199',
          prefixIcon: Icon(Icons.currency_rupee),
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildRechargeButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _processingPayment ? null : _processRecharge,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _processingPayment
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('PROCEED TO PAY', style: TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}