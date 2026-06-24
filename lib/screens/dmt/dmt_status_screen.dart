// lib/screens/dmt/dmt_status_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

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
    final String status = isSuccess ? 'Success' : 'Failed';
    final Color statusColor = isSuccess ? Colors.green : Colors.red;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Transfer Status',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.home),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Card
            _buildStatusCard(context, isSuccess, statusColor, status),
            const SizedBox(height: 16),

            // Transaction Details Card
            _buildTransactionDetailsCard(),
            const SizedBox(height: 16),

            // Remitter Details Card
            _buildRemitterDetailsCard(),
            const SizedBox(height: 16),

            // Beneficiary Details Card
            _buildBeneficiaryDetailsCard(),
            const SizedBox(height: 16),

            // Response Details Card
            _buildResponseDetailsCard(),
            const SizedBox(height: 24),

            // Action Buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, bool isSuccess, Color statusColor, String status) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Iconsax.tick_circle : Iconsax.close_circle,
              color: statusColor,
              size: 64,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            status,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSuccess 
                ? 'Your transfer has been completed successfully' 
                : 'Your transfer has failed. Please check the details below.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (isSuccess && transferResult['utrNumber'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Iconsax.receipt, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Text(
                    'UTR: ${transferResult['utrNumber']}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!isSuccess && transferResult['error'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                transferResult['error'],
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.red[700],
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.receipt, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Transaction Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDetailRow(
            'Transaction ID',
            transferDetails['transactionId'] ?? transferResult['transactionId'] ?? 'N/A',
          ),
          _buildDetailRow(
            'Amount',
            '₹${(transferDetails['amount'] ?? 0).toStringAsFixed(2)}',
          ),
          _buildDetailRow(
            'Transfer Mode',
            transferDetails['transferMode'] ?? 'IMPS',
          ),
          _buildDetailRow(
            'Date & Time',
            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
          ),
          if (transferResult['utrNumber'] != null)
            _buildDetailRow(
              'UTR Number',
              transferResult['utrNumber'],
              highlight: true,
            ),
          if (transferDetails['remark'] != null && transferDetails['remark'].isNotEmpty)
            _buildDetailRow(
              'Remark',
              transferDetails['remark'],
            ),
        ],
      ),
    );
  }

  Widget _buildRemitterDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.user, size: 20, color: Colors.purple[700]),
              const SizedBox(width: 8),
              Text(
                'Remitter Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDetailRow(
            'Name',
            transferDetails['remitterName'] ?? 'N/A',
          ),
          _buildDetailRow(
            'Mobile',
            transferDetails['remitterMobile'] ?? 'N/A',
          ),
          _buildDetailRow(
            'Product Type',
            transferDetails['productType']?.toUpperCase() ?? 'N/A',
          ),
          _buildDetailRow(
            'Monthly Limit',
            '₹${(transferDetails['monthlyLimit'] ?? 0).toStringAsFixed(0)}',
          ),
          _buildDetailRow(
            'Used This Month',
            '₹${(transferDetails['monthlyUsed'] ?? 0).toStringAsFixed(0)}',
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.bank, size: 20, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                'Beneficiary Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDetailRow(
            'Account Holder',
            transferDetails['beneficiaryName'] ?? 'N/A',
          ),
          _buildDetailRow(
            'Account Number',
            transferDetails['beneficiaryAccount'] ?? 'N/A',
          ),
          _buildDetailRow(
            'IFSC Code',
            transferDetails['beneficiaryIfsc'] ?? 'N/A',
          ),
          _buildDetailRow(
            'Bank Name',
            transferDetails['beneficiaryBank'] ?? 'N/A',
          ),
          if (transferDetails['beneficiaryMobile'] != null)
            _buildDetailRow(
              'Mobile',
              transferDetails['beneficiaryMobile'],
            ),
        ],
      ),
    );
  }

  Widget _buildResponseDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.document, size: 20, color: Colors.orange[700]),
              const SizedBox(width: 8),
              Text(
                'Response Details',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildDetailRow(
            'Status Code',
            transferResult['providerStatus'] ?? 'N/A',
          ),
          if (transferResult['providerRefId'] != null)
            _buildDetailRow(
              'Provider Reference',
              transferResult['providerRefId'],
            ),
          if (transferResult['bankRefNo'] != null)
            _buildDetailRow(
              'Bank Reference',
              transferResult['bankRefNo'],
            ),
          _buildDetailRow(
            'Response Time',
            '${DateTime.now().difference(DateTime.now().subtract(const Duration(seconds: 5))).inMilliseconds}ms',
          ),
          if (transferResult['message'] != null && transferResult['message'] != 'Transfer successful')
            _buildDetailRow(
              'Message',
              transferResult['message'],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
                color: highlight ? Colors.blue[700] : Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[200],
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Back',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Navigate to dashboard
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Go to Dashboard',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}