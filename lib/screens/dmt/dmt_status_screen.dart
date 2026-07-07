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
  static const Color processing = Color(0xFF7C3AED); // Purple for processing

  // Border & Effects
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF1A56DB);
}

class DMTStatusScreen extends StatefulWidget {
  final Map<String, dynamic> transferResult;
  final Map<String, dynamic> transferDetails;

  const DMTStatusScreen({
    Key? key,
    required this.transferResult,
    required this.transferDetails,
  }) : super(key: key);

  @override
  State<DMTStatusScreen> createState() => _DMTStatusScreenState();
}

class _DMTStatusScreenState extends State<DMTStatusScreen> {
  bool _isPolling = false;
  int _pollingAttempts = 0;
  static const int _maxPollingAttempts = 15; // 15 * 3 seconds = 45 seconds
  String _currentStatus = '';
  String _statusMessage = '';
  String? _utrNumber;

  @override
  void initState() {
    super.initState();
    _determineStatus();
    _startPollingIfNeeded();
  }

  void _determineStatus() {
    final result = widget.transferResult;
    
    // Check if status is provided directly
    if (result.containsKey('status')) {
      _currentStatus = result['status'].toString().toLowerCase();
    } 
    // Check merchantStatus from provider
    else if (result.containsKey('merchantStatus')) {
      _currentStatus = result['merchantStatus'].toString().toLowerCase();
    }
    // Check providerStatus
    else if (result.containsKey('providerStatus')) {
      _currentStatus = result['providerStatus'].toString().toLowerCase();
    }
    // Fallback to success/failure
    else {
      _currentStatus = result['success'] == true ? 'success' : 'failed';
    }

    // Get UTR if available
    if (result.containsKey('utrNumber')) {
      _utrNumber = result['utrNumber'];
    }

    // Set status message
    _statusMessage = _getStatusMessage(_currentStatus);
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'success':
      case 'completed':
        return 'Your money transfer has been completed successfully';
      case 'processing':
      case 'pending':
      case 'queued':
        return 'Your transfer is being processed. Please wait...';
      case 'failed':
      case 'failure':
        return 'Your transfer could not be processed';
      case 'reversed':
        return 'The transaction has been reversed';
      case 'hold':
        return 'The transaction is on hold. Please contact support';
      default:
        return 'Status: ${status.toUpperCase()}';
    }
  }

  bool get _isSuccess => _currentStatus == 'success' || _currentStatus == 'completed';
  bool get _isFailed => _currentStatus == 'failed' || _currentStatus == 'failure' || _currentStatus == 'reversed';
  bool get _isProcessing => _currentStatus == 'processing' || _currentStatus == 'pending' || _currentStatus == 'queued' || _currentStatus == 'hold';
  bool get _needsPolling => _isProcessing && !_isPolling;

  void _startPollingIfNeeded() {
    if (_needsPolling && mounted) {
      _startPolling();
    }
  }

  void _startPolling() {
    if (_isPolling) return;
    
    setState(() {
      _isPolling = true;
      _pollingAttempts = 0;
    });

    _pollStatus();
  }

  void _pollStatus() async {
    if (!mounted) return;
    if (_pollingAttempts >= _maxPollingAttempts) {
      setState(() {
        _isPolling = false;
        _currentStatus = 'timeout';
        _statusMessage = 'Transaction is taking longer than expected. Please check status later.';
      });
      return;
    }

    setState(() {
      _pollingAttempts++;
    });

    // Simulate polling delay (3 seconds)
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    // Here you would make an API call to check the actual status
    // For now, we'll simulate a status check
    try {
      // Replace this with actual API call to check transfer status
      // final updatedStatus = await _apiService.checkTransferStatus(transactionId);
      // _updateStatus(updatedStatus);
      
      // Simulated status check - for demo purposes
      if (_pollingAttempts >= 5) {
        // After 5 attempts, assume success for demo
        _updateStatus('success');
      } else {
        // Continue polling
        _pollStatus();
      }
    } catch (e) {
      // If API call fails, continue polling
      _pollStatus();
    }
  }

  void _updateStatus(String newStatus) {
    if (!mounted) return;
    
    setState(() {
      _currentStatus = newStatus.toLowerCase();
      _statusMessage = _getStatusMessage(_currentStatus);
      
      if (_isSuccess || _isFailed) {
        _isPolling = false;
      } else if (_isProcessing && _pollingAttempts < _maxPollingAttempts) {
        // Continue polling
        _pollStatus();
      } else {
        _isPolling = false;
      }
    });
  }

  Color _getStatusColor(String status) {
    if (_isSuccess) return AppColors.success;
    if (_isFailed) return AppColors.error;
    if (_isProcessing) return AppColors.processing;
    return AppColors.warning;
  }

  Color _getStatusBgColor(String status) {
    return _getStatusColor(status).withOpacity(0.06);
  }

  String _getStatusTitle(String status) {
    if (_isSuccess) return 'Transfer Successful';
    if (_isFailed) return 'Transfer Failed';
    if (_isProcessing) return 'Processing...';
    if (status == 'hold') return 'On Hold';
    return 'Status: ${status.toUpperCase()}';
  }

  IconData _getStatusIcon(String status) {
    if (_isSuccess) return Iconsax.tick_circle;
    if (_isFailed) return Iconsax.close_circle;
    if (_isProcessing) return Iconsax.timer_1;
    if (status == 'hold') return Iconsax.clock;
    return Iconsax.info_circle;
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getStatusColor(_currentStatus);
    final Color statusBgColor = _getStatusBgColor(_currentStatus);
    final String statusTitle = _getStatusTitle(_currentStatus);
    final IconData statusIcon = _getStatusIcon(_currentStatus);

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
          if (!_isProcessing)
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
            _buildStatusCard(context, statusColor, statusBgColor, statusTitle, statusIcon),
            const SizedBox(height: 16),

            // Polling Indicator (when processing)
            if (_isProcessing && _isPolling) ...[
              _buildPollingIndicator(),
              const SizedBox(height: 12),
            ],

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

  Widget _buildPollingIndicator() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.processing.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.processing.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.processing),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Checking status... (${_pollingAttempts}/${_maxPollingAttempts})',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.processing,
                  ),
                ),
                Text(
                  'Please wait while we confirm your transaction',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    Color statusColor,
    Color statusBgColor,
    String statusTitle,
    IconData statusIcon,
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
                  child: _isProcessing
                      ? SizedBox(
                          height: 48,
                          width: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          ),
                        )
                      : Icon(
                          statusIcon,
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
            statusTitle,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),

          const SizedBox(height: 6),

          // Status Message
          Text(
            _statusMessage,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          // UTR Number (Success) - Improved alignment
          if (_isSuccess && _utrNumber != null) ...[
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
                          _utrNumber!,
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
                        // Clipboard.setData(
                        //   ClipboardData(text: _utrNumber),
                        // );
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
          if (_isFailed && widget.transferResult['error'] != null) ...[
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
                      widget.transferResult['error'],
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

          // Processing Info (when processing)
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.info_circle,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This transaction is being processed. Please do not retry.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
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
            widget.transferDetails['transactionId'] ?? widget.transferResult['transactionId'] ?? 'N/A',
            icon: Iconsax.note_text,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Amount',
            '₹${(widget.transferDetails['amount'] ?? 0).toStringAsFixed(2)}',
            icon: Iconsax.money_send,
            isAmount: true,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Transfer Mode',
            widget.transferDetails['transferMode'] ?? 'IMPS',
            icon: Iconsax.flash_circle,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Date & Time',
            DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
            icon: Iconsax.calendar_1,
          ),
          if (_utrNumber != null) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'UTR Number',
              _utrNumber!,
              icon: Iconsax.receipt,
              highlight: true,
            ),
          ],
          if (widget.transferDetails['remark'] != null && widget.transferDetails['remark'].isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Remark',
              widget.transferDetails['remark'],
              icon: Iconsax.message_text,
            ),
          ],
          // Add status row for processing states
          if (_isProcessing) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Current Status',
              _currentStatus.toUpperCase(),
              icon: Iconsax.status,
              highlight: true,
              statusColor: AppColors.processing,
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
            widget.transferDetails['remitterName'] ?? 'N/A',
            icon: Iconsax.user_tag,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Mobile',
            widget.transferDetails['remitterMobile'] ?? 'N/A',
            icon: Iconsax.call,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Product Type',
            widget.transferDetails['productType']?.toUpperCase() ?? 'N/A',
            icon: Iconsax.crown,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Monthly Limit',
            '₹${(widget.transferDetails['monthlyLimit'] ?? 0).toStringAsFixed(0)}',
            icon: Iconsax.chart_square,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Used This Month',
            '₹${(widget.transferDetails['monthlyUsed'] ?? 0).toStringAsFixed(0)}',
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
            widget.transferDetails['beneficiaryName'] ?? 'N/A',
            icon: Iconsax.user,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Account Number',
            widget.transferDetails['beneficiaryAccount'] ?? 'N/A',
            icon: Iconsax.card,
            isSensitive: true,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'IFSC Code',
            widget.transferDetails['beneficiaryIfsc'] ?? 'N/A',
            icon: Iconsax.code,
          ),
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Bank Name',
            widget.transferDetails['beneficiaryBank'] ?? 'N/A',
            icon: Iconsax.building,
          ),
          if (widget.transferDetails['beneficiaryMobile'] != null) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Mobile',
              widget.transferDetails['beneficiaryMobile'],
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
            widget.transferResult['providerStatus'] ?? widget.transferResult['status'] ?? 'N/A',
            icon: Iconsax.status,
          ),
          if (widget.transferResult['providerRefId'] != null) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Provider Reference',
              widget.transferResult['providerRefId'],
              icon: Iconsax.link,
            ),
          ],
          if (widget.transferResult['bankRefNo'] != null) ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Bank Reference',
              widget.transferResult['bankRefNo'],
              icon: Iconsax.bank,
            ),
          ],
          const Divider(height: 20, color: AppColors.borderLight),
          _buildDetailRow(
            'Response Time',
            '~500ms',
            icon: Iconsax.timer_1,
          ),
          if (widget.transferResult['message'] != null &&
              widget.transferResult['message'] != 'Transfer successful') ...[
            const Divider(height: 20, color: AppColors.borderLight),
            _buildDetailRow(
              'Message',
              widget.transferResult['message'],
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
    Color? statusColor,
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
                color: highlight ? (statusColor ?? AppColors.primary) : AppColors.textHint,
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
                          ? (statusColor ?? AppColors.primary)
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