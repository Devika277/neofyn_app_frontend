// lib/screens/receipt_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/receipt_model.dart';

class ReceiptScreen extends StatefulWidget {
  final ReceiptModel receipt;

  const ReceiptScreen({Key? key, required this.receipt}) : super(key: key);

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  bool _isGeneratingPDF = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        title: Text(
          'Transaction Receipt',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0A0E0A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white70),
            onPressed: () => _showReceiptOptions(context),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, color: Colors.white70),
            onPressed: () {
              // Copy receipt details to clipboard
              final details = _getReceiptText();
              Clipboard.setData(ClipboardData(text: details));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Receipt details copied!',
                      style: GoogleFonts.inter(fontSize: 13)),
                  backgroundColor: const Color(0xFF1A1F1A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: _buildReceiptCard(),
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }

  String _getReceiptText() {
    final buffer = StringBuffer();
    buffer.writeln('Neofyn Bharath - Transaction Receipt');
    buffer.writeln('Type: ${widget.receipt.typeLabel}');
    buffer.writeln('Status: ${widget.receipt.displayStatus}');
    buffer.writeln('RRN: ${widget.receipt.rrn ?? "N/A"}');
    buffer.writeln('Date: ${_formatDate(widget.receipt.transactionDateTime)}');

    if (widget.receipt.isAmountRequired && widget.receipt.transactionAmount != '0') {
      buffer.writeln('Amount: ₹${widget.receipt.transactionAmount}');
    }

    if (widget.receipt.availableBalance != null &&
        widget.receipt.availableBalance != '0' &&
        widget.receipt.availableBalance!.isNotEmpty) {
      buffer.writeln('Balance: ₹${widget.receipt.availableBalance}');
    }

    buffer.writeln('Bank IIN: ${widget.receipt.bankIIN}');
    buffer.writeln('Aadhaar: ${_maskAadhaar(widget.receipt.aadhaarNumber ?? '')}');

    return buffer.toString();
  }

  Widget _buildReceiptCard() {
    final isSuccess = widget.receipt.isSuccess;
    final statusColor =
    isSuccess ? const Color(0xFF2ECC71) : const Color(0xFFEF4444);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Status Icon
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.1),
                    border:
                    Border.all(color: statusColor.withOpacity(0.3), width: 2),
                  ),
                  child: Icon(
                    isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 48,
                    color: statusColor,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            'Neofyn Bharath',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.receipt.typeLabel,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Dashed line
          _buildDashedLine(),
          const SizedBox(height: 20),

          // Status
          _buildDetailRow(
            'Status',
            widget.receipt.displayStatus,
            valueColor: statusColor,
          ),

          // RRN (always show)
          if (widget.receipt.rrn != null && widget.receipt.rrn!.isNotEmpty)
            _buildDetailRow('RRN', widget.receipt.rrn!),

          // Transaction Ref ID (show only if available)
          if (widget.receipt.txnRefId != null &&
              widget.receipt.txnRefId!.isNotEmpty &&
              widget.receipt.txnRefId != 'N/A' &&
              widget.receipt.txnRefId != widget.receipt.rrn)
            _buildDetailRow('Transaction Ref ID', widget.receipt.txnRefId!),

          // Merchant Ref ID (show only if available and not empty)
          if (widget.receipt.merchantRefId.isNotEmpty &&
              widget.receipt.merchantRefId != 'N/A' &&
              widget.receipt.merchantRefId != widget.receipt.rrn)
            _buildDetailRow('Merchant Ref ID', widget.receipt.merchantRefId),

          // Merchant ID (show only if available and not empty)
          if (widget.receipt.merchantId.isNotEmpty &&
              widget.receipt.merchantId != 'N/A')
            _buildDetailRow('Merchant ID', widget.receipt.merchantId),

          // Date & Time
          _buildDetailRow(
            'Date & Time',
            _formatDate(widget.receipt.transactionDateTime),
          ),

          // Amount Section - Only for CW (Cash Withdrawal)
          if (widget.receipt.isAmountRequired &&
              widget.receipt.transactionAmount != '0' &&
              widget.receipt.transactionAmount != '0.00') ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Text(
                    'Transaction Amount',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹ ${widget.receipt.transactionAmount}',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Balance Section - Only for BE (Balance Enquiry) and MS (Mini Statement)
          if ((widget.receipt.transactionType == 'BE' ||
              widget.receipt.transactionType == 'MS') &&
              widget.receipt.availableBalance != null &&
              widget.receipt.availableBalance != '0' &&
              widget.receipt.availableBalance != '0.00' &&
              widget.receipt.availableBalance!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1AA88A).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF1AA88A).withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Available Balance',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹ ${widget.receipt.availableBalance}',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1AA88A),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Bank Details
          _buildDetailRow('Bank IIN', widget.receipt.bankIIN),

          if (widget.receipt.bankName != null &&
              widget.receipt.bankName!.isNotEmpty &&
              widget.receipt.bankName != 'N/A' &&
              widget.receipt.bankName != 'Not Available')
            _buildDetailRow('Bank Name', widget.receipt.bankName!),

          // Aadhaar (masked)
          if (widget.receipt.aadhaarNumber != null &&
              widget.receipt.aadhaarNumber!.isNotEmpty)
            _buildDetailRow(
              'Aadhaar',
              _maskAadhaar(widget.receipt.aadhaarNumber!),
            ),

          // Mobile
          if (widget.receipt.mobileNumber.isNotEmpty &&
              widget.receipt.mobileNumber != 'N/A')
            _buildDetailRow('Mobile', widget.receipt.mobileNumber),

          // Device Info (show only if available)
          if (widget.receipt.deviceUsed != null &&
              widget.receipt.deviceUsed!.isNotEmpty &&
              widget.receipt.deviceUsed != 'N/A' &&
              widget.receipt.deviceUsed != 'Not Available')
            _buildDetailRow('Device', widget.receipt.deviceUsed!),

          // Provider
          if (widget.receipt.udf1 != null && widget.receipt.udf1!.isNotEmpty)
            _buildDetailRow('Provider', widget.receipt.udf1!),

          // Pipe
          if (widget.receipt.pipe.isNotEmpty && widget.receipt.pipe != '1')
            _buildDetailRow('Pipe', widget.receipt.pipe),

          // NPCI Message
          if (widget.receipt.npciMessage != null &&
              widget.receipt.npciMessage!.isNotEmpty &&
              widget.receipt.npciMessage != 'N/A') ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.receipt.npciMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: statusColor,
                  fontSize: 12,
                ),
              ),
            ),
          ],

          // Status Description
          if (widget.receipt.statusDescription != null &&
              widget.receipt.statusDescription!.isNotEmpty &&
              widget.receipt.statusDescription != widget.receipt.npciMessage)
            _buildDetailRow(
              'Message',
              widget.receipt.statusDescription!,
              valueColor: statusColor,
            ),

          // UDF fields (show only if available)
          if (widget.receipt.udf2 != null && widget.receipt.udf2!.isNotEmpty)
            _buildDetailRow('UDF2', widget.receipt.udf2!),
          if (widget.receipt.udf3 != null && widget.receipt.udf3!.isNotEmpty)
            _buildDetailRow('UDF3', widget.receipt.udf3!),

          // ✅ MINI STATEMENT TABLE
          if (widget.receipt.isMiniStatement) ...[
            const SizedBox(height: 20),
            _buildDashedLine(),
            const SizedBox(height: 16),
            _buildMiniStatementSection(),
            const SizedBox(height: 12),
            _buildDashedLine(),
          ],

          const SizedBox(height: 20),

          // Footer
          Text(
            'Thank you for using Neofyn Bharath',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white60,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Powered by Neofyn Bharath',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: Colors.white38,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Generated on ${_formatDate(DateTime.now().toString())}',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFFE67E22),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              'Transaction History',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE67E22),
              ),
            ),
            const Spacer(),
            Text(
              '${widget.receipt.miniStatementEntries?.length ?? 0} entries',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (widget.receipt.miniStatementEntries == null ||
            widget.receipt.miniStatementEntries!.isEmpty) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No transaction history available',
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ] else ...[
          // Table Container with rounded corners
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withOpacity(0.06),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Table Header
                Container(
                  padding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE67E22).withOpacity(0.1),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Text(
                          'Date',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        flex: 1,
                        child: Text(
                          'Txn',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        flex: 2,
                        child: Text(
                          'Amount',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        flex: 4,
                        child: Text(
                          'Narration',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),

                // Table Rows
                ...widget.receipt.miniStatementEntries!.asMap().entries.map(
                      (entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isLast = index ==
                        widget.receipt.miniStatementEntries!.length - 1;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: index.isEven
                            ? Colors.white.withOpacity(0.02)
                            : Colors.transparent,
                        border: isLast
                            ? null
                            : Border(
                          bottom: BorderSide(
                              color: Colors.white.withOpacity(0.04)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.date,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 3, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isCredit
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                item.isCredit ? 'Cr' : 'Dr',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                  item.isCredit ? Colors.green : Colors.red,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₹${item.amount}',
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: item.isCredit
                                    ? Colors.green
                                    : Colors.red,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            flex: 4,
                            child: Text(
                              item.narration.trim(),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDetailRow(
      String label,
      String value, {
        Color? valueColor,
        TextStyle? valueStyle,
      }) {
    // Skip rendering if value is empty or N/A
    if (value.isEmpty || value == 'N/A' || value == 'Not Available') {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white60,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyle ??
                  GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.white,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedLine() {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: DashedLinePainter(),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E0A),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showReceiptOptions(context),
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text('Download / Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56DB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, size: 20),
              label: const Text('Close'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── BOTTOM SHEET: RECEIPT OPTIONS ──────────────────────────
  void _showReceiptOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F1A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Receipt Options',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download, print or share your receipt',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildOptionButton(
                  icon: Icons.download_rounded,
                  label: 'Download\nPDF',
                  color: const Color(0xFF1A56DB),
                  onTap: () {
                    Navigator.pop(context);
                    _downloadPDF();
                  },
                ),
                _buildOptionButton(
                  icon: Icons.print_rounded,
                  label: 'Print\nReceipt',
                  color: const Color(0xFF3498DB),
                  onTap: () {
                    Navigator.pop(context);
                    _printReceipt();
                  },
                ),
                _buildOptionButton(
                  icon: Icons.share_rounded,
                  label: 'Share\nPDF',
                  color: const Color(0xFFE67E22),
                  onTap: () {
                    Navigator.pop(context);
                    _sharePDF();
                  },
                ),
                _buildOptionButton(
                  icon: Icons.copy_rounded,
                  label: 'Copy\nDetails',
                  color: const Color(0xFF9B59B6),
                  onTap: () {
                    Navigator.pop(context);
                    final details = _getReceiptText();
                    Clipboard.setData(ClipboardData(text: details));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Receipt details copied!',
                            style: GoogleFonts.inter(fontSize: 13)),
                        backgroundColor: const Color(0xFF1A1F1A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── PDF GENERATION AND DOWNLOAD ─────────────────────────────
  Future<void> _downloadPDF() async {
    setState(() => _isGeneratingPDF = true);
    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Storage permission required to save PDF'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }
      }

      final pdf = await _generatePDF();

      // Get the Downloads directory
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        if (await _requestStoragePermission()) {
          // Try common downloads paths
          final paths = [
            '/storage/emulated/0/Download',
            '/storage/emulated/0/Downloads',
            '/sdcard/Download',
            '/sdcard/Downloads',
          ];

          for (final path in paths) {
            final dir = Directory(path);
            if (await dir.exists()) {
              downloadsDir = dir;
              break;
            }
          }

          if (downloadsDir == null) {
            final directory = await getExternalStorageDirectory();
            if (directory != null) {
              final parentDir = Directory(directory.path.replaceAll(
                  '/Android/data/${await _getPackageName()}/files', ''));
              downloadsDir = Directory('${parentDir.path}/Download');
              if (!await downloadsDir!.exists()) {
                downloadsDir = Directory('${parentDir.path}/Downloads');
              }
            }
          }
        }
      }

      downloadsDir ??= await getApplicationDocumentsDirectory();

      // Create Neofyn receipts subfolder
      final receiptDir = Directory('${downloadsDir!.path}/Neofyn_Receipts');
      if (!await receiptDir.exists()) {
        await receiptDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'Neofyn_Receipt_${widget.receipt.merchantRefId}_$timestamp.pdf';
      final file = File('${receiptDir.path}/$fileName');

      await file.writeAsBytes(await pdf.save());

      final fileExists = await file.exists();
      final fileSize = fileExists ? await file.length() : 0;

      debugPrint('✅ PDF saved successfully!');
      debugPrint('📁 Path: ${file.path}');
      debugPrint('📏 Size: $fileSize bytes');
      debugPrint('📄 Exists: $fileExists');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF2ECC71), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PDF saved successfully!',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Find in Downloads/Neofyn_Receipts',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A1F1A),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OPEN',
              textColor: const Color(0xFF2ECC71),
              onPressed: () {
                _openPdfFile(file.path);
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Error saving PDF: ${e.toString()}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A1F1A),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _isGeneratingPDF = false);
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      if (await _getAndroidVersion() >= 33) {
        return true;
      } else if (await _getAndroidVersion() >= 29) {
        return true;
      } else {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        return status.isGranted;
      }
    }
    return true;
  }

  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      try {
        final rawVersion =
        await Process.run('getprop', ['ro.build.version.sdk']);
        return int.tryParse(rawVersion.stdout.toString().trim()) ?? 29;
      } catch (e) {
        return 29;
      }
    }
    return 29;
  }

  Future<String> _getPackageName() async {
    return 'com.neofyn.bharath'; // Replace with your actual package name
  }

  void _openPdfFile(String filePath) {
    Share.shareXFiles([XFile(filePath)], text: 'Open PDF');
  }

  Future<void> _printReceipt() async {
    try {
      final pdf = await _generatePDF();
      await Printing.layoutPdf(
        onLayout: (format) async => pdf.save(),
        name: 'Neofyn_Receipt_${widget.receipt.merchantRefId}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Print error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _sharePDF() async {
    try {
      final pdf = await _generatePDF();

      final directory = await getApplicationDocumentsDirectory();
      final receiptDir = Directory('${directory.path}/Neofyn_Receipts');

      if (!await receiptDir.exists()) {
        await receiptDir.create(recursive: true);
      }

      final fileName =
          'Neofyn_Receipt_${widget.receipt.merchantRefId}.pdf';
      final file = File('${receiptDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Neofyn Bharath Transaction Receipt - ${widget.receipt.typeLabel}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final isSuccess = widget.receipt.isSuccess;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[
            // Header
            pw.Text(
              'Neofyn Bharath',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'AEPS Services',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              widget.receipt.typeLabel,
              style: const pw.TextStyle(fontSize: 12),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              isSuccess ? 'SUCCESS' : 'FAILED',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: isSuccess ? PdfColors.green : PdfColors.red,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Details - only show if available
            if (widget.receipt.rrn != null &&
                widget.receipt.rrn!.isNotEmpty)
              _pdfRow('RRN', widget.receipt.rrn!),

            if (widget.receipt.txnRefId != null &&
                widget.receipt.txnRefId!.isNotEmpty &&
                widget.receipt.txnRefId != 'N/A')
              _pdfRow('Txn Ref ID', widget.receipt.txnRefId!),

            if (widget.receipt.merchantRefId.isNotEmpty &&
                widget.receipt.merchantRefId != 'N/A')
              _pdfRow('Merchant Ref ID', widget.receipt.merchantRefId),

            if (widget.receipt.merchantId.isNotEmpty &&
                widget.receipt.merchantId != 'N/A')
              _pdfRow('Merchant ID', widget.receipt.merchantId),

            _pdfRow(
              'Date & Time',
              _formatDate(widget.receipt.transactionDateTime),
            ),

            if (widget.receipt.isAmountRequired &&
                widget.receipt.transactionAmount != '0')
              _pdfRow('Amount', 'Rs.${widget.receipt.transactionAmount}'),

            if (widget.receipt.availableBalance != null &&
                widget.receipt.availableBalance != '0' &&
                widget.receipt.availableBalance!.isNotEmpty)
              _pdfRow('Balance', 'Rs.${widget.receipt.availableBalance}'),

            _pdfRow('Bank IIN', widget.receipt.bankIIN),

            if (widget.receipt.aadhaarNumber != null &&
                widget.receipt.aadhaarNumber!.isNotEmpty)
              _pdfRow(
                'Aadhaar',
                _maskAadhaar(widget.receipt.aadhaarNumber!),
              ),

            if (widget.receipt.mobileNumber.isNotEmpty &&
                widget.receipt.mobileNumber != 'N/A')
              _pdfRow('Mobile', widget.receipt.mobileNumber),

            if (widget.receipt.npciMessage != null &&
                widget.receipt.npciMessage!.isNotEmpty)
              _pdfRow('Message', widget.receipt.npciMessage!),
          ];

          // Mini Statement Table in PDF
          if (widget.receipt.isMiniStatement &&
              widget.receipt.miniStatementEntries != null &&
              widget.receipt.miniStatementEntries!.isNotEmpty) {
            widgets.addAll([
              pw.SizedBox(height: 8),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                'Transaction History',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              // Table Header
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('Date',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Expanded(
                      flex: 1,
                      child: pw.Text('Txn',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.center),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text('Amount',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text('Narration',
                          style: pw.TextStyle(
                              fontSize: 8, fontWeight: pw.FontWeight.bold),
                          textAlign: pw.TextAlign.right),
                    ),
                  ],
                ),
              ),
              // Table Rows
              ...widget.receipt.miniStatementEntries!.map(
                    (entry) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(
                          color: PdfColors.grey300, width: 0.5),
                    ),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(entry.date,
                            style: const pw.TextStyle(fontSize: 7)),
                      ),
                      pw.Expanded(
                        flex: 1,
                        child: pw.Text(
                          entry.txnType,
                          style: pw.TextStyle(
                            fontSize: 7,
                            color: entry.isCredit
                                ? PdfColors.green
                                : PdfColors.red,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text('Rs.${entry.amount}',
                            style: const pw.TextStyle(fontSize: 7),
                            textAlign: pw.TextAlign.right),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(entry.narration.trim(),
                            style: const pw.TextStyle(fontSize: 7),
                            textAlign: pw.TextAlign.right,
                            maxLines: 1),
                      ),
                    ],
                  ),
                ),
              ),
            ]);
          }

          // Footer
          widgets.addAll([
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Thank you for using Neofyn Bharath',
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Powered by Neofyn Bharath',
              style: const pw.TextStyle(fontSize: 8),
            ),
            pw.Text(
              'Generated: ${_formatDate(DateTime.now().toString())}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ]);

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: widgets,
          );
        },
      ),
    );

    return pdf;
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style:
              pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─── UTILITY METHODS ────────────────────────────────────────
  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  String _maskAadhaar(String aadhaar) {
    if (aadhaar.isEmpty) return 'XXXXXXXXXXXX';
    if (aadhaar.length <= 4) return 'XXXX$aadhaar';
    return 'XXXX XXXX ${aadhaar.substring(aadhaar.length - 4)}';
  }
}

// ─── DASHED LINE PAINTER ──────────────────────────────────────
class DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
          Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}