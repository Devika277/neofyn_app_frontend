// lib/screens/dmt_receipt_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class DmtReceiptModel {
  final String transactionId;
  final String utrNumber;
  final String amount;
  final String commission;
  final String status;
  final String transferMode;
  final String remitterName;
  final String remitterMobile;
  final String beneficiaryName;
  final String accountNumber;
  final String bankName;
  final String ifscCode;
  final String beneficiaryMobile;
  final String remark;
  final String failureReason;
  final DateTime transactionDate;
  final String merchantName;
  final String retailerId;

  DmtReceiptModel({
    required this.transactionId,
    required this.utrNumber,
    required this.amount,
    this.commission = '',
    required this.status,
    this.transferMode = '',
    required this.remitterName,
    this.remitterMobile = '',
    required this.beneficiaryName,
    required this.accountNumber,
    required this.bankName,
    this.ifscCode = '',
    this.beneficiaryMobile = '',
    this.remark = '',
    this.failureReason = '',
    required this.transactionDate,
    this.merchantName = 'NEOFYN Bharath',
    this.retailerId = '',
  });

  String get formattedDate => DateFormat('dd MMM yyyy, hh:mm a').format(transactionDate);
  String get formattedDateShort => DateFormat('dd/MM/yyyy').format(transactionDate);
  String get formattedTime => DateFormat('hh:mm:ss a').format(transactionDate);
  bool get isSuccess => status.toLowerCase() == 'success';
}

class DmtReceiptScreen extends StatelessWidget {
  final DmtReceiptModel receipt;

  const DmtReceiptScreen({Key? key, required this.receipt}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        title: Text(
          'DMT Receipt',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A0E0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.share, color: Colors.white70, size: 20),
            onPressed: () => _shareReceipt(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Status Card
            _buildStatusCard(),
            const SizedBox(height: 16),
            // Receipt Card
            _buildReceiptCard(),
            const SizedBox(height: 16),
            // Action Buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A342A)),
      ),
      child: Column(
        children: [
          // Status Icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: receipt.isSuccess
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : const Color(0xFFEF4444).withOpacity(0.1),
              border: Border.all(
                color: receipt.isSuccess
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
                width: 2,
              ),
            ),
            child: Icon(
              receipt.isSuccess ? Iconsax.tick_circle : Iconsax.close_circle,
              color: receipt.isSuccess
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          // Status Text
          Text(
            receipt.isSuccess ? 'Transaction Successful' : 'Transaction Failed',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Amount
          Text(
            '₹${receipt.amount}',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: receipt.isSuccess
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Sent Successfully',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A342A)),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          const Divider(color: Color(0xFF2A342A), height: 24),
          // Transaction Details
          _buildSectionTitle('Transaction Details'),
          _buildDetailRow('Transaction ID', receipt.transactionId),
          _buildDetailRow('UTR Number', receipt.utrNumber),
          _buildDetailRow('Transfer Mode', receipt.transferMode),
          _buildDetailRow('Date', receipt.formattedDate),
          if (receipt.remark.isNotEmpty)
            _buildDetailRow('Remark', receipt.remark),
          const Divider(color: Color(0xFF2A342A), height: 24),
          // Remitter Details
          _buildSectionTitle('Remitter Details'),
          _buildDetailRow('Name', receipt.remitterName),
          if (receipt.remitterMobile.isNotEmpty)
            _buildDetailRow('Mobile', receipt.remitterMobile),
          const Divider(color: Color(0xFF2A342A), height: 24),
          // Beneficiary Details
          _buildSectionTitle('Beneficiary Details'),
          _buildDetailRow('Name', receipt.beneficiaryName),
          _buildDetailRow('Account Number', _maskAccount(receipt.accountNumber)),
          _buildDetailRow('Bank', receipt.bankName),
          if (receipt.ifscCode.isNotEmpty)
            _buildDetailRow('IFSC Code', receipt.ifscCode),
          if (receipt.beneficiaryMobile.isNotEmpty)
            _buildDetailRow('Mobile', receipt.beneficiaryMobile),
          const Divider(color: Color(0xFF2A342A), height: 24),
          // Amount Details
          _buildSectionTitle('Amount Details'),
          _buildDetailRow('Transfer Amount', '₹${receipt.amount}'),
          if (receipt.commission.isNotEmpty && receipt.commission != 'null')
            _buildDetailRow('Commission', '₹${receipt.commission}'),
          if (receipt.failureReason.isNotEmpty)
            _buildDetailRow('Failure Reason', receipt.failureReason,
                valueColor: const Color(0xFFEF4444)),
          const Divider(color: Color(0xFF2A342A), height: 24),
          // Footer
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Logo/Title
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF008169), Color(0xFF1AA88A)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Iconsax.money_send,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receipt.merchantName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Digital Money Transfer',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF1AA88A),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Date and Time
        Text(
          '${receipt.formattedDateShort} | ${receipt.formattedTime}',
          style: GoogleFonts.poppins(
            fontSize: 11,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1AA88A),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(height: 1, color: const Color(0xFF2A342A)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        // Status Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: receipt.isSuccess
                ? const Color(0xFF10B981).withOpacity(0.1)
                : const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: receipt.isSuccess
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                receipt.isSuccess ? Iconsax.shield_tick : Iconsax.warning_2,
                size: 14,
                color: receipt.isSuccess
                    ? const Color(0xFF10B981)
                    : const Color(0xFFEF4444),
              ),
              const SizedBox(width: 6),
              Text(
                receipt.isSuccess ? 'Verified Transaction' : 'Failed Transaction',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: receipt.isSuccess
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'This is a computer generated receipt',
          style: GoogleFonts.poppins(fontSize: 10, color: Colors.white30),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _downloadReceipt(context),
            icon: const Icon(Iconsax.document_download, size: 18),
            label: const Text('Download Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008169),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Iconsax.close_circle, size: 18),
            label: const Text('Close'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Color(0xFF2A342A)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _maskAccount(String account) {
    if (account.length <= 4) return account;
    return '${'*' * (account.length - 4)}${account.substring(account.length - 4)}';
  }

  void _shareReceipt(BuildContext context) {
    // Implement share functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Share feature coming soon'),
        backgroundColor: const Color(0xFF1A1F1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _downloadReceipt(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            const Text('Receipt downloaded successfully'),
          ],
        ),
        backgroundColor: const Color(0xFF1A1F1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}