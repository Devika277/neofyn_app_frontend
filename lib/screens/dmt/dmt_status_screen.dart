// lib/screens/dmt/dmt_status_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../services/dmt/api_service.dart'; // IMPORT YOUR API SERVICE

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
  static const Color info = Color(0xFF3B82F6);
  static const Color processing = Color(0xFF8B5CF6);
  static const Color borderDark = Color(0xFF2A342A);
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
  final ApiService _apiService = ApiService();
  bool _isPolling = false;
  int _pollingAttempts = 0;
  static const int _maxPollingAttempts = 24; // 24 * 5 seconds = 2 minutes
  String _currentStatus = '';
  String _statusMessage = '';
  String? _referenceId;
  String? _rrnNumber;
  String? _providerStatusCode;
  String? _transactionId;

  static const Map<String, String> _providerStatusMap = {
    '000': 'success',
    '001': 'success',
    '002': 'failed',
    '003': 'pending',
    '004': 'queued',
    '005': 'processing',
    '006': 'hold',
    '007': 'reversed',
  };

  @override
  void initState() {
    super.initState();
    _transactionId = widget.transferResult['transactionId']?.toString() ??
        widget.transferDetails['transactionId']?.toString();
    _determineStatus();
    _startPollingIfNeeded();
  }

  @override
  void dispose() {
    _isPolling = false;
    super.dispose();
  }

  void _determineStatus() {
    final result = widget.transferResult;
    final details = widget.transferDetails;

    debugPrint('📊 DMT Transfer Result: $result');

    if (result.containsKey('providerStatus') && result['providerStatus'] != null) {
      _providerStatusCode = result['providerStatus'].toString().trim();
    }

    final message = result['message']?.toString().toLowerCase() ?? '';
    final success = result['success'];

    if (_providerStatusCode != null && _providerStatusMap.containsKey(_providerStatusCode)) {
      _currentStatus = _providerStatusMap[_providerStatusCode]!;
    } else if (message.contains('queued')) {
      _currentStatus = 'queued';
    } else if (message.contains('processing')) {
      _currentStatus = 'processing';
    } else if (message.contains('pending')) {
      _currentStatus = 'pending';
    } else if (message.contains('success') || message.contains('completed')) {
      _currentStatus = 'success';
    } else if (message.contains('fail')) {
      _currentStatus = 'failed';
    } else {
      _currentStatus = success == true ? 'success' : 'failed';
    }

    _referenceId = result['providerRefId']?.toString() ??
        details['providerRefId']?.toString();

    _rrnNumber = result['rrn']?.toString() ??
        result['bankRefNo']?.toString() ??
        result['utrNumber']?.toString() ??
        result['utr_number']?.toString() ??
        details['utrNumber']?.toString() ??
        details['utr_number']?.toString();

    _statusMessage = _getStatusMessage(_currentStatus);

    debugPrint('📊 Status: $_currentStatus | TxnID: $_transactionId | RRN: $_rrnNumber');
  }

  String _getStatusMessage(String status) {
    switch (status) {
      case 'success':
      case 'completed':
        return 'Your money transfer has been completed successfully';
      case 'queued':
        return 'Your transfer is queued and will be processed shortly';
      case 'processing':
        return 'Your transfer is being processed. Please wait...';
      case 'pending':
        return 'Your transfer is pending confirmation';
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
  bool get _isProcessing => _currentStatus == 'processing' || _currentStatus == 'pending' || _currentStatus == 'queued';
  bool get _isOnHold => _currentStatus == 'hold';
  bool get _needsPolling => (_isProcessing || _isOnHold) && !_isPolling && _transactionId != null;

  void _startPollingIfNeeded() {
    if (_needsPolling && mounted) {
      debugPrint('🔄 Starting polling for: $_transactionId');
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

    // Stop after max attempts
    if (_pollingAttempts >= _maxPollingAttempts) {
      debugPrint('⏰ Polling timeout');
      setState(() {
        _isPolling = false;
        _statusMessage = 'Taking longer than expected. Please check history for updates.';
      });
      return;
    }

    setState(() {
      _pollingAttempts++;
    });

    debugPrint('🔄 Polling $_pollingAttempts/$_maxPollingAttempts for $_transactionId');

    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) return;

    try {
      // 🔴 MAKE REAL API CALL - SAME AS PAYOUT
      if (_transactionId != null) {
        final response = await _apiService.checkDmtStatus(
          transactionId: _transactionId!,
        );

        debugPrint('📡 Status check response: $response');

        if (response['success'] == true) {
          final data = response['data'] ?? response;
          final newStatus = data['status']?.toString().toLowerCase() ?? '';
          final rrn = data['rrn']?.toString() ??
              data['bankRefNo']?.toString() ??
              data['utrNumber']?.toString() ??
              data['utr_number']?.toString();

          debugPrint('📡 New Status: $newStatus | RRN: $rrn');

          if (newStatus == 'success' || newStatus == 'completed') {
            _updateStatus('success', rrn: rrn);
            return;
          } else if (newStatus == 'failed' || newStatus == 'failure' || newStatus == 'reversed') {
            _updateStatus('failed');
            return;
          }
        }
      }

      // Check if transaction is too old (>5 min like payout)
      final createdAt = widget.transferResult['created_at'] ?? widget.transferDetails['created_at'];
      if (createdAt != null) {
        final created = DateTime.tryParse(createdAt.toString());
        if (created != null && DateTime.now().difference(created).inMinutes > 5) {
          debugPrint('⏰ Transaction older than 5 minutes');
          _isPolling = false;
          setState(() {
            _statusMessage = 'Transaction pending. Please check history for updates.';
          });
          return;
        }
      }

      // Continue polling
      if (_isPolling && _pollingAttempts < _maxPollingAttempts) {
        _pollStatus();
      }
    } catch (e) {
      debugPrint('❌ Status check error: $e');
      // Continue polling on error
      if (mounted && _isPolling && _pollingAttempts < _maxPollingAttempts) {
        _pollStatus();
      }
    }
  }

  void _updateStatus(String newStatus, {String? rrn}) {
    if (!mounted) return;

    setState(() {
      _currentStatus = newStatus.toLowerCase();
      _statusMessage = _getStatusMessage(_currentStatus);

      if (rrn != null && rrn.isNotEmpty) {
        _rrnNumber = rrn;
      }

      if (_isSuccess || _isFailed) {
        _isPolling = false;
        debugPrint('✅ Final: $_currentStatus | RRN: $_rrnNumber');
      }
    });
  }

  String _getDisplayReference() {
    if (_isSuccess) {
      return _rrnNumber ?? _referenceId ?? 'N/A';
    }
    return _referenceId ?? 'N/A';
  }

  String _getDisplayReferenceLabel() {
    if (_isSuccess && _rrnNumber != null && _rrnNumber!.isNotEmpty) {
      return 'RRN Number';
    }
    if (_isSuccess) {
      return 'UTR Number';
    }
    return 'Reference ID';
  }

  String _getDisplayStatus() {
    switch (_currentStatus) {
      case 'success': return 'SUCCESS';
      case 'completed': return 'COMPLETED';
      case 'failed': return 'FAILED';
      case 'failure': return 'FAILED';
      case 'queued': return 'QUEUED';
      case 'processing': return 'PROCESSING';
      case 'pending': return 'PENDING';
      case 'reversed': return 'REVERSED';
      case 'hold': return 'ON HOLD';
      default: return _currentStatus.toUpperCase();
    }
  }

  Color _getStatusColor() {
    if (_isSuccess) return AppColors.success;
    if (_isFailed) return AppColors.error;
    if (_isProcessing) return AppColors.processing;
    if (_isOnHold) return AppColors.warning;
    return AppColors.warning;
  }

  String _getStatusTitle() {
    if (_isSuccess) return 'Transaction Successful';
    if (_isFailed) return 'Transaction Failed';
    if (_currentStatus == 'queued') return 'Transaction Queued';
    if (_currentStatus == 'processing') return 'Processing...';
    if (_currentStatus == 'pending') return 'Pending';
    if (_isOnHold) return 'On Hold';
    return 'Status: ${_currentStatus.toUpperCase()}';
  }

  IconData _getStatusIcon() {
    if (_isSuccess) return Iconsax.tick_circle;
    if (_isFailed) return Iconsax.close_circle;
    if (_isProcessing || _isOnHold) return Iconsax.clock;
    return Iconsax.info_circle;
  }

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getStatusColor();
    final String statusTitle = _getStatusTitle();
    final IconData statusIcon = _getStatusIcon();
    final String displayRef = _getDisplayReference();
    final String displayRefLabel = _getDisplayReferenceLabel();

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'Transfer Status',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textWhite),
        ),
        centerTitle: true,
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isProcessing || _isOnHold)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
              onPressed: () {
                setState(() {
                  _isPolling = true;
                  _pollingAttempts = 0;
                });
                _pollStatus();
              },
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(statusColor, statusTitle, statusIcon, displayRef, displayRefLabel),
            const SizedBox(height: 16),

            if (_isPolling) ...[
              _buildPollingIndicator(),
              const SizedBox(height: 12),
            ],

            _buildInfoCard('Transaction Details', [
              _infoRow('Transaction ID', widget.transferDetails['transactionId'] ?? widget.transferResult['transactionId'] ?? 'N/A'),
              _infoRow('Amount', '₹${(widget.transferDetails['amount'] ?? 0).toStringAsFixed(2)}'),
              _infoRow('Transfer Mode', widget.transferDetails['transferMode'] ?? 'IMPS'),
              _infoRow('Date & Time', DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())),
              if (displayRef.isNotEmpty && displayRef != 'N/A')
                _infoRow(displayRefLabel, displayRef, valueColor: _isSuccess ? AppColors.success : AppColors.processing),
              _infoRow('Status', _getDisplayStatus(), valueColor: statusColor),
            ]),
            const SizedBox(height: 12),

            _buildInfoCard('Remitter Details', [
              _infoRow('Name', widget.transferDetails['remitterName'] ?? 'N/A'),
              _infoRow('Mobile', widget.transferDetails['remitterMobile'] ?? 'N/A'),
            ]),
            const SizedBox(height: 12),

            _buildInfoCard('Beneficiary Details', [
              _infoRow('Account Holder', widget.transferDetails['beneficiaryName'] ?? 'N/A'),
              _infoRow('Account Number', _maskAccount(widget.transferDetails['beneficiaryAccount'] ?? 'N/A')),
              _infoRow('IFSC Code', widget.transferDetails['beneficiaryIfsc'] ?? 'N/A'),
              _infoRow('Bank Name', widget.transferDetails['beneficiaryBank'] ?? 'N/A'),
            ]),
            const SizedBox(height: 12),

            _buildInfoCard('Response Details', [
              if (_providerStatusCode != null)
                _infoRow('Provider Code', _providerStatusCode!),
              if (widget.transferResult['message'] != null && widget.transferResult['message'].toString().isNotEmpty)
                _infoRow('Message', widget.transferResult['message'].toString()),
              if (_referenceId != null && _referenceId!.isNotEmpty)
                _infoRow('Provider Ref ID', _referenceId!),
            ]),
            const SizedBox(height: 20),

            if (_isProcessing || _isOnHold)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isPolling = true;
                        _pollingAttempts = 0;
                      });
                      _pollStatus();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Check Status Now'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.warning,
                      side: const BorderSide(color: AppColors.warning),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Go Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(Color statusColor, String statusTitle, IconData statusIcon, String displayRef, String displayRefLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
          ),
          child: (_isProcessing || _isOnHold)
              ? Padding(
            padding: const EdgeInsets.all(14),
            child: CircularProgressIndicator(strokeWidth: 3, color: statusColor),
          )
              : Icon(statusIcon, size: 36, color: statusColor),
        ),
        const SizedBox(height: 12),
        Text(statusTitle, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor)),
        const SizedBox(height: 4),
        Text(
          _statusMessage,
          style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.5), fontSize: 11),
          textAlign: TextAlign.center,
        ),

        if (displayRef.isNotEmpty && displayRef != 'N/A') ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withOpacity(0.2)),
            ),
            child: Row(children: [
              Icon(_isSuccess ? Iconsax.receipt_text : Iconsax.link, size: 18, color: statusColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(displayRefLabel, style: GoogleFonts.poppins(fontSize: 10, color: statusColor.withOpacity(0.7), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(displayRef, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: displayRef));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$displayRefLabel copied', style: GoogleFonts.poppins(fontSize: 13)),
                        backgroundColor: statusColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Iconsax.copy, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ]),
          ),
        ],

        if (_isPolling) ...[
          const SizedBox(height: 12),
          const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.warning)),
        ],
      ]),
    );
  }

  Widget _buildPollingIndicator() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.processing.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.processing.withOpacity(0.2)),
      ),
      child: Row(children: [
        SizedBox(
          height: 18, width: 18,
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppColors.processing)),
        ),
        const SizedBox(width: 10),
        Text(
          'Checking status... (${_pollingAttempts}/${_maxPollingAttempts})',
          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.processing, fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 12),
        ...children,
      ]),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12))),
        Expanded(child: Text(value.isNotEmpty ? value : 'N/A', textAlign: TextAlign.right, style: GoogleFonts.poppins(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  String _maskAccount(String account) {
    if (account.length <= 4) return account;
    return '••••${account.substring(account.length - 4)}';
  }
}