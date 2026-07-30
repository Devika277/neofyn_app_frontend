// lib/screens/CardPay/cardpay_receipt_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/cardpay_models.dart';
import '../../providers/cardpay_provider.dart';

class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);
  static const Color textDarkHint = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color processing = Color(0xFF8B5CF6);
  static const Color borderDark = Color(0xFF2A342A);
}

class CardPayReceiptScreen extends StatefulWidget {
  final String ref;

  const CardPayReceiptScreen({Key? key, required this.ref}) : super(key: key);

  @override
  State<CardPayReceiptScreen> createState() => _CardPayReceiptScreenState();
}

class _CardPayReceiptScreenState extends State<CardPayReceiptScreen> {
  Map<String, dynamic>? _receipt;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReceipt();
    });
  }

  Future<void> _loadReceipt() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<CardPayProvider>(context, listen: false);
      final result = await provider.getReceipt(widget.ref);

      if (!mounted) return;

      if (result != null && result['receipt'] != null) {
        setState(() {
          _receipt = result['receipt'] as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load receipt';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'Transaction Receipt',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 16 : 18,
            color: AppColors.textWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.refresh, color: AppColors.textDarkSecondary, size: 20),
            onPressed: _loadReceipt,
          ),
          IconButton(
            icon: const Icon(Iconsax.share, color: AppColors.textDarkSecondary, size: 20),
            onPressed: _shareReceipt,
          ),
        ],
      ),
      body: _buildBody(isSmallScreen),
    );
  }

  Widget _buildBody(bool isSmallScreen) {
    if (_isLoading) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                'Loading receipt...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textDarkSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.darkSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.warning_2, size: 48, color: AppColors.error),
                ),
                const SizedBox(height: 20),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textDarkSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadReceipt,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_receipt == null || _receipt!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.receipt_1, size: 64, color: AppColors.textDarkHint.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No receipt found',
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: AppColors.textDarkHint,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      child: Column(
        children: [
          // Status Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getStatusColor().withOpacity(0.2),
                  _getStatusColor().withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getStatusColor().withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _getStatusColor().withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getStatusIcon(),
                    size: 56,
                    color: _getStatusColor(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getStatusText(),
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ref: ${_receipt!['merchant_ref_id'] ?? 'N/A'}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textDarkSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Transaction Details Card
          _buildDetailCard(
            title: 'Transaction Details',
            icon: Iconsax.transaction_minus,
            children: [
              _buildDetailRow('Reference ID', _receipt!['merchant_ref_id'] ?? 'N/A'),
              _buildDetailRow('Amount', '₹${_formatAmount(_receipt!['amount'])}', isAmount: true),
              _buildDetailRow('Status', _getStatusText(), valueColor: _getStatusColor()),
              _buildDetailRow('Status Code', _receipt!['txn_status_code']?.toString() ?? 'N/A'),
              _buildDetailRow('Date', _formatDate(_receipt!['created_at'])),
              if (_receipt!['charges'] != null)
                _buildDetailRow('Charges', '₹${_formatAmount(_receipt!['charges'])}'),
            ],
          ),
          const SizedBox(height: 12),

          // Card Details
          if (_receipt!['card_holder_name'] != null || _receipt!['card_network'] != null)
            _buildDetailCard(
              title: 'Card Details',
              icon: Iconsax.card,
              children: [
                if (_receipt!['card_holder_name'] != null)
                  _buildDetailRow('Card Holder', _receipt!['card_holder_name']),
                if (_receipt!['card_network'] != null)
                  _buildDetailRow('Card Network', _receipt!['card_network'].toString()),
                if (_receipt!['card_last_four'] != null)
                  _buildDetailRow('Last 4 Digits', _receipt!['card_last_four'].toString()),
                if (_receipt!['rrn'] != null)
                  _buildDetailRow('RRN', _receipt!['rrn'].toString()),
              ],
            ),
          const SizedBox(height: 12),

          // Customer Details
          _buildDetailCard(
            title: 'Customer Details',
            icon: Iconsax.user,
            children: [
              _buildDetailRow('Name', _receipt!['customer_name'] ?? _receipt!['name'] ?? 'N/A'),
              _buildDetailRow('Mobile', _receipt!['customer_mobile'] ?? _receipt!['mobile']?.toString() ?? 'N/A'),
              if (_receipt!['customer_email'] != null || _receipt!['email'] != null)
                _buildDetailRow('Email', _receipt!['customer_email'] ?? _receipt!['email'] ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 12),

          // Location Details
          if (_receipt!['location'] != null || _receipt!['latitude'] != null)
            _buildDetailCard(
              title: 'Location',
              icon: Iconsax.location,
              children: [
                if (_receipt!['location'] != null)
                  _buildDetailRow('Address', _receipt!['location']),
                if (_receipt!['latitude'] != null)
                  _buildDetailRow('Latitude', _receipt!['latitude'].toString()),
                if (_receipt!['longitude'] != null)
                  _buildDetailRow('Longitude', _receipt!['longitude'].toString()),
              ],
            ),
          const SizedBox(height: 12),

          // Balance Changes
          if (_receipt!['balance_before'] != null || _receipt!['balance_after'] != null)
            _buildDetailCard(
              title: 'Balance Info',
              icon: Iconsax.wallet_money,
              children: [
                if (_receipt!['balance_before'] != null)
                  _buildDetailRow('Balance Before', '₹${_formatAmount(_receipt!['balance_before'])}'),
                if (_receipt!['balance_after'] != null)
                  _buildDetailRow('Balance After', '₹${_formatAmount(_receipt!['balance_after'])}', isAmount: true),
              ],
            ),
          const SizedBox(height: 16),

          // Wallet Credited Badge
          if (_receipt!['wallet_credited'] == true)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Iconsax.tick_circle, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Wallet Credited Successfully',
                    style: GoogleFonts.poppins(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryLight),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textDarkHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isAmount ? FontWeight.w700 : FontWeight.w500,
                color: valueColor ?? AppColors.textWhite,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '0.00';

    try {
      double value;
      if (amount is double) {
        value = amount;
      } else if (amount is int) {
        value = amount.toDouble();
      } else if (amount is String) {
        final cleaned = amount.replaceAll(RegExp(r'[^0-9.]'), '');
        value = double.tryParse(cleaned) ?? 0.0;
      } else {
        return '0.00';
      }
      return value.toStringAsFixed(2);
    } catch (_) {
      return '0.00';
    }
  }

  String _getStatusText() {
    final status = _receipt!['txn_status'] ?? 'pending';
    return status.toString().toUpperCase();
  }

  Color _getStatusColor() {
    final status = _receipt!['txn_status'] ?? 'pending';
    switch (status.toString().toLowerCase()) {
      case 'success':
      case 'completed':
        return AppColors.success;
      case 'pending':
      case 'processing':
        return AppColors.warning;
      case 'failed':
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textDarkHint;
    }
  }

  IconData _getStatusIcon() {
    final status = _receipt!['txn_status'] ?? 'pending';
    switch (status.toString().toLowerCase()) {
      case 'success':
      case 'completed':
        return Iconsax.tick_circle;
      case 'pending':
        return Iconsax.timer_1;
      case 'processing':
        return Iconsax.refresh;
      case 'failed':
      case 'rejected':
        return Iconsax.close_circle;
      default:
        return Iconsax.info_circle;
    }
  }

  String _formatDate(dynamic dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString.toString()).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } catch (_) {
      return dateTimeString.toString();
    }
  }

  void _shareReceipt() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Iconsax.share, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              'Share feature coming soon',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}