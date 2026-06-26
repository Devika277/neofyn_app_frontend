import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bbps_provider.dart';
import '../../models/bbps_models.dart';

class BillPaymentScreen extends StatefulWidget {
  const BillPaymentScreen({Key? key}) : super(key: key);

  @override
  State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}



class _BillPaymentScreenState extends State<BillPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _paramControllers = {};


  bool _amountRequired = false;
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

  // Build the form fields dynamically from biller details' requiredParams
  List<Widget> _buildParameterFields(BillerDetails details) {
  final customerParams = (details['customerParam'] as List<dynamic>?) ?? [];

  if (customerParams.isEmpty) {
    debugPrint('⚠️ No required parameters found');
    return const [];
  }

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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: _paramControllers[paramName],
        decoration: InputDecoration(
          labelText: '$fieldLabel ${isOptional ? '(optional)' : '*'}',
          border: const OutlineInputBorder(),
        ),
        keyboardType: paramName.toLowerCase().contains('mobile') ||
                      paramName.toLowerCase().contains('phone')
            ? TextInputType.phone
            : TextInputType.text,
        validator: isOptional ? null : (v) => v!.isEmpty ? 'Enter $fieldLabel' : null,
      ),
    );
  }).toList();
}

 void _fetchBill() {
  if (!_formKey.currentState!.validate()) return;
  final provider = context.read<BBPSProvider>();
  final biller = provider.selectedBiller!;
  final details = provider.billerDetails;

  // Build the customerParams array from the form controllers
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
          if (!isOptional && customerId == null) {
            customerId = value; // use first required param as customerId
          }
        }
      }
    }
  }

  if (customerParams.isEmpty || customerId == null || customerId!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please fill all required fields')),
    );
    return;
  }

  // Save customerId for the pay step
  _fetchedCustomerId = customerId;

  // Clear any previous amount input state
  _amountController.clear();
  _amountRequired = false;

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

    // Determine the amount
    double? amount;
    if (fetchResult!.fetchBillResult?.amount != null) {
        amount = fetchResult.fetchBillResult!.amount;
    } else {
        // custom amount from user input
        if (_amountController.text.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter the recharge amount')),
            );
            return;
        }
        amount = double.tryParse(_amountController.text.trim());
        if (amount == null || amount <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invalid amount')),
            );
            return;
        }
    }

    provider.payBill(
        transactionId: fetchResult.transactionId!,
        serviceType: provider.selectedBiller?.billerCode,
        customerId: _fetchedCustomerId ?? fetchResult.fetchBillResult?.raw['customerId']?.toString() ?? '',
        amount: amount,
        additionalData: {
            'billerId': provider.selectedBiller?.billerCode,
        },
    );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pay Bill')),
      body: Consumer<BBPSProvider>(
        builder: (context, provider, _) {
          // Step 0: Loading categories
          if (provider.categoriesLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Step 1: Choose category
          if (provider.selectedCategory == null) {
            return _buildCategoryStep(provider);
          }

          // Step 2: Choose biller within category
          if (provider.selectedBiller == null) {
            return _buildBillerStep(provider);
          }

          // Step 3: Enter details / Fetch bill
          if (provider.fetchBillResponse == null && provider.payBillResponse == null) {
            return _buildDetailsStep(provider);
          }

          // Step 4: Bill fetched → show bill
          if (provider.fetchBillResponse != null && provider.payBillResponse == null) {
            return _buildFetchedBill(provider);
          }

          // Step 5: Payment result
          if (provider.payBillResponse != null) {
            return _buildPaymentResult(provider);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  // ---------- STEP WIDGETS ----------

  Widget _buildCategoryStep(BBPSProvider provider) {
    if (provider.categories.isEmpty) {
      return const Center(child: Text('No categories available'));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: provider.categories.length,
      itemBuilder: (_, index) {
        final cat = provider.categories[index];
        return Card(
          elevation: 2,
          child: InkWell(
            onTap: () {
              provider.selectCategory(cat);
              provider.loadBillersForCategory(cat.code);
            },
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_getCategoryIcon(cat.name), size: 30),
                    const SizedBox(height: 6),
                    Text(cat.name, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBillerStep(BBPSProvider provider) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.arrow_back),
          title: Text(provider.selectedCategory?.name ?? ''),
          onTap: () => provider.selectCategory(null),
        ),
        const Divider(),
        if (provider.billersLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (provider.billers.isEmpty)
          const Expanded(child: Center(child: Text('No billers found')))
        else
          Expanded(
            child: ListView.builder(
              itemCount: provider.billers.length,
              itemBuilder: (_, i) {
                final biller = provider.billers[i];
                return ListTile(
                  title: Text(biller.billerName),
                  subtitle: Text('Code: ${biller.billerCode}'),
                  onTap: () {
                    provider.selectBiller(biller);
                    // Load details for this biller
                    provider.loadBillerDetails(
                      provider.selectedCategory!.code,
                      biller.billerCode,
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsStep(BBPSProvider provider) {
  final biller = provider.selectedBiller!;
  final details = provider.billerDetails; // this is already the real object

  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => provider.selectBiller(null),
              ),
              Expanded(
                child: Text(
                  biller.billerName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Divider(),
          if (provider.billerDetailsLoading)
            const Center(child: CircularProgressIndicator())
          else if (details == null)
            const Text('No details available.')
          else ...[
            Text('Enter your billing details:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ..._buildParameterFields(details),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: provider.fetchBillLoading ? null : _fetchBill,
            child: provider.fetchBillLoading
                ? const CircularProgressIndicator()
                : const Text('Fetch Bill'),
          ),
          if (provider.paymentError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(provider.paymentError!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildFetchedBill(BBPSProvider provider) {
  final bill = provider.fetchBillResponse!.fetchBillResult;

  // ✅ Check if VimoPay fetch actually failed
  final txnStatus = bill?.raw['txnStatus']?.toString() ?? '';
  final txnStatusCode = bill?.raw['txnStatusCode']?.toString() ?? '';
  final responseMessage = bill?.raw['responseMessage']?.toString() ?? '';

  if (txnStatus.toUpperCase() == 'FAILED' || txnStatusCode == '001') {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            responseMessage.isNotEmpty ? responseMessage : 'Bill fetch failed',
            style: const TextStyle(fontSize: 18, color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              provider.resetBillPaymentFlow();
              _paramControllers.clear();
              _amountController.clear();
              _fetchedCustomerId = null;
              _amountRequired = false;
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // ✅ Normal successful bill display
  return Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Bill Details', style: Theme.of(context).textTheme.headlineSmall),
        const Divider(),
        if (bill?.customerName != null && bill!.customerName!.isNotEmpty)
          Text('Name: ${bill.customerName}'),
        if (bill?.amount != null)
          Text('Amount: ₹${bill!.amount!.toStringAsFixed(2)}')
        else ...[
          Text('Enter recharge amount:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount *',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            validator: (v) => v!.isEmpty ? 'Enter amount' : null,
          ),
        ],
        if (bill?.dueDate != null) Text('Due Date: ${bill!.dueDate.toString()}'),
        if (bill?.raw['billNumber'] != null) Text('Bill No: ${bill!.raw['billNumber']}'),

        // 👇 THIS IS THE MISSING PART – show payment error here 👇
        if (provider.paymentError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              provider.paymentError!,
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),

        const SizedBox(height: 20),
        Row(
          children: [
            ElevatedButton(
              onPressed: provider.payBillLoading ? null : _payBill,
              child: provider.payBillLoading
                  ? const CircularProgressIndicator()
                  : const Text('Pay Now'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () {
                provider.resetBillPaymentFlow();
                _paramControllers.clear();
                _amountController.clear();
                _fetchedCustomerId = null;
                _amountRequired = false;
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildPaymentResult(BBPSProvider provider) {
    final result = provider.payBillResponse!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            result.success ? Icons.check_circle : Icons.error,
            size: 80,
            color: result.success ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 16),
          Text(result.message, style: const TextStyle(fontSize: 18)),
          if (result.refunded) const Text('Amount has been refunded.'),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              provider.resetBillPaymentFlow();
              _paramControllers.clear();
            },
            child: const Text('Make Another Payment'),
          ),
        ],
      ),
    );
  }

  // Helper for category icons (optional)
  IconData _getCategoryIcon(String name) {
    switch (name.toLowerCase()) {
      case 'electricity':
        return Icons.flash_on;
      case 'water':
        return Icons.water_drop;
      case 'gas':
        return Icons.local_fire_department;
      case 'broadband':
      case 'postpaid':
        return Icons.wifi;
      default:
        return Icons.receipt_long;
    }
  }
}