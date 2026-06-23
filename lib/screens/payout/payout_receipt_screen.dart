// lib/screens/payout/payout_receipt_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/Payout/payout_service.dart';

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

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();
    final tx = _transaction!;
    final mobileFormat = PdfPageFormat(250 * PdfPageFormat.point, 550 * PdfPageFormat.point, marginAll: 10 * PdfPageFormat.point);

    pdf.addPage(pw.Page(pageFormat: mobileFormat, build: (ctx) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(border: pw.Border.all(style: pw.BorderStyle.dashed, width: 1), borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(children: [
          pw.SizedBox(height: 10),
          pw.Text('₹ ${tx['amount']}', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
          pw.Text('Payout Transfer', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('TRANSACTION ID', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
            pw.Text('${tx['txnId'] ?? 'N/A'}', style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Divider(thickness: 0.5),
          ])),
          _pdfRow('Number', tx['beneficiaryAccountNumber'] ?? 'N/A'),
          _pdfRow('Provider Id', tx['txnId'] ?? '0'),
          _pdfRow('Account Holder', tx['beneficiaryName'] ?? 'N/A'),
          _pdfRow('Product', 'payout'),
          _pdfRow('Bank', 'BANK: ${tx['beneficiaryAccountNumber']} IFSC: ${tx['beneficiaryIFSC']}'),
          _pdfRow('Date Time', _formatDate(tx['createdAt'])),
          pw.SizedBox(height: 20),
          pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
          pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(tx['remitterName']?.toUpperCase() ?? 'SHOP NAME', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text(tx['remitterPhone'] ?? '', style: const pw.TextStyle(fontSize: 10)),
            pw.Text(tx['beneficiaryLocation'] ?? 'Address not available', style: const pw.TextStyle(fontSize: 9)),
          ])),
          pw.Spacer(),
          pw.Container(alignment: pw.Alignment.center, child: pw.Text('NEOFYN FIN TECH', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange))),
        ]),
      );
    }));
    return pdf.save();
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700)),
        pw.Text(value, style: const pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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

  static const success = Color(0xFF2ECC71);

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
    final tx = _transaction!;
    return Center(child: SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
        child: Column(children: [
          Container(width: 64, height: 64, decoration: BoxDecoration(color: accent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, size: 40, color: accent)),
          const SizedBox(height: 12),
          Text('₹ ${tx['amount']}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: accent)),
          const Text('Payout Transfer', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.white)),
          const SizedBox(height: 24),
          Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TRANSACTION ID', style: TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 2),
            Text(tx['txnId'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
          ])),
          const SizedBox(height: 12),
          divider(),
          const SizedBox(height: 12),
          _r('Number', tx['beneficiaryAccountNumber'] ?? 'N/A'),
          _r('Provider Id', tx['txnId'] ?? '0'),
          _r('Account Holder', tx['beneficiaryName'] ?? 'N/A'),
          _r('Product', 'payout'),
          _r('Bank', 'BANK: ${tx['beneficiaryAccountNumber']}\nIFSC: ${tx['beneficiaryIFSC']}'),
          _r('Date Time', _formatDate(tx['createdAt'])),
          const SizedBox(height: 20),
          divider(),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerLeft, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx['remitterName']?.toUpperCase() ?? 'SHOP NAME', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            Text(tx['remitterPhone'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            Text(tx['beneficiaryLocation'] ?? '', style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ])),
          const SizedBox(height: 24),
          const Text('NEOFYN FIN TECH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: accent)),
        ]),
      ),
    ));
  }

  Widget divider() => Container(height: 1, color: Colors.white.withOpacity(0.06));

  Widget _r(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 90, child: Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12))),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500))),
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