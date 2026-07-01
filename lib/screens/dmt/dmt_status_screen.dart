// lib/screens/dmt/dmt_status_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NEOFYN FIN TECH BRAND TOKENS - Premium Professional UI
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // Primary palette - Sophisticated Blue-Theme
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primarySurface = Color(0xFFEFF6FF);

  // Backgrounds
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardColor = Colors.white;
  static const Color surface = Color(0xFFFFFFFF);

  // Text colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textHint = Color(0xFF94A3B8);
  static const Color textWhite = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF0284C7);

  // Border & Effects
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF1A56DB);
}

class DMTStatusScreen extends StatelessWidget {
  final Map<String, dynamic> transferResult;
  final Map<String, dynamic> transferDetails;

  const DMTStatusScreen({
    Key? key,
    required this.transferResult,
    required this.transferDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isSuccess = transferResult['success'] == true;
    final String status = isSuccess ? 'Transfer Successful' : 'Transfer Failed';
    final Color statusColor = isSuccess ? AppColors.success : AppColors.error;
    final Color statusBgColor = isSuccess
        ? AppColors.success.withOpacity(0.06)
        : AppColors.error.withOpacity(0.06);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Transfer Status',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Iconsax.home_2, color: AppColors.textWhite, size: 20),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                      (route) => false,
                );
              },
              tooltip: 'Home',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(context, isSuccess, statusColor, statusBgColor, status),
            const SizedBox(height: 16),

            // Transaction Details Card
            _buildTransactionDetailsCard(),
            const SizedBox(height: 12),

            // Remitter Details Card
            _buildRemitterDetailsCard(),
            const SizedBox(height: 12),

            // Beneficiary Details Card
            _buildBeneficiaryDetailsCard(),
            const SizedBox(height: 12),

            // Response Details Card
            _buildResponseDetailsCard(),
            const SizedBox(height: 20),

            // Action Buttons
            _buildActionButtons(context),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      BuildContext context,
      bool isSuccess,
      Color statusColor,
      Color statusBgColor,
      String status,
      ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusBgColor,
            Colors.white,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Animated Status Icon
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.15),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isSuccess ? Iconsax.tick_circle : Iconsax.close_circle,
                    color: statusColor,
                    size: 64,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Status Text
          Text(
            status,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),

          const SizedBox(height: 6),

          // Status Message
          Text(
            isSuccess
                ? 'Your money transfer has been completed successfully'
                : 'Your transfer could not be processed',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          // UTR Number (Success) - Improved alignment
          if (isSuccess && transferResult['utrNumber'] != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.success.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.receipt_text,
                      size: 18,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'UTR Number',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.success.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          transferResult['utrNumber'],
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: transferResult['utrNumber']),
                        );
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'UTR copied to clipboard',
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            margin: const EdgeInsets.all(16),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Iconsax.copy,
                          size: 16,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error Message (Failed)
          if (!isSuccess && transferResult['error'] != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.error.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Iconsax.warning_2,
                      size: 16,
                      color: AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      transferResult['error'],
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
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

  Widget _buildTransactionDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Iconsax.receipt_2,
            title: 'Transaction Details',
            iconColor: AppColors.primary,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Transaction ID',
            transferDetails['transactionId'] ?? transferResult['transactionId'] ?? 'N/A',
            icon: Iconsax.note_text,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Amount',
            '₹${(transferDetails['amount'] ?? 0).toStringAsFixed(2)}',
            icon: Iconsax.money_send,
            isAmount: true,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Transfer Mode',
            transferDetails['transferMode'] ?? 'IMPS',
            icon: Iconsax.flash_circle,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Date & Time',
            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
            icon: Iconsax.calendar_1,
          ),
          if (transferResult['utrNumber'] != null) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'UTR Number',
              transferResult['utrNumber'],
              icon: Iconsax.receipt,
              highlight: true,
            ),
          ],
          if (transferDetails['remark'] != null && transferDetails['remark'].isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Remark',
              transferDetails['remark'],
              icon: Iconsax.message_text,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemitterDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Iconsax.user,
            title: 'Remitter Details',
            iconColor: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Name',
            transferDetails['remitterName'] ?? 'N/A',
            icon: Iconsax.user_tag,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Mobile',
            transferDetails['remitterMobile'] ?? 'N/A',
            icon: Iconsax.call,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Product Type',
            transferDetails['productType']?.toUpperCase() ?? 'N/A',
            icon: Iconsax.crown,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Monthly Limit',
            '₹${(transferDetails['monthlyLimit'] ?? 0).toStringAsFixed(0)}',
            icon: Iconsax.chart_square,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Used This Month',
            '₹${(transferDetails['monthlyUsed'] ?? 0).toStringAsFixed(0)}',
            icon: Iconsax.activity,
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Iconsax.bank,
            title: 'Beneficiary Details',
            iconColor: AppColors.success,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Account Holder',
            transferDetails['beneficiaryName'] ?? 'N/A',
            icon: Iconsax.user,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Account Number',
            transferDetails['beneficiaryAccount'] ?? 'N/A',
            icon: Iconsax.card,
            isSensitive: true,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'IFSC Code',
            transferDetails['beneficiaryIfsc'] ?? 'N/A',
            icon: Iconsax.code,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Bank Name',
            transferDetails['beneficiaryBank'] ?? 'N/A',
            icon: Iconsax.building,
          ),
          if (transferDetails['beneficiaryMobile'] != null) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Mobile',
              transferDetails['beneficiaryMobile'],
              icon: Iconsax.mobile,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResponseDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Iconsax.document_text,
            title: 'Response Details',
            iconColor: AppColors.warning,
          ),
          const SizedBox(height: 16),
          _buildDetailRow(
            'Status Code',
            transferResult['providerStatus'] ?? 'N/A',
            icon: Iconsax.status,
          ),
          if (transferResult['providerRefId'] != null) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Provider Reference',
              transferResult['providerRefId'],
              icon: Iconsax.link,
            ),
          ],
          if (transferResult['bankRefNo'] != null) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Bank Reference',
              transferResult['bankRefNo'],
              icon: Iconsax.bank,
            ),
          ],
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Response Time',
            '~500ms',
            icon: Iconsax.timer_1,
          ),
          if (transferResult['message'] != null &&
              transferResult['message'] != 'Transfer successful') ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Message',
              transferResult['message'],
              icon: Iconsax.message,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: iconColor.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
      String label,
      String value, {
        IconData? icon,
        bool highlight = false,
        bool isAmount = false,
        bool isSensitive = false,
      }) {
    // Mask sensitive data like account numbers
    String displayValue = value;
    if (isSensitive && value.length > 4) {
      displayValue = '••••${value.substring(value.length - 4)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 12,
                color: highlight ? AppColors.primary : AppColors.textHint,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    displayValue,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: highlight || isAmount ? FontWeight.w700 : FontWeight.w500,
                      color: highlight
                          ? AppColors.primary
                          : isAmount
                          ? AppColors.textPrimary
                          : AppColors.textPrimary,
                      letterSpacing: highlight ? 0.3 : 0,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                if (isSensitive && value.length > 4) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(
                        Iconsax.copy,
                        size: 12,
                        color: AppColors.textHint,
                      ),
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.borderLight,
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderLight, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.heavyImpact();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                      (route) => false,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.home_2, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Go to Dashboard',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}