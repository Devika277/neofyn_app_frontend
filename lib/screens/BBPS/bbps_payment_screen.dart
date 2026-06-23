// lib/screens/bbps_payment_screen.dart
//
// Full BBPS bill payment flow with proper FASTag support:
//   Step 1 — Select category → select biller → enter vehicle number → Fetch Bill
//   Step 2 — Review bill details (with adhoc amount support) → enter amount → Pay Now
//   Step 3 — Success / Failure screen

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import '../../services/api_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STATIC DATA — categories and billers
// ─────────────────────────────────────────────────────────────────────────────
const _staticCategories = [
  {'id': 'ELECTRICITY', 'name': 'Electricity', 'icon': '⚡'},
  {'id': 'DTH', 'name': 'DTH', 'icon': '📡'},
  {'id': 'FASTAG', 'name': 'Fastag', 'icon': '🚗'},
  {'id': 'POSTPAID', 'name': 'Postpaid Mobile', 'icon': '📱'},
  {'id': 'GAS', 'name': 'Gas', 'icon': '🔥'},
  {'id': 'WATER', 'name': 'Water', 'icon': '💧'},
  {'id': 'LOAN', 'name': 'Loan Repayment', 'icon': '🏦'},
  {'id': 'INSURANCE', 'name': 'Insurance', 'icon': '🛡️'},
];

const _staticBillers = {
  'ELECTRICITY': [
    {'id': 'BESCOM', 'name': 'BESCOM (Karnataka)'},
    {'id': 'MSEDCL', 'name': 'MSEDCL (Maharashtra)'},
    {'id': 'TNEB', 'name': 'TNEB (Tamil Nadu)'},
    {'id': 'TSSPDCL', 'name': 'TSSPDCL (Telangana)'},
    {'id': 'KSEB', 'name': 'KSEB (Kerala)'},
    {'id': 'UPPCL', 'name': 'UPPCL (Uttar Pradesh)'},
    {'id': 'WBSEDCL', 'name': 'WBSEDCL (West Bengal)'},
    {'id': 'DHBVN', 'name': 'DHBVN (Haryana)'},
  ],
  'DTH': [
    {'id': 'TATASKY', 'name': 'Tata Play (Tata Sky)'},
    {'id': 'AIRTEL_DTH', 'name': 'Airtel Digital TV'},
    {'id': 'DISHTV', 'name': 'Dish TV'},
    {'id': 'SUNDIRECT', 'name': 'Sun Direct'},
    {'id': 'VIDEOCON', 'name': 'Videocon D2H'},
  ],
  'FASTAG': [
    {'id': 'HDFC_FASTAG', 'name': 'HDFC Bank FASTag'},
    {'id': 'ICICI_FASTAG', 'name': 'ICICI Bank FASTag'},
    {'id': 'SBI_FASTAG', 'name': 'SBI FASTag'},
    {'id': 'AXIS_FASTAG', 'name': 'Axis Bank FASTag'},
    {'id': 'PAYTM_FASTAG', 'name': 'Paytm FASTag'},
  ],
  'POSTPAID': [
    {'id': 'AIRTEL_POST', 'name': 'Airtel Postpaid'},
    {'id': 'JIO_POST', 'name': 'Jio Postpaid'},
    {'id': 'VI_POST', 'name': 'Vi (Vodafone Idea) Postpaid'},
    {'id': 'BSNL_POST', 'name': 'BSNL Postpaid'},
  ],
  'GAS': [
    {'id': 'IGL', 'name': 'Indraprastha Gas (IGL)'},
    {'id': 'MGL', 'name': 'Mahanagar Gas (MGL)'},
    {'id': 'ADANI_GAS', 'name': 'Adani Gas'},
    {'id': 'GAIL_GAS', 'name': 'GAIL Gas'},
  ],
  'WATER': [
    {'id': 'BWSSB', 'name': 'BWSSB (Bangalore)'},
    {'id': 'MCGM_WATER', 'name': 'MCGM (Mumbai)'},
    {'id': 'DJB', 'name': 'Delhi Jal Board'},
    {'id': 'HMWS', 'name': 'HMWSSB (Hyderabad)'},
  ],
  'LOAN': [
    {'id': 'HDFC_LOAN', 'name': 'HDFC Bank Loan'},
    {'id': 'SBI_LOAN', 'name': 'SBI Loan'},
    {'id': 'ICICI_LOAN', 'name': 'ICICI Bank Loan'},
    {'id': 'BAJAJ_LOAN', 'name': 'Bajaj Finserv'},
    {'id': 'TATA_CAP', 'name': 'Tata Capital'},
  ],
  'INSURANCE': [
    {'id': 'LIC', 'name': 'LIC Premium'},
    {'id': 'HDFC_LIFE', 'name': 'HDFC Life Insurance'},
    {'id': 'SBI_LIFE', 'name': 'SBI Life Insurance'},
    {'id': 'ICICI_PRU', 'name': 'ICICI Prudential'},
  ],
};

