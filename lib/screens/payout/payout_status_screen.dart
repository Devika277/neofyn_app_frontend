// lib/screens/payout/payout_status_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../services/payout/payout_service.dart';
import '../payout/payout_receipt_screen.dart';

class PayoutStatusScreen extends StatefulWidget {
  final String merchantRefId;

  const PayoutStatusScreen({Key? key, required this.merchantRefId}) : super(key: key);

  @override
  State<PayoutStatusScreen> createState() => _PayoutStatusScreenState();
}

class _PayoutStatusScreenState extends State<PayoutStatusScreen> {
  final PayoutService _service = PayoutService();
  Map<String, dynamic>? _transaction;
  bool _loading = true;
  bool _isPolling = true;
  int _attempts = 0;
  static const int _maxAttempts = 2;
  bool _isGeneratingPDF = false;

  // ─── Theme Colors ─────────────────────────────────────
  static const Color bg = Color(0xFF0A0E0A);
  static const Color card = Color(0xFF1A1F1A);
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF59E0B);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _fetchStatusLoop();
  }

  @override
  void dispose() {
    _isPolling = false;
    super.dispose();
  }

  Future<void> _fetchStatusLoop() async {
    _attempts = 0;
    while (_isPolling && mounted && _attempts < _maxAttempts) {
      _attempts++;
      try {
        final response = await _service.getTransactionStatus(widget.merchantRefId);
        if (response['success'] == true) {
          final data = response['data'];
          if (mounted) setState(() { _transaction = data; _loading = false; });
          final status = data?['status']?.toString().toLowerCase() ?? '';
          if (status == 'success' || status == 'failed') {
            _isPolling = false;
            break;
          }
          final createdAt = data?['created_at'];
          if (createdAt != null) {
            final created = DateTime.tryParse(createdAt.toString());
            if (created != null && DateTime.now().difference(created).inMinutes > 2) {
              debugPrint('Status polling stopped: transaction older than 2 minutes');
              _isPolling = false;
              if (mounted) {
                setState(() {
                  _loading = false;
                  _transaction = {
                    ...data,
                    'status': 'pending',
                    'message': 'Transaction is pending. Please check later in history.',
                  };
                });
              }
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Status polling error: $e');
        _isPolling = false;
      }
      if (_isPolling && _attempts < _maxAttempts) {
        await Future.delayed(const Duration(seconds: 5));
      }
    }
    if (mounted && _loading) {
      setState(() {
        _loading = false;
        if (_transaction == null) {
          _transaction = {
            'status': 'pending',
            'message': 'Status check completed. Please check transaction history for updates.',
          };
        }
      });
    }
  }

  Future<void> _manualRefresh() async {
    setState(() => _loading = true);
    try {
      final response = await _service.getTransactionStatus(widget.merchantRefId);
      if (response['success'] == true && mounted) {
        setState(() { _transaction = response['data']; _loading = false; });
        final status = _transaction?['status']?.toString().toLowerCase() ?? '';
        if (status == 'success' || status == 'failed') _isPolling = false;
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Payout Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70), 
            onPressed: _manualRefresh, 
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded, color: Colors.white70),
            onPressed: () => _shareReceipt(context),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _transaction == null
          ? _buildNotFound()
          : _buildReceipt(),
    );
  }

  Widget _buildNotFound() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: error.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.error_outline, size: 56, color: error)),
      const SizedBox(height: 16),
      const Text('Transaction not found', style: TextStyle(color: Colors.white70, fontSize: 15)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: _manualRefresh, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Retry'), style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
    ]));
  }

  Widget _buildReceipt() {
    final tx = _transaction!;
    String g(String k, {String d = ''}) => tx[k]?.toString() ?? d;

    final isSuccess = g('status').toLowerCase() == 'success';
    final isFailed = g('status').toLowerCase() == 'failed';
    final isProcessing = !isSuccess && !isFailed;

    final statusColor = isSuccess ? success : (isFailed ? error : warning);
    final statusIcon = isSuccess ? Icons.check_circle_rounded : (isFailed ? Icons.cancel_rounded : Icons.access_time_rounded);
    final statusTitle = isSuccess ? 'Transaction Successful' : (isFailed ? 'Transaction Failed' : 'Processing');

    final amount = double.tryParse(g('amount')) ?? 0;
    final charge = double.tryParse(g('payout_charge')) ?? 0;
    final totalDeduction = double.tryParse(g('total_deduction')) ?? amount;
    final aepsBalance = double.tryParse(g('aeps_balance')) ?? 0;
    final mainBalance = double.tryParse(g('main_balance')) ?? 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        // ── Main Receipt Card ──────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: card,
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
              // ========== BIG LOGO ==========
              Image.asset(
                'assets/images/logo_white.png',
                height: 100,
                width: 100,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.account_balance,
                      color: Colors.white.withOpacity(0.3),
                      size: 50,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Title with gradient underline
              Column(
                children: [
                  Text(
                    'Neofyn Bharath',
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 2,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          statusColor.withOpacity(0.6),
                          statusColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Payout badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.payments_rounded,
                      color: primary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Payout Transfer',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ========== STATUS ICON (Small) ==========
              Stack(
                alignment: Alignment.center,
                children: [
                  // Pulsing outer ring
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 1500),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Container(
                        width: 60 + (value * 8),
                        height: 60 + (value * 8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor.withOpacity(0.04 * (1 - value * 0.5)),
                          border: Border.all(
                            color: statusColor.withOpacity(0.08 * (1 - value * 0.5)),
                            width: 1,
                          ),
                        ),
                      );
                    },
                  ),
                  // Main status icon with glow
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor.withOpacity(0.12),
                            border: Border.all(
                              color: statusColor.withOpacity(0.4),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: statusColor.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(
                            statusIcon,
                            size: 26,
                            color: statusColor,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Status Text with gradient
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    statusColor,
                    statusColor.withOpacity(0.6),
                  ],
                ).createShader(bounds),
                child: Text(
                  statusTitle,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Status message
              Text(
                isProcessing ? 'Your payout is being processed...' : g('message'),
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),

              if (isProcessing) ...[
                const SizedBox(height: 12),
                const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: warning)),
              ],

              // ── Amount Section ──────────────────────────
              if (amount > 0) ...[
                const SizedBox(height: 20),
                Container(height: 1, color: Colors.white.withOpacity(0.08)),
                const SizedBox(height: 16),
                Row(children: [
                  _compactChip('AEPS', amount, blue),
                  const SizedBox(width: 8),
                  const Icon(Icons.add_rounded, color: Colors.white24, size: 14),
                  const SizedBox(width: 8),
                  _compactChip('Fee', charge, amber),
                  const SizedBox(width: 8),
                  const Icon(Icons.drag_handle_rounded, color: Colors.white24, size: 14),
                  const SizedBox(width: 8),
                  _compactChip('Total', totalDeduction, primary),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  _compactBalance('AEPS Bal', aepsBalance, blue),
                  const Spacer(),
                  _compactBalance('Main Bal', mainBalance, amber),
                ]),
              ],

              const SizedBox(height: 20),

              // Dashed line
              CustomPaint(
                size: const Size(double.infinity, 1),
                painter: DashedLinePainterPayout(
                  color: Colors.white.withOpacity(0.12),
                  dashWidth: 8,
                  dashSpace: 6,
                ),
              ),
              const SizedBox(height: 16),

              // ── Transaction Details ────────────────────
              _buildDetailRow('Transaction ID', g('id')),
              _buildDetailRow('Reference ID', g('merchantrefid')),
              _buildDetailRow('Amount', '₹${amount.toStringAsFixed(2)}'),
              if (charge > 0) _buildDetailRow('Commission', '₹${charge.toStringAsFixed(2)}'),
              _buildDetailRow('Payment Mode', g('paymentmode')),
              _buildDetailRow('Status', g('status').toUpperCase(), valueColor: statusColor),
              _buildDetailRow('Provider Ref ID', g('providerrefid')),
              _buildDetailRow('Bank Ref No', g('bankrefno')),
              _buildDetailRow('Date & Time', _formatDate(tx['created_at'])),

              const SizedBox(height: 16),
              CustomPaint(
                size: const Size(double.infinity, 1),
                painter: DashedLinePainterPayout(
                  color: Colors.white.withOpacity(0.12),
                  dashWidth: 8,
                  dashSpace: 6,
                ),
              ),
              const SizedBox(height: 16),

              // ── Beneficiary Details ────────────────────
              _buildDetailRow('Beneficiary', g('beneficiaryname')),
              _buildDetailRow('Account', g('beneficiaryaccountnumber')),
              _buildDetailRow('IFSC Code', g('beneficiaryifsc')),

              const SizedBox(height: 20),

              // ── Footer ──────────────────────────────────
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
        ),

        const SizedBox(height: 16),

        // ── Action Buttons ──────────────────────────────
        if (isSuccess) ...[
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [primary, primaryLight]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PayoutReceiptScreen(merchantRefId: widget.merchantRefId))),
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
              label: const Text('View Full Receipt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (isProcessing)
          OutlinedButton.icon(
            onPressed: _manualRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Check Status Now'),
            style: OutlinedButton.styleFrom(
              foregroundColor: warning,
              side: const BorderSide(color: warning),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),

        const SizedBox(height: 8),

        OutlinedButton.icon(
          onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          icon: const Icon(Icons.home_rounded, size: 18),
          label: const Text('Go to Home'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withOpacity(0.2)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ─── Compact chip for header ───────────────────────────
  Widget _compactChip(String label, double value, Color color) {
    return Expanded(
      child: Column(children: [
        Text('₹${value.toStringAsFixed(0)}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ─── Compact balance row ───────────────────────────────
  Widget _compactBalance(String label, double value, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text('$label: ', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
      Text('₹${value.toStringAsFixed(2)}', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]);
  }

  // ─── Detail Row (like receipt_screen) ───────────────────
  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    TextStyle? valueStyle,
  }) {
    if (value.isEmpty || value == 'N/A' || value == 'null') {
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

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime.toString();
    }
  }

  // ─── SHARE RECEIPT ──────────────────────────────────────
  Future<void> _shareReceipt(BuildContext context) async {
    try {
      final pdf = await _generatePDF();
      final directory = await getApplicationDocumentsDirectory();
      final receiptDir = Directory('${directory.path}/Payout_Receipts');
      if (!await receiptDir.exists()) {
        await receiptDir.create(recursive: true);
      }
      final fileName = 'Payout_Receipt_${widget.merchantRefId}.pdf';
      final file = File('${receiptDir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Payout Transaction Receipt - ${_transaction?['merchantrefid'] ?? ''}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: $e'),
            backgroundColor: error,
          ),
        );
      }
    }
  }

  // ─── PDF GENERATION ──────────────────────────────────────
  Future<pw.Document> _generatePDF() async {
    final pdf = pw.Document();
    final tx = _transaction!;
    String g(String k, {String d = ''}) => tx[k]?.toString() ?? d;
    final isSuccess = g('status').toLowerCase() == 'success';

    // Load logo
    Uint8List? logoBytes;
    try {
      final logoData = await rootBundle.load('assets/images/logo_white.png');
      logoBytes = logoData.buffer.asUint8List();
    } catch (e) {
      // Logo not found
    }

    final amount = double.tryParse(g('amount')) ?? 0;
    final charge = double.tryParse(g('payout_charge')) ?? 0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) {
          final widgets = <pw.Widget>[
            // Logo and Header
            if (logoBytes != null)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Image(
                    pw.MemoryImage(logoBytes),
                    height: 30,
                    width: 30,
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    'Neofyn Bharath',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              )
            else
              pw.Text(
                'Neofyn Bharath',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Payout Transfer',
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              g('status').toUpperCase(),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: isSuccess ? PdfColors.green : PdfColors.red,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Amount
            pw.Text(
              '₹${amount.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: isSuccess ? PdfColors.green : PdfColors.red,
              ),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 8),

            // Transaction Details
            _pdfRow('Transaction ID', g('id')),
            _pdfRow('Reference ID', g('merchantrefid')),
            _pdfRow('Amount', '₹${amount.toStringAsFixed(2)}'),
            if (charge > 0) _pdfRow('Commission', '₹${charge.toStringAsFixed(2)}'),
            _pdfRow('Payment Mode', g('paymentmode')),
            _pdfRow('Status', g('status').toUpperCase()),
            _pdfRow('Provider Ref ID', g('providerrefid')),
            _pdfRow('Bank Ref No', g('bankrefno')),
            _pdfRow('Date & Time', _formatDate(tx['created_at'])),

            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Beneficiary Details
            _pdfRow('Beneficiary', g('beneficiaryname')),
            _pdfRow('Account', g('beneficiaryaccountnumber')),
            _pdfRow('IFSC Code', g('beneficiaryifsc')),

            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.SizedBox(height: 8),

            // Footer
            pw.Text(
              'Thank you for using Neofyn Bharath',
              style: const pw.TextStyle(fontSize: 10),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              'Powered by Neofyn Bharath',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
            pw.Text(
              'Generated: ${_formatDate(DateTime.now().toString())}',
              style: const pw.TextStyle(fontSize: 8),
              textAlign: pw.TextAlign.center,
            ),
          ];

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
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── DASHED LINE PAINTER FOR PAYOUT ──────────────────────
class DashedLinePainterPayout extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedLinePainterPayout({
    this.color = Colors.white,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}