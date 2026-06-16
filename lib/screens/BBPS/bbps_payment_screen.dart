// lib/screens/bbps_payment_screen.dart
//
// Full BBPS bill payment flow:
//   Step 1 — Select category → select biller → enter consumer number → Fetch Bill
//   Step 2 — Review bill details → enter amount → Pay Now
//   Step 3 — Success / Failure screen

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_logger.dart';
 
// ─────────────────────────────────────────────────────────────────────────────
// STATIC DATA — categories and billers hardcoded, no API call needed
// ─────────────────────────────────────────────────────────────────────────────
const _staticCategories = [
  {'id': 'ELECTRICITY', 'name': 'Electricity',    'icon': '⚡'},
  {'id': 'DTH',         'name': 'DTH',             'icon': '📡'},
  {'id': 'FASTAG',      'name': 'Fastag',           'icon': '🚗'},
  {'id': 'POSTPAID',    'name': 'Postpaid Mobile',  'icon': '📱'},
  {'id': 'GAS',         'name': 'Gas',              'icon': '🔥'},
  {'id': 'WATER',       'name': 'Water',            'icon': '💧'},
  {'id': 'LOAN',        'name': 'Loan Repayment',   'icon': '🏦'},
  {'id': 'INSURANCE',   'name': 'Insurance',        'icon': '🛡️'},
];
 
const _staticBillers = {
  'ELECTRICITY': [
    {'id': 'BESCOM',   'name': 'BESCOM (Karnataka)'},
    {'id': 'MSEDCL',   'name': 'MSEDCL (Maharashtra)'},
    {'id': 'TNEB',     'name': 'TNEB (Tamil Nadu)'},
    {'id': 'TSSPDCL',  'name': 'TSSPDCL (Telangana)'},
    {'id': 'KSEB',     'name': 'KSEB (Kerala)'},
    {'id': 'UPPCL',    'name': 'UPPCL (Uttar Pradesh)'},
    {'id': 'WBSEDCL',  'name': 'WBSEDCL (West Bengal)'},
    {'id': 'DHBVN',    'name': 'DHBVN (Haryana)'},
  ],
  'DTH': [
    {'id': 'TATASKY',   'name': 'Tata Play (Tata Sky)'},
    {'id': 'AIRTEL_DTH','name': 'Airtel Digital TV'},
    {'id': 'DISHTV',    'name': 'Dish TV'},
    {'id': 'SUNDIRECT', 'name': 'Sun Direct'},
    {'id': 'VIDEOCON',  'name': 'Videocon D2H'},
  ],
  'FASTAG': [
    {'id': 'HDFC_FASTAG',  'name': 'HDFC Bank FASTag'},
    {'id': 'ICICI_FASTAG', 'name': 'ICICI Bank FASTag'},
    {'id': 'SBI_FASTAG',   'name': 'SBI FASTag'},
    {'id': 'AXIS_FASTAG',  'name': 'Axis Bank FASTag'},
    {'id': 'PAYTM_FASTAG', 'name': 'Paytm FASTag'},
  ],
  'POSTPAID': [
    {'id': 'AIRTEL_POST', 'name': 'Airtel Postpaid'},
    {'id': 'JIO_POST',    'name': 'Jio Postpaid'},
    {'id': 'VI_POST',     'name': 'Vi (Vodafone Idea) Postpaid'},
    {'id': 'BSNL_POST',   'name': 'BSNL Postpaid'},
  ],
  'GAS': [
    {'id': 'IGL',         'name': 'Indraprastha Gas (IGL)'},
    {'id': 'MGL',         'name': 'Mahanagar Gas (MGL)'},
    {'id': 'ADANI_GAS',   'name': 'Adani Gas'},
    {'id': 'GAIL_GAS',    'name': 'GAIL Gas'},
  ],
  'WATER': [
    {'id': 'BWSSB',       'name': 'BWSSB (Bangalore)'},
    {'id': 'MCGM_WATER',  'name': 'MCGM (Mumbai)'},
    {'id': 'DJB',         'name': 'Delhi Jal Board'},
    {'id': 'HMWS',        'name': 'HMWSSB (Hyderabad)'},
  ],
  'LOAN': [
    {'id': 'HDFC_LOAN',   'name': 'HDFC Bank Loan'},
    {'id': 'SBI_LOAN',    'name': 'SBI Loan'},
    {'id': 'ICICI_LOAN',  'name': 'ICICI Bank Loan'},
    {'id': 'BAJAJ_LOAN',  'name': 'Bajaj Finserv'},
    {'id': 'TATA_CAP',    'name': 'Tata Capital'},
  ],
  'INSURANCE': [
    {'id': 'LIC',         'name': 'LIC Premium'},
    {'id': 'HDFC_LIFE',   'name': 'HDFC Life Insurance'},
    {'id': 'SBI_LIFE',    'name': 'SBI Life Insurance'},
    {'id': 'ICICI_PRU',   'name': 'ICICI Prudential'},
  ],
};
 
// ─────────────────────────────────────────────────────────────────────────────
 
