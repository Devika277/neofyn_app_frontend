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
  final PayoutService _payoutService = PayoutService();
  Map<String, dynamic>? _transaction;
  bool _loading = true;
  bool _isPolling = true;

  @override
  void initState() {
    super.initState();
    // _fetchStatus();
  }

  @override
  void dispose() {
    _isPolling = false;
    super.dispose();
  }

  // Future<void> _fetchStatus() async {
  //   while (_isPolling && mounted) {
  //     try {
  //       final response = await _payoutService.getTransactionStatus(widget.merchantRefId);
  //       if (response['success'] == true) {
  //         setState(() {
  //           _transaction = response['data'];
  //           _loading = false;
  //         });
  //         if (_transaction!['status'] == 'SUCCESS' || _transaction!['status'] == 'FAILED') {
  //           _isPolling = false;
  //         }
  //       }
  //     } catch (e) {
  //       debugPrint('Polling error: $e');
  //     }
  //     if (_isPolling) await Future.delayed(const Duration(seconds: 3));
  //   }
  // }

  // --- PDF GENERATION LOGIC ---
Future<Uint8List> _generatePdf() async {
  final pdf = pw.Document();
  final tx = _transaction!;

  // Define Mobile Resolution (roughly 3.5 inches wide, height varies by content)
  // 1 point = 1/72 inch. 250pt wide is standard for mobile receipts.
  final mobileFormat = PdfPageFormat(
    250 * PdfPageFormat.point, 
    550 * PdfPageFormat.point, // Height can be adjusted based on content
    marginAll: 10 * PdfPageFormat.point
  );

pdf.addPage(
    pw.Page(
      pageFormat: mobileFormat,
      build: (pw.Context context) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(style: pw.BorderStyle.dashed, width: 1),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            children: [
              pw.SizedBox(height: 10),
              pw.Text('₹ ${tx['amount']}', 
                style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
              pw.Text('Payout Transfer', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 15),
              
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('TRANSACTION ID', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.Text('${tx['txnId'] ?? 'N/A'}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Divider(thickness: 0.5),
                  ]
                )
              ),

              // Mapping fields to match your image exactly
              _pdfRow('Number', tx['beneficiaryAccountNumber'] ?? 'N/A'),
              _pdfRow('Provider Id', tx['txnId'] ?? '0'),
              _pdfRow('Account Holder', tx['beneficiaryName'] ?? 'N/A'),
              _pdfRow('Product', 'payout'),
              _pdfRow('Bank', 'BANK: ${tx['beneficiaryAccountNumber']} IFSC: ${tx['beneficiaryIFSC']}'),
              _pdfRow('Date Time', _formatDate(tx['createdAt'])),
              
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
              
              // Shop Details Section
              pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(tx['remitterName']?.toUpperCase() ?? 'SHOP NAME', 
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Text(tx['remitterPhone'] ?? '', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(tx['beneficiaryLocation'] ?? 'Address not available', 
                      style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
              
              pw.Spacer(),
              pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Text('NEOFYN BHARAT', 
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
              ),
            ],
          ),
        );
      },
    ),
  );
  return pdf.save();
}

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        // Fixed the typo here
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
        children: [
          pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

Future<void> _downloadPdf() async {
  try {
    final bytes = await _generatePdf();
    Directory? downloadsDir;

    if (Platform.isAndroid) {
      // This targets the public "Download" folder on Android
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }

    final String fileName = 'Receipt_${widget.merchantRefId}.pdf';
    final File file = File('${downloadsDir!.path}/$fileName');
    
    await file.writeAsBytes(bytes);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Receipt saved to Downloads folder"),
        backgroundColor: Colors.green,
        action: SnackBarAction(label: "Open", onPressed: () => Printing.sharePdf(bytes: bytes, filename: fileName)),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error saving file: $e"), backgroundColor: Colors.red),
    );
  }
}

  Future<void> _sharePdf() async {
    final bytes = await _generatePdf();
    await Printing.sharePdf(bytes: bytes, filename: 'receipt_${widget.merchantRefId}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Receipt'), actions: [
        if (!_loading) IconButton(icon: const Icon(Icons.share), onPressed: _sharePdf),
      ]),
      body: _loading 
        ? const Center(child: CircularProgressIndicator()) 
        : _buildReceiptUI(),
      bottomNavigationBar: _loading ? null : _buildActionButtons(),
    );
  }

 Widget _buildReceiptUI() {
  final tx = _transaction!;
  return Center(
    child: SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, size: 70, color: Colors.orange),
            const SizedBox(height: 10),
            Text("₹ ${tx['amount']}", 
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange)),
            const Text("Payout Transfer", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
            const SizedBox(height: 30),
            
            // Transaction ID Section
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TRANSACTION ID", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  Text(tx['txnId'] ?? "N/A", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            const Divider(height: 30),

            // Main Details matching image_4673d5.jpg
            _detailRow("Number", tx['beneficiaryAccountNumber']),
            _detailRow("Provider Id", tx['txnId'] ?? "0"),
            _detailRow("Account Holder", tx['beneficiaryName']),
            _detailRow("Product", "payout"),
            _detailRow("Bank", "BANK: ${tx['beneficiaryAccountNumber']}\nIFSC: ${tx['beneficiaryIFSC']}"),
            _detailRow("Date Time", _formatDate(tx['createdAt'])),
            
            const SizedBox(height: 30),
            const Divider(height: 1, thickness: 1, color: Colors.grey),
            const SizedBox(height: 20),

            // Shop / Remitter Section
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx['remitterName']?.toUpperCase() ?? "SHOP NAME", 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(tx['remitterPhone'] ?? ""),
                  Text(tx['beneficiaryLocation'] ?? "Address Detail", 
                    style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Brand Logo placeholder
            const Text("NEOFYN BHARAT", 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.orange)),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: ElevatedButton.icon(onPressed: () => Printing.layoutPdf(onLayout: (format) => _generatePdf()), icon: const Icon(Icons.print), label: const Text("Print"))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(onPressed: _downloadPdf, icon: const Icon(Icons.download), label: const Text("Save"))),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime);
      return '${dt.day} May, 2026 | ${dt.hour}:${dt.minute.toString().padLeft(2, '0')} PM';
    } catch (e) { return dateTime.toString(); }
  }
}