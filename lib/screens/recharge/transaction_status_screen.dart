import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:my_app/services/recharges/recharge_service.dart';

class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color darkBg = Color(0xFF0A0E0A);
  static const Color darkSurface = Color(0xFF1A1F1A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF9CA3AF);
  static const Color textDarkHint = Color(0xFF6B7280);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color borderDark = Color(0xFF2A342A);
  static const Color borderFocus = Color(0xFF008169);
}

class TransactionStatusScreen extends StatefulWidget {
  final int transactionId;
  final double amount;
  final String operator;
  final String mobile;
  final String initialStatus;

  const TransactionStatusScreen({
    Key? key,
    required this.transactionId,
    required this.amount,
    required this.operator,
    required this.mobile,
    this.initialStatus = 'pending',
  }) : super(key: key);

  @override
  State<TransactionStatusScreen> createState() => _TransactionStatusScreenState();
}

class _TransactionStatusScreenState extends State<TransactionStatusScreen>
    with TickerProviderStateMixin {
  Timer? _pollingTimer;
  String _currentStatus = 'pending';
  String _statusMessage = '';
  String _operatorRefId = '';
  int _pollCount = 0;
  final int _maxPolls = 12;

  late AnimationController _pulseController;
  late AnimationController _checkmarkController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.initialStatus;
    _initAnimations();
    _startPolling();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkmarkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // If already success, show checkmark immediately
    if (_currentStatus == 'success') {
      _checkmarkController.forward();
    }
  }

  void _startPolling() {
    // Don't poll for already completed transactions
    if (_currentStatus == 'success' || _currentStatus == 'failed') {
      return;
    }

    // Poll every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    if (_pollCount >= _maxPolls) {
      _pollingTimer?.cancel();
      if (mounted) {
        setState(() {
          _statusMessage = 'Taking longer than expected. Check history.';
        });
      }
      return;
    }

    _pollCount++;

    try {
      final result = await RechargeService.checkTransactionStatus(widget.transactionId);

      if (!mounted) return;

      setState(() {
        _currentStatus = result['status'] ?? _currentStatus;
        _statusMessage = result['message'] ?? '';
        _operatorRefId = result['operator_ref_id'] ?? '';
      });

      if (_currentStatus == 'success' || _currentStatus == 'failed') {
        _pollingTimer?.cancel();
        if (_currentStatus == 'success') {
          _checkmarkController.forward();
          HapticFeedback.heavyImpact();
        }
      }
    } catch (e) {
      debugPrint('Status check error: $e');
      // Stop polling after too many errors
      if (_pollCount >= 3) {
        _pollingTimer?.cancel();
        if (mounted) {
          setState(() {
            _statusMessage = 'Check transaction history for status.';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _pulseController.dispose();
    _checkmarkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'Transaction Status',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: AppColors.textWhite,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Status Icon
              _buildStatusIcon(),
              const SizedBox(height: 28),
              // Title
              Text(
                _getStatusTitle(),
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _getStatusColor(),
                ),
              ),
              const SizedBox(height: 10),
              // Message
              Text(
                _getStatusMessage(),
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textDarkSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              // Transaction Card
              _buildTransactionCard(),
              const SizedBox(height: 16),
              // Operator Ref
              if (_operatorRefId.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.receipt_1, size: 16, color: AppColors.primaryLight),
                      const SizedBox(width: 8),
                      Text(
                        'Ref: $_operatorRefId',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),
              // Progress bar (only for pending)
              if (_currentStatus == 'pending') ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _pollCount / _maxPolls,
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    color: AppColors.primaryLight,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Checking status...',
                  style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkHint),
                ),
                const SizedBox(height: 24),
              ],
              // Action buttons
              if (_currentStatus == 'success' || _currentStatus == 'failed')
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentStatus == 'success' ? AppColors.success : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: Text(
                      _currentStatus == 'success' ? 'Done' : 'Try Again',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Iconsax.receipt_1, size: 18, color: AppColors.primaryLight),
                label: Text(
                  'View History',
                  style: GoogleFonts.poppins(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              if (_currentStatus == 'pending') ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _pollingTimer?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Go Back',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDarkSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (_currentStatus) {
      case 'success':
        return AnimatedBuilder(
          animation: _checkmarkController,
          builder: (context, child) {
            return Transform.scale(
              scale: _checkmarkController.value,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 72),
              ),
            );
          },
        );
      case 'failed':
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.cancel_rounded, color: AppColors.error, size: 72),
        );
      default:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation(AppColors.warning),
                  ),
                ),
              ),
            );
          },
        );
    }
  }

  Widget _buildTransactionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        children: [
          _buildDetailRow('Transaction ID', '#${widget.transactionId}'),
          const SizedBox(height: 10),
          _buildDetailRow('Mobile', widget.mobile),
          const SizedBox(height: 10),
          _buildDetailRow('Operator', widget.operator),
          const SizedBox(height: 10),
          _buildDetailRow('Amount', '₹${widget.amount.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _buildDetailRow('Status', _getStatusBadge(), isStatus: true, statusColor: _getStatusColor()),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false, Color? statusColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDarkSecondary)),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (statusColor ?? AppColors.primary).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value,
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
          )
        else
          Text(value,
              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textWhite)),
      ],
    );
  }

  String _getStatusTitle() {
    switch (_currentStatus) {
      case 'success': return 'Recharge Successful! 🎉';
      case 'failed': return 'Recharge Failed';
      case 'pending': return 'Processing...';
      default: return 'Checking...';
    }
  }

  String _getStatusMessage() {
    switch (_currentStatus) {
      case 'success':
        return '₹${widget.amount.toStringAsFixed(2)} recharged to ${widget.mobile}';
      case 'failed':
        return _statusMessage.isNotEmpty ? _statusMessage : 'Amount will be refunded to your wallet.';
      case 'pending':
        return _getPendingMessage();
      default:
        return 'Fetching status...';
    }
  }

  String _getPendingMessage() {
    final messages = [
      'Connecting to ${widget.operator}...',
      'Verifying mobile number...',
      'Processing payment...',
      'Waiting for confirmation...',
      'Almost there...',
      'Still processing...',
    ];
    return messages[(_pollCount - 1).clamp(0, messages.length - 1)];
  }

  String _getStatusBadge() {
    switch (_currentStatus) {
      case 'success': return '✅ Successful';
      case 'failed': return '❌ Failed';
      case 'pending': return '⏳ Processing';
      default: return '🔄 Unknown';
    }
  }

  Color _getStatusColor() {
    switch (_currentStatus) {
      case 'success': return AppColors.success;
      case 'failed': return AppColors.error;
      default: return AppColors.warning;
    }
  }
}