// ─────────────────────────────────────────────────────────────────────────────

enum _Step { selectCategory, selectBiller, enterDetails, reviewBill, result }

class BBPSPaymentScreen extends StatefulWidget {
  final String? preselectedCategory;
  final String? title;
  final String? categoryName;
  final String? categoryEmoji;

  const BBPSPaymentScreen({
    super.key,
    this.preselectedCategory,
    this.categoryEmoji,
    this.categoryName,
    this.title,
  });

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
  List<Map<String, dynamic>> _billers = [];

  // FASTag specific variables
  bool _billerAcceptsAdhoc = false;
  double _adhocMinLimit = 0;
  double _adhocMaxLimit = 0;
  List<Map<String, dynamic>> _requiredParams = [];
  String _paymentAmountExactness = '';
  double _fetchedBillAmount = 0;
  String _customerName = '';
  String _availableBalance = '';

  // Controllers
  final _consumerCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  // Bill data from backend
  Map<String, dynamic>? _fetchBillResponse;
  String? _merchantRefId;
  int? _transactionId;

  // Pay result
  bool? _paySuccess;
  String _payMessage = '';
  String? _txnId;

  // Location
  Position? _currentPosition;
  bool _locationLoading = false;

  // Balance
  double _walletBalance = 0;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadToken();
    _fetchWalletBalance();
    _getCurrentLocation();

