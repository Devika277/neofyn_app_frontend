// lib/screens/history/dmt_history_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/dmt/api_service.dart';
import 'dmt_receipt_screen.dart';

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

class DmtHistoryScreen extends StatefulWidget {
  const DmtHistoryScreen({Key? key}) : super(key: key);

  @override
  State<DmtHistoryScreen> createState() => _DmtHistoryScreenState();
}

class _DmtHistoryScreenState extends State<DmtHistoryScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];
  String _userId = '';

  bool _isLoading = true;
  bool _isFetching = false;
  String _searchQuery = '';
  bool _showFilters = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedDateFilter = 'ALL';
  String _selectedStatus = 'ALL';

  final Map<String, String> _dateFilters = {
    'ALL': 'All Time',
    'TODAY': 'Today',
    'WEEK': 'This Week',
    'MONTH': 'This Month',
    'CUSTOM': 'Custom',
  };

  final Map<String, Map<String, dynamic>> _statusFilters = {
    'ALL': {'label': 'All', 'color': AppColors.textDarkSecondary},
    'SUCCESS': {'label': 'Success', 'color': AppColors.success},
    'FAILED': {'label': 'Failed', 'color': AppColors.error},
    'PENDING': {'label': 'Pending', 'color': AppColors.warning},
    'PROCESSING': {'label': 'Processing', 'color': AppColors.processing},
  };

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId') ?? '';
    if (_userId.isNotEmpty) _fetchHistory();
  }

  bool get _hasActiveFilters =>
      _selectedStatus != 'ALL' || _searchQuery.isNotEmpty || _selectedDateFilter != 'ALL';

  Future<void> _fetchHistory() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() {
      _isLoading = true;
      _allTransactions.clear();
      _filteredTransactions.clear();
    });

    try {
      final list = await _apiService.getDmtHistory(
        userId: _userId,
        limit: 1000,
        offset: 0,
      );

      final seenIds = <String>{};
      final uniqueList = list.where((tx) {
        final id = tx['id']?.toString() ?? '';
        if (seenIds.contains(id)) return false;
        seenIds.add(id);
        return true;
      }).toList();

      debugPrint('✅ DMT History loaded: ${uniqueList.length} unique transactions');

      if (mounted) {
        setState(() {
          _allTransactions = uniqueList;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('DMT History error: $e');
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isFetching = false;
    }
  }

  void _applyFilters() {
    final filtered = _allTransactions.where((tx) {
      if (_selectedStatus != 'ALL') {
        final status = (tx['status'] ?? '').toString().toUpperCase();
        if (status != _selectedStatus) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final fields = [
          tx['id']?.toString(),
          tx['iyda_txn_id']?.toString(),
          tx['utr_number']?.toString(),
          tx['remitter_name']?.toString(),
          tx['remitter_mobile']?.toString(),
          tx['beneficiary_name']?.toString(),
          tx['account_number']?.toString(),
          tx['bank_name']?.toString(),
          tx['beneficiary_mobile']?.toString(),
        ];

        if (!fields.any((f) => f != null && f.toLowerCase().contains(q))) {
          return false;
        }
      }

      if (_selectedDateFilter != 'ALL') {
        final txDate = _parseDate(tx['created_at']);
        if (txDate == null) return false;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        switch (_selectedDateFilter) {
          case 'TODAY':
            if (txDate.isBefore(today)) return false;
            break;
          case 'WEEK':
            if (txDate.isBefore(today.subtract(Duration(days: now.weekday - 1)))) return false;
            break;
          case 'MONTH':
            if (txDate.isBefore(DateTime(now.year, now.month, 1))) return false;
            break;
          case 'CUSTOM':
            if (_startDate != null && txDate.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day)))
              return false;
            if (_endDate != null && txDate.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59)))
              return false;
            break;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final dateA = _parseDate(a['created_at']) ?? DateTime(2000);
      final dateB = _parseDate(b['created_at']) ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    if (mounted) setState(() => _filteredTransactions = filtered);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = 'ALL';
      _searchQuery = '';
      _selectedDateFilter = 'ALL';
      _startDate = null;
      _endDate = null;
      _showFilters = false;
    });
    _applyFilters();
  }

  void _setDateFilter(String filter) {
    if (filter == 'CUSTOM') {
      _pickDateRange();
      return;
    }
    setState(() => _selectedDateFilter = filter);
    _applyFilters();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF008169),
            surface: Color(0xFF1A1F1A),
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: const Color(0xFF1A1F1A),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _selectedDateFilter = 'CUSTOM';
      });
      _applyFilters();
    }
  }