enum _Step { selectCategory, selectBiller, enterDetails, reviewBill, result }
 
class BBPSPaymentScreen extends StatefulWidget {
  final String? preselectedCategory;
  final String? title;
  final String? categoryName;      // ← Add this
  final String? categoryEmoji;  
 
  const BBPSPaymentScreen({super.key, this.preselectedCategory,this.categoryEmoji, this.categoryName, this.title});
 
  @override
  State<BBPSPaymentScreen> createState() => _BBPSPaymentScreenState();
}
 
class _BBPSPaymentScreenState extends State<BBPSPaymentScreen> {
  _Step _step = _Step.selectCategory;
  bool _loading = false;
  String? _error;
  String _token = '';
  static const _base = 'http://192.168.2.151:3000';
 
  // Selections
  Map<String, dynamic>? _selectedCategory;
  Map<String, dynamic>? _selectedBiller;
 
  // Controllers
  final _consumerCtrl = TextEditingController();
  final _amountCtrl   = TextEditingController();
 
  // Bill data from backend
  Map<String, dynamic>? _fetchBillResponse; // full backend response
  String? _merchantRefId;
 
  // Pay result
  bool? _paySuccess;
  String _payMessage = '';
  String? _transactionId;
 
  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadToken();
 
    // Auto-select category if coming from grid tap
     if (widget.preselectedCategory != null) {
    // Try to find matching category
    Map<String, dynamic> match;
    
    final searchTerm = widget.preselectedCategory!.toLowerCase();
    
    // Search by ID or Name
    final found = _staticCategories.where(
      (c) => c['id']!.toLowerCase() == searchTerm ||
             c['name']!.toLowerCase().contains(searchTerm)
    ).toList();
    
    if (found.isNotEmpty) {
      match = found.first;
    } else {
      // Create custom category if not found
      match = {
        'id': widget.preselectedCategory,
        'name': widget.categoryName ?? widget.preselectedCategory,
        'icon': widget.categoryEmoji ?? '📄',
      };
    }
    
    _selectedCategory = match;
    _step = _Step.selectBiller;
  }
}
 
  @override
  void dispose() {
    _consumerCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }
 
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _token = prefs.getString('accessToken') ?? '');
  }
 
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_token',
  };
 
  // ── Fetch Bill (hits your backend → VimoPay) ───────────────────────────────
  Future<void> _onFetchBill() async {
    if (_consumerCtrl.text.trim().length < 3) {
      return _setError('Enter a valid consumer / account number');
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await LoggedHttpClient.post(
        Uri.parse('$_base/api/bbps/fetch-bill'),
        headers: _headers,
        body: jsonEncode({
          'billerId':       _selectedBiller!['id'],
          'consumerNumber': _consumerCtrl.text.trim(),
          'additionalParams': {},
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode >= 400) throw Exception(body['error'] ?? 'Fetch failed');
 
      // Store what we need for pay
      _merchantRefId      = body['merchantRefId'];
      _fetchBillResponse  = body['fetchBillResult'] as Map<String, dynamic>? ?? {};
 
      // Pre-fill amount if returned
      final amt = body['billAmount'];
      if (amt != null) _amountCtrl.text = amt.toString();
 
      setState(() => _step = _Step.reviewBill);
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }
 
  // ── Pay Bill (hits your backend → VimoPay) ─────────────────────────────────
  Future<void> _onPayNow() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return _setError('Enter a valid amount');
 
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Confirm Payment', style: TextStyle(color: Colors.white)),
        content: Text(
          'Pay ₹${amount.toStringAsFixed(2)} to ${_selectedBiller?['name']}\n'
          'Account: ${_consumerCtrl.text.trim()}',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pay Now'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
 
    setState(() { _loading = true; _error = null; });
    try {
      final res = await LoggedHttpClient.post(
        Uri.parse('$_base/api/bbps/pay-bill'),
        headers: _headers,
        body: jsonEncode({
          'merchantRefId':  _merchantRefId,
          'fetchBillResult': _fetchBillResponse ?? {},
          'amount':         amount,
        }),
      );
      final body = jsonDecode(res.body) as Map<String, dynamic>;
 
      setState(() {
        _paySuccess     = body['success'] == true;
        _payMessage     = body['message'] ?? (_paySuccess! ? 'Payment successful' : 'Payment failed');
        _transactionId  = body['transactionId']?.toString();
        _step           = _Step.result;
      });
    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }
 
  void _setError(String msg) => setState(() => _error = msg);
 
  void _reset() => setState(() {
    _step = _Step.selectCategory;
    _selectedCategory = null;
    _selectedBiller = null;
    _consumerCtrl.clear();
    _amountCtrl.clear();
    _merchantRefId = null;
    _fetchBillResponse = null;
    _paySuccess = null;
    _error = null;
  });
 
  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(widget.title ?? _selectedCategory?['name'] ?? 'Bill Payment',
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: _stepProgress(),
            backgroundColor: Colors.grey[800],
            color: const Color(0xFF2ECC71),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildBody(),
          if (_loading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
              ),
            ),
        ],
      ),
    );
  }
 
  double _stepProgress() {
    switch (_step) {
      case _Step.selectCategory: return 0.1;
      case _Step.selectBiller:   return 0.3;
      case _Step.enterDetails:   return 0.5;
      case _Step.reviewBill:     return 0.75;
      case _Step.result:         return 1.0;
    }
  }
 
  Widget _buildBody() {
    switch (_step) {
      case _Step.selectCategory: return _buildCategoryList();
      case _Step.selectBiller:   return _buildBillerList();
      case _Step.enterDetails:   return _buildEnterDetails();
      case _Step.reviewBill:     return _buildReviewBill();
      case _Step.result:         return _buildResult();
    }
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // STEP 1: Category List
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildCategoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Select Category'),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _staticCategories.length,
            itemBuilder: (_, i) {
              final cat = _staticCategories[i];
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  _selectedCategory = cat;
                  _step = _Step.selectBiller;
                }),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(cat['icon']!, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 8),
                      Text(cat['name']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2: Biller List
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBillerList() {
    final billers = _staticBillers[_selectedCategory?['id']] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Select ${_selectedCategory?['name']} Provider'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: billers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final b = billers[i];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() {
                  _selectedBiller = b;
                  _step = _Step.enterDetails;
                  _error = null;
                }),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt, color: Color(0xFF2ECC71), size: 20),
                      const SizedBox(width: 12),
                      Text(b['name']!, style: const TextStyle(color: Colors.white, fontSize: 15)),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 14),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _backButton(() => setState(() => _step = _Step.selectCategory)),
      ],
    );
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // STEP 3: Enter Consumer Details
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEnterDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Enter Account Details'),
 
          // Selected biller chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2ECC71), size: 16),
                const SizedBox(width: 6),
                Text(_selectedBiller?['name'] ?? '',
                    style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 24),
 
          // Consumer number
          TextField(
            controller: _consumerCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'Consumer / Account Number',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2ECC71)),
              ),
            ),
          ),
          const SizedBox(height: 12),
 
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
 
          const SizedBox(height: 24),
 
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: !_loading ? _onFetchBill : null,
              child: const Text('Fetch Bill', style: TextStyle(fontSize: 16, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          _backButton(() => setState(() { _step = _Step.selectBiller; _error = null; })),
        ],
      ),
    );
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // STEP 4: Review Bill & Pay
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildReviewBill() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Review & Pay'),
 
          // Bill card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: Column(
              children: [
                _row('Provider',     _selectedBiller?['name'] ?? '-'),
                _row('Account No.',  _consumerCtrl.text),
                _row('Category',     _selectedCategory?['name'] ?? '-'),
                if ((_fetchBillResponse?['billAmount']) != null)
                  _row('Bill Amount', '₹${_fetchBillResponse!['billAmount']}',
                      valueColor: Colors.red),
                if ((_fetchBillResponse?['dueDate']) != null)
                  _row('Due Date', _fetchBillResponse!['dueDate'].toString()),
                if ((_fetchBillResponse?['consumerName']) != null)
                  _row('Name', _fetchBillResponse!['consumerName'].toString()),
              ],
            ),
          ),
          const SizedBox(height: 20),
 
          // Amount input
          TextField(
            controller: _amountCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Payment Amount',
              labelStyle: const TextStyle(color: Colors.grey),
              prefixText: '₹ ',
              prefixStyle: const TextStyle(color: Colors.white, fontSize: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[700]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2ECC71)),
              ),
            ),
          ),
          const SizedBox(height: 12),
 
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
 
          const SizedBox(height: 20),
 
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: !_loading ? _onPayNow : null,
              child: const Text('Pay Now', style: TextStyle(fontSize: 18, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          _backButton(() => setState(() { _step = _Step.enterDetails; _error = null; })),
        ],
      ),
    );
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // STEP 5: Result
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildResult() {
    final success = _paySuccess ?? false;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (success ? const Color(0xFF2ECC71) : Colors.red).withOpacity(0.15),
              ),
              child: Icon(
                success ? Icons.check_circle : Icons.cancel,
                size: 60,
                color: success ? const Color(0xFF2ECC71) : Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              success ? 'Payment Successful!' : 'Payment Failed',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: success ? const Color(0xFF2ECC71) : Colors.red,
              ),
            ),
            const SizedBox(height: 12),
            Text(_payMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70)),
            if (_transactionId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Txn ID: $_transactionId',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
            if (!success) ...[
              const SizedBox(height: 8),
              const Text('Amount refunded to wallet.',
                  style: TextStyle(color: Colors.orange)),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _reset,
                child: const Text('Pay Another Bill',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
 
  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _sectionHeader(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(text,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
  );
 
  Widget _row(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.end,
              style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal)),
        ),
      ],
    ),
  );
 
  Widget _backButton(VoidCallback onTap) => TextButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.arrow_back, size: 16, color: Colors.grey),
    label: const Text('Back', style: TextStyle(color: Colors.grey)),
  );
}