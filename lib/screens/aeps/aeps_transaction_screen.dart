// lib/screens/aeps_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/receipt_model.dart';
import '../../providers/aeps_provider.dart';
import '../../services/AEPS/location_service.dart';
import '../receipt_screen.dart';
import 'biometric_service.dart';
import '../../services/AEPS/aeps_service.dart' as aeps;
import 'dart:convert';

class TxnColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color cardColor = Color(0xFF1A1F1A);
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

enum DeviceType {
  mantra('Mantra', Icons.fingerprint, 'mantra'),
  morpho('Morpho', Icons.scanner, 'morpho');
  final String shortName, apiValue;
  final IconData icon;
  const DeviceType(this.shortName, this.icon, this.apiValue);
}

enum AepsServiceType {
  cashWithdrawal('CW', 'Cash Withdrawal', Icons.money_rounded, Color(0xFF2ECC71)),
  balanceEnquiry('BE', 'Balance Enquiry', Icons.account_balance_wallet_rounded, Color(0xFF3498DB)),
  miniStatement('MS', 'Mini Statement', Icons.receipt_long_rounded, Color(0xFFE67E22));
  final String code, displayName;
  final IconData icon;
  final Color color;
  const AepsServiceType(this.code, this.displayName, this.icon, this.color);
  bool get isAmountRequired => code == 'CW';
}

class AepsTransactionScreen extends StatefulWidget {
  final String serviceType;
  const AepsTransactionScreen({super.key, required this.serviceType});
  @override
  State<AepsTransactionScreen> createState() => _AepsTransactionScreenState();
}

class _AepsTransactionScreenState extends State<AepsTransactionScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AepsServiceType _currentService;
  DeviceType _selectedDevice = DeviceType.mantra;
  final LocationService _locationService = LocationService();
  bool _isProcessing = false;
  bool _showingDialog = false; // Prevent duplicate dialogs

  final _services = [AepsServiceType.cashWithdrawal, AepsServiceType.balanceEnquiry, AepsServiceType.miniStatement];

  final _aadhaar = TextEditingController();
  final _amount = TextEditingController();
  final _mobile = TextEditingController();

  String? _bankIIN, _bankName, _pidData;
  bool _bioOk = false, _capturing = false;
  Map<String, double>? _loc;
  bool _gettingLoc = false, _devOk = false, _checkingDev = false;

  @override
  void initState() {
    super.initState();
    _currentService = _services.firstWhere((s) => s.code == widget.serviceType, orElse: () => _services[0]);
    _tabController = TabController(length: _services.length, vsync: this, initialIndex: _services.indexOf(_currentService));
    _tabController.addListener(() { if (!_tabController.indexIsChanging) setState(() => _currentService = _services[_tabController.index]); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AepsProvider>();
      if (p.banks.isEmpty) p.fetchBanks();
      if (p.bankIINs.isEmpty) p.fetchBankIINs();
      _getLoc(); _checkDev();
    });
  }

  @override
  void dispose() { _aadhaar.dispose(); _amount.dispose(); _mobile.dispose(); _tabController.dispose(); super.dispose(); }

  void _resetBio() => setState(() { _pidData = null; _bioOk = false; });
  String _mask(String a) => a.length >= 8 ? 'XXXX XXXX ${a.substring(a.length - 4)}' : a;

  // ======================================================================
  // DEVICE & LOCATION
  // ======================================================================
  Future<void> _checkDev() async {
  setState(() => _checkingDev = true);
  try {
    // ✅ Pass the selected device type
    final c = await BiometricService.checkDevice(
      deviceType: _selectedDevice.apiValue,  // This was missing!
    );
    if (mounted) setState(() => _devOk = c);
  } catch (e) {
    if (mounted) setState(() => _devOk = false);
    debugPrint('Device check error: $e');
  } finally {
    if (mounted) setState(() => _checkingDev = false);
  }
}

  Future<void> _getLoc() async {
    setState(() => _gettingLoc = true);
    try { if (await _locationService.showLocationDialog(context)) { final l = await _locationService.getLocationMap(); if (mounted) setState(() => _loc = l); } }
    catch (e) { _err('Location failed'); } finally { if (mounted) setState(() => _gettingLoc = false); }
  }

  // ======================================================================
  // BIOMETRIC CAPTURE
  // ======================================================================
