import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class DmtReceiptModel {
  final String transactionId;
  final String utrNumber;
  final String amount;
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
  final String outletName;
  final String senderName;
  final String senderMobile;
  final String shopAddress;
  final String shopPhone;

  DmtReceiptModel({
    required this.transactionId,
    required this.utrNumber,
    required this.amount,
    required this.status,
    this.transferMode = 'IMPS',
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
    this.outletName = '',
    this.senderName = '',
    this.senderMobile = '',
    this.shopAddress = '',
    this.shopPhone = '',
  });

  String get formattedDate => DateFormat('dd-MM-yyyy hh:mm a').format(transactionDate);
  String get formattedDateShort => DateFormat('dd-MM-yyyy').format(transactionDate);
  String get formattedTime => DateFormat('hh:mm a').format(transactionDate);
  String get fileNameDate => DateFormat('yyyyMMdd_HHmmss').format(transactionDate);

  bool get isSuccess => status.toLowerCase() == 'success' || status.toLowerCase() == 'completed';
  bool get isFailed => status.toLowerCase() == 'failed' || status.toLowerCase() == 'failure' || status.toLowerCase() == 'reversed';
  bool get isProcessing => status.toLowerCase() == 'processing' || status.toLowerCase() == 'pending' || status.toLowerCase() == 'queued';
  bool get isOnHold => status.toLowerCase() == 'hold';

  String get statusMessage {
    if (isSuccess) return failureReason.isNotEmpty ? failureReason : 'Transaction completed successfully';
    if (isFailed) return failureReason.isNotEmpty ? failureReason : 'Transaction failed';
    if (isProcessing) return 'Transaction is being processed';
    if (isOnHold) return 'Transaction is on hold. Please contact support';
    return 'Status: ${status.toUpperCase()}';
  }

  String get statusLabel {
    if (isFailed) return 'Failure Reason';
    if (isSuccess && failureReason.isNotEmpty) return 'Status Message';
    if (isProcessing) return 'Current Status';
    if (isOnHold) return 'Hold Info';
    return 'Message';
  }

  Color get statusColor {
    if (isSuccess) return const Color(0xFF10B981);
    if (isFailed) return const Color(0xFFEF4444);
    if (isProcessing) return const Color(0xFF8B5CF6);
    if (isOnHold) return const Color(0xFFF59E0B);
    return const Color(0xFF6B7280);
  }

  IconData get statusIcon {
    if (isSuccess) return Iconsax.tick_circle;
    if (isFailed) return Iconsax.close_circle;
    if (isProcessing) return Iconsax.timer_1;
    if (isOnHold) return Iconsax.clock;
    return Iconsax.info_circle;
  }

  String get statusTitle {
    if (isSuccess) return 'Transaction Successful';
    if (isFailed) return 'Transaction Failed';
    if (isProcessing) return 'Processing...';
    if (isOnHold) return 'On Hold';
    return 'Status: ${status.toUpperCase()}';
  }

  String get statusSubtitle {
    if (isSuccess) return 'Amount Sent Successfully';
    if (isFailed) return 'Transaction could not be completed';
    if (isProcessing) return 'Please wait while we process your transaction';
    if (isOnHold) return 'Please contact customer support';
    return 'Unknown status';
  }
}

class DmtReceiptScreen extends StatefulWidget {
  final DmtReceiptModel receipt;

  const DmtReceiptScreen({Key? key, required this.receipt}) : super(key: key);

  @override
  State<DmtReceiptScreen> createState() => _DmtReceiptScreenState();
}

