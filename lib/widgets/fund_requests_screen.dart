// lib/screens/fund_requests_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/fund_provider.dart';

class AppColors {
  static const Color primary = Color(0xFF008169);
  static const Color primaryDark = Color(0xFF005F4E);
  static const Color primaryLight = Color(0xFF1AA88A);
  static const Color inputBg = Color(0xFF1A1F1A);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF008169);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class FundRequestsScreen extends StatefulWidget {
  const FundRequestsScreen({super.key});

  @override
  State<FundRequestsScreen> createState() => _FundRequestsScreenState();
}

class _FundRequestsScreenState extends State<FundRequestsScreen> {
  bool _isInitialLoad = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  Future<void> _loadRequests() async {
    final fundProvider = context.read<FundProvider>();
    await fundProvider.getMyRequests();
    setState(() {
      _isInitialLoad = false;
    });
  }

  List<dynamic> _getFilteredRequests(FundProvider fundProvider) {
    if (_selectedFilter == 'all') return fundProvider.myRequests;
    return fundProvider.myRequests.where((request) {
      return (request['status'] ?? 'pending').toString().toLowerCase() == _selectedFilter;
    }).toList();
  }

  int _getStatusCount(FundProvider fundProvider, String status) {
    if (status == 'all') return fundProvider.myRequests.length;
    return fundProvider.myRequests.where((r) =>
    (r['status'] ?? 'pending').toString().toLowerCase() == status
    ).length;
  }

  @override
  Widget build(BuildContext context) {
    final fundProvider = context.watch<FundProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E0A),
              Color(0xFF0F1A0F),
              Color(0xFF0A0E0A),
              Color(0xFF050805),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Compact Header
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new, size: 14, color: Colors.white54),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'My Fund Requests',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _loadRequests();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.refresh, size: 16, color: Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),

              // Compact Filter Chips
              Container(
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip('All', 'all', _getStatusCount(fundProvider, 'all')),
                    _buildFilterChip('Pending', 'pending', _getStatusCount(fundProvider, 'pending')),
                    _buildFilterChip('Approved', 'approved', _getStatusCount(fundProvider, 'approved')),
                    _buildFilterChip('Rejected', 'rejected', _getStatusCount(fundProvider, 'rejected')),
                    _buildFilterChip('Cancelled', 'cancelled', _getStatusCount(fundProvider, 'cancelled')),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Content
              Expanded(
                child: _buildBody(fundProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _selectedFilter == value;
    Color chipColor;

    switch (value) {
      case 'approved':
        chipColor = AppColors.success;
        break;
      case 'rejected':
        chipColor = AppColors.error;
        break;
      case 'cancelled':
        chipColor = Colors.white38;
        break;
      case 'pending':
        chipColor = AppColors.warning;
        break;
      default:
        chipColor = AppColors.primaryLight;
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = value);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? chipColor.withOpacity(0.3) : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.circle, size: 6, color: chipColor),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? chipColor : Colors.white54,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? chipColor.withOpacity(0.2) : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? chipColor : Colors.white38,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FundProvider fundProvider) {
    if (_isInitialLoad && fundProvider.isLoadingRequests) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryLight,
          strokeWidth: 2,
        ),
      );
    }

    if (fundProvider.requestsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error.withOpacity(0.15),
                ),
                child: const Icon(Icons.error_outline, size: 28, color: AppColors.error),
              ),
              const SizedBox(height: 12),
              Text(
                fundProvider.requestsError!,
                style: const TextStyle(fontSize: 13, color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              _buildRetryButton(),
            ],
          ),
        ),
      );
    }

    final filteredRequests = _getFilteredRequests(fundProvider);

    if (filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 10),
            Text(
              'No requests found',
              style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: AppColors.primaryLight,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        itemCount: filteredRequests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(filteredRequests[index], fundProvider);
        },
      ),
    );
  }

  Widget _buildRequestCard(dynamic request, FundProvider fundProvider) {
    final status = request['status'] ?? 'pending';
    final amount = request['amount'] ?? '0';
    final bankName = request['bank_name'] ?? 'N/A';
    final paymentMode = request['payment_mode'] ?? 'N/A';
    final referenceNumber = request['reference_number'] ?? 'N/A';
    final remark = request['remark'] ?? '';
    final createdAt = request['created_at'] ?? '';

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (status.toString().toLowerCase()) {
      case 'approved':
        statusColor = AppColors.success;
        statusLabel = 'Approved';
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusLabel = 'Rejected';
        statusIcon = Icons.cancel;
        break;
      case 'cancelled':
        statusColor = Colors.white38;
        statusLabel = 'Cancelled';
        statusIcon = Icons.block;
        break;
      default:
        statusColor = AppColors.warning;
        statusLabel = 'Pending';
        statusIcon = Icons.schedule;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          // Top Row: Amount & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '₹${double.tryParse(amount.toString())?.toStringAsFixed(2) ?? amount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 10, color: statusColor),
                        const SizedBox(width: 3),
                        Text(
                          statusLabel,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Text(
                _formatDate(createdAt),
                style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.3)),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Details in compact grid
          Row(
            children: [
              Expanded(child: _buildCompactDetail('Bank', bankName, Icons.account_balance)),
              const SizedBox(width: 6),
              Expanded(child: _buildCompactDetail('Mode', paymentMode, Icons.payment)),
              const SizedBox(width: 6),
              Expanded(child: _buildCompactDetail('Ref', referenceNumber, Icons.receipt_long)),
            ],
          ),

          if (remark.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.notes, size: 10, color: Colors.white.withOpacity(0.3)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    remark,
                    style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.4)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Cancel button for pending
          if (status == 'pending') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 30,
              child: OutlinedButton(
                onPressed: fundProvider.isCancelling
                    ? null
                    : () => _handleCancelRequest(request, fundProvider),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  side: BorderSide(color: AppColors.error.withOpacity(0.2)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                child: fundProvider.isCancelling
                    ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.error),
                )
                    : const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 10, color: AppColors.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactDetail(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: Colors.white.withOpacity(0.3)),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.4)),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _handleCancelRequest(dynamic request, FundProvider fundProvider) async {
    HapticFeedback.heavyImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF151915),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text(
          'Cancel Request?',
          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          'Are you sure you want to cancel?',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('No', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: AppColors.error, fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await fundProvider.cancelRequest(request['id']);
      if (!success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fundProvider.cancelError ?? 'Failed to cancel',
              style: const TextStyle(fontSize: 11),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildRetryButton() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: OutlinedButton(
        onPressed: _loadRequests,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: BorderSide.none,
        ),
        child: const Text('Retry', style: TextStyle(fontSize: 11, color: Colors.white54)),
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }
}