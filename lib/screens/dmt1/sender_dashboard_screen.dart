import 'package:flutter/material.dart';
import '../../services/DMT/dmt_service.dart';
// import '../../services/storage_service.dart';
import 'add_beneficiary_screen.dart';
import 'send_money_screen.dart';  // Import the SendMoneyScreen

class SenderDashboardScreen extends StatefulWidget {
  final String mobileNumber;
  final String senderId;
  final String senderName;
  final String accountNumber;
  final String ifscCode;
  final double monthlyLimit;
  final double monthlyUsed;

  const SenderDashboardScreen({
    super.key,
    required this.mobileNumber,
    required this.senderId,
    required this.senderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.monthlyLimit,
    required this.monthlyUsed,
  });

  @override
  State<SenderDashboardScreen> createState() => _SenderDashboardScreenState();
}

class _SenderDashboardScreenState extends State<SenderDashboardScreen> {
  late DMTService _dmtService;
  List<dynamic> _beneficiaries = [];
  bool _isLoading = true;
  double _remainingLimit = 0;

  // Base URL – same as other screens
  final String _baseUrl = 'https://api.myneofyn.com';

  @override
  void initState() {
    super.initState();
    _dmtService = DMTService(_baseUrl);
    _remainingLimit = widget.monthlyLimit - widget.monthlyUsed;
    _loadBeneficiaries();
  }

  Future<void> _loadBeneficiaries() async {
    setState(() => _isLoading = true);
    try {
      final result = await _dmtService.getBeneficiaryList(widget.mobileNumber);
      // Vimopay returns 'beneficiaries' array, not 'data'
      setState(() {
        _beneficiaries = result['beneficiaries'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading beneficiaries: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Sender Dashboard', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF2ECC71)),
            onPressed: _loadBeneficiaries,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadBeneficiaries,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Sender Info Card
              // Container(
              //   padding: const EdgeInsets.all(20),
              //   decoration: BoxDecoration(
              //     gradient: LinearGradient(
              //       colors: [const Color(0xFF2ECC71).withOpacity(0.2), const Color(0xFF1A1A1A)],
              //       begin: Alignment.topLeft,
              //       end: Alignment.bottomRight,
              //     ),
              //     borderRadius: BorderRadius.circular(16),
              //     border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
              //   ),
              //   child: Column(
              //     children: [
              //       const CircleAvatar(
              //         radius: 40,
              //         backgroundColor: Color(0xFF2ECC71),
              //         child: Icon(Icons.person, size: 40, color: Colors.black),
              //       ),
              //       const SizedBox(height: 12),
              //       Text(widget.senderName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              //       const SizedBox(height: 4),
              //       Text('ID: ${widget.senderId}', style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 14)),
              //       const SizedBox(height: 4),
              //       Text('+91 ${widget.mobileNumber}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              //       const Divider(color: Colors.grey, height: 24),
              //       Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: [
              //           const Text('Account Number', style: TextStyle(color: Colors.grey, fontSize: 12)),
              //           Text(widget.accountNumber, style: const TextStyle(color: Colors.white, fontSize: 13)),
              //         ],
              //       ),
              //       const SizedBox(height: 8),
              //       Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: [
              //           const Text('IFSC Code', style: TextStyle(color: Colors.grey, fontSize: 12)),
              //           Text(widget.ifscCode, style: const TextStyle(color: Colors.white, fontSize: 13)),
              //         ],
              //       ),
              //       const SizedBox(height: 8),
              //       Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: [
              //           const Text('Monthly Limit', style: TextStyle(color: Colors.grey, fontSize: 12)),
              //           Text('₹${widget.monthlyLimit.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 13)),
              //         ],
              //       ),
              //       const SizedBox(height: 8),
              //       Row(
              //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //         children: [
              //           const Text('Remaining Limit', style: TextStyle(color: Colors.grey, fontSize: 12)),
              //           Text('₹${_remainingLimit.toStringAsFixed(0)}', 
              //               style: TextStyle(color: _remainingLimit > 0 ? const Color(0xFF2ECC71) : Colors.red, fontSize: 13)),
              //         ],
              //       ),
              //     ],
              //   ),
              // ),

              const SizedBox(height: 20),

              // Add Beneficiary Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddBeneficiaryScreen(
                          senderMobile: widget.mobileNumber,
                          onBeneficiaryAdded: _loadBeneficiaries,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add, color: Colors.black),
                  label: const Text('Add Beneficiary', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 24),

              // Beneficiaries List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Beneficiaries', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {},
                    child: const Text('View All', style: TextStyle(color: Color(0xFF2ECC71), fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)))
                  : _beneficiaries.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.account_balance, size: 50, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No beneficiaries added', style: TextStyle(color: Colors.grey)),
                              SizedBox(height: 8),
                              Text('Tap "Add Beneficiary" to add bank account', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _beneficiaries.length,
                          itemBuilder: (context, index) {
                            final ben = _beneficiaries[index];
                            return GestureDetector(
                              onTap: () {
                                // Navigate to SendMoneyScreen with selected beneficiary
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => SendMoneyScreen(
                                      beneficiary: ben,
                                      senderMobile: widget.mobileNumber,
                                    ),
                                  ),
                                ).then((_) {
                                  // Refresh limit after possible transaction
                                  _loadBeneficiaries();
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A1A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2ECC71).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.account_balance, color: Color(0xFF2ECC71)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ben['beneName'] ?? ben['benename'] ?? ben['name'] ?? '', 
                                              style: const TextStyle(color: Colors.white)),
                                          Text('${ben['accountNo'] ?? ben['accountno'] ?? ''} / ${ben['ifsc'] ?? ''}', 
                                              style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (ben['beneVerify'] == '1' || ben['verified'] == true) 
                                            ? Colors.green.withOpacity(0.2) 
                                            : Colors.orange.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        (ben['beneVerify'] == '1' || ben['verified'] == true) ? 'Verified' : 'Pending',
                                        style: TextStyle(
                                          color: (ben['beneVerify'] == '1' || ben['verified'] == true) ? Colors.green : Colors.orange, 
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ],
          ),
        ),
      ),
    );
  }
}