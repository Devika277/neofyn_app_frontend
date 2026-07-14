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

class TxnColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color cardColor = Color(0xFF1A1F1A);
  static const Color success = Color(0xFF2ECC71);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

enum DeviceType {
  mantra('Mantra MFS-110', 'Mantra', Icons.fingerprint, 'mantra'),
  morpho('Morpho MSO 1300', 'Morpho', Icons.scanner, 'morpho');

  final String displayName;
  final String shortName;
  final IconData icon;
  final String apiValue;
  const DeviceType(this.displayName, this.shortName, this.icon, this.apiValue);
}

enum AepsServiceType {
  cashWithdrawal('CW', 'Cash Withdrawal', Icons.money_rounded, Color(0xFF2ECC71)),
  balanceEnquiry('BE', 'Balance Enquiry', Icons.account_balance_wallet_rounded, Color(0xFF3498DB)),
  miniStatement('MS', 'Mini Statement', Icons.receipt_long_rounded, Color(0xFFE67E22));

  final String code;
  final String displayName;
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

class _AepsTransactionScreenState extends State<AepsTransactionScreen>
    with TickerProviderStateMixin {

  late TabController _tabController;
  late AepsServiceType _currentService;
  DeviceType _selectedDevice = DeviceType.mantra;
  final LocationService _locationService = LocationService();

  final List<AepsServiceType> _services = [
    AepsServiceType.cashWithdrawal,
    AepsServiceType.balanceEnquiry,
    AepsServiceType.miniStatement,
  ];

  // ✅ SHARED controllers - same for all tabs
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  // ✅ SHARED state
  String? _selectedBankIIN;
  String? _selectedBankName;
  String? _pidData;
  bool _isBiometricCaptured = false;
  bool _isCapturingBiometric = false;
  Map<String, double>? _location;
  bool _isGettingLocation = false;
  bool _isDeviceConnected = false;
  bool _isCheckingDevice = false;

  @override
  void initState() {
    super.initState();
    _currentService = _parseServiceType(widget.serviceType);

    _tabController = TabController(
      length: _services.length,
      vsync: this,
      initialIndex: _services.indexOf(_currentService),
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentService = _services[_tabController.index]);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AepsProvider>();
      if (provider.banks.isEmpty) provider.fetchBanks();
      if (provider.bankIINs.isEmpty) provider.fetchBankIINs();
      _getLocation();
      _checkDevice();
    });
  }

  AepsServiceType _parseServiceType(String type) {
    switch (type) {
      case 'CW': return AepsServiceType.cashWithdrawal;
      case 'BE': return AepsServiceType.balanceEnquiry;
      case 'MS': return AepsServiceType.miniStatement;
      default: return AepsServiceType.cashWithdrawal;
    }
  }

  @override
  void dispose() {
    _aadhaarController.dispose();
    _amountController.dispose();
    _mobileController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  bool get _isAmountRequired => _currentService.isAmountRequired;

  Future<void> _checkDevice() async {
    setState(() => _isCheckingDevice = true);
    try {
      final connected = await BiometricService.checkDevice();
      if (mounted) setState(() => _isDeviceConnected = connected);
    } catch (e) {
      if (mounted) setState(() => _isDeviceConnected = false);
    } finally {
      if (mounted) setState(() => _isCheckingDevice = false);
    }
  }

  Future<void> _getLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final isReady = await _locationService.showLocationDialog(context);
      if (isReady) {
        final location = await _locationService.getLocationMap();
        if (mounted) setState(() => _location = location);
      }
    } catch (e) {
      _showError('Failed to get location: $e');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _captureBiometric() async {
    if (_selectedBankIIN == null) { _showError('Select bank first'); return; }
    setState(() => _isCapturingBiometric = true);
    try {
      final provider = context.read<AepsProvider>();
      final pipe = provider.pipe ?? '1';
      final pidXml = await BiometricService.capturePid(clientKey: 'NEOFYN', skipWadh: true, pipe: pipe);
      if (mounted) {
        setState(() { _pidData = pidXml; _isBiometricCaptured = true; });
        _showSuccess('Biometric captured!');
      }
    } catch (e) {
      _showError('Capture failed: $e');
      BiometricService.resetDiscovery();
    } finally {
      if (mounted) setState(() => _isCapturingBiometric = false);
    }
  }

  Future<void> _processTransaction() async {
    if (_selectedBankIIN == null) { _showError('Select bank'); return; }
    if (_aadhaarController.text.length != 12) { _showError('Enter valid 12-digit Aadhaar'); return; }
    if (_isAmountRequired) {
      final amt = double.tryParse(_amountController.text) ?? 0;
      if (amt < 100 || amt > 10000) { _showError('Amount ₹100-₹10000'); return; }
    }
    if (!_isBiometricCaptured || _pidData == null) { _showError('Capture biometric first'); return; }
    if (_location == null) { await _getLocation(); if (_location == null) return; }

    final provider = context.read<AepsProvider>();
    final pipe = provider.pipe ?? '1';
    final merchantId = provider.getMerchantIdForPipe(pipe) ?? provider.merchantId;
    final merchantRefId = provider.getMerchantRefIdForPipe(pipe) ?? provider.merchantRefId;
    if (merchantId == null) { _showError('Merchant not registered'); return; }

    final confirmed = await _showConfirmDialog();
    if (!confirmed) return;

    try {
      final response = await provider.performAepsTransaction(
        merchantId: merchantId,
        transactionType: _currentService.code,
        aadhaarNumber: _aadhaarController.text,
        bankIIN: _selectedBankIIN!,
        amount: _isAmountRequired ? _amountController.text : '0',
        pidData: _pidData!,
        deviceType: _selectedDevice.apiValue,
        merchantRefId: merchantRefId ?? 'TXN_${DateTime.now().millisecondsSinceEpoch}',
        mobileNo: _mobileController.text.isNotEmpty ? _mobileController.text : (provider.mobileNo ?? ''),
        lat: _location!['latitude']?.toString() ?? '0.0',
        long: _location!['longitude']?.toString() ?? '0.0',
      );
      if (mounted && response != null) _showResult(response);
      else if (mounted) _showError(provider.errorMessage ?? 'Transaction failed');
    } catch (e) {
      _showError('Transaction failed: $e');
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxnColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Transaction', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          _row('Service', _currentService.displayName),
          _row('Aadhaar', _mask(_aadhaarController.text)),
          if (_isAmountRequired) _row('Amount', '₹${_amountController.text}'),
          _row('Bank', _selectedBankName ?? 'N/A'),
          _row('Biometric', _isBiometricCaptured ? '✓ Captured' : '✗ No'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: TxnColors.primary), child: const Text('Confirm', style: TextStyle(color: Colors.white))),
        ],
      ),
    ) ?? false;
  }

  Widget _row(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [SizedBox(width: 80, child: Text(l, style: const TextStyle(color: Colors.white60, fontSize: 12))), Expanded(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 13)))]));

  void _showResult(dynamic r) {
    final ok = r.responseCode == '000' || r.status == '000';
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: TxnColors.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(ok ? '✅ Successful' : '❌ Failed', style: TextStyle(color: ok ? TxnColors.success : TxnColors.error)),
      content: Text(r.statusDescription ?? r.npciMessage ?? '', style: const TextStyle(color: Colors.white70)),
      actions: [ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: TxnColors.primary), child: const Text('Done', style: TextStyle(color: Colors.white)))],
    ));
  }

  String _mask(String a) => a.length >= 8 ? 'XXXX XXXX ${a.substring(a.length - 4)}' : a;

  void _showError(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: TxnColors.error, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16)));
  }

  void _showSuccess(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: TxnColors.success, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AepsProvider>();
    final color = _currentService.color;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A0E0A), Color(0xFF0F1A0F), Color(0xFF0A0E0A), Color(0xFF050805)])),
        child: SafeArea(
          child: Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(context)),
                const SizedBox(width: 8),
                Expanded(child: Text(_currentService.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18))),
              ]),
            ),
            // Tabs
            Container(
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12)),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicator: BoxDecoration(color: TxnColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorPadding: const EdgeInsets.all(3),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                tabs: _services.map((s) => Tab(child: Text(s.displayName))).toList(),
              ),
            ),
            // Content - all tabs share same UI with same values
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: _services.map((s) => _buildContent(s)).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildContent(AepsServiceType service) {
    final canProceed = _selectedBankIIN != null && _aadhaarController.text.length == 12 && _isBiometricCaptured && _location != null && (!service.isAmountRequired || _amountController.text.isNotEmpty);
    final amtOk = !service.isAmountRequired || (double.tryParse(_amountController.text) ?? 0) >= 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _buildDeviceSelector(),
        const SizedBox(height: 8),
        _statusCard('Device', _isDeviceConnected, _isCheckingDevice, _checkDevice),
        const SizedBox(height: 8),
        _statusCard('Location', _location != null, _isGettingLocation, _getLocation),
        const SizedBox(height: 12),
        _label('Select Bank'),
        const SizedBox(height: 4),
        _bankDropdown(context.read<AepsProvider>().bankIINs),
        const SizedBox(height: 10),
        _label('Customer Mobile'),
        const SizedBox(height: 4),
        _input(_mobileController, 'Mobile number', Icons.phone_android_rounded, TextInputType.phone, 10),
        const SizedBox(height: 10),
        _label('Aadhaar Number'),
        const SizedBox(height: 4),
        _input(_aadhaarController, '12-digit Aadhaar', Icons.credit_card_rounded, TextInputType.number, 12),
        if (service.isAmountRequired) ...[
          const SizedBox(height: 10),
          _label('Amount (₹)'),
          const SizedBox(height: 4),
          _input(_amountController, '₹100 - ₹10000', Icons.currency_rupee_rounded, TextInputType.number),
        ],
        const SizedBox(height: 14),
        _biometricCard(),
        const SizedBox(height: 16),
        if (!amtOk && service.isAmountRequired) _amtError(),
        _processBtn(canProceed && amtOk, service.color, service.displayName),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildDeviceSelector() => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12)),
    child: Row(children: DeviceType.values.map((d) {
      final sel = _selectedDevice == d;
      return Expanded(child: GestureDetector(
        onTap: () => setState(() { _selectedDevice = d; _isBiometricCaptured = false; _pidData = null; _checkDevice(); }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: sel ? TxnColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: sel ? Border.all(color: TxnColors.primary.withOpacity(0.5)) : null),
          child: Column(children: [Icon(d.icon, color: sel ? TxnColors.primaryLight : Colors.white38, size: 20), const SizedBox(height: 2), Text(d.shortName, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontSize: 10))]),
        ),
      ));
    }).toList()),
  );

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(left: 4), child: Text(t, style: const TextStyle(color: Colors.white60, fontSize: 11)));

  Widget _statusCard(String label, bool ok, bool loading, VoidCallback onTap) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [
      loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TxnColors.primary)) : Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded, color: ok ? TxnColors.success : TxnColors.warning, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(ok ? '$label Ready' : '$label Required', style: TextStyle(color: ok ? TxnColors.success : TxnColors.warning, fontSize: 11))),
      GestureDetector(onTap: onTap, child: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 16)),
    ]),
  );

  Widget _bankDropdown(List<aeps.BankIIN> banks) => GestureDetector(
    onTap: () => _showBankDialog(banks),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Text(_selectedBankName ?? 'Select Bank', style: TextStyle(color: _selectedBankIIN != null ? Colors.white : Colors.white38, fontSize: 13))),
        if (_selectedBankIIN != null) GestureDetector(onTap: () => setState(() { _selectedBankIIN = null; _selectedBankName = null; _isBiometricCaptured = false; _pidData = null; }), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, color: Colors.white38, size: 16))),
        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 20),
      ]),
    ),
  );

  void _showBankDialog(List<aeps.BankIIN> banks) {
    String q = '';
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        final f = q.isEmpty ? banks : banks.where((b) => (b.description ?? '').toLowerCase().contains(q.toLowerCase()) || (b.iin ?? '').contains(q)).toList();
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: const BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.all(16), child: TextField(autofocus: true, onChanged: (v) => setM(() => q = v), style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Search bank...', hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search, color: TxnColors.primaryLight), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
            Expanded(child: ListView.builder(itemCount: f.length, itemBuilder: (_, i) {
              final b = f[i];
              final sel = b.iin == _selectedBankIIN;
              return ListTile(
                leading: Icon(sel ? Icons.check_circle : Icons.account_balance, color: sel ? TxnColors.primary : Colors.white38),
                title: Text(b.description ?? '', style: TextStyle(color: sel ? TxnColors.primaryLight : Colors.white, fontSize: 14)),
                subtitle: Text('IIN: ${b.iin}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () { setState(() { _selectedBankIIN = b.iin; _selectedBankName = b.description ?? b.iin; _isBiometricCaptured = false; _pidData = null; }); Navigator.pop(ctx); },
              );
            })),
          ]),
        );
      }),
    );
  }

  Widget _input(TextEditingController ctrl, String hint, IconData icon, TextInputType type, [int? max]) => Container(
    decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(10)),
    child: TextField(
      controller: ctrl, keyboardType: type, maxLength: max,
      inputFormatters: type == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white30, fontSize: 13), prefixIcon: Icon(icon, color: Colors.white38, size: 18), border: InputBorder.none, counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
    ),
  );

  Widget _biometricCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: _isBiometricCaptured ? TxnColors.success.withOpacity(0.3) : Colors.white.withOpacity(0.08))),
    child: Row(children: [
      _isCapturingBiometric ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: TxnColors.primary)) : Icon(_isBiometricCaptured ? Icons.check_circle : Icons.fingerprint, color: _isBiometricCaptured ? TxnColors.success : Colors.white38, size: 22),
      const SizedBox(width: 10),
      Expanded(child: Text(_isBiometricCaptured ? 'Biometric Captured' : 'Biometric Required', style: TextStyle(color: _isBiometricCaptured ? TxnColors.success : Colors.white, fontSize: 13))),
      if (_selectedBankIIN != null && !_isBiometricCaptured) ElevatedButton(onPressed: _captureBiometric, style: ElevatedButton.styleFrom(backgroundColor: TxnColors.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)), child: const Text('Capture', style: TextStyle(color: Colors.white, fontSize: 11))),
    ]),
  );

  Widget _amtError() => Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: TxnColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.warning_rounded, color: TxnColors.error, size: 14), SizedBox(width: 6), Text('Amount ₹100 - ₹10000', style: TextStyle(color: TxnColors.error, fontSize: 11))]));

  Widget _processBtn(bool enabled, Color color, String title) => SizedBox(
    width: double.infinity, height: 46,
    child: ElevatedButton(
      onPressed: enabled ? _processTransaction : null,
      style: ElevatedButton.styleFrom(backgroundColor: enabled ? color : Colors.grey[700], disabledBackgroundColor: Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      child: Text('Process $title', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
    ),
  );
}