// lib/screens/payout/payout_receipt_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/payout/payout_service.dart';

class PayoutReceiptScreen extends StatefulWidget {
  final String merchantRefId;
  const PayoutReceiptScreen({Key? key, required this.merchantRefId}) : super(key: key);

  @override
  State<PayoutReceiptScreen> createState() => _PayoutReceiptScreenState();
}

class _PayoutReceiptScreenState extends State<PayoutReceiptScreen> {
  Map<String, dynamic>? _transaction;
  bool _loading = true;
  bool _isDownloading = false;

  static const Color bg = Color(0xFF0A0E0A);
  static const Color card = Color(0xFF1A1F1A);
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color accent = Color(0xFFE67E22);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color success = Color(0xFF2ECC71);

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    try {
      final service = PayoutService();
      final response = await service.getTransactionStatus(widget.merchantRefId);
      if (mounted) {
        setState(() {
          _transaction = response['data'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String g(String key, {String d = ''}) {
    if (_transaction == null) return d;
    return _transaction![key]?.toString() ?? d;
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final tx = _transaction!;
    final amount = double.tryParse(g('amount')) ?? 0;
    final charge = double.tryParse(g('payout_charge')) ?? 0;
    final totalDeduction = double.tryParse(g('total_deduction')) ?? amount;
    final aepsBalance = double.tryParse(g('aeps_balance')) ?? 0;
    final mainBalance = double.tryParse(g('main_balance')) ?? 0;

    final mobileFormat = PdfPageFormat(280 * PdfPageFormat.point, 650 * PdfPageFormat.point, marginAll: 12 * PdfPageFormat.point);

    pdf.addPage(pw.Page(pageFormat: mobileFormat, build: (ctx) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(style: pw.BorderStyle.solid, width: 1, color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(children: [
          // Header
          pw.Center(child: pw.Text('PAYOUT RECEIPT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green))),
          pw.SizedBox(height: 8),
          pw.Center(child: pw.Text('₹ ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.orange))),
          pw.Center(child: pw.Text('via ${g('paymentmode')}', style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700))),
          pw.SizedBox(height: 12),

          // ✅ Deduction Breakdown
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(children: [
              pw.Text('DEDUCTION BREAKDOWN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.SizedBox(height: 6),
              _pdfBreakdownRow('Transfer Amount (AEPS Wallet)', '₹${amount.toStringAsFixed(2)}', PdfColors.blue),
              _pdfBreakdownRow('Commission (Main Wallet)', '₹${charge.toStringAsFixed(2)}', PdfColors.orange),
              pw.Divider(thickness: 0.5),
              _pdfBreakdownRow('Total Deduction', '₹${totalDeduction.toStringAsFixed(2)}', PdfColors.green, bold: true),
            ]),
          ),
          pw.SizedBox(height: 10),

          // ✅ Current Balances
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(children: [
              pw.Text('CURRENT BALANCES', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.SizedBox(height: 6),
              _pdfBreakdownRow('AEPS Wallet', '₹${aepsBalance.toStringAsFixed(2)}', PdfColors.blue),
              _pdfBreakdownRow('Main Wallet', '₹${mainBalance.toStringAsFixed(2)}', PdfColors.orange),
            ]),
          ),
          pw.SizedBox(height: 12),

          // Transaction Details
          pw.Text('TRANSACTION DETAILS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          _pdfRow('Transaction ID', g('id')),
          _pdfRow('Reference ID', g('merchantrefid')),
          _pdfRow('Provider Ref ID', g('providerrefid')),
          _pdfRow('Bank Ref No', g('bankrefno')),
          _pdfRow('Payment Mode', g('paymentmode')),
          _pdfRow('Date & Time', _formatDate(tx['created_at'])),
          pw.SizedBox(height: 8),

          // Beneficiary Details
          pw.Text('BENEFICIARY DETAILS', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          _pdfRow('Account Holder', g('beneficiaryname')),
          _pdfRow('Account Number', g('beneficiaryaccountnumber')),
          _pdfRow('IFSC Code', g('beneficiaryifsc')),

          pw.SizedBox(height: 20),
<<<<<<< HEAD
          pw.Center(child: pw.Text('NEOFYN BHARATH', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green))),
=======
          pw.Center(child: pw.Text('NEOFYN Bharath', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.green))),
>>>>>>> 24f057de74b8e6210d3b51a868c58b30d1d8b3b9
          pw.Center(child: pw.Text('Thank you for using our service', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500))),
        ]),
      );
    }));
    return pdf.save();
  }

  pw.Widget _pdfBreakdownRow(String label, String value, PdfColor color, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.Text(value.isNotEmpty ? value : 'N/A', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ]),
    );
  }

  Future<void> _downloadPdf() async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await _generatePdf();
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download/Neofyn_Receipts');
        if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }
      final fileName = 'Neofyn_Receipt_${widget.merchantRefId}.pdf';
      final file = File('${downloadsDir!.path}/$fileName');
      await file.writeAsBytes(bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [Icon(Icons.check_circle, color: success, size: 18), SizedBox(width: 8), Text('Saved to Downloads/Neofyn_Receipts', style: TextStyle(fontSize: 12))]),
          backgroundColor: card, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _sharePdf() async {
    final bytes = await _generatePdf();
    await Printing.sharePdf(bytes: bytes, filename: 'Neofyn_Receipt_${widget.merchantRefId}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Receipt', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: bg, foregroundColor: Colors.white, elevation: 0,
        actions: [
          if (!_loading) IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white70), onPressed: _sharePdf),
        ],
      ),
      body: _loading ? const Center(child: CircularProgressIndicator(color: primary)) : _buildReceiptUI(),
      bottomNavigationBar: _loading ? null : _buildActionButtons(),
    );
  }

