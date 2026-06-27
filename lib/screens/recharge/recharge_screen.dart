import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_app/models/recharge_models.dart';
import 'package:my_app/providers/recharge_provider.dart';
import 'package:my_app/services/recharges/recharge_service.dart';

class RechargePage extends ConsumerStatefulWidget {
  const RechargePage({Key? key}) : super(key: key);

  @override
  ConsumerState<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends ConsumerState<RechargePage>
    with SingleTickerProviderStateMixin {
  String? selectedOperator;
  String? selectedCircle;
  PlansResponse? cachedPlans;
  bool isLoadingPlans = false;
  late TabController _tabController;
  String _selectedCategory = 'all';

  @override
  void initState() {
    super.initState();
    selectedCircle = 'ALL';
    _tabController = TabController(length: 0, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(rechargeFormProvider);
    final notifier = ref.read(rechargeFormProvider.notifier);
    final operators = ref.watch(operatorsListProvider);
    final circles = ref.watch(circlesListProvider);

    // Fetch plans when operator changes
    if (selectedOperator != null && cachedPlans == null && !isLoadingPlans) {
      _fetchPlans(selectedOperator!, selectedCircle ?? 'ALL');
    }

    // Get category tabs
    final categories = cachedPlans?.plans.keys.toList() ?? [];
    if (_tabController.length != categories.length && categories.isNotEmpty) {
      _tabController.dispose();
      _tabController = TabController(length: categories.length, vsync: this);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Mobile Recharge',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0),
          child: Container(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Input Cards ───────────────────────────────────
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Mobile Number
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      hintText: 'Enter 10-digit mobile number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.phone_android),
                      labelStyle: const TextStyle(color: Colors.grey),
                    ),
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    onChanged: notifier.updateMobile,
                  ),
                  const SizedBox(height: 12),
                  
                  // Operator Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Operator',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.signal_cellular_alt),
                      labelStyle: const TextStyle(color: Colors.grey),
                    ),
                    value: selectedOperator,
                    hint: const Text('Select Operator'),
                    items: operators.map((String operator) {
                      return DropdownMenuItem<String>(
                        value: operator,
                        child: Row(
                          children: [
                            _getOperatorIcon(operator),
                            const SizedBox(width: 10),
                            Text(operator),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedOperator = newValue;
                        cachedPlans = null;
                      });
                      if (newValue != null) {
                        notifier.updateOperator(newValue);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Circle Dropdown
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Circle (State)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.location_on),
                      labelStyle: const TextStyle(color: Colors.grey),
                    ),
                    value: selectedCircle,
                    hint: const Text('Select Circle'),
                    items: circles.map((String circle) {
                      return DropdownMenuItem<String>(
                        value: circle,
                        child: Text(circle),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedCircle = newValue;
                        cachedPlans = null;
                      });
                      if (newValue != null) {
                        notifier.updateCircle(newValue);
                      }
                    },
                  ),
                ],
              ),
            ),

            // ─── Plans Section ────────────────────────────────
            if (selectedOperator != null && cachedPlans != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recharge Plans',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_getTotalPlans()} plans',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              
              // Category Tabs
              if (cachedPlans!.plans.keys.length > 1) ...[
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.green,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.green,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  tabs: cachedPlans!.plans.keys.map((category) {
                    return Tab(
                      child: Row(
                        children: [
                          Icon(
                            category.icon,
                            size: 16,
                            color: category.color,
                          ),
                          const SizedBox(width: 4),
                          Text(category.displayName),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
              
              // Plans Grid
              if (cachedPlans != null)
                _buildPlansGrid(cachedPlans!, _tabController),
              
              const SizedBox(height: 16),
            ],

            if (isLoadingPlans)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: Colors.green),
                ),
              ),

            // ─── Amount Input ──────────────────────────────────
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      hintText: 'Enter amount',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.currency_rupee),
                      labelStyle: const TextStyle(color: Colors.grey),
                    ),
                    keyboardType: TextInputType.number,
                    controller: TextEditingController(
                      text: formState.amount > 0 ? formState.amount.toString() : '',
                    ),
                    onChanged: (v) => notifier.updateAmount(double.tryParse(v) ?? 0),
                  ),
                  const SizedBox(height: 16),
                  
                  // Error / Success Messages
                  if (formState.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formState.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (formState.lastResponse != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: formState.lastResponse!.success
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formState.lastResponse!.message,
                        style: TextStyle(
                          color: formState.lastResponse!.success
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Recharge Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: formState.isLoading ? null : notifier.submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: formState.isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : const Text(
                              'Recharge Now',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchPlans(String operator, String circle) async {
    if (isLoadingPlans) return;
    isLoadingPlans = true;
    try {
      final response = await RechargeService.getPlans(operator, circle: circle);
      if (mounted) {
        setState(() {
          cachedPlans = response;
          isLoadingPlans = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingPlans = false;
        });
      }
    }
  }

  int _getTotalPlans() {
    if (cachedPlans == null) return 0;
    int count = 0;
    cachedPlans!.plans.forEach((_, plans) {
      count += plans.length;
    });
    return count;
  }

  Widget _buildPlansGrid(PlansResponse response, TabController tabController) {
    final categories = response.plans.keys.toList();
    
    if (categories.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No plans available'),
        ),
      );
    }

    // If only one category, show it directly
    if (categories.length == 1) {
      final plans = response.plans[categories.first]!;
      return _buildPlanCards(plans);
    }

    // Multiple categories with tabs
    return SizedBox(
      height: 400,
      child: TabBarView(
        controller: tabController,
        children: categories.map((category) {
          final plans = response.plans[category] ?? [];
          return _buildPlanCards(plans);
        }).toList(),
      ),
    );
  }

  Widget _buildPlanCards(List<RechargePlan> plans) {
    if (plans.isEmpty) {
      return const Center(
        child: Text('No plans in this category'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        return _buildPlanCard(plan);
      },
    );
  }

  Widget _buildPlanCard(RechargePlan plan) {
    final notifier = ref.read(rechargeFormProvider.notifier);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            notifier.updateAmount(plan.amount);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('₹${plan.amount.toStringAsFixed(2)} selected'),
                duration: const Duration(seconds: 1),
                backgroundColor: Colors.green,
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Price
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: (plan.category ?? 'data').color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          (plan.category ?? 'data').icon,
                          color: (plan.category ?? 'data').color,
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${plan.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: (plan.category ?? 'data').color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${plan.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (plan.validityDays != null)
                        Text(
                          '${plan.validityDays} days validity',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      if (plan.dataBenefit != null && plan.dataBenefit!.isNotEmpty)
                        Text(
                          plan.dataBenefit!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (plan.category != null && plan.category != 'others')
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (plan.category ?? 'data').color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (plan.category ?? 'data').displayName,
                            style: TextStyle(
                              fontSize: 10,
                              color: (plan.category ?? 'data').color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // Select Button
                ElevatedButton(
                  onPressed: () {
                    notifier.updateAmount(plan.amount);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('₹${plan.amount.toStringAsFixed(2)} selected'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(60, 32),
                  ),
                  child: const Text(
                    'Select',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getOperatorIcon(String operator) {
    IconData iconData;
    switch (operator.toUpperCase()) {
      case 'JIO':
        iconData = Icons.wifi;
        break;
      case 'AIRTEL':
        iconData = Icons.signal_cellular_alt;
        break;
      case 'VI':
        iconData = Icons.cell_tower;
        break;
      case 'BSNL':
        iconData = Icons.satellite;
        break;
      default:
        iconData = Icons.phone_android;
    }
    return Icon(iconData, color: Colors.green, size: 20);
  }
}