Future<void> _captureBio() async {
  if (_bankIIN == null) { _err('Select bank first'); return; }
  setState(() => _capturing = true);
  try {
    final p = context.read<AepsProvider>();
    final pipe = p.pipe ?? '1';
    
    // ✅ Pass device type and pipe for proper WADH handling
    final pid = await BiometricService.capturePid(
      clientKey: 'NEOFYN',
      skipWadh: true,  // 2FA doesn't need WADH during capture
      pipe: pipe,
      deviceType: _selectedDevice.apiValue,  // This was missing!
    );
    
    if (mounted) {
      setState(() { 
        _pidData = pid; 
        _bioOk = true; 
      });
      _ok('Biometric captured!');
    }
  } catch (e) {
    debugPrint('Capture error: $e');
    _err('Capture failed: ${e.toString()}');
    BiometricService.resetDiscovery();
  } finally {
    if (mounted) setState(() => _capturing = false);
  }
}

  // ======================================================================
  // TRANSACTION FLOW: Validate → Confirm → Process → Show Result
  // ======================================================================
  Future<void> _process() async {
    if (_isProcessing) return;

    // Step 1: Validate
    if (_bankIIN == null) { _err('Select bank'); return; }
    if (_aadhaar.text.length != 12) { _err('Enter 12-digit Aadhaar'); return; }
    if (_currentService.isAmountRequired) { final a = double.tryParse(_amount.text) ?? 0; if (a < 100 || a > 10000) { _err('Amount ₹100-₹10000'); return; } }
    if (!_bioOk || _pidData == null) { _err('Capture biometric first'); return; }
    if (_loc == null) { await _getLoc(); if (_loc == null) return; }

    final p = context.read<AepsProvider>();
    final pipe = p.pipe ?? '1';
    final mid = p.getMerchantIdForPipe(pipe) ?? p.merchantId;
    if (mid == null) { _err('Not registered'); return; }

    // Step 2: Confirm
    final confirmed = await _showConfirmDialog();
    if (!confirmed || !mounted) return;

    // Step 3: Process
    setState(() => _isProcessing = true);
    try {
      final r = await p.performAepsTransaction(
        merchantId: mid, transactionType: _currentService.code,
        aadhaarNumber: _aadhaar.text, bankIIN: _bankIIN!,
        amount: _currentService.isAmountRequired ? _amount.text : '0',
        pidData: _pidData!, deviceType: _selectedDevice.apiValue,
        merchantRefId: p.getMerchantRefIdForPipe(pipe) ?? 'TXN_${DateTime.now().millisecondsSinceEpoch}',
        mobileNo: _mobile.text.isNotEmpty ? _mobile.text : (p.mobileNo ?? ''),
        lat: _loc!['latitude']?.toString() ?? '0.0', long: _loc!['longitude']?.toString() ?? '0.0',
      );

      // Step 4: Reset biometric (each transaction needs fresh PID)
      _resetBio();

      // Step 5: Show result dialog
      if (mounted && r != null) {
        _showResultDialog(r);
      } else if (mounted) {
        _err(p.errorMessage ?? 'Transaction failed');
      }
    } catch (e) {
      if (mounted) _err('Transaction failed');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ======================================================================
  // CONFIRMATION DIALOG
  // ======================================================================
  Future<bool> _showConfirmDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxnColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _currentService.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(_currentService.icon, color: _currentService.color, size: 24)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Confirm Transaction', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
        ]),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _confirmRow(Icons.category_rounded, 'Service', _currentService.displayName),
            const SizedBox(height: 10),
            _confirmRow(Icons.credit_card_rounded, 'Aadhaar', _mask(_aadhaar.text)),
            if (_currentService.isAmountRequired) ...[const SizedBox(height: 10), _confirmRow(Icons.currency_rupee_rounded, 'Amount', '₹${_amount.text}')],
            const SizedBox(height: 10),
            _confirmRow(Icons.account_balance_rounded, 'Bank', _bankName ?? 'N/A'),
            const SizedBox(height: 10),
            _confirmRow(Icons.fingerprint, 'Biometric', _bioOk ? '✓ Captured' : '✗ No'),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _currentService.color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Confirm')),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _confirmRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, color: _currentService.color.withOpacity(0.7), size: 18),
      const SizedBox(width: 10),
      Text('$label:', style: const TextStyle(color: Colors.white60, fontSize: 13)),
      const Spacer(),
      Flexible(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
    ]);
  }

  // ======================================================================
  // RESULT DIALOG (shown once, has View Receipt button)
  // ======================================================================
  void _showResultDialog(dynamic response) {
    // Prevent duplicate dialogs
    if (_showingDialog) return;
    _showingDialog = true;

    final isSuccess = response.responseCode == '000' || response.status == '000';
    final desc = response.statusDescription ?? response.npciMessage ?? '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxnColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: isSuccess ? [TxnColors.success, TxnColors.success.withOpacity(0.7)] : [TxnColors.error, TxnColors.error.withOpacity(0.7)])),
            child: Icon(isSuccess ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 36),
          ),
          const SizedBox(height: 16),
          Text(isSuccess ? 'Transaction Successful' : 'Transaction Failed', style: TextStyle(color: isSuccess ? TxnColors.success : TxnColors.error, fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        ]),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (desc.isNotEmpty) ...[Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14), textAlign: TextAlign.center), const SizedBox(height: 16)],
            if (response.rrn != null) _resultRow('RRN', '${response.rrn}'),
            if (response.txnRefId != null) _resultRow('Ref ID', '${response.txnRefId}'),
            if (response.availableBalance != null) _resultRow('Balance', '₹${response.availableBalance}'),
          ]),
        ),
        actions: [
          // View Receipt button
          SizedBox(width: double.infinity, child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [TxnColors.primary, TxnColors.primaryLight]), borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showingDialog = false;
                _openReceiptScreen(response);
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 20),
              label: const Text('View Receipt'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          )),
          // Done button
          SizedBox(width: double.infinity, child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: isSuccess ? [TxnColors.primary, TxnColors.primaryLight] : [TxnColors.error, TxnColors.error.withOpacity(0.7)]), borderRadius: BorderRadius.circular(10)),
            child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _showingDialog = false; },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 15)),
            ),
          )),
        ],
      ),
    );
  }

  Widget _resultRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Text('$label:', style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right)),
    ]),
  );

  // ======================================================================
  // OPEN RECEIPT SCREEN
  // ======================================================================
  // void _openReceiptScreen(dynamic response) {
  //   try {
  //     final p = context.read<AepsProvider>();
  //     final isSuccess = response.responseCode == '000' || response.status == '000';
  //     final receipt = ReceiptModel.fromApiResponse({
  //       'data': {
  //         'status': isSuccess ? '000' : '001',
  //         'merchantRefId': p.merchantRefId ?? p.getMerchantRefIdForPipe(p.pipe ?? '1') ?? '',
  //         'txnRefId': response.txnRefId?.toString() ?? '',
  //         'merchantId': p.merchantId ?? '',
  //         'aadhaarNo': _aadhaar.text,
  //         'transactionAmount': _currentService.isAmountRequired ? _amount.text : '0',
  //         'availableBalance': response.availableBalance?.toString() ?? '0',
  //         'txnDateTime': response.txnDateTime?.toString() ?? DateTime.now().toString(),
  //         'bankIIN': _bankIIN ?? '',
  //         'npciCode': response.npciCode?.toString() ?? '',
  //         'npciMessage': response.npciMessage?.toString() ?? '',
  //         'statusDescription': response.statusDescription?.toString() ?? 'Completed',
  //         'rrn': response.rrn?.toString() ?? '',
  //         'pipe': p.pipe ?? '1',
  //       }
  //     }, transactionType: _currentService.code, merchantId: p.merchantId ?? 'N/A', mobileNumber: _mobile.text.isNotEmpty ? _mobile.text : (p.mobileNo ?? ''));
  //     Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)));
  //   } catch (e) { debugPrint('Receipt error: $e'); }
  // }


  void _openReceiptScreen(dynamic response) {
  try {
    final p = context.read<AepsProvider>();
    final isSuccess = response.responseCode == '000' || response.status == '000';

    // ✅ Extract mini statement entries from response
    List<MiniStatementEntry> miniStatementEntries = [];
    
    // Try to get transactionList from response
    dynamic transactionListData;
    
    // Check if response has transactionList directly
    if (response is Map) {
      transactionListData = response['transactionList'] ?? response['transaction_list'];
    } else {
      // Try to get from object properties
      try {
        transactionListData = (response as dynamic).transactionList;
      } catch (_) {}
    }
    
    // If transactionList is a string, parse it
    if (transactionListData is String && transactionListData.isNotEmpty) {
      try {
        final parsed = jsonDecode(transactionListData);
        if (parsed is List) {
          for (var item in parsed) {
            if (item is Map<String, dynamic>) {
              final entry = MiniStatementEntry(
                date: item['date']?.toString() ?? '',
                txnType: item['txnType']?.toString() ?? 'Dr',
                amount: item['amount']?.toString() ?? '0',
                narration: item['narration']?.toString() ?? '',
              );
              miniStatementEntries.add(entry);
            }
          }
        }
        debugPrint('✅ Parsed ${miniStatementEntries.length} entries from transactionList string');
      } catch (e) {
        debugPrint('❌ Error parsing transactionList string: $e');
      }
    } 
    // If transactionList is a List, use it directly
    else if (transactionListData is List) {
      for (var item in transactionListData) {
        if (item is Map<String, dynamic>) {
          final entry = MiniStatementEntry(
            date: item['date']?.toString() ?? '',
            txnType: item['txnType']?.toString() ?? 'Dr',
            amount: item['amount']?.toString() ?? '0',
            narration: item['narration']?.toString() ?? '',
          );
          miniStatementEntries.add(entry);
        }
      }
      debugPrint('✅ Parsed ${miniStatementEntries.length} entries from transactionList list');
    }

    // ✅ Also try to get from data field if available
    if (miniStatementEntries.isEmpty && response is Map && response.containsKey('data')) {
      final dataMap = response['data'] as Map?;
      if (dataMap != null) {
        dynamic dataList = dataMap['transactionList'] ?? dataMap['transaction_list'];
        if (dataList is List) {
          for (var item in dataList) {
            if (item is Map<String, dynamic>) {
              final entry = MiniStatementEntry(
                date: item['date']?.toString() ?? '',
                txnType: item['txnType']?.toString() ?? 'Dr',
                amount: item['amount']?.toString() ?? '0',
                narration: item['narration']?.toString() ?? '',
              );
              miniStatementEntries.add(entry);
            }
          }
          debugPrint('✅ Parsed ${miniStatementEntries.length} entries from data.transactionList');
        }
      }
    }

    debugPrint('📄 Mini statement entries: ${miniStatementEntries.length}');

    // Get amount
    String amount = _currentService.isAmountRequired ? _amount.text : '0';
    if (amount.isEmpty) amount = '0';
    
    // Get available balance from response
    String availableBalance = '0';
    try {
      if (response is Map) {
        availableBalance = response['availableBalance']?.toString() ?? '0';
      } else {
        availableBalance = (response as dynamic).availableBalance?.toString() ?? '0';
      }
    } catch (_) {}

    // Get NPCI message
    String npciMessage = '';
    try {
      if (response is Map) {
        npciMessage = response['npciMessage']?.toString() ?? '';
      } else {
        npciMessage = (response as dynamic).npciMessage?.toString() ?? '';
      }
    } catch (_) {}

    // Get status description
    String statusDescription = '';
    try {
      if (response is Map) {
        statusDescription = response['statusDescription']?.toString() ?? '';
      } else {
        statusDescription = (response as dynamic).statusDescription?.toString() ?? '';
      }
    } catch (_) {}

    // Build receipt data
    final Map<String, dynamic> apiResponse = {
      'data': {
        'status': isSuccess ? '000' : '001',
        'successStatus': isSuccess ? 'true' : 'false',
        'merchantRefId': p.merchantRefId ?? p.getMerchantRefIdForPipe(p.pipe ?? '1') ?? '',
        'txnRefId': _safeGet(response, 'txnRefId', ''),
        'merchantId': p.merchantId ?? '',
        'aadhaarNo': _aadhaar.text,
        'aadhaarNumber': _aadhaar.text,
        'aadhaar_last4': _aadhaar.text.length >= 4 ? _aadhaar.text.substring(_aadhaar.text.length - 4) : _aadhaar.text,
        'transactionAmount': amount,
        'amount': amount,
        'availableBalance': availableBalance,
        'txnDateTime': _safeGet(response, 'txnDateTime', DateTime.now().toString()),
        'bankIIN': _bankIIN ?? '',
        'bankName': _bankName ?? 'Not Available',
        'bank_name': _bankName ?? 'Not Available',
        'bank_iin': _bankIIN ?? '',
        'npciCode': _safeGet(response, 'npciCode', ''),
        'npciMessage': npciMessage,
        'statusDescription': statusDescription.isNotEmpty ? statusDescription : (isSuccess ? 'Transaction Successful' : 'Transaction Failed'),
        'rrn': _safeGet(response, 'rrn', ''),
        'pipe': p.pipe ?? '1',
        'deviceUsed': _selectedDevice.shortName,
        'device_used': _selectedDevice.shortName,
        'provider': 'VimoPay',
        'mobileNumber': _mobile.text.isNotEmpty ? _mobile.text : (p.mobileNo ?? ''),
        'txn_type': _currentService.code,
        'transactionType': _currentService.code,
        // ✅ Pass the parsed mini statement entries as List
        'transactionList': miniStatementEntries.map((e) => e.toJson()).toList(),
        'udf1': '',
        'udf2': '',
        'udf3': '',
      }
    };

    final receipt = ReceiptModel.fromApiResponse(
      apiResponse,
      transactionType: _currentService.code,
      merchantId: p.merchantId ?? 'N/A',
      mobileNumber: _mobile.text.isNotEmpty ? _mobile.text : (p.mobileNo ?? ''),
    );

    debugPrint('📄 Opening receipt with ${receipt.miniStatementEntries?.length ?? 0} mini statement entries');
    
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt))
    );
  } catch (e, stack) {
    debugPrint('❌ Receipt error: $e');
    debugPrint('❌ Stack: $stack');
    _err('Error opening receipt');
  }
}