class _DmtReceiptScreenState extends State<DmtReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isDownloading = false;
  bool _isSharing = false;

  DmtReceiptModel get receipt => widget.receipt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Payment Confirmation',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: const Color(0xFF1E293B)),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _isSharing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF64748B)))
                : const Icon(Iconsax.share, color: Color(0xFF64748B), size: 20),
            onPressed: _isSharing ? null : () => _shareReceipt(context),
          ),
          IconButton(
            icon: const Icon(Iconsax.copy, color: Color(0xFF64748B), size: 20),
            onPressed: () => _copyReceiptDetails(context),
          ),
        ],
      ),
      body: RepaintBoundary(
        key: _receiptKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildReceiptCard(),
              const SizedBox(height: 16),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final sc = receipt.statusColor;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sc.withOpacity(0.12),
              border: Border.all(color: sc, width: 2.5),
            ),
            child: receipt.isProcessing
                ? Padding(
              padding: const EdgeInsets.all(18),
              child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(sc)),
            )
                : Icon(receipt.statusIcon, color: sc, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            receipt.statusTitle,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${receipt.amount}',
            style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w800, color: sc, letterSpacing: 1),
          ),
          const SizedBox(height: 6),
          Text(
            receipt.statusSubtitle,
            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          if (receipt.statusMessage.isNotEmpty &&
              (receipt.isFailed || receipt.isProcessing || receipt.isOnHold || (receipt.isSuccess && receipt.failureReason.isNotEmpty))) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sc.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sc.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(receipt.isFailed ? Iconsax.warning_2 : Iconsax.info_circle, size: 18, color: sc),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(receipt.statusLabel, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: sc.withOpacity(0.8))),
                        const SizedBox(height: 3),
                        Text(receipt.statusMessage, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: sc)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReceiptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 16),
          if (receipt.outletName.isNotEmpty || receipt.shopAddress.isNotEmpty || receipt.shopPhone.isNotEmpty) ...[
            if (receipt.outletName.isNotEmpty) _buildOutletRow('Outlet Name', receipt.outletName),
            if (receipt.shopAddress.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildOutletRow('Shop Address', receipt.shopAddress),
            ],
            if (receipt.shopPhone.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildOutletRow('Shop Phone', receipt.shopPhone),
            ],
            const SizedBox(height: 14),
            _buildDivider(),
            const SizedBox(height: 16),
          ],
          if (receipt.senderName.isNotEmpty) ...[
            _buildSenderRow('Sender Name', receipt.senderName),
            const SizedBox(height: 10),
            _buildSenderRow('Sender Mobile', receipt.senderMobile),
            const SizedBox(height: 14),
            _buildDivider(),
            const SizedBox(height: 16),
          ],
          _buildSectionHeader('Beneficiary'),
          const SizedBox(height: 10),
          _buildTable([
            _buildTableRow('Name', receipt.beneficiaryName, isBold: true),
            _buildTableRow('Bank Name', receipt.bankName),
            _buildTableRow('Account No', receipt.accountNumber, showCopy: true, isHighlight: true),
            if (receipt.beneficiaryMobile.isNotEmpty) _buildTableRow('Mobile No', receipt.beneficiaryMobile),
          ]),
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildSectionHeader('Transaction Summary'),
          const SizedBox(height: 10),
          _buildTransactionSummaryTable(),
          const SizedBox(height: 12),
          _buildTotalRow(),
          const SizedBox(height: 10),
          _buildAmountInWords(),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF008169), Color(0xFF1AA88A)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(Iconsax.money_send, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 12),
        Text(
          receipt.merchantName,
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B), letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF1AA88A).withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1AA88A).withOpacity(0.2)),
          ),
          child: Text(
            'Payment Confirmation',
            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1AA88A)),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '${receipt.formattedDateShort}  ${receipt.formattedTime}',
          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF1AA88A),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.grey.shade200,
    );
  }

  Widget _buildOutletRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  Widget _buildSenderRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast) const Divider(color: Color(0xFFE2E8F0), height: 0.5, thickness: 0.5),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTableRow(String label, String value, {Color? valueColor, bool showCopy = false, bool isHighlight = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: isHighlight ? 13 : 12,
                      fontWeight: isBold ? FontWeight.w700 : (isHighlight ? FontWeight.w600 : FontWeight.w500),
                      color: valueColor ?? const Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (showCopy) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label copied', style: const TextStyle(fontSize: 12)),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Iconsax.copy, size: 12, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSummaryTable() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1AA88A).withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'TID/Type/UTR',
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1AA88A)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Amount',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1AA88A)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1AA88A)),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        receipt.transactionId,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${receipt.transferMode} / ${receipt.utrNumber}',
                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    '₹${receipt.amount}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: receipt.statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: receipt.statusColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        receipt.status.toUpperCase(),
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: receipt.statusColor),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1AA88A).withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1AA88A).withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Amount',
            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
          ),
          Text(
            '₹${receipt.amount}',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1AA88A)),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInWords() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            'Amount (In Words) : ',
            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              _numberToWords(int.parse(receipt.amount)),
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _numberToWords(int number) {
    if (number == 0) return 'Zero';
    final units = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine'];
    final teens = ['Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
    final tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
    String convert(int n) {
      if (n < 10) return units[n];
      if (n < 20) return teens[n - 10];
      if (n < 100) {
        final t = tens[n ~/ 10];
        final u = units[n % 10];
        return u.isEmpty ? t : '$t $u';
      }
      if (n < 1000) {
        final h = units[n ~/ 100];
        final rest = n % 100;
        return rest == 0 ? '$h Hundred' : '$h Hundred ${convert(rest)}';
      }
      if (n < 100000) {
        final t = n ~/ 1000;
        final rest = n % 1000;
        return rest == 0 ? '${convert(t)} Thousand' : '${convert(t)} Thousand ${convert(rest)}';
      }
      if (n < 10000000) {
        final l = n ~/ 100000;
        final rest = n % 100000;
        return rest == 0 ? '${convert(l)} Lakh' : '${convert(l)} Lakh ${convert(rest)}';
      }
      return 'Number too large';
    }
    return '${convert(number)} Only';
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.verify, size: 14, color: receipt.statusColor),
            const SizedBox(width: 6),
            Text(
              'This is a computer generated receipt',
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '© 2025 NEOFYN Bharath - All Rights Reserved',
          style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 4),
        Text(
          'This is a system generated Receipt. Hence no seal or signature required.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFFCBD5E1)),
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
            onPressed: _isDownloading ? null : () => _downloadReceipt(context),
            icon: _isDownloading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Iconsax.document_download, size: 18),
            label: Text(_isDownloading ? 'Downloading...' : 'Download Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008169),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Iconsax.close_circle, size: 18),
            label: const Text('Close'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FutureBuilder<Directory>(
          future: _getDmtFolderPath(),
          builder: (context, snapshot) {
            String pathDisplay = 'App Storage/NEOFYN/DMT/';

            if (snapshot.hasData) {
              String fullPath = snapshot.data!.path;
              if (fullPath.contains('/storage/emulated/0/')) {
                pathDisplay = fullPath.replaceAll('/storage/emulated/0/', 'Internal Storage/');
              } else if (fullPath.contains('/Android/data/')) {
                pathDisplay = 'App Storage/NEOFYN/DMT/';
              } else {
                pathDisplay = fullPath;
              }
            }

            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Iconsax.folder_2, color: Color(0xFF94A3B8), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Receipts saved to:\n$pathDisplay',
                      style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<List<Directory>?> getExternalCacheDirectories() async {
    if (!Platform.isAndroid) return null;
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) return [extDir];
    } catch (e) {
      debugPrint('External cache error: $e');
    }
    return null;
  }

  Future<Directory> _getDmtFolderPath() async {
    Directory? directory;

    if (Platform.isAndroid) {
      bool hasManageStorage = false;
      try {
        hasManageStorage = await Permission.manageExternalStorage.isGranted;
      } catch (e) {
        hasManageStorage = false;
      }

      if (hasManageStorage) {
        final publicPaths = [
          '/storage/emulated/0/Documents/NEOFYN/DMT',
          '/storage/emulated/0/Download/NEOFYN/DMT',
        ];

        for (final path in publicPaths) {
          try {
            final dir = Directory(path);
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            final testFile = File('${dir.path}/.write_test');
            await testFile.writeAsString('test');
            await testFile.delete();
            debugPrint('✅ Using public directory: $path');
            return dir;
          } catch (e) {
            debugPrint('⚠️ Cannot use public path $path: $e');
          }
        }
      }

      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          directory = Directory('${extDir.path}/NEOFYN/DMT');
          if (!await directory!.exists()) {
            await directory.create(recursive: true);
          }
          final testFile = File('${directory.path}/.write_test');
          await testFile.writeAsString('test');
          await testFile.delete();
          debugPrint('✅ Using external storage directory: ${directory.path}');
          return directory;
        }
      } catch (e) {
        debugPrint('⚠️ External storage failed: $e');
      }

      try {
        final externalDirs = await getExternalCacheDirectories();
        if (externalDirs != null && externalDirs.isNotEmpty) {
          final parentDir = externalDirs.first.parent;
          directory = Directory('$parentDir/NEOFYN/DMT');
          if (!await directory!.exists()) {
            await directory.create(recursive: true);
          }
          debugPrint('✅ Using app external storage: ${directory.path}');
          return directory;
        }
      } catch (e) {
        debugPrint('⚠️ App external storage failed: $e');
      }
    }

    try {
      final appDir = await getApplicationDocumentsDirectory();
      directory = Directory('${appDir.path}/NEOFYN/DMT');
      if (!await directory!.exists()) {
        await directory.create(recursive: true);
      }
      debugPrint('📁 Using app internal storage: ${directory.path}');
    } catch (e) {
      directory = Directory('${Directory.systemTemp.path}/NEOFYN/DMT');
      if (!await directory!.exists()) {
        await directory.create(recursive: true);
      }
      debugPrint('⚠️ Using temp directory: ${directory.path}');
    }

    return directory;
  }

  Future<File> _generatePdf() async {
    final pdf = pw.Document();
    final sc = receipt.statusColor;

    PdfColor toPdfColor(Color color) => PdfColor.fromInt(color.value);

    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();
    final fontSemiBold = await PdfGoogleFonts.poppinsSemiBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Container(
                      width: 60,
                      height: 60,
                      decoration: pw.BoxDecoration(
                        color: toPdfColor(const Color(0xFF008169)),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
                      ),
                      child: pw.Center(
                        child: pw.Text('NB', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: fontBold)),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(receipt.merchantName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: fontBold)),
                    pw.SizedBox(height: 2),
                    pw.Text('Payment Confirmation', style: pw.TextStyle(fontSize: 11, color: toPdfColor(const Color(0xFF1AA88A)), font: fontSemiBold)),
                    pw.SizedBox(height: 4),
                    pw.Text('${receipt.formattedDateShort}  ${receipt.formattedTime}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              if (receipt.outletName.isNotEmpty) ...[
                pw.Row(
                  children: [
                    pw.SizedBox(width: 100, child: pw.Text('Outlet Name :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))),
                    pw.Expanded(child: pw.Text(receipt.outletName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold))),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],

              pw.Row(
                children: [
                  pw.SizedBox(width: 100, child: pw.Text('Sender Name :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))),
                  pw.Expanded(child: pw.Text(receipt.senderName.isNotEmpty ? receipt.senderName : receipt.remitterName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold))),
                ],
              ),
              pw.SizedBox(height: 4),

              pw.Row(
                children: [
                  pw.SizedBox(width: 100, child: pw.Text('Beneficiary :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))),
                  pw.Expanded(child: pw.Text(receipt.beneficiaryName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold))),
                ],
              ),
              pw.SizedBox(height: 4),

              pw.Row(
                children: [
                  pw.SizedBox(width: 100, child: pw.Text('Bank Name :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))),
                  pw.Expanded(child: pw.Text(receipt.bankName, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold))),
                ],
              ),
              pw.SizedBox(height: 4),

              if (receipt.beneficiaryMobile.isNotEmpty) ...[
                pw.Row(
                  children: [
                    pw.SizedBox(width: 100, child: pw.Text('Mobile No :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))),
                    pw.Expanded(child: pw.Text(receipt.beneficiaryMobile, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold))),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],

              if (receipt.senderMobile.isNotEmpty) ...[
                pw.Row(
                  children: [
                    pw.SizedBox(width: 100, child: pw.Text('Sender Mobile :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))),
                    pw.Expanded(child: pw.Text(receipt.senderMobile, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold))),
                  ],
                ),
                pw.SizedBox(height: 4),
              ],

              pw.Row(
                children: [
                  pw.SizedBox(width: 100, child: pw.Text('Account No :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))),
                  pw.Expanded(child: pw.Text(receipt.accountNumber, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold))),
                ],
              ),
              pw.SizedBox(height: 4),

              pw.Row(
                children: [
                  pw.SizedBox(width: 100, child: pw.Text('Date & Time :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font))),
                  pw.Expanded(child: pw.Text(receipt.formattedDate, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold))),
                ],
              ),
              pw.SizedBox(height: 16),

              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 10),

              pw.Text('Transaction Summary', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: fontBold)),
              pw.SizedBox(height: 8),

              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: toPdfColor(const Color(0xFF1AA88A).withOpacity(0.08)),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 3, child: pw.Text('TID/Type/UTR', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: toPdfColor(const Color(0xFF1AA88A)), font: fontBold))),
                    pw.Expanded(flex: 1, child: pw.Text('Amount', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: toPdfColor(const Color(0xFF1AA88A)), font: fontBold))),
                    pw.Expanded(flex: 1, child: pw.Text('Status', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: toPdfColor(const Color(0xFF1AA88A)), font: fontBold))),
                  ],
                ),
              ),

              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(receipt.transactionId, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontBold)),
                          pw.Text('${receipt.transferMode} / ${receipt.utrNumber}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600, font: font)),
                        ],
                      ),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text('₹${receipt.amount}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: fontBold)),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Container(
                        alignment: pw.Alignment.centerRight,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: pw.BoxDecoration(
                            color: toPdfColor(receipt.statusColor.withOpacity(0.12)),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                            border: pw.Border.all(color: toPdfColor(receipt.statusColor.withOpacity(0.2)), width: 0.5),
                          ),
                          child: pw.Text(
                            receipt.status.toUpperCase(),
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: toPdfColor(receipt.statusColor), font: fontBold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 8),

              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: toPdfColor(const Color(0xFF1AA88A).withOpacity(0.06)),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  border: pw.Border.all(color: toPdfColor(const Color(0xFF1AA88A).withOpacity(0.15)), width: 0.5),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Amount : ₹${receipt.amount}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: fontBold)),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),

              pw.Row(
                children: [
                  pw.Text('Amount (In Words) : ', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600, font: font)),
                  pw.Expanded(child: pw.Text(_numberToWords(int.parse(receipt.amount)), style: pw.TextStyle(fontSize: 9, font: fontSemiBold))),
                ],
              ),
              pw.SizedBox(height: 16),

              pw.Divider(color: PdfColors.grey300, thickness: 0.5),
              pw.SizedBox(height: 8),

              pw.Center(child: pw.Text('© 2025 NEOFYN Bharath - All Rights Reserved', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, font: font))),
              pw.SizedBox(height: 2),
              pw.Center(child: pw.Text('This is a system generated Receipt. Hence no seal or signature required.', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, font: font))),
            ],
          );
        },
      ),
    );

    final dir = await _getDmtFolderPath();
    final fileName = 'DMT_Receipt_${receipt.transactionId}_${receipt.fileNameDate}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> _downloadReceipt(BuildContext context) async {
    setState(() => _isDownloading = true);

    try {
      if (Platform.isAndroid) {
        try {
          final status = await Permission.manageExternalStorage.status;
          if (!status.isGranted) {
            await Permission.manageExternalStorage.request();
          }
        } catch (e) {
          debugPrint('Permission request skipped: $e');
        }
      }

      final file = await _generatePdf();
      setState(() => _isDownloading = false);

      if (mounted) {
        String displayPath = file.path;
        if (displayPath.contains('/storage/emulated/0/')) {
          displayPath = displayPath.replaceAll('/storage/emulated/0/', 'Internal Storage/');
        } else if (displayPath.contains('/data/data/')) {
          displayPath = 'App Storage/DMT Receipts';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 20),
                  SizedBox(width: 8),
                  Expanded(child: Text('Receipt downloaded successfully')),
                ]),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '📁 $displayPath',
                    style: GoogleFonts.poppins(fontSize: 9, color: Colors.white70),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A1F1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Open',
              textColor: const Color(0xFF1AA88A),
              onPressed: () {
                try {
                  OpenFile.open(file.path);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cannot open file: $e'),
                      backgroundColor: const Color(0xFF1A1F1A),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      debugPrint('❌ Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Iconsax.close_circle, color: Color(0xFFEF4444), size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text('Download failed')),
            ]),
            backgroundColor: const Color(0xFF1A1F1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _copyReceiptDetails(BuildContext context) {
    final details = '''
╔══════════════════════════════════╗
║     ${receipt.merchantName}     ║
║     Payment Confirmation        ║
╚══════════════════════════════════╝

${receipt.outletName.isNotEmpty ? 'Outlet Name: ${receipt.outletName}\n' : ''}${receipt.shopAddress.isNotEmpty ? 'Shop Address: ${receipt.shopAddress}\n' : ''}${receipt.shopPhone.isNotEmpty ? 'Shop Phone: ${receipt.shopPhone}\n' : ''}${receipt.senderName.isNotEmpty ? 'Sender Name: ${receipt.senderName}\n' : ''}${receipt.senderMobile.isNotEmpty ? 'Sender Mobile: ${receipt.senderMobile}\n' : ''}
Beneficiary: ${receipt.beneficiaryName}
Bank Name: ${receipt.bankName}
Account No: ${receipt.accountNumber}
${receipt.beneficiaryMobile.isNotEmpty ? 'Mobile No: ${receipt.beneficiaryMobile}\n' : ''}
Transaction ID: ${receipt.transactionId}
${receipt.utrNumber.isNotEmpty ? 'UTR Number: ${receipt.utrNumber}\n' : ''}Transfer Mode: ${receipt.transferMode}
Date & Time: ${receipt.formattedDate}
Status: ${receipt.status.toUpperCase()}
Amount: ₹${receipt.amount}
Amount (In Words): ${_numberToWords(int.parse(receipt.amount))}
${receipt.statusMessage.isNotEmpty ? '\n${receipt.statusLabel}: ${receipt.statusMessage}' : ''}
────────────────────────────────────
Generated by ${receipt.merchantName}
This is a system generated Receipt
''';
    Clipboard.setData(ClipboardData(text: details));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 20), SizedBox(width: 8), Text('Receipt copied')]),
        backgroundColor: const Color(0xFF1A1F1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _shareReceipt(BuildContext context) async {
    setState(() => _isSharing = true);
    try {
      final file = await _generatePdf();
      await Share.shareXFiles([XFile(file.path)], text: 'DMT Transaction Receipt - ${receipt.transactionId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: const Color(0xFF1A1F1A)),
        );
      }
    } finally {
      setState(() => _isSharing = false);
    }
  }
}