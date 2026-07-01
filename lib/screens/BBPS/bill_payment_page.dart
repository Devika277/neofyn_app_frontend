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

  // ────────────────────────────────────────────────────────────────────────────
  //  SEARCHABLE BOTTOM SHEET DROPDOWN
  // ────────────────────────────────────────────────────────────────────────────

  void _showSearchableDropdown<T>({
    required String title,
    required List<T> items,
    required String Function(T) displayName,
    required String Function(T) subtitle,
    required void Function(T) onSelected,
    required IconData icon,
    bool isLoading = false,
  }) {
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = searchController.text.toLowerCase();
            final filteredItems = query.isEmpty
                ? items
                : items.where((item) {
              final name = displayName(item).toLowerCase();
              final sub = subtitle(item).toLowerCase();
              return name.contains(query) || sub.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: const BoxDecoration(
                color: Color(0xFF151915),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        Icon(icon, color: AppColors.primaryLight, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setSheetState(() {}),
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search biller...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.3), size: 18),
                        suffixIcon: query.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.3), size: 16),
                          onPressed: () {
                            searchController.clear();
                            setSheetState(() {});
                          },
                        )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Results Count
                  if (!isLoading)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.list, size: 14, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(width: 6),
                          Text(
                            '${filteredItems.length} billers available',
                            style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                          ),
                        ],
                      ),
                    ),
                  // List
                  Expanded(
                    child: isLoading
                        ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryLight,
                        strokeWidth: 2,
                      ),
                    )
                        : filteredItems.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                            child: Icon(Icons.search_off, size: 36, color: Colors.white.withOpacity(0.2)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No billers found',
                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                      itemCount: filteredItems.length,
                      itemBuilder: (_, index) {
                        final item = filteredItems[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                            leading: Container(
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
                              child: Icon(icon, size: 16, color: AppColors.primaryLight),
                            ),
                            title: Text(
                              displayName(item),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: subtitle(item).isNotEmpty
                                ? Text(
                              subtitle(item),
                              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                            )
                                : null,
                            trailing: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              child: const Icon(Icons.add, color: AppColors.primaryLight, size: 14),
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            onTap: () {
                              onSelected(item);
                              Navigator.pop(sheetContext);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  //  DROPDOWN SELECTOR (Used in inner screen)
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildDropdownSelector({
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    String? selectedText,
    String? selectedSubtext,
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white60,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selectedText != null
                      ? AppColors.primary.withOpacity(0.4)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                    child: Icon(icon, size: 16, color: AppColors.primaryLight),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedText ?? hint,
                          style: TextStyle(
                            fontSize: 13,
                            color: selectedText != null ? Colors.white : Colors.white38,
                            fontWeight: selectedText != null ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (selectedSubtext != null && selectedSubtext.isNotEmpty)
                          Text(
                            selectedSubtext,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.4),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryLight,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withOpacity(0.5),
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildParameterFields(BillerDetails? details) {
    if (details == null) return const [];

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

              // Result screens
              if (provider.payBillResponse != null) return _buildPaymentResult(provider);
              if (provider.fetchBillResponse != null && provider.payBillResponse == null) {
                return _buildFetchedBill(provider);
              }

              // STEP 1: Show category grid (Like Google Pay home)
              if (provider.selectedCategory == null) {
                return _buildCategoryGrid(provider);
              }

              // STEP 2: Inner screen with dropdown and form
              return _buildInnerScreen(provider);
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STEP 1: CATEGORY GRID (Like Google Pay Home Screen)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCategoryGrid(BBPSProvider provider) {
    final categories = provider.categories;

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
              child: Icon(Icons.category_outlined, size: 36, color: Colors.white.withOpacity(0.3)),
            ),
            const SizedBox(height: 12),
            const Text('No categories available', style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 12),
            _buildRetryButton(() => provider.loadBillCategories()),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context); // Go back to previous screen
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back, size: 18, color: Colors.white54),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.3), AppColors.primaryLight.withOpacity(0.15)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.electrical_services, color: AppColors.primaryLight, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pay Bills',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bharat Bill Payment System',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 12, color: AppColors.success),
                    SizedBox(width: 4),
                    Text(
                      'Secure',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Category Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            physics: const BouncingScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: categories.length,
            itemBuilder: (_, index) {
              final cat = categories[index];
              return _buildCategoryCard(cat, provider);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(dynamic cat, BBPSProvider provider) {
    final icon = _getCategoryIcon(cat.name ?? '');
    final colors = _getCategoryColors(cat.name ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.mediumImpact();
          provider.selectCategory(cat);
          provider.loadBillersForCategory(cat.code);
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors[0].withOpacity(0.15),
                colors[1].withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors[0].withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colors[0].withOpacity(0.3), colors[1].withOpacity(0.2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors[0].withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, size: 24, color: colors[1]),
              ),
              const SizedBox(height: 10),
              Text(
                cat.name ?? '',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
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
  //  STEP 2: INNER SCREEN (Dropdown + Form)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInnerScreen(BBPSProvider provider) {
    return Column(
      children: [
        // Header with back button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  provider.selectCategory(null);
                  provider.selectBiller(null);
                  _paramControllers.clear();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white54),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withOpacity(0.2), AppColors.primaryLight.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(provider.selectedCategory?.name ?? ''),
                  color: AppColors.primaryLight,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  provider.selectedCategory?.name ?? 'Pay Bill',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(14),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Biller Dropdown
                  _buildDropdownSelector(
                    label: 'Select Biller',
                    hint: 'Choose your biller',
                    icon: Icons.business,
                    selectedText: provider.selectedBiller?.billerName,
                    selectedSubtext: provider.selectedBiller?.billerCode,
                    isLoading: provider.billersLoading,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _showSearchableDropdown(
                        title: 'Select Biller',
                        items: provider.billers,
                        displayName: (b) => b.billerName ?? '',
                        subtitle: (b) => b.billerCode ?? '',
                        icon: Icons.business,
                        isLoading: provider.billersLoading,
                        onSelected: (biller) {
                          provider.selectBiller(biller);
                          provider.loadBillerDetails(
                            provider.selectedCategory!.code,
                            biller.billerCode,
                          );
                          _paramControllers.clear();
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Details Form (shows after biller selected)
                  if (provider.selectedBiller != null) ...[
                    if (provider.billerDetailsLoading)
                      Column(
                        children: List.generate(3, (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.06)),
                            ),
                          ),
                        )),
                      )
                    else if (provider.billerDetails != null) ...[
                      ..._buildParameterFields(provider.billerDetails),
                      const SizedBox(height: 16),
                      _buildGradientButton(
                        label: 'Fetch Bill',
                        isLoading: provider.fetchBillLoading,
                        onPressed: provider.fetchBillLoading ? null : _fetchBill,
                      ),
                    ] else ...[
                      _buildEmptyState('No details required for this biller'),
                    ],
                  ] else ...[
                    // Show placeholder when no biller selected
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                              ),
                              child: Icon(
                                Icons.touch_app_outlined,
                                size: 40,
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select a biller to continue',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap on the dropdown above to choose',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (provider.paymentError != null && provider.fetchBillResponse == null) ...[
                    const SizedBox(height: 10),
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
  //  STEP 3: COMPACT FETCHED BILL
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
              _buildRetryButton(() {
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
                Container(
                  padding: const EdgeInsets.all(16),
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
        _buildBottomBar(
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
  //  STEP 4: COMPACT RESULT
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
  //  REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGradientButton({
    required String label,
    bool isLoading = false,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 44,
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
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildRetryButton(VoidCallback onPressed) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white70,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildBottomBar({
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
                  width: 16,
                  height: 16,
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

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
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
      case 'broadband':
      case 'postpaid': return Icons.wifi;
      case 'insurance': return Icons.shield;
      case 'education': return Icons.school;
      case 'housing': return Icons.home;
      case 'recharge': return Icons.phone_android;
      default: return Icons.receipt_long;
    }
  }

  List<Color> _getCategoryColors(String name) {
    switch (name.toLowerCase()) {
      case 'electricity': return [const Color(0xFFFFB300), const Color(0xFFFF8F00)];
      case 'water': return [const Color(0xFF29B6F6), const Color(0xFF0288D1)];
      case 'gas': return [const Color(0xFFEF5350), const Color(0xFFC62828)];
      case 'broadband':
      case 'postpaid': return [const Color(0xFF66BB6A), const Color(0xFF2E7D32)];
      case 'insurance': return [const Color(0xFFAB47BC), const Color(0xFF6A1B9A)];
      case 'education': return [const Color(0xFFFF7043), const Color(0xFFD84315)];
      case 'housing': return [const Color(0xFF8D6E63), const Color(0xFF4E342E)];
      case 'recharge': return [const Color(0xFF42A5F5), const Color(0xFF1565C0)];
      default: return [AppColors.primary, AppColors.primaryLight];
    }
  }
}