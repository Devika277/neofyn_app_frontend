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
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color background = Color(0xFF0A0E0A);
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
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();

  late TabController _tabController;

  String? _selectedBankIIN;
  String? _selectedBankName;
  Map<String, double>? _location;
  bool _isGettingLocation = false;

  String? _pidData;
  bool _isCapturingBiometric = false;
  bool _isBiometricCaptured = false;

  bool _isDeviceConnected = false;
  bool _isCheckingDevice = false;
  final LocationService _locationService = LocationService();

  DeviceType _selectedDevice = DeviceType.mantra;
  late AepsServiceType _currentService;

  // ✅ Only 3 services
  final List<AepsServiceType> _availableServices = [
    AepsServiceType.cashWithdrawal,
    AepsServiceType.balanceEnquiry,
    AepsServiceType.miniStatement,
  ];

  final Map<String, String> _tabAmounts = {};
  final Map<String, String> _tabAadhaar = {};
  final Map<String, String> _tabMobile = {};

  @override
  void initState() {
    super.initState();

    _currentService = _parseServiceType(widget.serviceType);

    final initialIndex = _availableServices.indexOf(_currentService);
    _tabController = TabController(
      length: _availableServices.length,
      vsync: this,
      initialIndex: initialIndex >= 0 ? initialIndex : 0,
    );

    // _tabController.addListener(_onTabChanged);

    // Use addListener without the indexIsChanging check
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return; // Skip during animation
      _saveCurrentTabValues();

      setState(() {
        _currentService = _availableServices[_tabController.index];

        final tabKey = _currentService.code;
        _amountController.text = _tabAmounts[tabKey] ?? '';
        _aadhaarController.text = _tabAadhaar[tabKey] ?? '';
        _mobileController.text = _tabMobile[tabKey] ?? '';
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AepsProvider>();
      if (provider.banks.isEmpty) provider.fetchBanks();
      if (provider.bankIINs.isEmpty) provider.fetchBankIINs();
    });
    _getLocation();
    _checkDevice();
  }

  AepsServiceType _parseServiceType(String type) {
    switch (type) {
      case 'CW':
        return AepsServiceType.cashWithdrawal;
      case 'BE':
        return AepsServiceType.balanceEnquiry;
      case 'MS':
        return AepsServiceType.miniStatement;
      default:
        return AepsServiceType.cashWithdrawal;
    }
  }
  void _onTabChanged() {
    // Remove the indexIsChanging check - always update
    _saveCurrentTabValues();
    _updateForCurrentTab();
  }
  /*void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _saveCurrentTabValues();

      setState(() {
        _currentService = _availableServices[_tabController.index];

        final tabKey = _currentService.code;
        _amountController.text = _tabAmounts[tabKey] ?? '';
        _aadhaarController.text = _tabAadhaar[tabKey] ?? '';
        _mobileController.text = _tabMobile[tabKey] ?? '';
      });
    }
  }*/
  void _updateForCurrentTab() {
    final newService = _availableServices[_tabController.index];

    // Restore saved values for the new tab
    final tabKey = newService.code;

    setState(() {
      _currentService = newService;
      _amountController.text = _tabAmounts[tabKey] ?? '';
      _aadhaarController.text = _tabAadhaar[tabKey] ?? '';
      _mobileController.text = _tabMobile[tabKey] ?? '';
    });
  }
 /* void _saveCurrentTabValues() {
    final tabKey = _currentService.code;
    _tabAmounts[tabKey] = _amountController.text;
    _tabAadhaar[tabKey] = _aadhaarController.text;
    _tabMobile[tabKey] = _mobileController.text;
  }*/
  void _saveCurrentTabValues() {
    if (_currentService == null) return;
    final tabKey = _currentService.code;
    _tabAmounts[tabKey] = _amountController.text;
    _tabAadhaar[tabKey] = _aadhaarController.text;
    _tabMobile[tabKey] = _mobileController.text;
  }

  @override
  void dispose() {
    _saveCurrentTabValues();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _aadhaarController.dispose();
    _amountController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  bool get _isAmountRequired => _currentService.isAmountRequired;

  Color _getServiceColor() => _currentService.color;
  IconData _getServiceIcon() => _currentService.icon;
  String _getServiceTitle() => _currentService.displayName;

  Future<void> _checkDevice() async {
    setState(() => _isCheckingDevice = true);
    try {
      final connected = await BiometricService.checkDevice();
      setState(() => _isDeviceConnected = connected);
    } catch (e) {
      setState(() => _isDeviceConnected = false);
    } finally {
      setState(() => _isCheckingDevice = false);
    }
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
      final provider = context.read<AepsProvider>();
      final currentPipe = provider.pipe ?? '1';

      final pidXml = await BiometricService.capturePid(
        clientKey: 'NEOFYN',
        skipWadh: true,
        pipe: currentPipe,
      );

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
      _showError('Please enter valid 12-digit Aadhaar');
      return;
    }
    if (_isAmountRequired) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount < 100 || amount > 10000) {
        _showError('Amount must be ₹100-₹10000');
        return;
      }
    }
    if (!_isBiometricCaptured || _pidData == null) {
      _showError('Capture biometric first');
      return;
    }
    if (_location == null) {
      _showError('Location required. Enable GPS.');
      await _getLocation();
      if (_location == null) return;
    }

    final provider = context.read<AepsProvider>();
    final currentPipe = provider.pipe ?? '1';
    final merchantId = provider.getMerchantIdForPipe(currentPipe) ?? provider.merchantId;
    final merchantRefId = provider.getMerchantRefIdForPipe(currentPipe) ?? provider.merchantRefId;

    if (merchantId == null) {
      _showError('Merchant not registered for pipe $currentPipe');
      return;
    }

    final confirmed = await _showConfirmationDialog();
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
        backgroundColor: TxnColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _getServiceColor().withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(_getServiceIcon(), color: _getServiceColor(), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Confirm Transaction', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('Service', _getServiceTitle()),
            const SizedBox(height: 8),
            _confirmRow('Aadhaar', _maskAadhaar(_aadhaarController.text)),
            if (_isAmountRequired) ...[
              const SizedBox(height: 8),
              _confirmRow('Amount', amountText),
            ],
            const SizedBox(height: 8),
            _confirmRow('Bank', _selectedBankName ?? 'N/A'),
            const SizedBox(height: 8),
            _confirmRow('Device', _selectedDevice.displayName),
            const SizedBox(height: 8),
            _confirmRow('Biometric', _isBiometricCaptured ? '✓ Captured' : '✗ Not captured'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_getServiceColor(), _getServiceColor().withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  Widget _confirmRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }

  void _showResultDialog(dynamic response) {
    final isSuccess = response.responseCode == '000' || response.status == '000';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: TxnColors.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isSuccess ? TxnColors.success : TxnColors.error).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isSuccess ? Icons.check_circle_rounded : Icons.error_rounded, color: isSuccess ? TxnColors.success : TxnColors.error, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(isSuccess ? 'Transaction Successful' : 'Transaction Failed', style: TextStyle(color: isSuccess ? TxnColors.success : TxnColors.error, fontSize: 16, fontWeight: FontWeight.w600))),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(response.statusDescription ?? response.npciMessage ?? 'Transaction completed', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              const SizedBox(height: 16),
              if (response.rrn != null) _resultRow('RRN', response.rrn),
              if (response.txnRefId != null) _resultRow('Ref ID', response.txnRefId),
              if (response.availableBalance != null) _resultRow('Balance', '₹${response.availableBalance}'),
              if (response.npciMessage != null) _resultRow('Status', response.npciMessage),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [TxnColors.primary, TxnColors.primaryLight]), borderRadius: BorderRadius.circular(10)),
              child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(ctx); _openReceiptScreen(response); },
                icon: const Icon(Icons.receipt_long_rounded, size: 20),
                label: const Text('View Receipt'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(colors: isSuccess ? [TxnColors.primary, TxnColors.primaryLight] : [TxnColors.error, TxnColors.error.withOpacity(0.7)]), borderRadius: BorderRadius.circular(10)),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openReceiptScreen(dynamic response) {
    try {
      final provider = context.read<AepsProvider>();
      final receipt = ReceiptModel.fromApiResponse(
        {
          'data': {
            'status': response.responseCode == '000' ? '000' : '001',
            'merchantRefId': provider.merchantRefId ?? '',
            'txnRefId': response.txnRefId ?? '',
            'merchantId': provider.merchantId ?? '',
            'aadhaarNo': _aadhaarController.text,
            'transactionAmount': _isAmountRequired ? _amountController.text : '0',
            'availableBalance': response.availableBalance ?? '0',
            'txnDateTime': DateTime.now().toString(),
            'bankIIN': _selectedBankIIN ?? '',
            'npciCode': response.npciCode ?? '',
            'npciMessage': response.npciMessage ?? '',
            'statusDescription': response.statusDescription ?? 'Transaction Successful',
            'rrn': response.rrn ?? '',
            'pipe': provider.pipe ?? '1',
          }
        },
        transactionType: _currentService.code,
        merchantId: provider.merchantId ?? 'N/A',
        mobileNumber: _mobileController.text.isNotEmpty ? _mobileController.text : (provider.mobileNo ?? ''),
      );
      Navigator.push(context, MaterialPageRoute(builder: (context) => ReceiptScreen(receipt: receipt)));
    } catch (e) {
      debugPrint('❌ Error opening receipt: $e');
    }
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  String _maskAadhaar(String aadhaar) {
    if (aadhaar.isEmpty) return '';
    if (aadhaar.length < 4) return aadhaar;
    if (aadhaar.length >= 8) return 'XXXX XXXX ${aadhaar.substring(aadhaar.length - 4)}';
    return aadhaar;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: TxnColors.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(16)));
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: TxnColors.success, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(16)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AepsProvider>();

    // Make sure currentService is in sync with tab controller
    if (_tabController.index < _availableServices.length) {
      _currentService = _availableServices[_tabController.index];
    }
    // final provider = context.watch<AepsProvider>();
    final serviceColor = _getServiceColor();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A0E0A), Color(0xFF0F1A0F), Color(0xFF0A0E0A), Color(0xFF050805)], stops: [0.0, 0.3, 0.7, 1.0]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(context)),
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: serviceColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(_getServiceIcon(), color: serviceColor, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_getServiceTitle(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18))),
                  ],
                ),
              ),
              Container(
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  indicator: BoxDecoration(color: TxnColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: TxnColors.primary.withOpacity(0.5), width: 1.5)),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white54,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
                  // In the build method, update the TabBar tabs:
                  tabs: _availableServices.map((service) {
                    // Don't use _currentService here as it may be stale
                    final tabIndex = _availableServices.indexOf(service);
                    return Tab(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                            service.icon,
                            size: 16,
                            color: _tabController.index == tabIndex ? Colors.white : Colors.white54
                        ),
                        const SizedBox(width: 6),
                        Text(
                          service.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: provider.isLoading || provider.isLoadingBankIINs
                    ? const Center(child: CircularProgressIndicator(color: TxnColors.primary))
                    : TabBarView(
                  controller: _tabController,
                  physics: const BouncingScrollPhysics(),
                  children: _availableServices.map((service) {
                    return _buildServiceContent(service: service, serviceColor: service.color, bankIINs: provider.bankIINs);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceContent({required AepsServiceType service, required Color serviceColor, required List<aeps.BankIIN> bankIINs}) {
    final canProceed = _selectedBankIIN != null && _aadhaarController.text.length == 12 && _isBiometricCaptured && _location != null && (!service.isAmountRequired || _amountController.text.isNotEmpty);
    final amountValid = !service.isAmountRequired || (double.tryParse(_amountController.text) ?? 0) >= 100;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [serviceColor.withOpacity(0.2), serviceColor.withOpacity(0.05)]), borderRadius: BorderRadius.circular(12), border: Border.all(color: serviceColor.withOpacity(0.2))),
            child: Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: serviceColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: Icon(service.icon, color: serviceColor, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(service.displayName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(service.isAmountRequired ? 'Amount required: ₹100 - ₹10,000' : 'No amount required', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11)),
              ])),
            ]),
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Select Device'),
          const SizedBox(height: 8),
          _buildDeviceSelector(),
          const SizedBox(height: 16),
          _buildDeviceStatusCard(),
          const SizedBox(height: 16),
          _buildLocationCard(),
          const SizedBox(height: 16),
          _buildSectionLabel('Select Bank'),
          const SizedBox(height: 8),
          _buildBankDropdown(bankIINs),
          const SizedBox(height: 16),
          _buildSectionLabel('Customer Mobile'),
          const SizedBox(height: 8),
          _buildInputField(controller: _mobileController, hint: 'Enter customer mobile number', icon: Icons.phone_android_rounded, keyboardType: TextInputType.phone, maxLength: 10),
          const SizedBox(height: 16),
          _buildSectionLabel('Aadhaar Number'),
          const SizedBox(height: 8),
          _buildInputField(controller: _aadhaarController, hint: 'Enter 12-digit Aadhaar', icon: Icons.credit_card_rounded, keyboardType: TextInputType.number, maxLength: 12),
          if (service.isAmountRequired) ...[
            const SizedBox(height: 16),
            _buildSectionLabel('Amount (₹)'),
            const SizedBox(height: 8),
            _buildInputField(controller: _amountController, hint: '₹100 - ₹10000', icon: Icons.currency_rupee_rounded, keyboardType: TextInputType.number),
            const SizedBox(height: 4),
            const Text('Min: ₹100 | Max: ₹10,000', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
          const SizedBox(height: 16),
          _buildBiometricCard(),
          const SizedBox(height: 24),
          if (!amountValid && service.isAmountRequired) _buildAmountError(),
          _buildProcessButton(canProceed && amountValid, serviceColor),
          const SizedBox(height: 16),
          _buildInfoNoteForService(service),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: Row(
        children: DeviceType.values.map((device) {
          final isSelected = _selectedDevice == device;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() { _selectedDevice = device; _isBiometricCaptured = false; _pidData = null; _checkDevice(); }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(color: isSelected ? TxnColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: isSelected ? Border.all(color: TxnColors.primary.withOpacity(0.5), width: 1.5) : null),
                child: Column(children: [
                  Icon(device.icon, color: isSelected ? TxnColors.primaryLight : Colors.white38, size: 24),
                  const SizedBox(height: 6),
                  Text(device.shortName, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 12, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                  const SizedBox(height: 2),
                  Text(device.displayName.split(' ').last, style: TextStyle(color: isSelected ? Colors.white.withOpacity(0.7) : Colors.white30, fontSize: 9)),
                ]),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500));

  Widget _buildDeviceStatusCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: (_isDeviceConnected ? TxnColors.success : TxnColors.warning).withOpacity(0.3))),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: (_isDeviceConnected ? TxnColors.success : TxnColors.warning).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: _isCheckingDevice ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TxnColors.primary)) : Icon(_isDeviceConnected ? Icons.usb_rounded : Icons.usb_off_rounded, color: _isDeviceConnected ? TxnColors.success : TxnColors.warning, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isDeviceConnected ? '${_selectedDevice.displayName} Connected' : '${_selectedDevice.displayName} Not Connected', style: TextStyle(color: _isDeviceConnected ? TxnColors.success : TxnColors.warning, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(_isDeviceConnected ? 'RD Service ready' : 'Check USB and RD Service', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 20), onPressed: _checkDevice),
      ]),
    );
  }

  Widget _buildLocationCard() {
    final hasLocation = _location != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: (hasLocation ? TxnColors.success : TxnColors.warning).withOpacity(0.3))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: (hasLocation ? TxnColors.success : TxnColors.warning).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: _isGettingLocation ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TxnColors.primary)) : Icon(hasLocation ? Icons.location_on_rounded : Icons.location_off_rounded, color: hasLocation ? TxnColors.success : TxnColors.warning, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hasLocation ? 'Location Ready' : 'Location Required', style: TextStyle(color: hasLocation ? TxnColors.success : TxnColors.warning, fontWeight: FontWeight.w600, fontSize: 13)),
          if (hasLocation) Text('Lat: ${_location!['latitude']!.toStringAsFixed(4)}, Lng: ${_location!['longitude']!.toStringAsFixed(4)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        IconButton(icon: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 20), onPressed: _getLocation),
      ]),
    );
  }

  Widget _buildBankDropdown(List<aeps.BankIIN> bankIINs) {
    return GestureDetector(
      onTap: () => _showBankSearchDialog(bankIINs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: Row(children: [
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(_selectedBankName ?? 'Select Bank', style: TextStyle(color: _selectedBankIIN != null ? Colors.white : Colors.white38, fontSize: 14), overflow: TextOverflow.ellipsis))),
          if (_selectedBankIIN != null) GestureDetector(onTap: () => setState(() { _selectedBankIIN = null; _selectedBankName = null; _isBiometricCaptured = false; _pidData = null; }), child: const Padding(padding: EdgeInsets.all(8.0), child: Icon(Icons.close, color: Colors.white38, size: 18))),
          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54),
        ]),
      ),
    );
  }

  void _showBankSearchDialog(List<aeps.BankIIN> bankIINs) {
    String localSearchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredBanks = localSearchQuery.isEmpty ? bankIINs : bankIINs.where((bank) {
              final s = localSearchQuery.toLowerCase();
              return (bank.description ?? '').toLowerCase().contains(s) || (bank.iin ?? '').toLowerCase().contains(s);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: const BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
              child: Column(children: [
                Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8), child: Text('Select Bank', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: TxnColors.primary.withOpacity(0.3))),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setModalState(() => localSearchQuery = v),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(hintText: 'Search bank...', hintStyle: TextStyle(color: Colors.white38), prefixIcon: Icon(Icons.search_rounded, color: TxnColors.primaryLight, size: 22), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
                    ),
                  ),
                ),
                Expanded(
                  child: filteredBanks.isEmpty
                      ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.search_off_rounded, color: Colors.white24, size: 48), SizedBox(height: 12), Text('No banks found', style: TextStyle(color: Colors.white38, fontSize: 14))]))
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filteredBanks.length,
                    itemBuilder: (context, index) {
                      final bank = filteredBanks[index];
                      final isSelected = bank.iin == _selectedBankIIN;
                      return ListTile(
                        onTap: () { setState(() { _selectedBankIIN = bank.iin; _selectedBankName = bank.description ?? bank.iin; _isBiometricCaptured = false; _pidData = null; }); Navigator.pop(context); },
                        leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: isSelected ? TxnColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Icon(isSelected ? Icons.check_circle : Icons.account_balance_rounded, color: isSelected ? TxnColors.primary : Colors.white38, size: 20)),
                        title: Text(bank.description ?? bank.iin ?? 'Unknown', style: TextStyle(color: isSelected ? TxnColors.primaryLight : Colors.white, fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                        subtitle: Text('IIN: ${bank.iin}', style: TextStyle(color: isSelected ? TxnColors.primary.withOpacity(0.7) : Colors.white38, fontSize: 12)),
                      );
                    },
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String hint, required IconData icon, TextInputType keyboardType = TextInputType.text, int? maxLength}) {
    return Container(
      decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.08))),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: keyboardType == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white30, fontSize: 14), prefixIcon: Icon(icon, color: Colors.white38, size: 20), border: InputBorder.none, counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)),
      ),
    );
  }

  Widget _buildBiometricCard() {
    final bankSelected = _selectedBankIIN != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: _isBiometricCaptured ? TxnColors.success.withOpacity(0.3) : Colors.white.withOpacity(0.08))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _isBiometricCaptured ? TxnColors.success.withOpacity(0.1) : (bankSelected ? TxnColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.05)), borderRadius: BorderRadius.circular(10)), child: _isCapturingBiometric ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: TxnColors.primary)) : Icon(_isBiometricCaptured ? Icons.check_circle_rounded : Icons.fingerprint_rounded, color: _isBiometricCaptured ? TxnColors.success : (bankSelected ? TxnColors.primaryLight : Colors.white38), size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_isBiometricCaptured ? 'Biometric Captured' : 'Biometric Required', style: TextStyle(color: _isBiometricCaptured ? TxnColors.success : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(_isBiometricCaptured ? 'Ready for transaction' : 'Tap to capture fingerprint', style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ])),
        if (bankSelected && !_isBiometricCaptured)
          Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [TxnColors.primary, TxnColors.primaryLight]), borderRadius: BorderRadius.circular(8)),
            child: ElevatedButton(onPressed: _captureBiometric, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Capture', style: TextStyle(color: Colors.white, fontSize: 12))),
          ),
      ]),
    );
  }

  Widget _buildAmountError() => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: TxnColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: TxnColors.error.withOpacity(0.3))), child: const Row(children: [Icon(Icons.warning_rounded, color: TxnColors.error, size: 18), SizedBox(width: 8), Text('Amount must be ₹100 - ₹10000', style: TextStyle(color: TxnColors.error, fontSize: 12))]));

  Widget _buildProcessButton(bool enabled, Color serviceColor) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        gradient: enabled ? LinearGradient(colors: [serviceColor, serviceColor.withOpacity(0.7)]) : LinearGradient(colors: [Colors.grey[800]!, Colors.grey[700]!]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: enabled ? [BoxShadow(color: serviceColor.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))] : [],
      ),
      child: ElevatedButton(
        onPressed: enabled ? _processTransaction : null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(_getServiceIcon(), color: Colors.white, size: 18), const SizedBox(width: 8), Text('Process ${_getServiceTitle()}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))]),
      ),
    );
  }

  Widget _buildInfoNoteForService(AepsServiceType service) {
    String note;
    switch (service) {
      case AepsServiceType.cashWithdrawal: note = '• Customer must be present physically\n• Biometric authentication required\n• Cash will be dispensed after success'; break;
      case AepsServiceType.balanceEnquiry: note = '• Check account balance\n• No amount deduction\n• Requires biometric authentication'; break;
      case AepsServiceType.miniStatement: note = '• View last 5 transactions\n• No amount deduction\n• Requires biometric authentication'; break;
    }
    return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: TxnColors.primary.withOpacity(0.15))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.info_outline_rounded, color: TxnColors.primaryLight, size: 16), SizedBox(width: 6), Text('Note', style: TextStyle(color: TxnColors.primaryLight, fontWeight: FontWeight.w600, fontSize: 13))]), const SizedBox(height: 8), Text(note, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.5))]));
  }
}