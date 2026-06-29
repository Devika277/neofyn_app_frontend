import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:my_app/models/recharge_models.dart';
import 'package:my_app/providers/recharge_provider.dart';
import 'package:my_app/screens/recharge/transaction_status_screen.dart';
import 'package:my_app/services/recharges/recharge_service.dart';

// ─── NEOFYN BRAND COLORS ──────────────────────────────────
class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);
  static const Color textDarkHint = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color borderDark = Color(0xFF2A342A);
  static const Color borderFocus = Color(0xFF008169);
}

class RechargePage extends ConsumerStatefulWidget {
  const RechargePage({Key? key}) : super(key: key);

  @override
  ConsumerState<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends ConsumerState<RechargePage> {
  // Form state
  String? selectedOperator;
  String? selectedCircle;
  String? _mobileError;
  bool _showOperatorSection = false;

  // Plans state
  List<RechargePlan>? allPlans;
  Map<String, List<RechargePlan>> categorizedPlans = {};
  bool isLoadingPlans = false;
  List<String> _categories = [];
  String _activeCategory = 'all';

  // Selection state
  RechargePlan? selectedPlan;
  double? _filterAmount;
  bool _isSubmitting = false;

  // Controllers
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Focus node for search
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    selectedCircle = 'ALL';
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ─── MOBILE ──────────────────────────────────────────────
  void _onMobileChanged(String value) {
    if (value.length == 10) {
      HapticFeedback.mediumImpact();
      setState(() {
        _showOperatorSection = true;
        _mobileError = null;
      });
    } else {
      setState(() {
        _showOperatorSection = false;
        allPlans = null;
        selectedOperator = null;
        selectedPlan = null;
      });
    }
    ref.read(rechargeFormProvider.notifier).updateMobile(value);
  }

  // ─── OPERATOR ────────────────────────────────────────────
  void _onOperatorChanged(String? newOperator) {
    if (newOperator == selectedOperator) return;
    HapticFeedback.selectionClick();
    setState(() {
      selectedOperator = newOperator;
      allPlans = null;
      categorizedPlans = {};
      _categories = [];
      _activeCategory = 'all';
      _searchController.clear();
      _filterAmount = null;
      selectedPlan = null;
    });
    if (newOperator != null) {
      ref.read(rechargeFormProvider.notifier).updateOperator(newOperator);
      _fetchPlans();
    }
  }

  void _onCircleChanged(String? newCircle) {
    if (newCircle == selectedCircle) return;
    setState(() {
      selectedCircle = newCircle;
      allPlans = null;
      categorizedPlans = {};
      _categories = [];
      _activeCategory = 'all';
      _searchController.clear();
      _filterAmount = null;
      selectedPlan = null;
    });
    ref.read(rechargeFormProvider.notifier).updateCircle(newCircle ?? 'ALL');
    if (selectedOperator != null) _fetchPlans();
  }

  // ─── FETCH PLANS ─────────────────────────────────────────
  Future<void> _fetchPlans() async {
    if (selectedOperator == null || isLoadingPlans) return;
    setState(() => isLoadingPlans = true);
    try {
      final response = await RechargeService.getPlans(selectedOperator!, circle: selectedCircle ?? 'ALL');
      if (!mounted) return;
      setState(() {
        if (response != null && response.success) {
          allPlans = _parsePlans(response);
          _categorizePlans();
        } else {
          allPlans = [];
        }
        isLoadingPlans = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoadingPlans = false;
        allPlans = [];
      });
      _showSnackBar('Failed to load plans');
    }
  }

  List<RechargePlan> _parsePlans(dynamic response) {
    List<RechargePlan> plans = [];
    try {
      if (response.plans != null) {
        if (response.plans is Map && response.plans['data'] != null) {
          for (var planData in (response.plans['data'] as List)) {
            plans.add(RechargePlan.fromJson(planData is Map<String, dynamic> ? planData : jsonDecode(jsonEncode(planData))));
          }
        } else if (response.plans is Map) {
          response.plans.forEach((key, value) {
            if (value is List) {
              for (var planData in value) {
                plans.add(RechargePlan.fromJson(planData is Map<String, dynamic> ? planData : jsonDecode(jsonEncode(planData))));
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Parse error: $e');
    }
    plans.sort((a, b) => a.amount.compareTo(b.amount));
    return plans;
  }

  void _categorizePlans() {
    if (allPlans == null || allPlans!.isEmpty) return;
    Map<String, List<RechargePlan>> temp = {};
    for (var plan in allPlans!) {
      String category = plan.category ?? 'all';
      temp.putIfAbsent(category, () => []);
      temp[category]!.add(plan);
    }
    categorizedPlans = temp;
    _categories = temp.keys.toList();
  }

  // ─── FILTER LOGIC ────────────────────────────────────────
  List<RechargePlan> _getFilteredPlans() {
    if (allPlans == null) return [];

    List<RechargePlan> result;

    // Filter by category
    if (_activeCategory == 'all') {
      result = List.from(allPlans!);
    } else {
      result = List.from(categorizedPlans[_activeCategory] ?? []);
    }

    // Filter by amount
    if (_filterAmount != null) {
      result = result.where((p) => p.amount >= _filterAmount!).toList();
    }

    return result;
  }

  void _onSearchChanged(String value) {
    final amount = double.tryParse(value);
    setState(() {
      _filterAmount = amount;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _filterAmount = null;
    });
  }

  void _selectPlan(RechargePlan plan) {
    HapticFeedback.lightImpact();
    setState(() {
      selectedPlan = plan;
      _searchController.text = plan.amount.toStringAsFixed(0);
      _filterAmount = plan.amount;
    });
    ref.read(rechargeFormProvider.notifier).updateAmount(plan.amount);
  }

  void _selectCategory(String category) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeCategory = category;
    });
  }

  // ─── VALIDATION ──────────────────────────────────────────
  bool _validate() {
    if (_mobileController.text.length != 10) {
      setState(() => _mobileError = 'Enter valid 10-digit number');
      return false;
    }
    if (selectedOperator == null) {
      _showSnackBar('Please select an operator');
      return false;
    }
    if (selectedPlan == null) {
      _showSnackBar('Please select a plan');
      return false;
    }
    return true;
  }

  // ─── SUBMIT ──────────────────────────────────────────────
  Future<void> _handleRecharge() async {
    if (_isSubmitting) return;
    if (!_validate()) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    final notifier = ref.read(rechargeFormProvider.notifier);
    notifier.updateMobile(_mobileController.text);

    try {
      final response = await notifier.submit();
      if (!mounted) return;

      if (response?.data != null) {
        final transactionId = int.tryParse(response!.data!.transactionId.toString()) ?? 0;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => TransactionStatusScreen(
            transactionId: transactionId,
            amount: selectedPlan?.amount ?? 0,
            operator: selectedOperator ?? '',
            mobile: _mobileController.text,
            initialStatus: response.isPending ? 'pending' : response.isSuccess ? 'success' : 'failed',
          ),
        ));
      } else {
        _showSnackBar(response?.message ?? 'Recharge failed');
      }
    } catch (e) {
      if (mounted) _showSnackBar('Something went wrong');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Iconsax.warning_2, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: GoogleFonts.poppins(fontSize: 13))),
        ]),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(rechargeFormProvider);
    final operators = ref.watch(operatorsListProvider);
    final circles = ref.watch(circlesListProvider);
    final filteredPlans = _getFilteredPlans();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text('Mobile Recharge', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textWhite)),
        centerTitle: true,
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // ═══ STICKY HEADER ═══════════════════════════════
          _buildStickyHeader(operators, circles),

          // ═══ SCROLLABLE CONTENT ═══════════════════════════
          Expanded(
            child: selectedOperator == null
                ? _buildEmptyState('Enter mobile & select operator')
                : isLoadingPlans
                ? _buildLoadingState()
                : (allPlans == null || allPlans!.isEmpty)
                ? _buildEmptyState('No plans available')
                : _buildPlansList(filteredPlans),
          ),
        ],
      ),
      // ═══ BOTTOM BAR ══════════════════════════════════════
      bottomSheet: selectedPlan != null ? _buildBottomBar(formState) : null,
    );
  }

  // ─── STICKY HEADER ───────────────────────────────────────
  Widget _buildStickyHeader(List<String> operators, List<String> circles) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        border: Border(bottom: BorderSide(color: AppColors.borderDark.withOpacity(0.6))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hero Card
          _buildHeroCard(),
          const SizedBox(height: 10),

          // Mobile
          _buildLabel('Mobile Number'),
          const SizedBox(height: 5),
          _buildMobileField(),
          if (_mobileError != null) _buildErrorText(_mobileError!),

          // Operator + Circle
          if (_showOperatorSection) ...[
            const SizedBox(height: 10),
            _buildLabel('Operator & Circle'),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(flex: 3, child: _buildOperatorDropdown(operators)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _buildCircleDropdown(circles)),
            ]),
          ],
        ],
      ),
    );
  }

  // ─── HERO ────────────────────────────────────────────────
  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Iconsax.mobile, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prepaid Recharge', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              Text('Instant • All Operators', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70)),
            ],
          ),
        ),
      ]),
    );
  }

  // ─── LABELS ──────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(text, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary, letterSpacing: 0.3));
  }

  Widget _buildErrorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 4),
      child: Row(children: [
        const Icon(Iconsax.warning_2, size: 10, color: AppColors.error),
        const SizedBox(width: 3),
        Text(text, style: GoogleFonts.poppins(fontSize: 10, color: AppColors.error)),
      ]),
    );
  }

  // ─── MOBILE FIELD ────────────────────────────────────────
  Widget _buildMobileField() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _mobileError != null ? AppColors.error : AppColors.borderDark),
      ),
      child: TextFormField(
        controller: _mobileController,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textWhite),
        decoration: InputDecoration(
          hintText: 'Enter 10-digit number',
          hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDarkHint),
          prefixIcon: const Icon(Iconsax.call, color: AppColors.primaryLight, size: 17),
          border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
        onChanged: _onMobileChanged,
      ),
    );
  }

  // ─── OPERATOR DROPDOWN ───────────────────────────────────
  Widget _buildOperatorDropdown(List<String> operators) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderDark)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedOperator,
          isExpanded: true,
          hint: Text('Operator', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDarkHint)),
          icon: const Icon(Iconsax.arrow_down_1, color: AppColors.primaryLight, size: 15),
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textWhite),
          dropdownColor: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(10),
          items: operators.map((op) => DropdownMenuItem(value: op, child: Text(op, style: GoogleFonts.poppins(fontSize: 12)))).toList(),
          onChanged: _onOperatorChanged,
        ),
      ),
    );
  }

  // ─── CIRCLE DROPDOWN ─────────────────────────────────────
  Widget _buildCircleDropdown(List<String> circles) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.borderDark)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCircle,
          isExpanded: true,
          hint: Text('Circle', style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDarkHint)),
          icon: const Icon(Iconsax.arrow_down_1, color: AppColors.primaryLight, size: 15),
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textWhite),
          dropdownColor: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(10),
          items: circles.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins(fontSize: 11)))).toList(),
          onChanged: _onCircleChanged,
        ),
      ),
    );
  }

  // ─── EMPTY / LOADING STATES ──────────────────────────────
  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.mobile, size: 56, color: AppColors.textDarkHint.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary, height: 1.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 32, height: 32, child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryLight)),
          const SizedBox(height: 14),
          Text('Loading plans...', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDarkSecondary)),
        ],
      ),
    );
  }

  // ─── PLANS LIST ──────────────────────────────────────────
  Widget _buildPlansList(List<RechargePlan> filteredPlans) {
    return Column(
      children: [
        // Search + Category Section
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          decoration: BoxDecoration(
            color: AppColors.darkBg,
            border: Border(bottom: BorderSide(color: AppColors.borderDark.withOpacity(0.3))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search Field
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderDark),
                ),
                child: TextFormField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textWhite),
                  decoration: InputDecoration(
                    hintText: 'Filter by amount (e.g. 299)',
                    hintStyle: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkHint),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 10, right: 4),
                      child: Icon(Iconsax.search_normal, size: 15, color: Color(0xFF1AA88A)),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                      onTap: _clearSearch,
                      child: const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
                      ),
                    )
                        : null,
                    border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),

              // Category Chips
              if (_categories.length > 1) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final isAll = index == 0;
                      final cat = isAll ? 'all' : _categories[index - 1];
                      final isSelected = _activeCategory == cat;
                      return GestureDetector(
                        onTap: () => _selectCategory(cat),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.darkSurface,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark),
                          ),
                          child: Text(isAll ? 'All' : cat.toUpperCase(),
                              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600,
                                  color: isSelected ? Colors.white : AppColors.textDarkSecondary)),
                        ),
                      );
                    },
                  ),
                ),
              ],

              // Count
              const SizedBox(height: 6),
              Row(children: [
                Text('${filteredPlans.length} plans', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkSecondary)),
                if (selectedPlan != null) ...[
                  const Spacer(),
                  Text('Selected: ₹${selectedPlan!.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryLight)),
                ],
              ]),
            ],
          ),
        ),

        // Plans List
        Expanded(
          child: filteredPlans.isEmpty
              ? Center(
            child: Text('No plans match your filter', style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDarkSecondary)),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            physics: const BouncingScrollPhysics(),
            itemCount: filteredPlans.length,
            itemBuilder: (context, index) => _buildPlanCard(filteredPlans[index]),
          ),
        ),
      ],
    );
  }

  // ─── PLAN CARD ───────────────────────────────────────────
  Widget _buildPlanCard(RechargePlan plan) {
    final isSelected = selectedPlan?.amount == plan.amount && selectedPlan?.id == plan.id;

    return GestureDetector(
      onTap: () => _selectPlan(plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.08) : AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark, width: isSelected ? 2 : 1),
        ),
        child: Row(
          children: [
            // Price badge
            Container(
              width: 58, height: 44,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.darkBg,
                borderRadius: BorderRadius.circular(8),
                border: isSelected ? null : Border.all(color: AppColors.borderDark),
              ),
              child: Center(
                child: Text('₹${plan.amount.toStringAsFixed(0)}',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : AppColors.primaryLight)),
              ),
            ),
            const SizedBox(width: 10),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (plan.dataBenefit != null && plan.dataBenefit!.isNotEmpty)
                    Text(plan.dataBenefit!,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textWhite, height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (plan.validityDays != null) ...[
                        Text('${plan.validityDays} days', style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textDarkSecondary)),
                        const SizedBox(width: 6),
                      ],
                      if (plan.category != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                              color: _getCategoryColor(plan.category!).withOpacity(0.2), borderRadius: BorderRadius.circular(3)),
                          child: Text(plan.category!.toUpperCase(),
                              style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w700, color: _getCategoryColor(plan.category!))),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Radio
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark, width: 2),
              ),
              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM BAR ──────────────────────────────────────────
  Widget _buildBottomBar(dynamic formState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkBg,
        border: Border(top: BorderSide(color: AppColors.borderDark)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Amount', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkSecondary)),
                Text('₹${selectedPlan!.amount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textWhite)),
              ],
            ),
          ),
          SizedBox(
            height: 46, width: 140,
            child: ElevatedButton(
              onPressed: (_isSubmitting || formState.isLoading) ? null : _handleRecharge,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.borderDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              child: (_isSubmitting || formState.isLoading)
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Iconsax.flash, color: Colors.white, size: 15),
                const SizedBox(width: 4),
                Text('Recharge', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'data': return Colors.blue;
      case 'topup': return Colors.orange;
      case 'unlimited': return Colors.purple;
      case 'combo': return AppColors.primaryLight;
      case 'validity': return Colors.teal;
      default: return AppColors.primaryLight;
    }
  }
}