// ✅ Helper to safely get values from response
String _safeGet(dynamic obj, String key, [String defaultValue = '']) {
  try {
    if (obj == null) return defaultValue;
    if (obj is Map) {
      return obj[key]?.toString() ?? defaultValue;
    }
    // Try as object
    try {
      final value = (obj as dynamic)[key];
      return value?.toString() ?? defaultValue;
    } catch (_) {
      return defaultValue;
    }
  } catch (_) {
    return defaultValue;
  }
}

  // ======================================================================
  // SNACKBARS
  // ======================================================================
  void _err(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: TxnColors.error, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 3))); }
  void _ok(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: TxnColors.success, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 2))); }

  // ======================================================================
  // BUILD
  // ======================================================================
  @override
  Widget build(BuildContext context) {
    final p = context.watch<AepsProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A0E0A), Color(0xFF0F1A0F), Color(0xFF0A0E0A), Color(0xFF050805)])),
        child: SafeArea(child: Column(children: [
          // Header
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 4), Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: _currentService.color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(_currentService.icon, color: _currentService.color, size: 20)),
            const SizedBox(width: 8), Expanded(child: Text(_currentService.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 17))),
          ])),
          // Tabs
          Container(height: 40, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(10)), child: TabBar(controller: _tabController, isScrollable: false, indicator: BoxDecoration(color: TxnColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), indicatorSize: TabBarIndicatorSize.tab, indicatorPadding: const EdgeInsets.all(2), labelColor: Colors.white, unselectedLabelColor: Colors.white54, labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), tabs: _services.map((s) => Tab(child: Text(s.displayName))).toList())),
          // Content
          Expanded(child: _isProcessing ? const Center(child: CircularProgressIndicator(color: TxnColors.primary)) : TabBarView(controller: _tabController, children: _services.map((s) => _content(s)).toList())),
        ])),
      ),
    );
  }

  Widget _content(AepsServiceType s) {
    final p = context.read<AepsProvider>();
    final ok = _bankIIN != null && _aadhaar.text.length == 12 && _bioOk && _loc != null && (!s.isAmountRequired || _amount.text.isNotEmpty);
    final aOk = !s.isAmountRequired || (double.tryParse(_amount.text) ?? 0) >= 100;
    return SingleChildScrollView(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _devSel(), const SizedBox(height: 8),
      _statusCard('Device', _devOk, _checkingDev, _checkDev), const SizedBox(height: 6),
      _statusCard('Location', _loc != null, _gettingLoc, _getLoc), const SizedBox(height: 10),
      _label('Select Bank'), const SizedBox(height: 4), _bankDropdown(p.bankIINs), const SizedBox(height: 10),
      _label('Customer Mobile'), const SizedBox(height: 4), _textField(_mobile, 'Mobile', Icons.phone_android_rounded, TextInputType.phone, 10), const SizedBox(height: 10),
      _label('Aadhaar Number'), const SizedBox(height: 4), _textField(_aadhaar, '12-digit Aadhaar', Icons.credit_card_rounded, TextInputType.number, 12),
      if (s.isAmountRequired) ...[const SizedBox(height: 10), _label('Amount (₹)'), const SizedBox(height: 4), _textField(_amount, '₹100-₹10000', Icons.currency_rupee_rounded, TextInputType.number)],
      const SizedBox(height: 12), _biometricCard(), const SizedBox(height: 14),
      if (!aOk && s.isAmountRequired) _amountError(),
      _processButton(ok && aOk, s.color, s.displayName), const SizedBox(height: 16),
    ]));
  }

