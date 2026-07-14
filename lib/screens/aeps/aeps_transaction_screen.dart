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
  final String displayName, shortName, apiValue;
  final IconData icon;
  const DeviceType(this.displayName, this.shortName, this.icon, this.apiValue);
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

  final _services = [
    AepsServiceType.cashWithdrawal,
    AepsServiceType.balanceEnquiry,
    AepsServiceType.miniStatement,
  ];

  // Shared controllers
  final _aadhaar = TextEditingController();
  final _amount = TextEditingController();
  final _mobile = TextEditingController();

  // Shared state
  String? _bankIIN, _bankName, _pidData;
  bool _bioOk = false, _capturing = false;
  Map<String, double>? _loc;
  bool _gettingLoc = false, _devOk = false, _checkingDev = false;

  @override
  void initState() {
    super.initState();
    _currentService = _parseService(widget.serviceType);
    _tabController = TabController(length: _services.length, vsync: this, initialIndex: _services.indexOf(_currentService));
    _tabController.addListener(() { if (!_tabController.indexIsChanging) setState(() => _currentService = _services[_tabController.index]); });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AepsProvider>();
      if (p.banks.isEmpty) p.fetchBanks();
      if (p.bankIINs.isEmpty) p.fetchBankIINs();
      _getLoc(); _checkDev();
    });
  }

  AepsServiceType _parseService(String t) {
    for (final s in _services) { if (s.code == t) return s; }
    return _services[0];
  }

  @override
  void dispose() { _aadhaar.dispose(); _amount.dispose(); _mobile.dispose(); _tabController.dispose(); super.dispose(); }

  void _resetBio() => setState(() { _pidData = null; _bioOk = false; });

  Future<void> _checkDev() async {
    setState(() => _checkingDev = true);
    try { final c = await BiometricService.checkDevice(); if (mounted) setState(() => _devOk = c); } catch (_) { if (mounted) setState(() => _devOk = false); }
    finally { if (mounted) setState(() => _checkingDev = false); }
  }

  Future<void> _getLoc() async {
    setState(() => _gettingLoc = true);
    try { if (await _locationService.showLocationDialog(context)) { final l = await _locationService.getLocationMap(); if (mounted) setState(() => _loc = l); } }
    catch (e) { _err('Location failed: $e'); } finally { if (mounted) setState(() => _gettingLoc = false); }
  }

  Future<void> _captureBio() async {
    if (_bankIIN == null) { _err('Select bank first'); return; }
    setState(() => _capturing = true);
    try {
      final p = context.read<AepsProvider>();
      final pid = await BiometricService.capturePid(clientKey: 'NEOFYN', skipWadh: true, pipe: p.pipe ?? '1');
      if (mounted) { setState(() { _pidData = pid; _bioOk = true; }); _ok('Biometric captured!'); }
    } catch (e) { _err('Capture failed: $e'); BiometricService.resetDiscovery(); }
    finally { if (mounted) setState(() => _capturing = false); }
  }

  Future<void> _process() async {
    if (_isProcessing) return;
    if (_bankIIN == null) { _err('Select bank'); return; }
    if (_aadhaar.text.length != 12) { _err('Enter 12-digit Aadhaar'); return; }
    if (_currentService.isAmountRequired) { final a = double.tryParse(_amount.text) ?? 0; if (a < 100 || a > 10000) { _err('Amount ₹100-₹10000'); return; } }
    if (!_bioOk || _pidData == null) { _err('Capture biometric first'); return; }
    if (_loc == null) { await _getLoc(); if (_loc == null) return; }

    final p = context.read<AepsProvider>();
    final pipe = p.pipe ?? '1';
    final mid = p.getMerchantIdForPipe(pipe) ?? p.merchantId;
    if (mid == null) { _err('Not registered'); return; }

    if (!await _confirm()) return;
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
      if (mounted && r != null) {
        _showResult(r);
        _resetBio(); // ✅ Reset biometric after transaction
      } else if (mounted) _err(p.errorMessage ?? 'Failed');
    } catch (e) { _err('Failed: $e'); }
    finally { if (mounted) setState(() => _isProcessing = false); }
  }

  Future<bool> _confirm() async => await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
    backgroundColor: TxnColors.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: _currentService.color.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(_currentService.icon, color: _currentService.color, size: 24)),
      const SizedBox(width: 12), const Text('Confirm Transaction', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
    ]),
    content: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)), child: Column(mainAxisSize: MainAxisSize.min, children: [
      _cr(Icons.category_rounded, 'Service', _currentService.displayName), const SizedBox(height: 10),
      _cr(Icons.credit_card_rounded, 'Aadhaar', _mask(_aadhaar.text)),
      if (_currentService.isAmountRequired) ...[const SizedBox(height: 10), _cr(Icons.currency_rupee_rounded, 'Amount', '₹${_amount.text}')],
      const SizedBox(height: 10), _cr(Icons.account_balance_rounded, 'Bank', _bankName ?? 'N/A'),
      const SizedBox(height: 10), _cr(Icons.fingerprint, 'Biometric', _bioOk ? '✓ Captured' : '✗ No'),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
      ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _currentService.color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Confirm')),
    ],
  )) ?? false;

  Widget _cr(IconData i, String l, String v) => Row(children: [Icon(i, color: _currentService.color.withOpacity(0.7), size: 18), const SizedBox(width: 10), Text('$l:', style: const TextStyle(color: Colors.white60, fontSize: 13)), const Spacer(), Text(v, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))]);

  void _showResult(dynamic r) {
    final ok = r.responseCode == '000' || r.status == '000';
    final desc = r.statusDescription ?? r.npciMessage ?? '';
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(
      backgroundColor: TxnColors.cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: ok ? [TxnColors.success, TxnColors.success.withOpacity(0.7)] : [TxnColors.error, TxnColors.error.withOpacity(0.7)])), child: Icon(ok ? Icons.check_rounded : Icons.close_rounded, color: Colors.white, size: 36)),
        const SizedBox(height: 16),
        Text(ok ? 'Transaction Successful' : 'Transaction Failed', style: TextStyle(color: ok ? TxnColors.success : TxnColors.error, fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
      ]),
      content: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(12)), child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (desc.isNotEmpty) ...[Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14), textAlign: TextAlign.center), const SizedBox(height: 16)],
        if (r.rrn != null) _rr('RRN', '${r.rrn}'),
        if (r.txnRefId != null) _rr('Ref ID', '${r.txnRefId}'),
        if (r.availableBalance != null) _rr('Balance', '₹${r.availableBalance}'),
        if (r.npciMessage != null && ok) _rr('NPCI', '${r.npciMessage}'),
        // Mini statement
        if (_currentService.code == 'MS' && r.transactionList != null) ...[
          const SizedBox(height: 12), const Divider(color: Colors.white12), const SizedBox(height: 8),
          const Text('Mini Statement', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
          ...((r.transactionList as List).take(5).map((tx) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
            Text(tx['date']?.toString() ?? '', style: const TextStyle(color: Colors.white54, fontSize: 11)), const SizedBox(width: 8),
            Text(tx['txnType']?.toString() ?? '', style: TextStyle(color: tx['txnType'] == 'Cr' ? TxnColors.success : TxnColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
            const Spacer(), Text('₹${tx['amount'] ?? ''}', style: const TextStyle(color: Colors.white, fontSize: 12)),
          ])))),
        ],
      ])),
      actions: [
        // View Receipt button
        SizedBox(width: double.infinity, child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [TxnColors.primary, TxnColors.primaryLight]), borderRadius: BorderRadius.circular(10)),
          child: ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); _openReceipt(r); },
            icon: const Icon(Icons.receipt_long_rounded, size: 20),
            label: const Text('View Receipt'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        )),
        // Done button
        SizedBox(width: double.infinity, child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: ok ? [TxnColors.primary, TxnColors.primaryLight] : [TxnColors.error, TxnColors.error.withOpacity(0.7)]), borderRadius: BorderRadius.circular(10)),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 14)),
            child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        )),
      ],
    ));
  }

  void _openReceipt(dynamic r) {
    try {
      final p = context.read<AepsProvider>();
      final ok = r.responseCode == '000' || r.status == '000';
      final receipt = ReceiptModel.fromApiResponse({
        'data': {
          'status': ok ? '000' : '001',
          'merchantRefId': p.merchantRefId ?? p.getMerchantRefIdForPipe(p.pipe ?? '1') ?? '',
          'txnRefId': r.txnRefId?.toString() ?? '',
          'merchantId': p.merchantId ?? p.getMerchantIdForPipe(p.pipe ?? '1') ?? '',
          'aadhaarNo': _aadhaar.text,
          'transactionAmount': _currentService.isAmountRequired ? _amount.text : '0',
          'availableBalance': r.availableBalance?.toString() ?? '0',
          'txnDateTime': r.txnDateTime?.toString() ?? DateTime.now().toString(),
          'bankIIN': _bankIIN ?? '',
          'npciCode': r.npciCode?.toString() ?? '',
          'npciMessage': r.npciMessage?.toString() ?? '',
          'statusDescription': r.statusDescription?.toString() ?? r.npciMessage?.toString() ?? 'Completed',
          'rrn': r.rrn?.toString() ?? '',
          'pipe': p.pipe ?? '1',
        }
      }, transactionType: _currentService.code, merchantId: p.merchantId ?? 'N/A', mobileNumber: _mobile.text.isNotEmpty ? _mobile.text : (p.mobileNo ?? ''));
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)));
    } catch (e) { debugPrint('Receipt error: $e'); }
  }

  Widget _rr(String l, String v) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Text('$l:', style: const TextStyle(color: Colors.white60, fontSize: 12)), const SizedBox(width: 8), Expanded(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500), textAlign: TextAlign.right))]));

  String _mask(String a) => a.length >= 8 ? 'XXXX XXXX ${a.substring(a.length - 4)}' : a;
  void _err(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: TxnColors.error, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 3))); }
  void _ok(String m) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: TxnColors.success, behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), duration: const Duration(seconds: 2))); }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AepsProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0A0E0A), Color(0xFF0F1A0F), Color(0xFF0A0E0A), Color(0xFF050805)])),
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10), child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20), onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _currentService.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(_currentService.icon, color: _currentService.color, size: 22)),
            const SizedBox(width: 10), Expanded(child: Text(_currentService.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18))),
          ])),
          Container(height: 42, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12)), child: TabBar(controller: _tabController, isScrollable: false, indicator: BoxDecoration(color: TxnColors.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), indicatorSize: TabBarIndicatorSize.tab, indicatorPadding: const EdgeInsets.all(3), labelColor: Colors.white, unselectedLabelColor: Colors.white54, labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600), tabs: _services.map((s) => Tab(child: Text(s.displayName))).toList())),
          Expanded(child: _isProcessing ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: TxnColors.primary), SizedBox(height: 16), Text('Processing...', style: TextStyle(color: Colors.white54))])) : TabBarView(controller: _tabController, children: _services.map((s) => _content(s)).toList())),
        ])),
      ),
    );
  }

  Widget _content(AepsServiceType s) {
    final p = context.read<AepsProvider>();
    final ok = _bankIIN != null && _aadhaar.text.length == 12 && _bioOk && _loc != null && (!s.isAmountRequired || _amount.text.isNotEmpty);
    final aOk = !s.isAmountRequired || (double.tryParse(_amount.text) ?? 0) >= 100;
    return SingleChildScrollView(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _devSel(), const SizedBox(height: 8),
      _sc('Device', _devOk, _checkingDev, _checkDev), const SizedBox(height: 8),
      _sc('Location', _loc != null, _gettingLoc, _getLoc), const SizedBox(height: 12),
      _lbl('Select Bank'), const SizedBox(height: 4), _bank(p.bankIINs), const SizedBox(height: 10),
      _lbl('Customer Mobile'), const SizedBox(height: 4), _tf(_mobile, 'Mobile', Icons.phone_android_rounded, TextInputType.phone, 10), const SizedBox(height: 10),
      _lbl('Aadhaar'), const SizedBox(height: 4), _tf(_aadhaar, '12-digit Aadhaar', Icons.credit_card_rounded, TextInputType.number, 12),
      if (s.isAmountRequired) ...[const SizedBox(height: 10), _lbl('Amount (₹)'), const SizedBox(height: 4), _tf(_amount, '₹100-₹10000', Icons.currency_rupee_rounded, TextInputType.number)],
      const SizedBox(height: 14), _bio(), const SizedBox(height: 16),
      if (!aOk && s.isAmountRequired) _amtErr(),
      _btn(ok && aOk, s.color, s.displayName), const SizedBox(height: 20),
    ]));
  }

  Widget _devSel() => Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(12)), child: Row(children: DeviceType.values.map((d) {
    final sel = _selectedDevice == d;
    return Expanded(child: GestureDetector(onTap: () => setState(() { _selectedDevice = d; _resetBio(); _checkDev(); }), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: sel ? TxnColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: sel ? Border.all(color: TxnColors.primary.withOpacity(0.5)) : null), child: Column(children: [Icon(d.icon, color: sel ? TxnColors.primaryLight : Colors.white38, size: 20), const SizedBox(height: 2), Text(d.shortName, style: TextStyle(color: sel ? Colors.white : Colors.white54, fontSize: 10))]))));
  }).toList()));

  Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(left: 4), child: Text(t, style: const TextStyle(color: Colors.white60, fontSize: 11)));
  Widget _sc(String l, bool ok, bool ld, VoidCallback t) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(10)), child: Row(children: [ld ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TxnColors.primary)) : Icon(ok ? Icons.check_circle : Icons.warning_amber_rounded, color: ok ? TxnColors.success : TxnColors.warning, size: 16), const SizedBox(width: 8), Expanded(child: Text(ok ? '$l Ready' : '$l Required', style: TextStyle(color: ok ? TxnColors.success : TxnColors.warning, fontSize: 11))), GestureDetector(onTap: t, child: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 16))]));

  Widget _bank(List<aeps.BankIIN> b) => GestureDetector(onTap: () => _bankDlg(b), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(10)), child: Row(children: [Expanded(child: Text(_bankName ?? 'Select Bank', style: TextStyle(color: _bankIIN != null ? Colors.white : Colors.white38, fontSize: 13))), if (_bankIIN != null) GestureDetector(onTap: () => setState(() { _bankIIN = null; _bankName = null; _resetBio(); }), child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.close, color: Colors.white38, size: 16))), const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 20)])));

  void _bankDlg(List<aeps.BankIIN> b) {
    String q = '';
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => StatefulBuilder(builder: (ctx, sm) {
      final f = q.isEmpty ? b : b.where((x) => (x.description ?? '').toLowerCase().contains(q.toLowerCase()) || (x.iin ?? '').contains(q)).toList();
      return Container(height: MediaQuery.of(context).size.height * 0.55, decoration: const BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))), child: Column(children: [
        const SizedBox(height: 12), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.all(16), child: TextField(autofocus: true, onChanged: (v) => sm(() => q = v), style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Search...', hintStyle: const TextStyle(color: Colors.white38), prefixIcon: const Icon(Icons.search, color: TxnColors.primaryLight), filled: true, fillColor: Colors.white.withOpacity(0.05), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))),
        Expanded(child: ListView.builder(itemCount: f.length, itemBuilder: (_, i) {
          final x = f[i]; final sel = x.iin == _bankIIN;
          return ListTile(leading: Icon(sel ? Icons.check_circle : Icons.account_balance, color: sel ? TxnColors.primary : Colors.white38), title: Text(x.description ?? '', style: TextStyle(color: sel ? TxnColors.primaryLight : Colors.white, fontSize: 14)), subtitle: Text('IIN: ${x.iin}', style: const TextStyle(color: Colors.white38, fontSize: 11)), onTap: () { setState(() { _bankIIN = x.iin; _bankName = x.description ?? x.iin; _resetBio(); }); Navigator.pop(ctx); });
        })),
      ]));
    }));
  }

  Widget _tf(TextEditingController c, String h, IconData i, TextInputType t, [int? m]) => Container(decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(10)), child: TextField(controller: c, keyboardType: t, maxLength: m, inputFormatters: t == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: InputDecoration(hintText: h, hintStyle: const TextStyle(color: Colors.white30, fontSize: 13), prefixIcon: Icon(i, color: Colors.white38, size: 18), border: InputBorder.none, counterText: '', contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))));

  Widget _bio() => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: TxnColors.cardColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: _bioOk ? TxnColors.success.withOpacity(0.3) : Colors.white.withOpacity(0.08))), child: Row(children: [
    _capturing ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: TxnColors.primary)) : Icon(_bioOk ? Icons.check_circle : Icons.fingerprint, color: _bioOk ? TxnColors.success : Colors.white38, size: 22),
    const SizedBox(width: 10), Expanded(child: Text(_bioOk ? 'Biometric Captured' : 'Biometric Required', style: TextStyle(color: _bioOk ? TxnColors.success : Colors.white, fontSize: 13))),
    if (_bankIIN != null && !_bioOk) ElevatedButton(onPressed: _captureBio, style: ElevatedButton.styleFrom(backgroundColor: TxnColors.primary, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)), child: const Text('Capture', style: TextStyle(color: Colors.white, fontSize: 11))),
  ]));

  Widget _amtErr() => Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: TxnColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.warning_rounded, color: TxnColors.error, size: 14), SizedBox(width: 6), Text('Amount ₹100-₹10000', style: TextStyle(color: TxnColors.error, fontSize: 11))]));
  Widget _btn(bool e, Color c, String t) => SizedBox(width: double.infinity, height: 46, child: ElevatedButton(onPressed: e ? _process : null, style: ElevatedButton.styleFrom(backgroundColor: e ? c : Colors.grey[700], disabledBackgroundColor: Colors.grey[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))), child: Text('Process $t', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))));
}