  Widget _buildReceiptUI() {
    final amount = double.tryParse(g('amount')) ?? 0;
    final charge = double.tryParse(g('payout_charge')) ?? 0;
    final totalDeduction = double.tryParse(g('total_deduction')) ?? amount;
    final aepsBalance = double.tryParse(g('aeps_balance')) ?? 0;
    final mainBalance = double.tryParse(g('main_balance')) ?? 0;

    return Center(child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: Column(children: [
          // Success Icon
          Container(width: 64, height: 64, decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, size: 40, color: accent)),
          const SizedBox(height: 12),
          Text('₹ ${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: accent)),
          Text('via ${g('paymentmode')}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 24),

          // ✅ DEDUCTION BREAKDOWN CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.receipt_long_rounded, color: primary, size: 16),
                  SizedBox(width: 6),
                  Text('Deduction Breakdown', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
                const SizedBox(height: 14),
                // Transfer Amount from AEPS
                _breakdownTile(
                  'Transfer Amount',
                  'Deducted from AEPS Wallet',
                  amount,
                  blue,
                  Icons.account_balance_wallet_rounded,
                ),
                const SizedBox(height: 10),
                // Commission from Main Wallet
                _breakdownTile(
                  'Commission Charge',
                  'Deducted from Main Wallet',
                  charge,
                  amber,
                  Icons.wallet_rounded,
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: Colors.white.withOpacity(0.1)),
                const SizedBox(height: 10),
                // Total
                _breakdownTile(
                  'Total Deduction',
                  'Combined from both wallets',
                  totalDeduction,
                  primary,
                  Icons.summarize_rounded,
                  isTotal: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ✅ CURRENT BALANCES CARD
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(children: [
                  Icon(Icons.account_balance_rounded, color: primary, size: 16),
                  SizedBox(width: 6),
                  Text('Current Balances', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ]),
                const SizedBox(height: 14),
                _balanceTile('AEPS Wallet', aepsBalance, blue, Icons.account_balance_wallet_rounded),
                const SizedBox(height: 8),
                _balanceTile('Main Wallet', mainBalance, amber, Icons.wallet_rounded),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Transaction ID
          Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TRANSACTION ID', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 2),
            Text(g('id'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
          ])),
          const SizedBox(height: 12),
          divider(),
          const SizedBox(height: 12),

          // Details
          _r('Reference ID', g('merchantrefid')),
          _r('Provider Ref ID', g('providerrefid')),
          _r('Bank Ref No', g('bankrefno')),
          _r('Payment Mode', g('paymentmode')),
          _r('Account Holder', g('beneficiaryname')),
          _r('Account Number', g('beneficiaryaccountnumber')),
          _r('IFSC Code', g('beneficiaryifsc')),
          _r('Date & Time', _formatDate(_transaction!['created_at'])),
          const SizedBox(height: 20),
          divider(),
          const SizedBox(height: 16),
          const Text('NEOFYN BHARATH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: accent)),
          const SizedBox(height: 4),
          const Text('Thank you for using our service', style: TextStyle(color: Colors.white38, fontSize: 10)),
        ]),
      ),
    ));
  }

  // ✅ Breakdown tile widget
  Widget _breakdownTile(String title, String subtitle, double amount, Color color, IconData icon, {bool isTotal = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(isTotal ? 0.3 : 0.1)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: isTotal ? Colors.white : Colors.white70, fontSize: 12, fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500)),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9)),
          ]),
        ),
        Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: isTotal ? 15 : 13, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ✅ Balance tile widget
  Widget _balanceTile(String label, double balance, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text('₹${balance.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget divider() => Container(height: 1, color: Colors.white.withOpacity(0.06));

  Widget _r(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(child: Text(value.isNotEmpty ? value : 'N/A', textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05)))),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: () => Printing.layoutPdf(onLayout: (f) => _generatePdf()), icon: const Icon(Icons.print_rounded, size: 18), label: const Text('Print'), style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: BorderSide(color: Colors.white.withOpacity(0.2)), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(onPressed: _isDownloading ? null : _downloadPdf, icon: _isDownloading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download_rounded, size: 18), label: Text(_isDownloading ? 'Saving...' : 'Save PDF'), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))))),
      ]),
    );
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.day} ${_month(dt.month)}, ${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime.toString();
    }
  }

  String _month(int m) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m - 1];
}