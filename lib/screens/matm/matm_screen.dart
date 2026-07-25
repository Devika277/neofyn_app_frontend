// lib/screens/matm/matm_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/matm_service.dart';

class MatmScreen extends StatefulWidget {
  const MatmScreen({super.key});

  @override
  State<MatmScreen> createState() => _MatmScreenState();
}

class _MatmScreenState extends State<MatmScreen> {
  final TextEditingController _amountController = TextEditingController();
  String _responseText = 'Ready for transaction';
  bool _isLoading = false;
  String _merchantId = '';
  bool _isSdkAvailable = false;

  // Colors
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color accent = Color(0xFF00C897);
  static const Color success = Color(0xFF00E676);
  static const Color error = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFB74D);
  static const Color bg = Color(0xFF0A0E0A);
  static const Color surface = Color(0xFF151915);
  static const Color textHint = Color(0xFF6B7280);
  static const Color border = Color(0xFF2A342A);

  @override
  void initState() {
    super.initState();
    _loadMerchantIdAndCheckSDK();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadMerchantIdAndCheckSDK() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString('phone') ?? '';
    final userId = prefs.getString('userId') ?? '';
    
    setState(() {
      _merchantId = phone.isNotEmpty ? phone : userId;
      _responseText = '🔍 Initializing mATM SDK...';
    });

    await _checkSDKAvailability();
  }

  Future<void> _checkSDKAvailability() async {
    try {
      setState(() {
        _responseText = '✅ mATM SDK is ready\nMerchant ID: $_merchantId';
        _isSdkAvailable = true;
      });
    } catch (e) {
      setState(() {
        _responseText = '❌ mATM SDK not available: $e';
        _isSdkAvailable = false;
      });
    }
  }

  /// Test SDK Connection
  Future<void> _testSDKConnection() async {
    if (_merchantId.isEmpty) {
      setState(() {
        _responseText = '❌ Cannot test: Merchant ID is empty';
        _isSdkAvailable = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _responseText = '🔍 Testing SDK connection...\nPlease wait...';
    });

    try {
      print('🔍 [MATM] Testing SDK connection...');
      final response = await MatmService.balanceEnquiry(_merchantId);
      
      setState(() {
        _isSdkAvailable = true;
        _isLoading = false;
        _responseText = '✅ SDK Connection Successful!\n\n'
            'Merchant ID: $_merchantId\n'
            'Status: ${response.status}\n'
            'Description: ${response.statusDescription}\n\n'
            'You can now perform Balance Enquiry and Cash Withdrawal.';
      });
      
      _showSuccess('SDK connected successfully!');
    } catch (e) {
      print('❌ [MATM] SDK connection test failed: $e');
      setState(() {
        _isLoading = false;
        _isSdkAvailable = false;
        _responseText = '❌ SDK Connection Failed!\n\n'
            'Please check:\n'
            '1. Internet connection\n'
            '2. Merchant ID is valid\n'
            '3. SDK is properly initialized\n'
            '4. Check Logcat for errors\n\n'
            'Error: $e';
      });
      _showError('SDK connection failed: ${e.toString()}');
    }
  }

  Future<void> _performBalanceEnquiry() async {
    if (_merchantId.isEmpty) {
      _showError('Merchant ID not found. Please login again.');
      return;
    }

    if (!_isSdkAvailable) {
      _showError('mATM SDK not available. Please test connection first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _responseText = '⏳ Processing balance enquiry...';
    });

    try {
      print('🔍 [MATM DEBUG] Starting Balance Enquiry');
      print('📱 [MATM DEBUG] Merchant ID: $_merchantId');
      
      final response = await MatmService.balanceEnquiry(_merchantId);
      
      print('✅ [MATM DEBUG] Response received: ${response.status}');
      
      setState(() {
        _responseText = _formatResponse(response);
        _isLoading = false;
      });
      
      if (response.isSuccess) {
        _showSuccess('Balance enquiry completed');
      } else {
        _showError(response.statusDescription);
      }
    } catch (e, stackTrace) {
      print('❌ [MATM DEBUG] Error: $e');
      print('📚 [MATM DEBUG] Stack trace: $stackTrace');
      
      setState(() {
        _responseText = '❌ Error: $e\n\nPlease check:\n1. Internet connection\n2. Merchant ID validity\n3. SDK initialization';
        _isLoading = false;
      });
      _showError('Balance enquiry failed: ${e.toString()}');
    }
  }

  Future<void> _performCashWithdrawal() async {
    final amount = _amountController.text.trim();

    if (_merchantId.isEmpty) {
      _showError('Merchant ID not found. Please login again.');
      return;
    }

    if (!_isSdkAvailable) {
      _showError('mATM SDK not available. Please test connection first.');
      return;
    }

    if (amount.isEmpty) {
      _showError('Please enter an amount');
      return;
    }
    
    final amountDouble = double.tryParse(amount);
    if (amountDouble == null || amountDouble <= 0) {
      _showError('Please enter a valid amount greater than 0');
      return;
    }

    setState(() {
      _isLoading = true;
      _responseText = '⏳ Processing cash withdrawal...';
    });

    try {
      print('🔍 [MATM DEBUG] Starting Cash Withdrawal');
      print('📱 [MATM DEBUG] Merchant ID: $_merchantId');
      print('💰 [MATM DEBUG] Amount: $amount');
      
      final response = await MatmService.cashWithdrawal(_merchantId, amount);
      
      print('✅ [MATM DEBUG] Response received: ${response.status}');
      
      setState(() {
        _responseText = _formatResponse(response);
        _isLoading = false;
      });
      
      if (response.isSuccess) {
        _showSuccess('Cash withdrawal completed');
      } else {
        _showError(response.statusDescription);
      }
    } catch (e, stackTrace) {
      print('❌ [MATM DEBUG] Error: $e');
      print('📚 [MATM DEBUG] Stack trace: $stackTrace');
      
      setState(() {
        _responseText = '❌ Error: $e\n\nPlease check:\n1. Internet connection\n2. Amount validity\n3. SDK initialization';
        _isLoading = false;
      });
      _showError('Cash withdrawal failed: ${e.toString()}');
    }
  }

  String _formatResponse(MatmResponse response) {
    final buffer = StringBuffer();
    
    if (response.isSuccess) {
      buffer.writeln('✅ Status: SUCCESS (000)');
    } else if (response.isPending) {
      buffer.writeln('⏳ Status: PENDING (002)');
    } else if (response.isFailed) {
      buffer.writeln('❌ Status: FAILED (001)');
    } else if (response.isValidationFailed) {
      buffer.writeln('⚠️ Status: VALIDATION FAILED (003)');
    } else {
      buffer.writeln('Status: ${response.status}');
    }
    
    buffer.writeln('──────────────────────────');
    buffer.writeln('Merchant Status: ${response.merchantStatus}');
    buffer.writeln('Description: ${response.statusDescription}');
    
    if (response.availableBalance != null && response.availableBalance!.isNotEmpty) {
      buffer.writeln('\n💳 Available Balance');
      buffer.writeln('₹ ${response.availableBalance}');
    }
    
    if (response.txnAmount != null && response.txnAmount!.isNotEmpty) {
      buffer.writeln('\n💰 Transaction');
      buffer.writeln('Amount: ₹ ${response.txnAmount}');
    }
    
    if (response.bankName != null && response.bankName!.isNotEmpty) {
      buffer.writeln('\n🏦 Bank Details');
      buffer.writeln('Bank: ${response.bankName}');
    }
    
    if (response.bankRRN != null && response.bankRRN!.isNotEmpty) {
      buffer.writeln('RRN: ${response.bankRRN}');
    }
    
    if (response.cardNumber != null && response.cardNumber!.isNotEmpty) {
      buffer.writeln('Card: ${response.cardNumber}');
    }
    
    if (response.txnTime != null && response.txnTime!.isNotEmpty) {
      buffer.writeln('\n🕐 Time: ${response.txnTime}');
    }
    
    if (response.refId != null && response.refId!.isNotEmpty) {
      buffer.writeln('Reference ID: ${response.refId}');
    }
    
    return buffer.toString();
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Micro ATM'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering_rounded),
            onPressed: _isLoading ? null : _testSDKConnection,
            tooltip: 'Test Connection',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadMerchantIdAndCheckSDK,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SDK Status Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isSdkAvailable 
                    ? success.withOpacity(0.1) 
                    : error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isSdkAvailable 
                      ? success.withOpacity(0.3) 
                      : error.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isSdkAvailable 
                        ? Icons.check_circle_rounded 
                        : Icons.error_outline_rounded,
                    color: _isSdkAvailable ? success : error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isSdkAvailable ? 'SDK Ready' : 'SDK Not Available',
                          style: TextStyle(
                            color: _isSdkAvailable ? success : error,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Merchant ID: ${_merchantId.isEmpty ? 'Not loaded' : _merchantId}',
                          style: const TextStyle(
                            color: textHint,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isSdkAvailable 
                          ? success.withOpacity(0.2) 
                          : error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isSdkAvailable ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        color: _isSdkAvailable ? success : error,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Amount Input
            TextField(
              controller: _amountController,
              enabled: !_isLoading && _isSdkAvailable,
              decoration: InputDecoration(
                labelText: 'Enter Amount (₹)',
                labelStyle: TextStyle(color: textHint),
                hintText: '₹ 0',
                hintStyle: TextStyle(color: textHint.withOpacity(0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primary, width: 2),
                ),
                prefixIcon: const Icon(Icons.currency_rupee_rounded, color: primary),
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            
            // Test Connection Button
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _testSDKConnection,
              icon: const Icon(Icons.wifi_tethering_rounded, color: primary),
              label: const Text('Test Connection'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(color: primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || !_isSdkAvailable) ? null : _performBalanceEnquiry,
                    icon: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
                    label: const Text(
                      'Balance',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || !_isSdkAvailable) ? null : _performCashWithdrawal,
                    icon: const Icon(Icons.payments_outlined, color: Colors.white, size: 20),
                    label: const Text(
                      'Withdraw',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Quick amount suggestions
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['100', '200', '500', '1000', '2000'].map((amount) {
                return ActionChip(
                  label: Text('₹$amount'),
                  backgroundColor: surface,
                  labelStyle: const TextStyle(color: Colors.white),
                  side: BorderSide(color: border),
                  onPressed: (_isLoading || !_isSdkAvailable) ? null : () {
                    _amountController.text = amount;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            
            // Loading indicator
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: primary,
                    ),
                  ),
                ),
              ),
            
            // Response display
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Response',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: textHint),
                          onPressed: () {
                            // Copy to clipboard
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _responseText,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: _responseText.contains('❌') || _responseText.contains('Error')
                                ? error
                                : _responseText.contains('✅')
                                ? success
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}