    // Auto-select category if coming from grid tap
    if (widget.preselectedCategory != null) {
      Map<String, dynamic> match;

      final searchTerm = widget.preselectedCategory!.toLowerCase();

      final found = _staticCategories.where(
              (c) => c['id']!.toLowerCase() == searchTerm ||
              c['name']!.toLowerCase().contains(searchTerm)
      ).toList();

      if (found.isNotEmpty) {
        match = found.first;
        _billers = List<Map<String, dynamic>>.from(
            _staticBillers[match['id']] ?? []
        );
      } else {
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

  Future<void> _fetchWalletBalance() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/api/wallet/balance'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        setState(() => _walletBalance = (body['balance'] ?? 0).toDouble());
      }
    } catch (e) {
      print('Error fetching wallet balance: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _locationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = position;
        _locationLoading = false;
      });
    } catch (e) {
      print('Location error: $e');
      setState(() => _locationLoading = false);
    }
  }

  // ── Handle Biller Selection ───────────────────────────────────────────────
  Future<void> _onBillerSelected(Map<String, dynamic> biller) async {
    setState(() {
      _selectedBiller = biller;
      _loading = true;
      _error = null;
      _requiredParams = [];
      _billerAcceptsAdhoc = false;
      _adhocMinLimit = 0;
      _adhocMaxLimit = 0;
      _paymentAmountExactness = '';
      _fetchedBillAmount = 0;
    });

    try {
      // Fetch biller details from API
      final res = await LoggedHttpClient.post(
        Uri.parse('$_base/api/bbps/billerDetails'),
        headers: _headers,
        body: jsonEncode({
          'billerCategoryCode': _selectedCategory!['id'],
          'billerCode': biller['id'],
        }),
      );

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;

          setState(() {
            // Check if biller accepts adhoc payments (FASTag)
            _billerAcceptsAdhoc = data['billerAcceptsAdhoc'] == true;

            // Get payment mode limits
            if (data['PaymentModeList'] != null &&
                (data['PaymentModeList'] as List).isNotEmpty) {
              final paymentMode = (data['PaymentModeList'] as List).first;
              _adhocMinLimit = 100.0; // Force minimum to 100
              _adhocMaxLimit = double.tryParse(
                  paymentMode['maxLimit']?.toString() ?? '0'
              ) ?? 0;
            }

            // Get required parameters
            if (data['customerParam'] != null) {
              _requiredParams = List<Map<String, dynamic>>.from(
                  data['customerParam']
              );
            }
          });
        }
      }

      setState(() => _step = _Step.enterDetails);
    } catch (e) {
      _setError('Failed to load biller details: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Fetch Bill (with FASTag support) ─────────────────────────────────────
  Future<void> _onFetchBill() async {
    // Validate required params
    if (_selectedCategory!['id'] == 'FASTAG') {
      final vehicleNumber = _consumerCtrl.text.trim();
      if (vehicleNumber.length < 5) {
        return _setError('Enter a valid vehicle registration number (e.g., MH01AB1234)');
      }
    } else {
      if (_consumerCtrl.text.trim().length < 3) {
        return _setError('Enter a valid consumer / account number');
      }
    }

    setState(() { _loading = true; _error = null; });

    try {
      // Build customer params
      final customerParams = <Map<String, String>>[];
      if (_requiredParams.isNotEmpty) {
        customerParams.add({
          'key': _requiredParams[0]['paramName'] ?? 'consumerNumber',
          'value': _consumerCtrl.text.trim(),
        });
      }

      final res = await LoggedHttpClient.post(
        Uri.parse('$_base/api/payments'),
        headers: _headers,
        body: jsonEncode({
          'step': 'fetch',
          'serviceType': _selectedCategory!['name'],
          'customerId': _consumerCtrl.text.trim(),
          'additionalData': {
            'billerId': _selectedBiller!['id'],
            'provider': _selectedBiller!['name'],
            'customerParams': customerParams,
            'lat': _currentPosition?.latitude.toString() ?? '0.0',
            'long': _currentPosition?.longitude.toString() ?? '0.0',
          },
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode >= 400 || body['success'] != true) {
        throw Exception(body['message'] ?? 'Fetch failed');
      }

      final data = body['data'] as Map<String, dynamic>?;
      _transactionId = data?['transactionId'] as int?;

      final fetchBillResult = data?['fetchBillResult'] as Map<String, dynamic>?;

      if (fetchBillResult == null) {
        throw Exception('No bill details returned');
      }

      // Store bill data
      _merchantRefId = _transactionId?.toString();
      _fetchBillResponse = fetchBillResult;

      // Extract payment details
      final exactness = fetchBillResult['paymentAmountExactness']?.toString() ?? '';
      final fetchedAmount = double.tryParse(
          fetchBillResult['amount']?.toString() ?? '0'
      ) ?? 0;

      setState(() {
        _paymentAmountExactness = exactness;
        _fetchedBillAmount = fetchedAmount;

        // Extract customer name and available balance
        _customerName = fetchBillResult['customerName']?.toString() ?? '';

        if (fetchBillResult['additionalParam'] != null) {
          final additionalParams = fetchBillResult['additionalParam'] as List;
          for (final param in additionalParams) {
            if (param['key'] == 'Available Balance' ||
                param['key'] == 'Wallet Balance') {
              _availableBalance = param['value']?.toString() ?? '';
            }
          }
        }
      });

      // Handle zero/negative bill amount for non-adhoc billers
      if (fetchedAmount <= 0 && exactness.isNotEmpty && !_billerAcceptsAdhoc) {
        setState(() {
          _paySuccess = false;
          _payMessage = fetchBillResult['responseMessage']?.toString() ??
              'No bill due for this consumer number. Cannot proceed with payment.';
          _step = _Step.result;
        });
        return;
      }

      // Set amount based on exactness
      if (exactness == 'Exact') {
        _amountCtrl.text = fetchedAmount.toString();
      } else if (exactness == 'Exact and above') {
        _adhocMinLimit = fetchedAmount;
        _amountCtrl.clear();
      } else if (_billerAcceptsAdhoc) {
        _amountCtrl.clear();
      }

      setState(() => _step = _Step.reviewBill);

    } catch (e) {
      _setError(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  // ── Pay Bill (with FASTag amount validation) ─────────────────────────────
  Future<void> _onPayNow() async {
    final amount = double.tryParse(_amountCtrl.text.trim());

    // Validate amount
    if (amount == null || amount <= 0) {
      return _setError('Enter a valid amount');
    }

    // Amount validation based on exactness
    if (_paymentAmountExactness == 'Exact') {
      if (amount != _fetchedBillAmount) {
        return _setError('Amount must be exactly ₹${_fetchedBillAmount}');
      }
    } else if (_paymentAmountExactness == 'Exact and above') {
      if (amount < _fetchedBillAmount) {
        return _setError('Amount cannot be less than ₹$_fetchedBillAmount');
      }
    } else if (_billerAcceptsAdhoc) {
      if (_adhocMinLimit > 0 && amount < _adhocMinLimit) {
        return _setError('Minimum amount is ₹$_adhocMinLimit');
      }
      if (_adhocMaxLimit > 0 && amount > _adhocMaxLimit) {
        return _setError('Maximum amount is ₹$_adhocMaxLimit');
      }
    }

    // Check wallet balance
    if (amount > _walletBalance) {
      return _setError('Insufficient wallet balance');
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Confirm Payment',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_customerName.isNotEmpty)
              _buildConfirmationRow('Name', _customerName),
            _buildConfirmationRow('Provider', _selectedBiller?['name'] ?? ''),
            _buildConfirmationRow('Vehicle/Account', _consumerCtrl.text),
            if (_selectedCategory!['id'] == 'FASTAG' && _availableBalance.isNotEmpty)
              _buildConfirmationRow('Available Balance', '₹$_availableBalance'),
            const SizedBox(height: 8),
            _buildConfirmationRow('Amount', '₹${amount.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2ECC71),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pay Now', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() { _loading = true; _error = null; });

    try {
      final res = await LoggedHttpClient.post(
        Uri.parse('$_base/api/payments'),
        headers: _headers,
        body: jsonEncode({
          'step': 'pay',
          'serviceType': _selectedCategory!['name'],
          'customerId': _consumerCtrl.text.trim(),
          'transactionId': _transactionId,
          'amount': amount,
          'additionalData': {
            'provider': _selectedBiller?['name'],
            'lat': _currentPosition?.latitude.toString() ?? '0.0',
            'long': _currentPosition?.longitude.toString() ?? '0.0',
          },
        }),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      setState(() {
        _paySuccess = body['success'] == true;
        _payMessage = body['message'] ??
            (_paySuccess! ? 'Payment successful' : 'Payment failed');
        _txnId = body['data']?['transactionId']?.toString();
        _step = _Step.result;
      });

      // Refresh wallet balance
      if (_paySuccess == true) {
        _fetchWalletBalance();
      }

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
    _billers = [];
    _consumerCtrl.clear();
    _amountCtrl.clear();
    _merchantRefId = null;
    _fetchBillResponse = null;
    _transactionId = null;
    _paySuccess = null;
    _error = null;
    _billerAcceptsAdhoc = false;
    _adhocMinLimit = 0;
    _adhocMaxLimit = 0;
    _requiredParams = [];
    _paymentAmountExactness = '';
    _fetchedBillAmount = 0;
    _customerName = '';
    _availableBalance = '';
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
        title: Text(
          widget.title ?? _selectedCategory?['name'] ?? 'Bill Payment',
          style: const TextStyle(color: Colors.white),
        ),
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
        // Wallet balance card
        _buildWalletBalanceCard(),
        _sectionHeader('Select Service Category'),
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
                  _billers = List<Map<String, dynamic>>.from(
                      _staticBillers[cat['id']] ?? []
                  );
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
                      Text(
                        cat['name']!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
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

  Widget _buildWalletBalanceCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E5FBB), Color(0xFF114186)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2ECC71).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Wallet Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text('₹ ${_walletBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  )),
            ],
          ),
          const Spacer(),
          if (_locationLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          else
            const Icon(Icons.location_on, color: Colors.white54, size: 20),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 2: Biller List
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBillerList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWalletBalanceCard(),
        _sectionHeader('Select ${_selectedCategory?['name']} Provider'),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _billers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final b = _billers[i];
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _onBillerSelected(b),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[800]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedCategory?['id'] == 'FASTAG'
                            ? Icons.directions_car
                            : Icons.bolt,
                        color: const Color(0xFF2ECC71),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          b['name']!,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ),
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
  // STEP 3: Enter Consumer Details (with FASTag specific fields)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEnterDetails() {
    final isFastag = _selectedCategory?['id'] == 'FASTAG';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(isFastag ? 'Enter Vehicle Details' : 'Enter Account Details'),

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
                Text(
                  _selectedBiller?['name'] ?? '',
                  style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // FASTag specific info
          if (isFastag) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enter your vehicle registration number to recharge your FASTag',
                      style: TextStyle(color: Colors.blue[200], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Consumer/Vehicle number input
          TextField(
            controller: _consumerCtrl,
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: isFastag ? 'Vehicle Registration Number' : 'Consumer / Account Number',
              hintText: isFastag ? 'e.g., MH01AB1234' : 'Enter your account number',
              hintStyle: TextStyle(color: Colors.grey[600]),
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: Icon(
                isFastag ? Icons.directions_car : Icons.person_outline,
                color: Colors.grey,
              ),
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

          // Dynamic parameters from biller
          ..._requiredParams.map((param) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: param['paramName'] ?? 'Additional Info',
                hintText: param['description'] ?? '',
                hintStyle: TextStyle(color: Colors.grey[600]),
                labelStyle: const TextStyle(color: Colors.grey),
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
          )),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),

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
              child: const Text(
                'Fetch Bill',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _backButton(() => setState(() {
            _step = _Step.selectBiller;
            _error = null;
          })),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP 4: Review Bill & Pay (with FASTag amount support)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildReviewBill() {
    final isFastag = _selectedCategory?['id'] == 'FASTAG';
    final showAmountInput = _paymentAmountExactness != 'Exact';

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
                if (_customerName.isNotEmpty)
                  _row('Customer Name', _customerName),
                _row('Provider', _selectedBiller?['name'] ?? '-'),
                _row(isFastag ? 'Vehicle Number' : 'Account No.',
                    _consumerCtrl.text),
                _row('Category', _selectedCategory?['name'] ?? '-'),
                if (_availableBalance.isNotEmpty)
                  _row('Available Balance', '₹$_availableBalance'),
                if (_fetchedBillAmount > 0)
                  _row('Bill Amount', '₹$_fetchedBillAmount',
                      valueColor: Colors.orange),
                if (_fetchBillResponse?['dueDate'] != null)
                  _row('Due Date', _fetchBillResponse!['dueDate'].toString()),
                if (_billerAcceptsAdhoc)
                  _row('Payment Type', 'Flexible Amount',
                      valueColor: const Color(0xFF2ECC71)),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Amount input
          if (showAmountInput) ...[
            TextField(
              controller: _amountCtrl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Payment Amount',
                labelStyle: const TextStyle(color: Colors.grey),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: Colors.white, fontSize: 20),
                helperText: _getAmountHelperText(),
                helperStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
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
          ] else ...[
            // Fixed amount display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text('Fixed Payment Amount',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('₹ ${_fetchedBillAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF2ECC71),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      )),
                ],
              ),
            ),
          ],
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
              child: const Text(
                'Pay Now',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _backButton(() => setState(() {
            _step = _Step.enterDetails;
            _error = null;
          })),
        ],
      ),
    );
  }

  String _getAmountHelperText() {
    if (_paymentAmountExactness == 'Exact and above') {
      return 'Minimum amount: ₹$_fetchedBillAmount';
    } else if (_billerAcceptsAdhoc) {
      String text = '';
      if (_adhocMinLimit > 0) text += 'Min: ₹$_adhocMinLimit';
      if (_adhocMaxLimit > 0) text += '  Max: ₹$_adhocMaxLimit';
      return text.isNotEmpty ? text : 'Enter recharge amount';
    }
    return 'Enter payment amount';
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
                color: (success ? const Color(0xFF2ECC71) : Colors.red)
                    .withOpacity(0.15),
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
            Text(
              _payMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            if (_txnId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Txn ID: $_txnId',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
            if (!success) ...[
              const SizedBox(height: 8),
              const Text(
                'Amount will be refunded to your wallet.',
                style: TextStyle(color: Colors.orange),
              ),
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
                child: const Text(
                  'Pay Another Bill',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildConfirmationRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    ),
  );

  Widget _backButton(VoidCallback onTap) => TextButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.arrow_back, size: 16, color: Colors.grey),
    label: const Text('Back', style: TextStyle(color: Colors.grey)),
  );
}