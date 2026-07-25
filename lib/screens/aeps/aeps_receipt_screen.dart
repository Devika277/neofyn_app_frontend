// lib/screens/aeps/aeps_receipt_screen.dart

import 'dart:io';
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

class AepsReceiptScreen extends StatefulWidget {
  final String txnRefId;
  final Map<String, dynamic> transactionData;

  const AepsReceiptScreen({
    Key? key,
    required this.txnRefId,
    required this.transactionData,
  }) : super(key: key);

  @override
  State<AepsReceiptScreen> createState() => _AepsReceiptScreenState();
}

class _AepsReceiptScreenState extends State<AepsReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isDownloading = false;
  bool _isSharing = false;

  Map<String, dynamic> get tx => widget.transactionData;

  String get _txnTypeLabel {
    final t = (tx['transactionType'] ?? tx['type'] ?? '').toString();
    switch (t.toUpperCase()) {
      case 'CASH_WITHDRAWAL': return 'Cash Withdrawal';
      case 'BALANCE_ENQUIRY': return 'Balance Enquiry';
      case 'MINI_STATEMENT': return 'Mini Statement';
      default: return 'AEPS Transaction';
    }
  }

  bool get _isCashWithdrawal => _txnTypeLabel == 'Cash Withdrawal';
  bool get _isBalanceEnquiry => _txnTypeLabel == 'Balance Enquiry';
  bool get _isMiniStatement => _txnTypeLabel == 'Mini Statement';

  String get _amount => (tx['amount'] ?? '0').toString();
  String get _balance => (tx['balance'] ?? tx['accountBalance'] ?? '').toString();
  String get _refId => tx['txnRefId'] ?? tx['merchantRefId'] ?? widget.txnRefId;
  String get _rrn => tx['rrn'] ?? 'N/A';
  String get _stan => tx['stan'] ?? 'N/A';
  String get _bankName => tx['bankName'] ?? tx['bankIin'] ?? 'N/A';
  String get _aadhaar => _maskAadhaar(tx['aadhaarLast4'] ?? tx['maskedAadhaar']);
  String get _mobile => tx['mobileNumber'] ?? tx['mobile'] ?? 'N/A';
  String get _merchantId => tx['merchantId'] ?? 'N/A';
  String get _terminalId => tx['terminalId'] ?? 'N/A';

  List<Map<String, dynamic>> get _miniStatementEntries {
    final data = tx['miniStatementData'] ?? tx['mini_statement'] ?? tx['statement'];
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  String get _formattedDate {
    try {
      final dt = DateTime.parse((tx['createdAt'] ?? tx['timestamp'] ?? DateTime.now().toString()).toString()).toLocal();
      return DateFormat('dd-MM-yyyy hh:mm a').format(dt);
    } catch (_) { return DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()); }
  }

  String get _formattedDateShort {
    try {
      final dt = DateTime.parse((tx['createdAt'] ?? tx['timestamp'] ?? DateTime.now().toString()).toString()).toLocal();
      return DateFormat('dd-MM-yyyy').format(dt);
    } catch (_) { return DateFormat('dd-MM-yyyy').format(DateTime.now()); }
  }

  String get _formattedTime {
    try {
      final dt = DateTime.parse((tx['createdAt'] ?? tx['timestamp'] ?? DateTime.now().toString()).toString()).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) { return DateFormat('hh:mm a').format(DateTime.now()); }
  }

  String get _fileNameDate {
    try {
      final dt = DateTime.parse((tx['createdAt'] ?? tx['timestamp'] ?? DateTime.now().toString()).toString()).toLocal();
      return DateFormat('yyyyMMdd_HHmmss').format(dt);
    } catch (_) { return DateFormat('yyyyMMdd_HHmmss').format(DateTime.now()); }
  }

  IconData get _txnIcon {
    if (_isCashWithdrawal) return Iconsax.money_send;
    if (_isBalanceEnquiry) return Iconsax.wallet_1;
    if (_isMiniStatement) return Iconsax.receipt_item;
    return Iconsax.finger_scan;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('AEPS Receipt', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: const Color(0xFF1E293B))),
        centerTitle: true,
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        leading: IconButton(icon: const Icon(Iconsax.arrow_left, color: Color(0xFF1E293B)), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: _isSharing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF64748B))) : const Icon(Iconsax.share, color: Color(0xFF64748B), size: 20),
            onPressed: _isSharing ? null : () => _shareReceipt(context),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withOpacity(0.12),
              border: Border.all(color: const Color(0xFF10B981), width: 2.5),
            ),
            child: const Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 36),
          ),
          const SizedBox(height: 16),
          Text('TRANSACTION SUCCESSFUL', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
          const SizedBox(height: 8),
          if (_isCashWithdrawal)
            Text('₹$_amount', style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w800, color: const Color(0xFF10B981), letterSpacing: 1)),
          if (_isBalanceEnquiry && _balance.isNotEmpty)
            Text('₹$_balance', style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.w800, color: const Color(0xFF10B981), letterSpacing: 1)),
          const SizedBox(height: 6),
          Text(_txnTypeLabel, style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)), textAlign: TextAlign.center),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildSectionHeader('TRANSACTION DETAILS'),
          const SizedBox(height: 10),
          _buildTable([
            _buildTableRow('Transaction Type', _txnTypeLabel, isBold: true),
            _buildTableRow('Reference ID', _refId, showCopy: true, isHighlight: true),
            _buildTableRow('RRN', _rrn),
            _buildTableRow('STAN', _stan),
            _buildTableRow('Date & Time', _formattedDate),
            _buildTableRow('Status', 'SUCCESS', valueColor: const Color(0xFF10B981), isBold: true),
          ]),
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildSectionHeader('CUSTOMER DETAILS'),
          const SizedBox(height: 10),
          _buildTable([
            _buildTableRow('Aadhaar Number', _aadhaar),
            _buildTableRow('Bank Name', _bankName),
            _buildTableRow('Mobile Number', _mobile),
          ]),
          if (_isMiniStatement && _miniStatementEntries.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildDivider(),
            const SizedBox(height: 16),
            _buildSectionHeader('MINI STATEMENT'),
            const SizedBox(height: 10),
            _buildMiniStatementWidget(),
          ],
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildSectionHeader('AGENT DETAILS'),
          const SizedBox(height: 10),
          _buildTable([
            _buildTableRow('Merchant ID', _merchantId),
            _buildTableRow('Terminal ID', _terminalId),
          ]),
          if (_isCashWithdrawal) ...[
            const SizedBox(height: 12),
            _buildTotalRow(),
            const SizedBox(height: 8),
            _buildAmountInWords(),
          ],
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
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF008169), Color(0xFF1AA88A)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(_txnIcon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 12),
        Text('NEOFYN BHARATH', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B), letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFF1AA88A).withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1AA88A).withOpacity(0.2))),
          child: Text(_txnTypeLabel, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1AA88A))),
        ),
        const SizedBox(height: 10),
        Text('$_formattedDateShort  $_formattedTime', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(width: 4, height: 18, decoration: BoxDecoration(color: const Color(0xFF1AA88A), borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildDivider() => Container(height: 1, color: Colors.grey.shade200);

  Widget _buildTable(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200, width: 1)),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          return Column(children: [entry.value, if (entry.key != rows.length - 1) const Divider(color: Color(0xFFE2E8F0), height: 0.5, thickness: 0.5)]);
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
          SizedBox(width: 100, child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500))),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(child: Text(value, textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: isHighlight ? 13 : 12, fontWeight: isBold ? FontWeight.w700 : (isHighlight ? FontWeight.w600 : FontWeight.w500), color: valueColor ?? const Color(0xFF1E293B)))),
                if (showCopy) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied', style: const TextStyle(fontSize: 12)), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 1)));
                    },
                    child: Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: const Icon(Iconsax.copy, size: 12, color: Color(0xFF64748B))),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatementWidget() {
    final entries = _miniStatementEntries;
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200, width: 1)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: const Color(0xFF1AA88A).withOpacity(0.06), borderRadius: const BorderRadius.vertical(top: Radius.circular(10))),
            child: Row(children: [
              SizedBox(width: 25, child: Text('#', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1AA88A)))),
              const Expanded(flex: 3, child: Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1AA88A)))),
              const Expanded(flex: 2, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1AA88A)))),
            ]),
          ),
          ...entries.asMap().entries.map((e) {
            final item = e.value;
            final isCredit = (item['type'] ?? '').toString().toUpperCase() == 'CREDIT';
            final amtColor = isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                SizedBox(width: 25, child: Text('${e.key + 1}', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)))),
                Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['narration'] ?? 'Transaction', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B))),
                  Text(_formatMiniDate(item['date']), style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
                ])),
                Expanded(flex: 2, child: Text('₹${item['amount'] ?? '0'}', textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: amtColor))),
              ]),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1AA88A).withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1AA88A).withOpacity(0.15))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Total Amount', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
        Text('₹$_amount', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1AA88A))),
      ]),
    );
  }

  Widget _buildAmountInWords() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Text('Amount (In Words) : ', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
        Expanded(child: Text(_numberToWords(int.tryParse(_amount) ?? 0), style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF1E293B), fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildFooter() {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Iconsax.verify, size: 14, color: Color(0xFF10B981)),
        const SizedBox(width: 6),
        Text('This is a computer generated receipt', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8))),
      ]),
      const SizedBox(height: 6),
      Text('© 2025 NEOFYN Bharath - All Rights Reserved', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8))),
      const SizedBox(height: 4),
      Text('This is a system generated Receipt. Hence no seal or signature required.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 9, color: const Color(0xFFCBD5E1))),
    ]);
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isDownloading ? null : () => _downloadReceipt(context),
            icon: _isDownloading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Iconsax.document_download, size: 18),
            label: Text(_isDownloading ? 'Downloading...' : 'Download Receipt'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF008169), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _printReceipt,
              icon: const Icon(Iconsax.printer, size: 18),
              label: const Text('Print'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1AA88A), side: const BorderSide(color: Color(0xFF1AA88A)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Iconsax.close_circle, size: 18),
              label: const Text('Close'),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF64748B), side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        FutureBuilder<Directory>(
          future: _getAepsFolderPath(),
          builder: (context, snapshot) {
            String pathDisplay = 'App Storage/NEOFYN/AEPS/';
            if (snapshot.hasData) {
              String fullPath = snapshot.data!.path;
              if (fullPath.contains('/storage/emulated/0/')) {
                pathDisplay = fullPath.replaceAll('/storage/emulated/0/', 'Internal Storage/');
              }
            }
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Row(children: [
                const Icon(Iconsax.folder_2, color: Color(0xFF94A3B8), size: 14),
                const SizedBox(width: 6),
                Expanded(child: Text('Receipts saved to:\n$pathDisplay', style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)))),
              ]),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  FOLDER & PDF
  // ─────────────────────────────────────────────────────────────
  Future<Directory> _getAepsFolderPath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      final paths = ['/storage/emulated/0/Documents/NEOFYN/AEPS', '/storage/emulated/0/Download/NEOFYN/AEPS'];
      for (final path in paths) {
        try {
          final dir = Directory(path);
          if (!await dir.exists()) await dir.create(recursive: true);
          return dir;
        } catch (_) {}
      }
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          directory = Directory('${extDir.path}/NEOFYN/AEPS');
          if (!await directory!.exists()) await directory.create(recursive: true);
          return directory;
        }
      } catch (_) {}
    }
    final appDir = await getApplicationDocumentsDirectory();
    directory = Directory('${appDir.path}/NEOFYN/AEPS');
    if (!await directory!.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> _generatePdf() async {
    final pdf = pw.Document();
    PdfColor pc(Color c) => PdfColor.fromInt(c.value);
    final f = await PdfGoogleFonts.poppinsRegular();
    final fb = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Center(child: pw.Column(children: [
          pw.Container(width: 60, height: 60, decoration: pw.BoxDecoration(color: pc(const Color(0xFF008169)), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14))), child: pw.Center(child: pw.Text('NB', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: fb)))),
          pw.SizedBox(height: 8),
          pw.Text('NEOFYN BHARATH', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: fb)),
          pw.SizedBox(height: 4),
          pw.Text('$_formattedDateShort  $_formattedTime', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: f)),
        ])),
        pw.SizedBox(height: 16),
        _pdfRow(f, fb, 'Transaction Type', _txnTypeLabel),
        _pdfRow(f, fb, 'Reference ID', _refId),
        _pdfRow(f, fb, 'RRN', _rrn),
        _pdfRow(f, fb, 'STAN', _stan),
        _pdfRow(f, fb, 'Date & Time', _formattedDate),
        _pdfRow(f, fb, 'Status', 'SUCCESS', vc: pc(const Color(0xFF10B981))),
        pw.SizedBox(height: 10), pw.Divider(), pw.SizedBox(height: 10),
        pw.Text('Customer Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: fb)),
        pw.SizedBox(height: 6),
        _pdfRow(f, fb, 'Aadhaar Number', _aadhaar),
        _pdfRow(f, fb, 'Bank Name', _bankName),
        _pdfRow(f, fb, 'Mobile Number', _mobile),
        pw.SizedBox(height: 10), pw.Divider(), pw.SizedBox(height: 10),
        pw.Text('Agent Details', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, font: fb)),
        pw.SizedBox(height: 6),
        _pdfRow(f, fb, 'Merchant ID', _merchantId),
        _pdfRow(f, fb, 'Terminal ID', _terminalId),
        if (_isCashWithdrawal) ...[
          pw.SizedBox(height: 10),
          pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: pc(const Color(0xFF1AA88A).withOpacity(0.06)), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)))),
          pw.SizedBox(height: 6),
        ],
        pw.SizedBox(height: 20), pw.Divider(),
        pw.Center(child: pw.Text('© 2025 NEOFYN Bharath', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, font: f))),
      ]),
    ));

    final dir = await _getAepsFolderPath();
    final file = File('${dir.path}/AEPS_Receipt_${_refId}_$_fileNameDate.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _pdfRow(pw.Font f, pw.Font fb, String label, String value, {PdfColor? vc}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(children: [
        pw.SizedBox(width: 100, child: pw.Text('$label :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: f))),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fb, color: vc ?? PdfColors.black))),
      ]),
    );
  }

  Future<void> _downloadReceipt(BuildContext context) async {
    setState(() => _isDownloading = true);
    try {
      final file = await _generatePdf();
      if (mounted) {
        String dp = file.path.replaceAll('/storage/emulated/0/', 'Internal Storage/');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 20), SizedBox(width: 8), Text('Receipt saved!', style: TextStyle(color: Colors.white))]),
            Text('📁 $dp', style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ]),
          backgroundColor: const Color(0xFF1A1F1A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Open', textColor: const Color(0xFF1AA88A), onPressed: () => OpenFile.open(file.path)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download failed'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _shareReceipt(BuildContext context) async {
    setState(() => _isSharing = true);
    try {
      final file = await _generatePdf();
      await Share.shareXFiles([XFile(file.path)], text: 'AEPS Receipt - $_refId');
    } catch (_) {} finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _printReceipt() async {
    try {
      final file = await _generatePdf();
      await Printing.sharePdf(bytes: await file.readAsBytes(), filename: 'AEPS_Receipt_$_refId.pdf');
    } catch (_) {}
  }

  // ─── Utils ─────────────────────────────────────────────────
  String _maskAadhaar(dynamic r) {
    if (r == null) return 'XXXX XXXX XXXX';
    final s = r.toString();
    if (s.length == 4) return 'XXXX XXXX $s';
    if (s.length == 12) return 'XXXX XXXX ${s.substring(8)}';
    return s;
  }

  String _formatMiniDate(dynamic d) {
    if (d == null) return '';
    try { return DateFormat('dd-MM-yyyy').format(DateTime.parse(d.toString())); } catch (_) { return ''; }
  }

  String _numberToWords(int n) {
    if (n == 0) return 'Zero';
    final u = ['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'];
    final t = ['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];
    String c(int n) {
      if (n < 20) return u[n];
      if (n < 100) return '${t[n~/10]} ${u[n%10]}'.trim();
      if (n < 1000) return '${u[n~/100]} Hundred ${c(n%100)}'.trim();
      if (n < 100000) return '${c(n~/1000)} Thousand ${c(n%1000)}'.trim();
      if (n < 10000000) return '${c(n~/100000)} Lakh ${c(n%100000)}'.trim();
      return '';
    }
    return '${c(n)} Only';
  }
}