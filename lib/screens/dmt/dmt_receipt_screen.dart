// lib/screens/dmt_receipt_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
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
    if (isSuccess) return 'Sent Successfully';
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
            icon: _isSharing
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)
            )
                : const Icon(Iconsax.share, color: Colors.white70, size: 20),
            onPressed: _isSharing ? null : () => _shareReceipt(context),
          ),
          IconButton(
            icon: const Icon(Iconsax.copy, color: Colors.white70, size: 20),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A342A)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sc.withOpacity(0.1),
              border: Border.all(color: sc, width: 2),
            ),
            child: receipt.isProcessing
                ? Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(sc),
              ),
            )
                : Icon(
              receipt.statusIcon,
              color: sc,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            receipt.statusTitle,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${receipt.amount}',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: sc,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            receipt.statusSubtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.white54,
            ),
            textAlign: TextAlign.center,
          ),
          if (receipt.statusMessage.isNotEmpty &&
              (receipt.isFailed || receipt.isProcessing || receipt.isOnHold ||
                  (receipt.isSuccess && receipt.failureReason.isNotEmpty))) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: sc.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sc.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    receipt.isFailed ? Iconsax.warning_2 : Iconsax.info_circle,
                    size: 16,
                    color: sc,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          receipt.statusLabel,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: sc.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          receipt.statusMessage,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sc,
                          ),
                        ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A342A)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(color: Color(0xFF2A342A), height: 24),
          _buildSectionTitle('Transaction Details'),
          _buildDetailRow('Transaction ID', receipt.transactionId, showCopy: true),
          if (receipt.utrNumber.isNotEmpty && receipt.utrNumber != 'N/A')
            _buildDetailRow('UTR Number', receipt.utrNumber, showCopy: true, isHighlight: true),
          _buildDetailRow('Transfer Mode', receipt.transferMode),
          _buildDetailRow('Date', receipt.formattedDate),
          _buildDetailRow('Status', receipt.status.toUpperCase(),
              valueColor: receipt.statusColor, isHighlight: true),
          if (receipt.remark.isNotEmpty)
            _buildDetailRow('Remark', receipt.remark),
          const Divider(color: Color(0xFF2A342A), height: 24),
          _buildSectionTitle('Remitter Details'),
          _buildDetailRow('Name', receipt.remitterName),
          if (receipt.remitterMobile.isNotEmpty)
            _buildDetailRow('Mobile', receipt.remitterMobile),
          const Divider(color: Color(0xFF2A342A), height: 24),
          _buildSectionTitle('Beneficiary Details'),
          _buildDetailRow('Name', receipt.beneficiaryName),
          _buildDetailRow('Account Number', _maskAccount(receipt.accountNumber), showCopy: true),
          _buildDetailRow('Bank', receipt.bankName),
          if (receipt.ifscCode.isNotEmpty)
            _buildDetailRow('IFSC Code', receipt.ifscCode, showCopy: true),
          if (receipt.beneficiaryMobile.isNotEmpty)
            _buildDetailRow('Mobile', receipt.beneficiaryMobile),
          const Divider(color: Color(0xFF2A342A), height: 24),
          _buildSectionTitle('Amount Details'),
          _buildDetailRow('Transfer Amount', '₹${receipt.amount}', isHighlight: true),
          if (receipt.commission.isNotEmpty && receipt.commission != 'null')
            _buildDetailRow('Commission', '₹${receipt.commission}'),
          if (receipt.isFailed && receipt.failureReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              'Failure Reason',
              receipt.failureReason,
              valueColor: const Color(0xFFEF4444),
              isHighlight: true,
            ),
          ],
          if (receipt.isSuccess && receipt.failureReason.isNotEmpty &&
              receipt.failureReason.toLowerCase() != 'transaction successful') ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              'Status Message',
              receipt.failureReason,
              valueColor: const Color(0xFF10B981),
            ),
          ],
          const Divider(color: Color(0xFF2A342A), height: 24),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
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

  Widget _buildDetailRow(String label, String value,
      {Color? valueColor, bool showCopy = false, bool isHighlight = false}) {
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
                      color: valueColor ?? Colors.white,
                    ),
                  ),
                ),
                if (showCopy) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      HapticFeedback.lightImpact();
                    },
                    child: Icon(
                      Iconsax.copy,
                      size: 14,
                      color: Colors.white30,
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

  Widget _buildFooter() {
    final sc = receipt.statusColor;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: sc.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sc),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                receipt.statusIcon,
                size: 14,
                color: sc,
              ),
              const SizedBox(width: 6),
              Text(
                receipt.isSuccess
                    ? 'Verified Transaction'
                    : receipt.isFailed
                    ? 'Failed Transaction'
                    : receipt.isProcessing
                    ? 'Transaction Processing'
                    : receipt.isOnHold
                    ? 'Transaction On Hold'
                    : 'Status: ${receipt.status.toUpperCase()}',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sc,
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
            onPressed: _isDownloading ? null : () => _downloadReceipt(context),
            icon: _isDownloading
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Iconsax.document_download, size: 18),
            label: Text(_isDownloading ? 'Downloading...' : 'Download Receipt'),
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
        const SizedBox(height: 16),
        // Folder path info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Iconsax.folder_2, color: Colors.white38, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Receipts saved to:\nInternal Storage/Documents/NEOFYN Bharath/DMT/',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white38,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _maskAccount(String account) {
    if (account.length <= 4) return account;
    return '${'*' * (account.length - 4)}${account.substring(account.length - 4)}';
  }

  // Get the DMT folder path
  Future<Directory> _getDmtFolderPath() async {
    Directory? directory;

    if (Platform.isAndroid) {
      // For Android 10 and below, use external storage
      // For Android 11+, use app-specific directory or media store
      directory = Directory('/storage/emulated/0/Documents/NEOFYN Bharath/DMT');

      // Check if we can access it, if not fallback to app directory
      if (!await directory.exists()) {
        try {
          await directory.create(recursive: true);
        } catch (e) {
          // Fallback to app documents directory
          final appDir = await getApplicationDocumentsDirectory();
          directory = Directory('${appDir.path}/NEOFYN Bharath/DMT');
        }
      }
    } else {
      // For iOS
      final appDir = await getApplicationDocumentsDirectory();
      directory = Directory('${appDir.path}/NEOFYN Bharath/DMT');
    }

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  // Generate PDF receipt
  Future<File> _generatePdf() async {
    final pdf = pw.Document();
    final sc = receipt.statusColor;

    // Convert Color to PdfColor
    PdfColor _toPdfColor(Color color) {
      return PdfColor.fromInt(color.value);
    }

    // Load a font that supports all characters
    final font = await PdfGoogleFonts.poppinsRegular();
    final fontBold = await PdfGoogleFonts.poppinsBold();
    final fontSemiBold = await PdfGoogleFonts.poppinsSemiBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          // Header
          pw.Center(
            child: pw.Column(
              children: [
                pw.Container(
                  width: 50,
                  height: 50,
                  decoration: pw.BoxDecoration(
                    color: _toPdfColor(const Color(0xFF008169)),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'NB',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        font: fontBold,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  receipt.merchantName,
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    font: fontBold,
                  ),
                ),
                pw.Text(
                  'Digital Money Transfer',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _toPdfColor(const Color(0xFF1AA88A)),
                    font: font,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  '${receipt.formattedDateShort} | ${receipt.formattedTime}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Status Section
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _toPdfColor(sc.withOpacity(0.1)),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
              border: pw.Border.all(color: _toPdfColor(sc), width: 1),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  receipt.statusTitle,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _toPdfColor(sc),
                    font: fontBold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  '₹${receipt.amount}',
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: _toPdfColor(sc),
                    font: fontBold,
                  ),
                ),
                if (receipt.statusMessage.isNotEmpty)
                  pw.Text(
                    receipt.statusMessage,
                    style: pw.TextStyle(fontSize: 10, color: _toPdfColor(sc), font: font),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // Transaction Details
          _buildPdfSection('Transaction Details', fontBold, fontSemiBold, font),
          _buildPdfRow('Transaction ID', receipt.transactionId, fontSemiBold, font),
          if (receipt.utrNumber.isNotEmpty)
            _buildPdfRow('UTR Number', receipt.utrNumber, fontSemiBold, font),
          _buildPdfRow('Transfer Mode', receipt.transferMode, fontSemiBold, font),
          _buildPdfRow('Date', receipt.formattedDate, fontSemiBold, font),
          _buildPdfRow('Status', receipt.status.toUpperCase(), fontSemiBold, font),
          if (receipt.remark.isNotEmpty)
            _buildPdfRow('Remark', receipt.remark, fontSemiBold, font),
          pw.SizedBox(height: 10),

          // Remitter Details
          _buildPdfSection('Remitter Details', fontBold, fontSemiBold, font),
          _buildPdfRow('Name', receipt.remitterName, fontSemiBold, font),
          if (receipt.remitterMobile.isNotEmpty)
            _buildPdfRow('Mobile', receipt.remitterMobile, fontSemiBold, font),
          pw.SizedBox(height: 10),

          // Beneficiary Details
          _buildPdfSection('Beneficiary Details', fontBold, fontSemiBold, font),
          _buildPdfRow('Name', receipt.beneficiaryName, fontSemiBold, font),
          _buildPdfRow('Account Number', _maskAccount(receipt.accountNumber), fontSemiBold, font),
          _buildPdfRow('Bank', receipt.bankName, fontSemiBold, font),
          if (receipt.ifscCode.isNotEmpty)
            _buildPdfRow('IFSC Code', receipt.ifscCode, fontSemiBold, font),
          if (receipt.beneficiaryMobile.isNotEmpty)
            _buildPdfRow('Mobile', receipt.beneficiaryMobile, fontSemiBold, font),
          pw.SizedBox(height: 10),

          // Amount Details
          _buildPdfSection('Amount Details', fontBold, fontSemiBold, font),
          _buildPdfRow('Transfer Amount', '₹${receipt.amount}', fontSemiBold, font),
          if (receipt.commission.isNotEmpty && receipt.commission != 'null')
            _buildPdfRow('Commission', '₹${receipt.commission}', fontSemiBold, font),
          pw.SizedBox(height: 20),

          // Footer
          pw.Center(
            child: pw.Text(
              'This is a computer generated receipt',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500, font: font),
            ),
          ),
          pw.Center(
            child: pw.Text(
              'Generated by ${receipt.merchantName}',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey500, font: font),
            ),
          ),
        ],
      ),
    );

    final dir = await _getDmtFolderPath();
    final fileName = 'DMT_Receipt_${receipt.transactionId}_${receipt.fileNameDate}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _buildPdfSection(String title, pw.Font fontBold, pw.Font fontSemiBold, pw.Font font) {
    return pw.Column(
      children: [
        pw.Row(
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _toPdfColor(const Color(0xFF1AA88A)),
                font: fontBold,
              ),
            ),
            pw.Expanded(
              child: pw.Container(
                height: 1,
                color: PdfColors.grey300,
                margin: const pw.EdgeInsets.only(left: 8),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  PdfColor _toPdfColor(Color color) {
    return PdfColor.fromInt(color.value);
  }

  pw.Widget _buildPdfRow(String label, String value, pw.Font fontSemiBold, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: font),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fontSemiBold),
          ),
        ],
      ),
    );
  }

  // Download receipt as PDF
  Future<void> _downloadReceipt(BuildContext context) async {
    setState(() => _isDownloading = true);

    try {
      // Request storage permission for Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Iconsax.warning_2, color: Color(0xFFF59E0B), size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('Storage permission is required to download receipt')),
                  ],
                ),
                backgroundColor: const Color(0xFF1A1F1A),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Color(0xFF1AA88A),
                  onPressed: () => openAppSettings(),
                ),
              ),
            );
          }
          setState(() => _isDownloading = false);
          return;
        }
      }

      // Generate PDF
      final file = await _generatePdf();

      setState(() => _isDownloading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 8),
                    const Text('Receipt downloaded successfully'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Saved to: Documents/NEOFYN Bharath/DMT/',
                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1A1F1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open',
              textColor: const Color(0xFF1AA88A),
              onPressed: () async {
                try {
                  final result = await OpenFile.open(file.path);
                  if (result.type != ResultType.done) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Could not open file. Please check your file manager.'),
                          backgroundColor: const Color(0xFF1A1F1A),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error opening file: $e'),
                        backgroundColor: const Color(0xFF1A1F1A),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isDownloading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Iconsax.close_circle, color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to download receipt: $e')),
              ],
            ),
            backgroundColor: const Color(0xFF1A1F1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _copyReceiptDetails(BuildContext context) {
    final details = '''
Transaction Receipt
-------------------
Status: ${receipt.statusTitle}
Amount: ₹${receipt.amount}
Transaction ID: ${receipt.transactionId}
UTR Number: ${receipt.utrNumber}
Date: ${receipt.formattedDate}
Transfer Mode: ${receipt.transferMode}
Remitter: ${receipt.remitterName}
Beneficiary: ${receipt.beneficiaryName}
Account: ${_maskAccount(receipt.accountNumber)}
Bank: ${receipt.bankName}
${receipt.ifscCode.isNotEmpty ? 'IFSC: ${receipt.ifscCode}' : ''}
${receipt.statusMessage.isNotEmpty ? '\n${receipt.statusLabel}: ${receipt.statusMessage}' : ''}
-------------------
${receipt.merchantName}
''';

    Clipboard.setData(ClipboardData(text: details));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            const Text('Receipt details copied to clipboard'),
          ],
        ),
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
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'DMT Transaction Receipt - ${receipt.transactionId}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: const Color(0xFF1A1F1A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      setState(() => _isSharing = false);
    }
  }
}