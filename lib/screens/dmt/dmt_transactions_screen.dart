// lib/screens/dmt/dmt_transactions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../services/dmt/api_service.dart';
import '../../models/dmt_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEOFYN FIN TECH BRAND TOKENS - Clean Professional UI
// ─────────────────────────────────────────────────────────────────────────────

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
  static const Color pending = Color(0xFF8B5CF6);

  static const Color borderDark = Color(0xFF2A342A);
  static const Color borderFocus = Color(0xFF008169);
}

class DMTTransactionsScreen extends StatefulWidget {
  final int? remitterId;

  const DMTTransactionsScreen({
    Key? key,
    this.remitterId,
  }) : super(key: key);

  @override
  State<DMTTransactionsScreen> createState() => _DMTTransactionsScreenState();
}

class _DMTTransactionsScreenState extends State<DMTTransactionsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<DMTTransaction> _transactions = [];
  List<DMTTransaction> _filteredTransactions = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final List<String> _filterOptions = ['All', 'Success', 'Failed', 'Pending'];

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    if (!_isRefreshing) {
      setState(() => _isLoading = true);
    }

    try {
      final transactions = await _apiService.getTransactions(
        remitterId: widget.remitterId,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _applyFilters();
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<DMTTransaction> filtered = _transactions;

    if (_selectedFilter != 'All') {
      filtered = filtered.where((t) => t.status.toLowerCase() == _selectedFilter.toLowerCase()).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) =>
      t.beneficiaryName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.remitterName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (t.utrNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
      ).toList();
    }

    setState(() => _filteredTransactions = filtered);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success': return AppColors.success;
      case 'failed': return AppColors.error;
      case 'pending': return AppColors.pending;
      default: return AppColors.warning;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'success': return Iconsax.tick_circle;
      case 'failed': return Iconsax.close_circle;
      case 'pending': return Iconsax.clock;
      default: return Iconsax.info_circle;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'success': return 'Successful';
      case 'failed': return 'Failed';
      case 'pending': return 'Pending';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final successCount = _transactions.where((t) => t.status.toLowerCase() == 'success').length;
    final failedCount = _transactions.where((t) => t.status.toLowerCase() == 'failed').length;
    final totalVolume = _transactions.where((t) => t.status.toLowerCase() == 'success').fold<double>(0, (sum, t) => sum + t.amount);

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textWhite),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: IconButton(
              icon: Icon(_isRefreshing ? Iconsax.refresh_circle : Iconsax.refresh, color: AppColors.textWhite, size: 20),
              onPressed: () {
                setState(() => _isRefreshing = true);
                _loadTransactions();
              },
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _transactions.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          // Stats Bar
          _buildStatsBar(successCount, failedCount, totalVolume),
          // Search Bar
          _buildSearchBar(),
          // Filter Chips
          _buildFilterChips(),
          // Transactions List
          Expanded(
            child: _filteredTransactions.isEmpty
                ? _buildNoResultsState()
                : RefreshIndicator(
              onRefresh: () async {
                setState(() => _isRefreshing = true);
                await _loadTransactions();
              },
              color: AppColors.primary,
              backgroundColor: AppColors.darkSurface,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                physics: const BouncingScrollPhysics(),
                itemCount: _filteredTransactions.length,
                itemBuilder: (context, index) => _buildTransactionCard(_filteredTransactions[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(int success, int failed, double volume) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          _buildStatItem(Iconsax.tick_circle, '$success', 'Success', AppColors.success),
          const SizedBox(width: 6),
          _buildStatItem(Iconsax.close_circle, '$failed', 'Failed', AppColors.error),
          const SizedBox(width: 6),
          _buildStatItem(Iconsax.money, '₹${volume.toStringAsFixed(0)}', 'Volume', AppColors.primaryLight),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textWhite)),
                Text(label, style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textDarkSecondary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: TextField(
          onChanged: (value) {
            setState(() => _searchQuery = value);
            _applyFilters();
          },
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: 'Search by name or UTR number',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.white38),
            prefixIcon: const Icon(Iconsax.search_normal, color: Colors.white38, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Iconsax.close_circle, color: Colors.white38, size: 18),
              onPressed: () {
                setState(() => _searchQuery = '');
                _applyFilters();
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 10),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filterOptions[index];
          final isSelected = _selectedFilter == filter;
          final count = filter == 'All'
              ? _transactions.length
              : _transactions.where((t) => t.status.toLowerCase() == filter.toLowerCase()).length;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedFilter = filter;
                _applyFilters();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.darkSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) Icon(_getStatusIcon(filter), size: 14, color: Colors.white),
                  if (isSelected) const SizedBox(width: 4),
                  Text(filter, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textDarkSecondary)),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : AppColors.textDarkSecondary)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard(DMTTransaction transaction) {
    final statusColor = _getStatusColor(transaction.status);
    final formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(transaction.createdAt));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _showTransactionDetails(transaction);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getStatusIcon(transaction.status), color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(transaction.beneficiaryName, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textWhite), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text('From: ${transaction.remitterName}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkSecondary)),
                      ],
                    ),
                  ),
                  Text('₹${transaction.amount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textWhite)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _buildChip(Iconsax.flash, transaction.transferMode, AppColors.primaryLight),
                    const SizedBox(width: 8),
                    _buildChip(_getStatusIcon(transaction.status), _getStatusLabel(transaction.status), statusColor),
                    const Spacer(),
                    Icon(Iconsax.clock, size: 10, color: AppColors.textDarkHint),
                    const SizedBox(width: 4),
                    Flexible(child: Text(formattedDate, style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textDarkHint), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              if (transaction.utrNumber != null || transaction.commissionAmount != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (transaction.utrNumber != null) ...[
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: transaction.utrNumber!));
                          HapticFeedback.lightImpact();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('UTR copied', style: GoogleFonts.poppins(fontSize: 12)), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(16), duration: const Duration(seconds: 1)),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('UTR: ${transaction.utrNumber!.length > 8 ? '${transaction.utrNumber!.substring(0, 8)}...' : transaction.utrNumber!}', style: GoogleFonts.poppins(fontSize: 9, color: AppColors.primaryLight)),
                              const SizedBox(width: 2),
                              const Icon(Iconsax.copy, size: 8, color: AppColors.primaryLight),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (transaction.commissionAmount != null) ...[
                      if (transaction.utrNumber != null) const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text('+₹${transaction.commissionAmount!.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.success)),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 3),
          Text(label, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  void _showTransactionDetails(DMTTransaction transaction) {
    final statusColor = _getStatusColor(transaction.status);
    final formattedDate = DateFormat('dd MMMM yyyy, hh:mm a').format(DateTime.parse(transaction.createdAt));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Icon(_getStatusIcon(transaction.status), color: statusColor, size: 28)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Transaction Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textWhite)),
                    if (transaction.utrNumber != null) Text('UTR: ${transaction.utrNumber}', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkSecondary)),
                  ]),
                ),
                Text('₹${transaction.amount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textWhite)),
              ],
            ),
            const SizedBox(height: 20),
            Divider(color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 16),
            _buildDetailRow('Status', _getStatusLabel(transaction.status), valueColor: statusColor),
            _buildDetailRow('Date & Time', formattedDate),
            _buildDetailRow('Beneficiary', transaction.beneficiaryName),
            _buildDetailRow('Remitter', transaction.remitterName),
            _buildDetailRow('Transfer Mode', transaction.transferMode),
            if (transaction.utrNumber != null) _buildDetailRow('UTR Number', transaction.utrNumber!, isCopyable: true),
            if (transaction.commissionAmount != null) _buildDetailRow('Commission', '₹${transaction.commissionAmount!.toStringAsFixed(2)}', valueColor: AppColors.success),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: Text('Close', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor, bool isCopyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textDarkSecondary))),
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor ?? AppColors.textWhite), textAlign: TextAlign.end)),
                if (isCopyable) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $value', style: GoogleFonts.poppins(fontSize: 12)), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(16), duration: const Duration(seconds: 1)));
                    },
                    child: const Icon(Iconsax.copy, size: 14, color: AppColors.primaryLight),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: AppColors.primaryLight), const SizedBox(height: 16), Text('Loading transactions...', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary))]));
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Iconsax.warning_2, size: 56, color: AppColors.error.withOpacity(0.7))),
          const SizedBox(height: 20),
          Text('Failed to Load', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
          const SizedBox(height: 8),
          Text(_errorMessage!, style: GoogleFonts.poppins(color: AppColors.textDarkSecondary, fontSize: 14), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
            child: ElevatedButton.icon(onPressed: _loadTransactions, style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)), icon: const Icon(Iconsax.refresh, color: Colors.white, size: 18), label: Text('Try Again', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Iconsax.receipt_text, size: 64, color: AppColors.primary.withOpacity(0.6))),
          const SizedBox(height: 24),
          Text('No Transactions Yet', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
          const SizedBox(height: 8),
          Text('Your transaction history will appear here', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary, height: 1.5)),
        ]),
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Iconsax.search_normal, size: 48, color: AppColors.warning.withOpacity(0.6))),
          const SizedBox(height: 20),
          Text('No Results Found', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textWhite)),
          const SizedBox(height: 8),
          Text('Try adjusting your filters or search query', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary)),
        ]),
      ),
    );
  }
}