// In _showReceipt method of _DmtHistoryScreenState, replace with this:

  // ✅ REPLACE your _showReceipt method with this:
  void _showReceipt(Map<String, dynamic> tx) {
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('📋 DMT TRANSACTION FULL DATA:');
      debugPrint('═══════════════════════════════════════');
      tx.forEach((key, value) {
        debugPrint('   $key = $value (${value.runtimeType})');
      });
      debugPrint('═══════════════════════════════════════');

      final dateStr = tx['created_at'];
      DateTime date;
      try {
        date = DateTime.parse(dateStr.toString()).toLocal();
      } catch (e) {
        date = DateTime.now();
      }

      // ✅ FIX: Use the correct API field names: business_name and phone
      final businessName = tx['business_name']?.toString() ?? '';
      final phone = tx['phone']?.toString() ?? '';

      debugPrint('🏪 Business Name: "$businessName"');
      debugPrint('📞 Phone: "$phone"');

      final receipt = DmtReceiptModel(
        transactionId: tx['iyda_txn_id']?.toString() ?? tx['id']?.toString() ?? 'N/A',
        utrNumber: tx['utr_number']?.toString() ?? '',
        amount: tx['amount']?.toString() ?? '0',
        status: tx['status']?.toString() ?? 'PENDING',
        transferMode: tx['transfer_mode']?.toString() ?? 'IMPS',
        remitterName: tx['remitter_name']?.toString() ?? 'N/A',
        remitterMobile: tx['remitter_mobile']?.toString() ?? '',
        beneficiaryName: tx['beneficiary_name']?.toString() ?? 'N/A',
        accountNumber: tx['account_number']?.toString() ?? 'N/A',
        bankName: tx['bank_name']?.toString() ?? 'N/A',
        ifscCode: tx['ifsc_code']?.toString() ?? '',
        beneficiaryMobile: tx['beneficiary_mobile']?.toString() ?? '',
        remark: tx['remark']?.toString() ?? '',
        failureReason: tx['failure_reason']?.toString() ?? '',
        transactionDate: date,
        merchantName: 'Neofyn Bharath',
        outletName: businessName,    // ✅ business_name from API
        shopAddress: businessName,   // ✅ Same as business name
        shopPhone: phone,            // ✅ phone from API
      );

      debugPrint('✅ Receipt Created - Shop: "${receipt.outletName}", Phone: "${receipt.shopPhone}"');

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DmtReceiptScreen(receipt: receipt)),
      );
    } catch (e) {
      debugPrint('❌ Error showing receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error loading receipt'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
  /*void _showReceipt(Map<String, dynamic> tx) {
    try {
      final dateStr = tx['created_at'];
      DateTime date;
      try {
        date = DateTime.parse(dateStr.toString()).toLocal();
      } catch (e) {
        date = DateTime.now();
      }

      final receipt = DmtReceiptModel(
        transactionId: tx['iyda_txn_id']?.toString() ?? tx['id']?.toString() ?? 'N/A',
        utrNumber: tx['utr_number']?.toString() ?? '',
        amount: tx['amount']?.toString() ?? '0',
        // commission: tx['commission_amount']?.toString() ?? '',
        status: tx['status']?.toString() ?? 'PENDING',
        transferMode: tx['transfer_mode']?.toString() ?? 'IMPS',
        remitterName: tx['remitter_name']?.toString() ?? 'N/A',
        remitterMobile: tx['remitter_mobile']?.toString() ?? '',
        beneficiaryName: tx['beneficiary_name']?.toString() ?? 'N/A',
        accountNumber: tx['account_number']?.toString() ?? 'N/A',
        bankName: tx['bank_name']?.toString() ?? 'N/A',
        ifscCode: tx['ifsc_code']?.toString() ?? '',
        beneficiaryMobile: tx['beneficiary_mobile']?.toString() ?? '',
        remark: tx['remark']?.toString() ?? '',
        failureReason: tx['failure_reason']?.toString() ?? '',
        transactionDate: date,
        merchantName: 'NEOFYN Bharath',
        // retailerId: _userId,
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DmtReceiptScreen(receipt: receipt)),
      );
    } catch (e) {
      debugPrint('Error showing receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error loading receipt'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }*/

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text(
          'DMT History',
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
          IconButton(
            icon: Icon(
              _showFilters ? Iconsax.filter_edit : Iconsax.filter,
              color: _showFilters ? AppColors.primaryLight : AppColors.textDarkSecondary,
              size: 20,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(Iconsax.refresh, color: AppColors.textDarkSecondary, size: 20),
            onPressed: _fetchHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_showFilters) _buildFilterSection(),
          if (_hasActiveFilters) _buildActiveFiltersBar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: TextField(
          onChanged: (v) {
            _searchQuery = v;
            _applyFilters();
          },
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: 'Search by name, mobile, UTR, account...',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDarkHint),
            prefixIcon: const Icon(Iconsax.search_normal, size: 16, color: Color(0xFF6B7280)),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
              onTap: () {
                setState(() => _searchQuery = '');
                _applyFilters();
              },
              child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)),
            )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Date Range', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ...['ALL', 'TODAY', 'WEEK', 'MONTH'].map((key) {
              final isSelected = _selectedDateFilter == key;
              return GestureDetector(
                onTap: () => _setDateFilter(key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark),
                  ),
                  child: Text(_dateFilters[key]!, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? AppColors.primaryLight : AppColors.textDarkSecondary)),
                ),
              );
            }),
            GestureDetector(
              onTap: () => _setDateFilter('CUSTOM'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: _selectedDateFilter == 'CUSTOM' ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _selectedDateFilter == 'CUSTOM' ? AppColors.primary : AppColors.borderDark),
                ),
                child: Text(
                  _selectedDateFilter == 'CUSTOM' && _startDate != null
                      ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                      : 'Custom',
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _selectedDateFilter == 'CUSTOM' ? AppColors.primaryLight : AppColors.textDarkSecondary),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          Text('Status', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: _statusFilters.entries.map((e) {
            final isSelected = _selectedStatus == e.key;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedStatus = e.key);
                _applyFilters();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? (e.value['color'] as Color).withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? (e.value['color'] as Color) : AppColors.borderDark),
                ),
                child: Text(e.value['label'], style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? (e.value['color'] as Color) : AppColors.textDarkSecondary)),
              ),
            );
          }).toList()),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: _clearAllFilters,
              child: Row(children: [
                const Icon(Iconsax.close_circle, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text('Clear All', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.error)),
              ]),
            ),
            Text('${_filteredTransactions.length} results', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkHint)),
          ]),
        ],
      ),
    );
  }

  Widget _buildActiveFiltersBar() {
    final parts = <String>[];
    if (_selectedStatus != 'ALL') parts.add(_statusFilters[_selectedStatus]?['label'] ?? '');
    if (_selectedDateFilter != 'ALL') parts.add(_dateFilters[_selectedDateFilter] ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Iconsax.filter, size: 12, color: AppColors.primaryLight),
        const SizedBox(width: 6),
        Expanded(child: Text(parts.where((p) => p.isNotEmpty).join(' • '), style: GoogleFonts.poppins(fontSize: 10, color: AppColors.primaryLight), overflow: TextOverflow.ellipsis)),
        GestureDetector(
          onTap: _clearAllFilters,
          child: Text('Clear', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkSecondary)),
        ),
      ]),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF008169)));
    }

    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Iconsax.receipt_1, size: 56, color: AppColors.textDarkHint.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              _allTransactions.isEmpty ? 'No DMT transactions yet' : 'No matching transactions',
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textWhite),
              textAlign: TextAlign.center,
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _clearAllFilters,
                child: Text('Clear Filters', style: GoogleFonts.poppins(color: AppColors.primaryLight)),
              ),
            ],
          ]),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _fetchHistory,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _filteredTransactions.length,
        itemBuilder: (_, i) => _buildCard(_filteredTransactions[i]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> tx) {
    final status = (tx['status'] ?? 'pending').toString().toLowerCase();
    final isSuccess = status == 'success' || status == 'completed';
    final isFailed = status == 'failed' || status == 'failure' || status == 'reversed';
    final isProcessing = status == 'processing' || status == 'pending' || status == 'queued';

    final Color sc = isSuccess
        ? AppColors.success
        : isFailed
        ? AppColors.error
        : isProcessing
        ? AppColors.processing
        : AppColors.warning;

    final IconData si = isSuccess
        ? Iconsax.tick_circle
        : isFailed
        ? Iconsax.close_circle
        : Iconsax.clock;

    final amount = tx['amount']?.toString() ?? '0';
    final beneName = tx['beneficiary_name']?.toString() ?? 'N/A';
    final remitterName = tx['remitter_name']?.toString() ?? 'N/A';
    final txnId = tx['iyda_txn_id']?.toString() ?? tx['id']?.toString() ?? 'N/A';
    final bankName = tx['bank_name']?.toString();
    final date = tx['created_at'];
    final commission = tx['commission_amount'];
    final utrNumber = tx['utr_number']?.toString();

    return GestureDetector(
      onTap: () => _showReceipt(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderDark),
        ),
        child: Column(
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(si, color: sc, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      beneName,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textWhite),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (remitterName != 'N/A')
                      Text(
                        'From: $remitterName',
                        style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkHint),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            txnId,
                            style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkHint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _copyToClipboard(txnId, 'Transaction ID'),
                          child: Icon(Iconsax.copy, size: 10, color: AppColors.textDarkHint),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹$amount',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textWhite),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: sc.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600, color: sc),
                    ),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Iconsax.calendar, size: 10, color: AppColors.textDarkHint),
              const SizedBox(width: 4),
              Text(_fmt(date), style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textDarkHint)),
              if (bankName != null) ...[
                const SizedBox(width: 12),
                Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.textDarkHint, shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Text(bankName, style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textDarkHint), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              if (commission != null && commission != 'null') ...[
                const SizedBox(width: 8),
                Text('Comm: ₹$commission', style: GoogleFonts.poppins(fontSize: 9, color: AppColors.primaryLight)),
              ],
              if (isSuccess && utrNumber != null && utrNumber.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'UTR: $utrNumber',
                    style: GoogleFonts.poppins(fontSize: 9, color: AppColors.success),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              Icon(Iconsax.arrow_right_3, size: 12, color: AppColors.textDarkHint),
            ]),
          ],
        ),
      ),
    );
  }

  String _fmt(dynamic d) {
    if (d == null) return '';
    try {
      return DateFormat('dd MMM, hh:mm a').format(DateTime.parse(d.toString()).toLocal());
    } catch (_) {
      return '';
    }
  }
}