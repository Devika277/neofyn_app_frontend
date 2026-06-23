import 'package:flutter/material.dart';
import 'package:my_app/screens/dmt1/sender_lookup_screen.dart';

class DmtHomeScreen extends StatelessWidget {
  const DmtHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {

    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2ECC71)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Money Transfer (DMT)',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Balance + Limit Card ──────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Wallet Balance',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('₹ 88,000',
                            style: TextStyle(
                                color: Color(0xFF2ECC71),
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text('Monthly Limit',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        SizedBox(height: 4),
                        Text('₹ 25,000 / ₹ 25,000',
                            style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── How it works ─────────────────────────────────
              const Text('HOW IT WORKS',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      letterSpacing: 0.8)),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: const [
                  _StepCard(step: '1', title: 'Register Sender',
                      sub: 'Mobile & OTP verify'),
                  _StepCard(step: '2', title: 'Add Beneficiary',
                      sub: 'Bank account details'),
                  _StepCard(step: '3', title: 'Verify Account',
                      sub: 'Penny drop check'),
                  _StepCard(step: '4', title: 'Transfer Money',
                      sub: 'IMPS / NEFT'),
                ],
              ),

              const SizedBox(height: 20),

              // ── CTA Button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Start New Transfer',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SenderLookupScreen()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ── Recent Transactions ──────────────────────────
              const Text('RECENT TRANSFERS',
                  style: TextStyle(
                      color: Colors.grey,
                      fontSize: 11,
                      letterSpacing: 0.8)),
              const SizedBox(height: 10),

              // TODO: replace with real data from your API
              _TxnRow(name: 'Rahul Kumar',  bank: 'HDFC · ****4521',
                  amount: '₹ 5,000',  status: 'success'),
              _TxnRow(name: 'Priya Singh',  bank: 'SBI · ****8823',
                  amount: '₹ 2,500',  status: 'pending'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Step Card widget ─────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final String step, title, sub;
  const _StepCard(
      {required this.step, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('Step $step',
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ),
          const SizedBox(height: 5),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          Text(sub,
              style: const TextStyle(color: Colors.grey, fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Transaction row widget ───────────────────────────────────
class _TxnRow extends StatelessWidget {
  final String name, bank, amount, status;
  const _TxnRow(
      {required this.name,
      required this.bank,
      required this.amount,
      required this.status});

  @override
  Widget build(BuildContext context) {
    final Color statusColor = status == 'success'
        ? const Color(0xFF2ECC71)
        : status == 'pending'
            ? Colors.amber
            : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Color(0xFF222222), width: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF1A1A1A),
            child: Text(name[0],
                style: const TextStyle(
                    color: Color(0xFF2ECC71),
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13)),
                Text(bank,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(amount,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Icon(Icons.circle, size: 6, color: statusColor),
                  const SizedBox(width: 4),
                  Text(status,
                      style: TextStyle(
                          color: Colors.grey, fontSize: 10)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}