Widget _devSel() => Container(
  padding: const EdgeInsets.all(2),
  decoration: BoxDecoration(
    color: TxnColors.cardColor,
    borderRadius: BorderRadius.circular(10)
  ),
  child: Row(
    children: DeviceType.values.map((d) {
      final sel = _selectedDevice == d;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() { 
              _selectedDevice = d; 
              _resetBio(); 
              _devOk = false; // ✅ Reset device status immediately
            });
            // ✅ Re-check device with new type
            _checkDev(); 
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: sel ? TxnColors.primary.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: sel ? Border.all(color: TxnColors.primary.withOpacity(0.5)) : null
            ),
            child: Column(
              children: [
                Icon(
                  d.icon,
                  color: sel ? TxnColors.primaryLight : Colors.white38,
                  size: 18
                ),
                const SizedBox(height: 2),
                Text(
                  d.shortName,
                  style: TextStyle(
                    color: sel ? Colors.white : Colors.white54,
                    fontSize: 10,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w400
                  )
                ),
              ],
            ),
          ),
        ),
      );
    }).toList(),
  ),
);

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(left: 4, bottom: 2), child: Text(t, style: const TextStyle(color: Colors.white60, fontSize: 11)));

  Widget _statusCard(String l, bool ok, bool ld, VoidCallback t) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(8)), child: Row(children: [
    ld ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: TxnColors.primary)) : Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded, color: ok ? TxnColors.success : TxnColors.warning, size: 14),
    const SizedBox(width: 6), Expanded(child: Text(ok ? '$l Ready' : '$l Required', style: TextStyle(color: ok ? TxnColors.success : TxnColors.warning, fontSize: 11))),
    GestureDetector(onTap: t, child: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 14)),
  ]));

  Widget _bankDropdown(List<aeps.BankIIN> b) => GestureDetector(onTap: () => _showBankDialog(b), child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(8)), child: Row(children: [
    Expanded(child: Text(_bankName ?? 'Select Bank', style: TextStyle(color: _bankIIN != null ? Colors.white : Colors.white38, fontSize: 13))),
    if (_bankIIN != null) GestureDetector(onTap: () => setState(() { _bankIIN = null; _bankName = null; _resetBio(); }), child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.close, color: Colors.white38, size: 14))),
    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 18),
  ])));

  void _showBankDialog(List<aeps.BankIIN> b) {
    String q = '';
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(builder: (ctx, sm) {
      final f = q.isEmpty ? b : b.where((x) => (x.description ?? '').toLowerCase().contains(q.toLowerCase()) || (x.iin ?? '').contains(q)).toList();
      return Container(height: MediaQuery.of(context).size.height * 0.5, decoration: const BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))), child: Column(children: [
        const SizedBox(height: 10), Container(width: 36, height: 3, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(12), child: TextField(autofocus: true, onChanged: (v) => sm(() => q = v), style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: 'Search bank...', hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search, color: TxnColors.primaryLight, size: 18), filled: true, fillColor: Colors.white.withOpacity(0.05), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)))),
        Expanded(child: ListView.builder(itemCount: f.length, itemBuilder: (_, i) {
          final x = f[i];
          return ListTile(dense: true, leading: Icon(x.iin == _bankIIN ? Icons.check_circle : Icons.account_balance, color: x.iin == _bankIIN ? TxnColors.primary : Colors.white38, size: 18), title: Text(x.description ?? '', style: TextStyle(color: x.iin == _bankIIN ? TxnColors.primaryLight : Colors.white, fontSize: 13)), subtitle: Text('IIN: ${x.iin}', style: const TextStyle(color: Colors.white38, fontSize: 10)), onTap: () { setState(() { _bankIIN = x.iin; _bankName = x.description ?? x.iin; _resetBio(); }); Navigator.pop(ctx); });
        })),
      ]));
    }));
  }

  Widget _textField(TextEditingController c, String h, IconData i, TextInputType t, [int? m]) => Container(decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(8)), child: TextField(controller: c, keyboardType: t, maxLength: m, inputFormatters: t == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: h, hintStyle: const TextStyle(color: Colors.white30, fontSize: 12), prefixIcon: Icon(i, color: Colors.white38, size: 16), border: InputBorder.none, counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), isDense: true)));

  Widget _biometricCard() => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: _bioOk ? TxnColors.success.withOpacity(0.3) : Colors.white.withOpacity(0.08))), child: Row(children: [
    _capturing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: TxnColors.primary)) : Icon(_bioOk ? Icons.check_circle : Icons.fingerprint, color: _bioOk ? TxnColors.success : Colors.white38, size: 20),
    const SizedBox(width: 8), Expanded(child: Text(_bioOk ? 'Biometric Captured' : 'Biometric Required', style: TextStyle(color: _bioOk ? TxnColors.success : Colors.white, fontSize: 12))),
    if (_bankIIN != null && !_bioOk) ElevatedButton(onPressed: _captureBio, style: ElevatedButton.styleFrom(backgroundColor: TxnColors.primary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), minimumSize: const Size(0, 32)), child: const Text('Capture', style: TextStyle(color: Colors.white, fontSize: 10))),
  ]));

  Widget _amountError() => Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 6), decoration: BoxDecoration(color: TxnColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: const Row(children: [Icon(Icons.warning_rounded, color: TxnColors.error, size: 12), SizedBox(width: 4), Text('₹100-₹10000', style: TextStyle(color: TxnColors.error, fontSize: 10))]));

  Widget _processButton(bool e, Color c, String t) => SizedBox(width: double.infinity, height: 42, child: ElevatedButton(onPressed: e ? _process : null, style: ElevatedButton.styleFrom(backgroundColor: e ? c : Colors.grey[700], disabledBackgroundColor: Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text('Process $t', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))));
}