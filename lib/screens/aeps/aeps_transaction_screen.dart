// lib/screens/aeps_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/aeps_provider.dart';   // ✅ uses all models from provider
import '../../services/AEPS/location_service.dart';
import 'biometric_service.dart';
import '../../services/AEPS/aeps_service.dart' as aeps;


// No import of aeps_models.dart – provider already defines needed types

class AepsTransactionScreen extends StatefulWidget {
  final String serviceType; // 'CW', 'BE', 'MS', 'CD', 'AP'
  const AepsTransactionScreen({super.key, required this.serviceType});

  @override
  State<AepsTransactionScreen> createState() => _AepsTransactionScreenState();
}

class _AepsTransactionScreenState extends State<AepsTransactionScreen> {
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String? _selectedBankIIN;
  String? _selectedBankName;
  Map<String, double>? _location;
  bool _isGettingLocation = false;

  // Biometric
  String? _pidData;
  bool _isCapturingBiometric = false;
  bool _isBiometricCaptured = false;

  final LocationService _locationService = LocationService();

  bool get _isAmountRequired => ['CW', 'CD', 'AP'].contains(widget.serviceType);

  String _getServiceTitle() {
    switch (widget.serviceType) {
      case 'CW': return 'Cash Withdrawal';
      case 'BE': return 'Balance Enquiry';
      case 'MS': return 'Mini Statement';
      case 'CD': return 'Cash Deposit';
      case 'AP': return 'Aadhaar Pay';
      default: return 'AEPS Transaction';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AepsProvider>();
      if (provider.banks.isEmpty) {
        provider.fetchBanks();
      }
    });
    _getLocation();
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final isReady = await _locationService.showLocationDialog(context);
      if (isReady) {
        final location = await _locationService.getLocationMap();
        setState(() => _location = location);
      }
    } catch (e) {
      _showError('Failed to get location: $e');
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _captureBiometric() async {
    if (_selectedBankIIN == null) {
      _showError('Please select a bank first');
      return;
    }
    setState(() => _isCapturingBiometric = true);
    try {
      final pidXml = await BiometricService.capturePid(clientKey: 'NEOFYN');
      setState(() {
        _pidData = pidXml;
        _isBiometricCaptured = true;
      });
      _showSuccess('Biometric captured! Ready for transaction');
    } catch (e) {
      _showError('Biometric capture failed: $e');
      BiometricService.resetDiscovery();
    } finally {
      setState(() => _isCapturingBiometric = false);
    }
  }

  Future<void> _processTransaction() async {
    if (_selectedBankIIN == null) {
      _showError('Please select a bank');
      return;
    }
    if (_aadhaarController.text.length != 12) {
      _showError('Please enter valid 12-digit Aadhaar number');
      return;
    }
    if (_isAmountRequired) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount < 100 || amount > 10000) {
        _showError('Amount must be between ₹100 and ₹10000');
        return;
      }
    }
    if (!_isBiometricCaptured || _pidData == null) {
      _showError('Please capture biometric first');
      return;
    }
    if (_location == null) {
      _showError('Location required. Please enable GPS.');
      await _getLocation();
      if (_location == null) return;
    }

    final provider = context.read<AepsProvider>();
    final userPhone = provider.mobileNo;
    if (userPhone == null || userPhone.isEmpty) {
      _showError('User phone not found');
      return;
    }

    // ✅ Use provider's fetchMerchantByPhone (now implemented)
    await provider.fetchMerchantByPhone(userPhone);
    final merchantId = provider.realMerchantId;
    if (merchantId == null) {
      _showError('Merchant not registered. Please complete registration first.');
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    final merchantRefId = 'TXN_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final response = await provider.performAepsTransaction(
        merchantId: merchantId,
        transactionType: widget.serviceType,
        aadhaarNumber: _aadhaarController.text,
        bankIIN: _selectedBankIIN!,
        amount: _isAmountRequired ? _amountController.text : '0',
        pidData: _pidData!,
        deviceType: 'mantra',
        merchantRefId: merchantRefId,
        mobileNo: provider.mobileNo ?? '',
      );
      if (mounted && response != null) {
        _showResultDialog(response);
      } else if (mounted) {
        _showError(provider.errorMessage ?? 'Transaction failed');
      }
    } catch (e) {
      _showError('Transaction failed: $e');
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final amountText = _isAmountRequired ? '₹${_amountController.text}' : 'N/A';
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Transaction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${_getServiceTitle()}'),
            const SizedBox(height: 8),
            Text('Aadhaar: ${_maskAadhaar(_aadhaarController.text)}'),
            if (_isAmountRequired) Text('Amount: $amountText'),
            Text('Bank: $_selectedBankName'),
            Text('Biometric: ${_isBiometricCaptured ? "✓ Captured" : "✗ Not captured"}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6200EE)),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showResultDialog(TransactionResponse response) {
    final isSuccess = response.status == '000' || response.status == 'Success';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(isSuccess ? Icons.check_circle : Icons.error,
                color: isSuccess ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(isSuccess ? 'Success' : 'Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(response.statusDescription ?? 'Transaction completed'),
              const Divider(),
              if (response.rrn != null) _infoRow('RRN', response.rrn!),
              if (response.txnRefId != null) _infoRow('Ref ID', response.txnRefId!),
              if (response.availableBalance != null)
                _infoRow('Balance', '₹${response.availableBalance}'),
              if (response.npciMessage != null) _infoRow('NPCI', response.npciMessage!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _maskAadhaar(String aadhaar) {
    if (aadhaar.length >= 8) return 'XXXX XXXX ${aadhaar.substring(aadhaar.length - 4)}';
    return aadhaar;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AepsProvider>();
    final banks = provider.banks;

    final canProceed = _selectedBankIIN != null &&
        _aadhaarController.text.length == 12 &&
        _isBiometricCaptured &&
        _location != null &&
        (!_isAmountRequired || _amountController.text.isNotEmpty);
    final amountValid = !_isAmountRequired ||
        (double.tryParse(_amountController.text) ?? 0) >= 100;

    return Scaffold(
      appBar: AppBar(
        title: Text(_getServiceTitle()),
        backgroundColor: const Color(0xFF6200EE),
        foregroundColor: Colors.white,
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildLocationCard(),
                  const SizedBox(height: 16),
                  _buildBankDropdown(banks),
                  const SizedBox(height: 16),
                  _buildAadhaarField(),
                  const SizedBox(height: 16),
                  if (_isAmountRequired) _buildAmountField(),
                  const SizedBox(height: 16),
                  _buildBiometricCard(),
                  const SizedBox(height: 24),
                  if (!amountValid && _isAmountRequired) _buildAmountError(),
                  const SizedBox(height: 16),
                  _buildProcessButton(canProceed && amountValid),
                  const SizedBox(height: 16),
                  if (_isAmountRequired) _buildInfoNote(),
                ],
              ),
            ),
    );
  }

  // ------------------ UI Components ------------------
  Widget _buildLocationCard() {
    final hasLocation = _location != null;
    return Card(
      color: (hasLocation ? Colors.green : Colors.orange).withOpacity(0.1),
      child: ListTile(
        leading: _isGettingLocation
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(hasLocation ? Icons.location_on : Icons.location_off,
                color: hasLocation ? Colors.green : Colors.orange),
        title: Text(hasLocation ? 'Location Ready' : 'Location Required',
            style: TextStyle(color: hasLocation ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
        subtitle: Text(hasLocation
            ? 'Lat: ${_location!['latitude']!.toStringAsFixed(4)}, Lng: ${_location!['longitude']!.toStringAsFixed(4)}'
            : 'Enable location to proceed'),
        trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: _getLocation),
      ),
    );
  }

  Widget _buildBankDropdown(List<aeps.Bank> banks) {
  final validValue = _selectedBankIIN != null && 
      banks.any((b) => b.code == _selectedBankIIN) 
      ? _selectedBankIIN 
      : null;


    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: DropdownButton<String>(
      value: validValue,
      isExpanded: true,
      hint: const Text('Select Bank', style: TextStyle(color: Colors.grey)),
      dropdownColor: Colors.grey[900],
      underline: const SizedBox(),
      items: banks.isEmpty
          ? null
          : banks.map((bank) {
              return DropdownMenuItem<String>(
                value: bank.code,
                child: Text(
                  bank.name ?? 'Unknown', // null safety
                  style: const TextStyle(color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
      onChanged: (value) {
        if (value == null) return;
        final bank = banks.firstWhere((b) => b.code == value);
        setState(() {
          _selectedBankIIN = value;
          _selectedBankName = bank.name ?? 'Unknown';
          _isBiometricCaptured = false;
          _pidData = null;
        });
      },
    ),
  );
}

  Widget _buildAadhaarField() {
    return TextField(
      controller: _aadhaarController,
      keyboardType: TextInputType.number,
      maxLength: 12,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: 'Aadhaar Number',
        hintText: '12-digit Aadhaar',
        prefixIcon: const Icon(Icons.credit_card),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        counterText: '',
      ),
    );
  }

  Widget _buildAmountField() {
    return Column(
      children: [
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'Amount (₹)',
            hintText: '₹100 - ₹10000',
            prefixIcon: const Icon(Icons.currency_rupee),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Text('Min: ₹100 | Max: ₹10,000', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildBiometricCard() {
    final bankSelected = _selectedBankIIN != null;
    return Card(
      color: _isBiometricCaptured
          ? Colors.green.shade50
          : (bankSelected ? Colors.blue.shade50 : Colors.grey.shade100),
      child: ListTile(
        leading: _isCapturingBiometric
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(_isBiometricCaptured ? Icons.check_circle : Icons.fingerprint,
                color: _isBiometricCaptured
                    ? Colors.green
                    : (bankSelected ? Colors.blue : Colors.grey)),
        title: Text(
          _isBiometricCaptured ? 'Biometric Captured ✓' : 'Biometric Required',
          style: TextStyle(
            color: _isBiometricCaptured ? Colors.green : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(_isBiometricCaptured
            ? 'Ready for transaction'
            : 'Tap to capture customer fingerprint'),
        trailing: bankSelected && !_isBiometricCaptured
            ? ElevatedButton(onPressed: _captureBiometric, child: const Text('Capture'))
            : null,
      ),
    );
  }

  Widget _buildAmountError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
      child: const Row(
        children: [
          Icon(Icons.warning, color: Colors.red, size: 20),
          SizedBox(width: 8),
          Text('Amount must be ₹100 - ₹10000', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildProcessButton(bool enabled) {
    return ElevatedButton.icon(
      onPressed: enabled ? _processTransaction : null,
      icon: const Icon(Icons.send),
      label: Text('Process ${_getServiceTitle()}'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        backgroundColor: const Color(0xFF6200EE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInfoNote() {
    String noteText;
    switch (widget.serviceType) {
      case 'CW':
        noteText = '• Customer must be present physically\n'
                   '• Biometric authentication required\n'
                   '• Cash will be dispensed after success';
        break;
      case 'CD':
        noteText = '• Customer deposits cash into their own bank account\n'
                   '• Biometric authentication required\n'
                   '• Amount will be credited after success';
        break;
      case 'AP':
        noteText = '• Customer pays the merchant (debit from customer)\n'
                   '• Biometric authentication required\n'
                   '• Merchant will receive the credited amount';
        break;
      default:
        noteText = '• Ensure biometric is captured\n'
                   '• Location must be enabled';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 4, 6, 7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color.fromARGB(255, 0, 33, 60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(noteText, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}