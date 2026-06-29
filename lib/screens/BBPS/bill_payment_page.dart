import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/bbps_provider.dart';
import '../../models/bbps_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN FIN TECH BRAND TOKENS
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color inputBg = Color(0xFF1A1F1A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF008169);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class BillPaymentScreen extends StatefulWidget {
  const BillPaymentScreen({Key? key}) : super(key: key);

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _paramControllers = {};
  final _amountController = TextEditingController();
  String? _fetchedCustomerId;

  @override
  void initState() {
    super.initState();
    final provider = context.read<BBPSProvider>();
    provider.loadBillCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (var c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _darkInputDecoration({
    required String hintText,
    String? labelText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      labelStyle: TextStyle(color: Colors.white54, fontSize: 11),
      hintStyle: TextStyle(color: Colors.white24, fontSize: 13),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: AppColors.primary.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.error, width: 1),
      ),
      prefixIcon: prefixIcon,
    );
  }

  List<Widget> _buildParameterFields(BillerDetails details) {
    final customerParams = (details['customerParam'] as List<dynamic>?) ?? [];
    if (customerParams.isEmpty) return const [];

    return customerParams.map<Widget>((param) {
      final p = param as Map<String, dynamic>;
      final paramName = (p['paramName'] ?? '').toString();
      final fieldLabel = (p['displayName'] ?? paramName).toString();
      final isOptional = p['optional'] == true;

      if (paramName.isEmpty) return const SizedBox.shrink();

      if (!_paramControllers.containsKey(paramName)) {
        _paramControllers[paramName] = TextEditingController();
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: _paramControllers[paramName],
          style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: _darkInputDecoration(
            hintText: 'Enter $fieldLabel',
            labelText: '$fieldLabel ${isOptional ? '(opt)' : '*'}',
            prefixIcon: Icon(
              paramName.toLowerCase().contains('mobile') ||
                  paramName.toLowerCase().contains('phone')
                  ? Icons.phone_android
                  : Icons.edit,
              size: 16,
              color: Colors.white30,
            ),
          ),
          keyboardType: paramName.toLowerCase().contains('mobile') ||
              paramName.toLowerCase().contains('phone')
              ? TextInputType.phone
              : TextInputType.text,
          validator: isOptional ? null : (v) => v!.isEmpty ? 'Required' : null,
        ),
      );
    }).toList();
  }

  void _fetchBill() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<BBPSProvider>();
    final biller = provider.selectedBiller!;
    final details = provider.billerDetails;

    final List<Map<String, String>> customerParams = [];
    String? customerId;

    if (details != null) {
      final customerParamDefs = (details['customerParam'] as List<dynamic>?) ?? [];
      for (var p in customerParamDefs) {
        final paramName = (p['paramName'] ?? '').toString();
        final isOptional = p['optional'] == true;
        if (paramName.isNotEmpty && _paramControllers.containsKey(paramName)) {
          final value = _paramControllers[paramName]!.text.trim();
          if (value.isNotEmpty) {
            customerParams.add({'key': paramName, 'value': value});
            if (!isOptional && customerId == null) customerId = value;
          }
        }
      }
    }

    if (customerParams.isEmpty || customerId == null || customerId!.isEmpty) {
      _showSnackBar('Please fill all required fields', error: true);
      return;
    }

    _fetchedCustomerId = customerId;
    _amountController.clear();

    provider.fetchBill(
      serviceType: biller.billerCode,
      customerId: customerId!,
      additionalData: {
        'billerId': biller.billerCode,
        'billerCategoryCode': biller.billerCategoryCode ?? provider.selectedCategory?.code,
        'customerParams': customerParams,
      },
    );
  }

  void _payBill() {
    final provider = context.read<BBPSProvider>();
    final fetchResult = provider.fetchBillResponse;
    if (fetchResult?.transactionId == null) return;

    double? amount;
    if (fetchResult!.fetchBillResult?.amount != null) {
      amount = fetchResult.fetchBillResult!.amount;
    } else {
      if (_amountController.text.isEmpty) {
        _showSnackBar('Please enter amount', error: true);
        return;
      }
      amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        _showSnackBar('Invalid amount', error: true);
        return;
      }
    }

    provider.payBill(
      transactionId: fetchResult.transactionId!,
      serviceType: provider.selectedBiller?.billerCode,
      customerId: _fetchedCustomerId ??
          fetchResult.fetchBillResult?.raw['customerId']?.toString() ?? '',
      amount: amount,
      additionalData: {'billerId': provider.selectedBiller?.billerCode},
    );
  }

  void _showSnackBar(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 12)),
        backgroundColor: error ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E0A),
              Color(0xFF0F1A0F),
              Color(0xFF0A0E0A),
              Color(0xFF050805),
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<BBPSProvider>(
            builder: (context, provider, _) {
              if (provider.categoriesLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryLight,
                    strokeWidth: 2,
                  ),
                );
              }

              if (provider.selectedCategory == null) return _buildCategoryStep(provider);
              if (provider.selectedBiller == null) return _buildBillerStep(provider);
              if (provider.fetchBillResponse == null && provider.payBillResponse == null) {
                return _buildDetailsStep(provider);
              }
              if (provider.fetchBillResponse != null && provider.payBillResponse == null) {
                return _buildFetchedBill(provider);
              }
              if (provider.payBillResponse != null) return _buildPaymentResult(provider);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 1: COMPACT CATEGORY GRID
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCategoryStep(BBPSProvider provider) {
    if (provider.categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined, size: 36, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 10),
            const Text('No categories', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 10),
            _buildCompactButton('Retry', Icons.refresh, () => provider.loadBillCategories()),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Compact header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(
            children: [
              Icon(Icons.grid_view, color: AppColors.primaryLight, size: 16),
              const SizedBox(width: 6),
              const Text(
                'Select Category',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
        // Compact grid - 3 columns, small cards
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.95,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: provider.categories.length,
            itemBuilder: (_, index) {
              final cat = provider.categories[index];
              return _buildCategoryCard(cat, provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(dynamic cat, BBPSProvider provider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          HapticFeedback.selectionClick();
          provider.selectCategory(cat);
          provider.loadBillersForCategory(cat.code);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.2),
                      AppColors.primaryLight.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Icon(
                  _getCategoryIcon(cat.name),
                  size: 20,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cat.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 2: COMPACT BILLER LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBillerStep(BBPSProvider provider) {
    return Column(
      children: [
        _buildCompactHeader(
          title: provider.selectedCategory?.name ?? 'Billers',
          onBack: () => provider.selectCategory(null),
        ),
        if (provider.billersLoading)
          const Expanded(
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2),
            ),
          )
        else if (provider.billers.isEmpty)
          const Expanded(
            child: Center(
              child: Text('No billers found', style: TextStyle(color: Colors.white54, fontSize: 13)),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
              itemCount: provider.billers.length,
              itemBuilder: (_, i) => _buildBillerTile(provider.billers[i], provider),
            ),
          ),
      ],
    );
  }

  Widget _buildBillerTile(dynamic biller, BBPSProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primary.withOpacity(0.2), AppColors.primaryLight.withOpacity(0.1)],
            ),
          ),
          child: const Icon(Icons.receipt_long, size: 18, color: AppColors.primaryLight),
        ),
        title: Text(
          biller.billerName,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
        ),
        subtitle: Text(
          biller.billerCode,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
        ),
        trailing: Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          HapticFeedback.selectionClick();
          provider.selectBiller(biller);
          provider.loadBillerDetails(provider.selectedCategory!.code, biller.billerCode);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 3: COMPACT DETAILS FORM
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDetailsStep(BBPSProvider provider) {
    final biller = provider.selectedBiller!;
    final details = provider.billerDetails;

    return Column(
      children: [
        _buildCompactHeader(
          title: biller.billerName,
          onBack: () => provider.selectBiller(null),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(14),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (provider.billerDetailsLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2),
                      ),
                    )
                  else if (details == null)
                    _buildInfoChip('No details available', AppColors.warning)
                  else ...[
                      const Text(
                        'Enter billing details',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      ..._buildParameterFields(details),
                      const SizedBox(height: 16),
                      _buildGradientButton(
                        label: 'Fetch Bill',
                        isLoading: provider.fetchBillLoading,
                        onPressed: provider.fetchBillLoading ? null : _fetchBill,
                      ),
                    ],
                  if (provider.paymentError != null) ...[
                    const SizedBox(height: 8),
                    _buildErrorChip(provider.paymentError!),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 4: COMPACT FETCHED BILL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFetchedBill(BBPSProvider provider) {
    final bill = provider.fetchBillResponse!.fetchBillResult;
    final txnStatus = bill?.raw['txnStatus']?.toString() ?? '';
    final txnStatusCode = bill?.raw['txnStatusCode']?.toString() ?? '';
    final responseMessage = bill?.raw['responseMessage']?.toString() ?? '';

    if (txnStatus.toUpperCase() == 'FAILED' || txnStatusCode == '001') {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withOpacity(0.15),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: const Icon(Icons.error_outline, size: 32, color: AppColors.error),
              ),
              const SizedBox(height: 12),
              Text(
                responseMessage.isNotEmpty ? responseMessage : 'Bill fetch failed',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              _buildCompactButton('Try Again', Icons.refresh, () {
                provider.resetBillPaymentFlow();
                _paramControllers.clear();
                _amountController.clear();
                _fetchedCustomerId = null;
              }),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Compact bill card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.receipt_long, size: 18, color: AppColors.primaryLight),
                          const SizedBox(width: 6),
                          const Text(
                            'Bill Details',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (bill?.customerName != null && bill!.customerName!.isNotEmpty)
                        _compactInfoRow('Name', bill.customerName!),
                      if (bill?.amount != null) ...[
                        _compactInfoRow('Amount', '₹${bill!.amount!.toStringAsFixed(2)}'),
                      ] else ...[
                        const Text(
                          'Recharge amount',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white70),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _amountController,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: _darkInputDecoration(
                            hintText: 'Enter amount',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.only(left: 12, top: 11),
                              child: Text('₹', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white70)),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      if (bill?.dueDate != null) _compactInfoRow('Due', bill!.dueDate.toString()),
                      if (bill?.raw['billNumber'] != null)
                        _compactInfoRow('Bill No', bill!.raw['billNumber'].toString()),
                    ],
                  ),
                ),
                if (provider.paymentError != null) ...[
                  const SizedBox(height: 8),
                  _buildErrorChip(provider.paymentError!),
                ],
              ],
            ),
          ),
        ),
        // Compact bottom bar
        _buildCompactBottomBar(
          primaryLabel: 'Pay Now',
          primaryLoading: provider.payBillLoading,
          onPrimaryPressed: provider.payBillLoading ? null : _payBill,
          onSecondaryPressed: () {
            provider.resetBillPaymentFlow();
            _paramControllers.clear();
            _amountController.clear();
            _fetchedCustomerId = null;
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 5: COMPACT RESULT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPaymentResult(BBPSProvider provider) {
    final result = provider.payBillResponse!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (result.success ? AppColors.success : AppColors.error).withOpacity(0.15),
                border: Border.all(
                  color: (result.success ? AppColors.success : AppColors.error).withOpacity(0.3),
                ),
              ),
              child: Icon(
                result.success ? Icons.check_circle : Icons.error,
                size: 44,
                color: result.success ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              result.message,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
              textAlign: TextAlign.center,
            ),
            if (result.refunded) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Text(
                  'Amount refunded',
                  style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500),
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buildGradientButton(
              label: 'Make Another Payment',
              onPressed: () {
                provider.resetBillPaymentFlow();
                _paramControllers.clear();
              },
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  COMPACT REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCompactHeader({required String title, required VoidCallback onBack}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onBack();
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white54),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String label,
    bool isLoading = false,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCompactButton(String label, IconData icon, VoidCallback onPressed) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBottomBar({
    required String primaryLabel,
    bool primaryLoading = false,
    VoidCallback? onPrimaryPressed,
    required VoidCallback onSecondaryPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A0F),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            offset: const Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: OutlinedButton(
                onPressed: onSecondaryPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: BorderSide(color: Colors.white.withOpacity(0.15)),
                  padding: EdgeInsets.zero,
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                onPressed: onPrimaryPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: EdgeInsets.zero,
                ),
                child: primaryLoading
                    ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : Text(
                  primaryLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 55,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String message, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: color),
          const SizedBox(width: 6),
          Text(message, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildErrorChip(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'electricity': return Icons.flash_on;
      case 'water': return Icons.water_drop;
      case 'gas': return Icons.local_fire_department;
      case 'broadband': case 'postpaid': return Icons.wifi;
      case 'insurance': return Icons.shield;
      case 'education': return Icons.school;
      case 'housing': return Icons.home;
      case 'recharge': return Icons.phone_android;
      default: return Icons.receipt_long;
    }
  }
}