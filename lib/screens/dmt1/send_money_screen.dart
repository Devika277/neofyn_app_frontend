import 'package:flutter/material.dart';
import '../../services/DMT/dmt_service.dart';
import '../../services/storage_service.dart';

class SendMoneyScreen extends StatefulWidget {
  final Map<String, dynamic> beneficiary;
  final String senderMobile;

  const SendMoneyScreen({
    super.key,
    required this.beneficiary,
    required this.senderMobile,
  });

  @override
  State<SendMoneyScreen> createState() => _SendMoneyScreenState();
}

class _SendMoneyScreenState extends State<SendMoneyScreen> {
  final _amountCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String _txnMode = 'IMPS';
  bool _loading = false;
  String? _beneAccId;

  // Define the baseUrl – use same as other DMT screens
  final String _baseUrl = 'https://api.myneofyn.com'; // Replace with env

  late DMTService _dmtService;

  @override
  void initState() {
    super.initState();
    print('Beneficiary data: ${widget.beneficiary}');

    _dmtService = DMTService(_baseUrl);
    _loadBeneAccId();
  }

Future<void> _loadBeneAccId() async {
  final benecode = widget.beneficiary['benecode'] ?? widget.beneficiary['beneCode'];
  if (benecode == null) return;
  
  String? id = await StorageService.getBeneAccId(benecode);
  if (id == null) {
    // Try to get from beneficiary object (if API returns it)
    id = widget.beneficiary['beneAccId'] ?? widget.beneficiary['txnId'];
    if (id != null) {
      await StorageService.saveBeneAccId(benecode, id);
    }
  }
  setState(() => _beneAccId = id);
}

  // Future<void> _sendOtp() async {
  // if (_beneAccId == null) {
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     const SnackBar(
  //       content: Text('Beneficiary not fully verified. Please remove and re-add the beneficiary.'),
  //       backgroundColor: Colors.orange,
  //     ),
  //   );
  //   return;
  // }
  //   try {
  //     await _dmtService.resendTransactionOtp(_beneAccId!);
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('OTP sent to beneficiary mobile')),
  //     );
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Failed to send OTP: $e')),
  //     );
  //   }
  // }

Future<void> _sendOrVerify() async {
  if (_beneAccId == null) {
    // No stored beneAccId → ask user to verify first
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Beneficiary Not Verified'),
        content: const Text('This beneficiary has not been verified. Do you want to verify the account now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2ECC71)),
            child: const Text('Verify', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _verifyBeneficiary();
    }
    return;
  }
  // If beneAccId exists, send OTP
  try {
    await _dmtService.resendTransactionOtp(_beneAccId!);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP sent to beneficiary mobile')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send OTP: $e')),
    );
  }
}


  Future<void> _verifyBeneficiary() async {
  setState(() => _loading = true);
  try {
    final accountNo = widget.beneficiary['accountNo'] ?? widget.beneficiary['accountNumber'];
    final ifsc = widget.beneficiary['ifsc'];
    if (accountNo == null || ifsc == null) {
      throw Exception('Account details missing for this beneficiary');
    }

    final pennyRes = await _dmtService.performPennyDrop(accountNo, ifsc);
    final isSuccess = pennyRes['successStatus'] == true && pennyRes['responseCode'] == '000';
    if (!isSuccess) {
      throw Exception(pennyRes['message'] ?? 'Penny drop failed');
    }

    final beneAccId = (pennyRes['txnId'] ?? pennyRes['beneAccId']).toString();
    if (beneAccId.isEmpty) throw Exception('No account ID returned');

    final beneCode = widget.beneficiary['benecode'] ?? widget.beneficiary['beneCode'];
    await StorageService.saveBeneAccId(beneCode, beneAccId);

    setState(() => _beneAccId = beneAccId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Beneficiary verified! You can now send OTP.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Verification failed: $e')),
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  Future<void> _sendMoney() async {
    if (_amountCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter amount')),
      );
      return;
    }
    if (_otpCtrl.text.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter 4-digit OTP')),
      );
      return;
    }
    if (_beneAccId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beneficiary account ID missing. Please re-add beneficiary.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await _dmtService.sendMoney(
        benneAccId: _beneAccId!,
        amount: _amountCtrl.text,
        otp: _otpCtrl.text,
        txnMode: _txnMode,
      );

      if (!mounted) return;

      if (res['txnStatus'] == 'SUCCESS') {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Text('Transaction Successful', style: TextStyle(color: Color(0xFF2ECC71))),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Txn ID: ${res['txnId']}', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Text('RRN: ${res['rrn']}', style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                Text('Amount: ₹${res['amount']}', style: const TextStyle(color: Colors.white)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // go back to dashboard
                },
                child: const Text('OK', style: TextStyle(color: Color(0xFF2ECC71))),
              ),
            ],
          ),
        );
      } else {
        throw Exception(res['message'] ?? 'Transaction failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Send Money', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Beneficiary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFF2ECC71)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.beneficiary['beneName'] ?? widget.beneficiary['name'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.account_balance, color: Colors.grey, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        widget.beneficiary['accountNo'] ?? widget.beneficiary['accountNumber'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.account_balance, color: Colors.grey, size: 18),
                      const SizedBox(width: 12),
                      Text(
                        widget.beneficiary['bankName'] ?? '',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Amount field
            TextField(
              controller: _amountCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.currency_rupee, color: Colors.grey),
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
            const SizedBox(height: 20),

            // Transaction mode
            const Text('Transaction Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Radio<String>(
                  value: 'IMPS',
                  groupValue: _txnMode,
                  onChanged: (val) => setState(() => _txnMode = val!),
                  activeColor: const Color(0xFF2ECC71),
                ),
                const Text('IMPS', style: TextStyle(color: Colors.white)),
                const SizedBox(width: 20),
                Radio<String>(
                  value: 'NEFT',
                  groupValue: _txnMode,
                  onChanged: (val) => setState(() => _txnMode = val!),
                  activeColor: const Color(0xFF2ECC71),
                ),
                const Text('NEFT', style: TextStyle(color: Colors.white)),
              ],
            ),
            const SizedBox(height: 20),

            // OTP section
            const Text('OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _otpCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      labelText: '4-digit OTP',
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
                ),
                const SizedBox(width: 12),
                ElevatedButton(
  onPressed: _sendOrVerify,
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFF2ECC71),
    foregroundColor: Colors.black,
  ),
  child: Text(_beneAccId == null ? 'Verify Account' : 'Send OTP'),
),
              ],
            ),
            const SizedBox(height: 30),

            // Transfer button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _loading ? null : _sendMoney,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text(
                        'Transfer Money',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}