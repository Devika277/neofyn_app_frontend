// lib/screens/aeps/aeps_transaction_history_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/AEPS/api_service.dart';
import '../receipt_screen.dart';
import '../../models/receipt_model.dart';

class AppColors {
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryDark = Color(0xFF1E40AF);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color darkBg = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF94A3B8);
  static const Color textDarkHint = Color(0xFF64748B);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color borderDark = Color(0xFF334155);
}

class AepsHistoryScreen extends StatefulWidget {
  const AepsHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AepsHistoryScreen> createState() => _AepsHistoryScreenState();
}

class _AepsHistoryScreenState extends State<AepsHistoryScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];

  bool _isLoading = true;
  bool _isFetching = false;

  String _selectedType = 'ALL';
  String _selectedStatus = 'ALL';
  String _searchQuery = '';
  bool _showFilters = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedDateFilter = 'ALL';

  final Map<String, String> _dateFilters = {
    'ALL': 'All Time',
    'TODAY': 'Today',
    'WEEK': 'This Week',
    'MONTH': 'This Month',
    'CUSTOM': 'Custom',
  };

  final Map<String, Map<String, dynamic>> _typeFilters = {
    'ALL': {'label': 'All Types', 'icon': Iconsax.receipt_1, 'color': AppColors.textDarkSecondary},
    'CW': {'label': 'Cash Withdrawal', 'icon': Iconsax.money_send, 'color': Colors.blue},
    'BE': {'label': 'Balance Enquiry', 'icon': Iconsax.wallet_1, 'color': Colors.purple},
    'MS': {'label': 'Mini Statement', 'icon': Iconsax.document_text, 'color': Colors.teal},
  };

  final Map<String, Map<String, dynamic>> _statusFilters = {
    'ALL': {'label': 'All Status', 'color': AppColors.textDarkSecondary},
    'SUCCESS': {'label': 'Success', 'color': AppColors.success},
    'FAILED': {'label': 'Failed', 'color': AppColors.error},
    'PENDING': {'label': 'Pending', 'color': AppColors.warning},
  };

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _selectedType != 'ALL' ||
          _selectedStatus != 'ALL' ||
          _searchQuery.isNotEmpty ||
          _selectedDateFilter != 'ALL';

  // Normalize transaction type from API
  String _normalizeType(String? rawType) {
    if (rawType == null || rawType.isEmpty) return 'UNKNOWN';
    final type = rawType.toUpperCase().trim().replaceAll(RegExp(r'[_\-\s]+'), '');
    if (type.contains('CASH') || type.contains('WITHDRAW') || type == 'CW') return 'CW';
    if (type.contains('BALANCE') || type.contains('ENQUIRY') || type == 'BE') return 'BE';
    if (type.contains('MINI') || type.contains('STATEMENT') || type == 'MS') return 'MS';
    return type;
  }

  String _normalizeStatus(String? rawStatus) {
    if (rawStatus == null || rawStatus.isEmpty) return 'PENDING';
    final status = rawStatus.toUpperCase().trim();
    if (status == '00' || status == '000' || status == 'SUCCESS' || status == 'COMPLETED') {
      return 'SUCCESS';
    }
    if (status == '01' || status == '001' || status == 'FAILED' || status == 'FAIL') {
      return 'FAILED';
    }
    if (status == 'PENDING' || status == 'PROCESSING') return 'PENDING';
    return status.toUpperCase();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString()).toLocal();
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchHistory() async {
    if (_isFetching) return;
    _isFetching = true;

    setState(() {
      _isLoading = true;
      _allTransactions.clear();
      _filteredTransactions.clear();
    });

    try {
      final response = await _apiService.getAepsHistory(limit: 500, offset: 0);
      final list = _extractList(response);

      if (!mounted) return;

      setState(() {
        _allTransactions = list;
        _isLoading = false;
      });
      _applyFilters();
      debugPrint('✅ Loaded: ${_allTransactions.length} transactions');
    } catch (e) {
      debugPrint('❌ Fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isFetching = false;
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    if (response is List) {
      return response.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    }
    if (response is Map) {
      final data = response['data'];
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
      }
      if (data is Map && data['transactions'] is List) {
        return (data['transactions'] as List)
            .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
            .toList();
      }
      if (response['transactions'] is List) {
        return (response['transactions'] as List)
            .map((e) => Map<String, dynamic>.from(e is Map ? e : {}))
            .toList();
      }
    }
    return [];
  }

  void _applyFilters() {
    final filtered = _allTransactions.where((tx) {
      // Type filter
      final rawType = (tx['txn_type'] ?? tx['transactionType'] ?? '').toString();
      final type = _normalizeType(rawType);
      if (_selectedType != 'ALL' && type != _selectedType) return false;

      // Status filter
      final rawStatus = (tx['npci_code'] ?? tx['status'] ?? '').toString();
      final status = _normalizeStatus(rawStatus);
      if (_selectedStatus != 'ALL' && status != _selectedStatus) return false;

      // Date filter
      if (_selectedDateFilter != 'ALL') {
        final txDate = _parseDate(
            tx['created_at'] ?? tx['createdAt'] ?? tx['txnDateTime'] ?? tx['timestamp']);
        if (txDate == null) return false;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        switch (_selectedDateFilter) {
          case 'TODAY':
            if (txDate.isBefore(today)) return false;
            break;
          case 'WEEK':
            final weekStart = today.subtract(Duration(days: now.weekday - 1));
            if (txDate.isBefore(weekStart)) return false;
            break;
          case 'MONTH':
            if (txDate.isBefore(DateTime(now.year, now.month, 1))) return false;
            break;
          case 'CUSTOM':
            if (_startDate != null && txDate.isBefore(_startDate!)) return false;
            if (_endDate != null && txDate.isAfter(_endDate!.add(const Duration(days: 1)))) return false;
            break;
        }
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final rrn = (tx['rrn'] ?? '').toString().toLowerCase();
        final bank = (tx['bank_name'] ?? tx['bankName'] ?? '').toString().toLowerCase();
        final aadhaar = (tx['aadhaar_last4'] ?? '').toString().toLowerCase();
        if (!rrn.contains(q) && !bank.contains(q) && !aadhaar.contains(q)) return false;
      }
      return true;
    }).toList();

    // Sort by date descending
    filtered.sort((a, b) {
      final dateA = _parseDate(a['created_at'] ?? a['createdAt']) ?? DateTime(2000);
      final dateB = _parseDate(b['created_at'] ?? b['createdAt']) ?? DateTime(2000);
      return dateB.compareTo(dateA);
    });

    if (mounted) setState(() => _filteredTransactions = filtered);
  }

  void _clearAllFilters() {
    setState(() {
      _selectedType = 'ALL';
      _selectedStatus = 'ALL';
      _searchQuery = '';
      _selectedDateFilter = 'ALL';
      _startDate = null;
      _endDate = null;
      _showFilters = false;
    });
    _applyFilters();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(
          start: DateTime.now().subtract(const Duration(days: 7)),
          end: DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.darkSurface,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: AppColors.darkSurface,
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

  void _setDateFilter(String filter) {
    if (filter == 'CUSTOM') {
      _pickDateRange();
      return;
    }
    setState(() => _selectedDateFilter = filter);
    if (filter == 'ALL') {
      _startDate = null;
      _endDate = null;
    }
    _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text('AEPS History',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textWhite)),
        centerTitle: true,
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
              icon: Icon(
                  _showFilters ? Iconsax.filter_edit : Iconsax.filter,
                  color: _showFilters ? AppColors.primaryLight : AppColors.textDarkSecondary,
                  size: 20),
              onPressed: () => setState(() => _showFilters = !_showFilters)),
          IconButton(
              icon: const Icon(Iconsax.refresh, color: AppColors.textDarkSecondary, size: 20),
              onPressed: _fetchHistory),
        ],
      ),
      body: Column(children: [
        _buildSearchBar(),
        if (_showFilters) _buildFilterSection(),
        if (_hasActiveFilters) _buildActiveFiltersBar(),
        Expanded(child: _buildContent()),
      ]),
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
            border: Border.all(color: AppColors.borderDark)),
        child: TextField(
          onChanged: (v) {
            _searchQuery = v;
            _applyFilters();
          },
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: 'Search by RRN, Bank, Aadhaar...',
            hintStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.textDarkHint),
            prefixIcon:
            const Icon(Iconsax.search_normal, size: 16, color: AppColors.textDarkHint),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                onTap: () {
                  _searchQuery = '';
                  _applyFilters();
                },
                child:
                const Icon(Icons.close, size: 16, color: AppColors.textDarkHint))
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
          border: Border.all(color: AppColors.borderDark)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Date Range Section
        Text('Date Range',
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary)),
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
                    border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.borderDark)),
                child: Text(_dateFilters[key]!,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? AppColors.primaryLight : AppColors.textDarkSecondary)),
              ),
            );
          }),
          GestureDetector(
            onTap: () => _setDateFilter('CUSTOM'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: _selectedDateFilter == 'CUSTOM'
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _selectedDateFilter == 'CUSTOM'
                          ? AppColors.primary
                          : AppColors.borderDark)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Iconsax.calendar_edit,
                    size: 12,
                    color: _selectedDateFilter == 'CUSTOM'
                        ? AppColors.primaryLight
                        : AppColors.textDarkSecondary),
                const SizedBox(width: 4),
                Text(
                    _selectedDateFilter == 'CUSTOM' && _startDate != null
                        ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                        : 'Custom',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _selectedDateFilter == 'CUSTOM'
                            ? AppColors.primaryLight
                            : AppColors.textDarkSecondary)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),

        // Type Section
        Text('Transaction Type',
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _typeFilters.entries.map((e) {
              final isSelected = _selectedType == e.key;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedType = e.key);
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.borderDark)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(e.value['icon'],
                        size: 14,
                        color: isSelected ? AppColors.primaryLight : AppColors.textDarkSecondary),
                    const SizedBox(width: 6),
                    Text(e.value['label'],
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.primaryLight
                                : AppColors.textDarkSecondary))
                  ]),
                ),
              );
            }).toList()),
        const SizedBox(height: 14),

        // Status Section
        Text('Status',
            style: GoogleFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _statusFilters.entries.map((e) {
              final isSelected = _selectedStatus == e.key;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStatus = e.key);
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: isSelected
                          ? (e.value['color'] as Color).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: isSelected ? (e.value['color'] as Color) : AppColors.borderDark)),
                  child: Text(e.value['label'],
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? (e.value['color'] as Color) : AppColors.textDarkSecondary)),
                ),
              );
            }).toList()),
        const SizedBox(height: 12),

        // Results count and clear button
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
              onTap: _clearAllFilters,
              child: Row(children: [
                const Icon(Iconsax.close_circle, size: 14, color: AppColors.error),
                const SizedBox(width: 4),
                Text('Clear All',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.error))
              ])),
          Text('${_filteredTransactions.length} results',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDarkHint)),
        ]),
      ]),
    );
  }

  Widget _buildActiveFiltersBar() {
    final parts = <String>[];
    if (_selectedType != 'ALL') parts.add(_typeFilters[_selectedType]?['label'] ?? '');
    if (_selectedStatus != 'ALL') parts.add(_statusFilters[_selectedStatus]?['label'] ?? '');
    if (_selectedDateFilter != 'ALL') parts.add(_dateFilters[_selectedDateFilter] ?? '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Iconsax.filter, size: 12, color: AppColors.primaryLight),
        const SizedBox(width: 6),
        Expanded(
            child: Text(parts.where((p) => p.isNotEmpty).join(' • '),
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.primaryLight),
                overflow: TextOverflow.ellipsis)),
        GestureDetector(
            onTap: _clearAllFilters,
            child: Text('Clear',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.textDarkSecondary))),
      ]),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Iconsax.receipt_1,
                  size: 56, color: AppColors.textDarkHint.withOpacity(0.3)),
              const SizedBox(height: 16),
              Text(
                  _allTransactions.isEmpty
                      ? 'No transactions yet'
                      : 'No matching transactions',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textWhite),
                  textAlign: TextAlign.center),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 8),
                TextButton(
                    onPressed: _clearAllFilters,
                    child: Text('Clear Filters',
                        style: GoogleFonts.inter(color: AppColors.primaryLight)))
              ],
            ])),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _filteredTransactions.length,
      itemBuilder: (_, i) => _buildTransactionCard(_filteredTransactions[i]),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    final rawType = (tx['txn_type'] ?? tx['transactionType'] ?? '').toString();
    final rawStatus = (tx['npci_code'] ?? tx['status'] ?? '').toString();
    final type = _normalizeType(rawType);
    final status = _normalizeStatus(rawStatus);

    final isSuccess = status == 'SUCCESS';
    final isFailed = status == 'FAILED';
    final Color statusColor = isSuccess
        ? AppColors.success
        : (isFailed ? AppColors.error : AppColors.warning);
    final IconData statusIcon = isSuccess
        ? Iconsax.tick_circle
        : (isFailed ? Iconsax.close_circle : Iconsax.clock);

    // Get type-specific display properties
    IconData typeIcon;
    String typeLabel;
    Color typeColor;

    switch (type) {
      case 'CW':
        typeIcon = Iconsax.money_send;
        typeLabel = 'Cash Withdrawal';
        typeColor = Colors.blue;
        break;
      case 'BE':
        typeIcon = Iconsax.wallet_1;
        typeLabel = 'Balance Enquiry';
        typeColor = Colors.purple;
        break;
      case 'MS':
        typeIcon = Iconsax.document_text;
        typeLabel = 'Mini Statement';
        typeColor = Colors.teal;
        break;
      default:
        typeIcon = Iconsax.finger_cricle;
        typeLabel = rawType.replaceAll('_', ' ').toUpperCase();
        typeColor = Colors.grey;
    }

    // Get amount - show only for CW, hide for BE/MS
    final amount = tx['amount'];
    final hasAmount = amount != null &&
        amount.toString() != '0' &&
        amount.toString() != 'null' &&
        amount.toString().isNotEmpty &&
        type == 'CW';

    // Get RRN and bank name
    final rrn = (tx['rrn'] ?? 'N/A').toString();
    final bankName = (tx['bank_name'] ?? tx['bankName'] ?? 'N/A').toString();
    final aadhaarLast4 = tx['aadhaar_last4']?.toString() ?? '';
    final maskedAadhaar = aadhaarLast4.isNotEmpty ? 'XXXX$aadhaarLast4' : '';

    // Get date
    final dateTime = _parseDate(tx['created_at'] ?? tx['createdAt']);
    final dateStr = dateTime != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dateTime) : 'N/A';

    return GestureDetector(
      onTap: () => _showTransactionDetails(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderDark)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Type icon, label, and amount/status
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(typeLabel,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textWhite)),
                      const SizedBox(height: 2),
                      Text('RRN: $rrn',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.textDarkHint),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Show amount only for CW transactions
                if (hasAmount) ...[
                  const SizedBox(width: 8),
                  Text('₹$amount',
                      style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textWhite)),
                ],
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 8, color: statusColor),
                      const SizedBox(width: 3),
                      Text(status,
                          style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),

            // Bottom row: Additional info
            if (bankName != 'N/A' || maskedAadhaar.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (bankName != 'N/A') ...[
                    const Icon(Iconsax.bank, size: 10, color: AppColors.textDarkHint),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(bankName,
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.textDarkHint),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  if (maskedAadhaar.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    const Icon(Iconsax.card, size: 10, color: AppColors.textDarkHint),
                    const SizedBox(width: 4),
                    Text(maskedAadhaar,
                        style: GoogleFonts.inter(
                            fontSize: 10, color: AppColors.textDarkHint)),
                  ],
                ],
              ),
            ],

            // Date
            const SizedBox(height: 4),
            Text(dateStr,
                style: GoogleFonts.inter(
                    fontSize: 9, color: AppColors.textDarkHint.withOpacity(0.7))),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(Map<String, dynamic> tx) {
    final rawType = (tx['txn_type'] ?? tx['transactionType'] ?? '').toString();
    final rawStatus = (tx['npci_code'] ?? tx['status'] ?? '').toString();
    final type = _normalizeType(rawType);
    final status = _normalizeStatus(rawStatus);
    final isSuccess = status == 'SUCCESS';
    final typeLabel = _getTypeLabel(rawType);
    final statusColor = isSuccess ? AppColors.success : AppColors.error;

    // Get Aadhaar
    final aadhaarLast4 = tx['aadhaar_last4']?.toString() ?? '';
    final maskedAadhaar = aadhaarLast4.isNotEmpty ? 'XXXX-XXXX-$aadhaarLast4' : 'N/A';

    // Get amount
    final amount = tx['amount'];
    final hasAmount = amount != null &&
        amount.toString() != '0' &&
        amount.toString() != 'null' &&
        amount.toString().isNotEmpty;
    final displayAmount = hasAmount ? '₹${amount.toString()}' : 'N/A';

    // Get available balance
    final availableBalance = tx['available_balance']?.toString() ?? '';
    final hasBalance = availableBalance.isNotEmpty && availableBalance != '0' && availableBalance != 'null';

    // Get bank details
    final bankIIN = tx['bank_iin']?.toString() ?? 'N/A';
    final bankName = tx['bank_name']?.toString() ?? 'N/A';

    // Get RRN
    final rrn = tx['rrn']?.toString() ?? 'N/A';

    // Get NPCI message
    final npciMessage = tx['npci_message']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Transaction Details',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textWhite,
              ),
            ),
            const SizedBox(height: 16),

            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildDetailRow('Transaction Type', typeLabel),
                    _buildDetailRow('Status', status, valueColor: statusColor),

                    if (npciMessage.isNotEmpty)
                      _buildDetailRow('Message', npciMessage),

                    _buildDetailRow('RRN', rrn),

                    // Show amount section only for CW
                    if (type == 'CW' && hasAmount)
                      _buildAmountSection(displayAmount, statusColor),

                    // Show balance section for BE and MS
                    if ((type == 'BE' || type == 'MS') && hasBalance)
                      _buildBalanceSection(availableBalance),

                    _buildDetailRow('Bank IIN', bankIIN),
                    if (bankName != 'N/A')
                      _buildDetailRow('Bank Name', bankName),

                    _buildDetailRow('Aadhaar', maskedAadhaar),
                    _buildDetailRow('Device', tx['device_used']?.toString() ?? 'N/A'),
                    _buildDetailRow('Provider', tx['provider']?.toString() ?? 'N/A'),

                    if (tx['pipe'] != null)
                      _buildDetailRow('Pipe', tx['pipe'].toString()),

                    _buildDetailRow('Date & Time',
                        _fmtLong(tx['created_at'] ?? tx['createdAt'])),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (isSuccess)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _generateReceipt(tx);
                        },
                        icon: const Icon(Iconsax.receipt_1, size: 16),
                        label: const Text('View Receipt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  if (isSuccess) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountSection(String amount, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text('Transaction Amount',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDarkSecondary)),
          const SizedBox(height: 4),
          Text(amount,
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildBalanceSection(String balance) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.success.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text('Available Balance',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textDarkSecondary)),
          const SizedBox(height: 4),
          Text('₹$balance',
              style: GoogleFonts.inter(
                  fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.success)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textDarkSecondary)),
          ),
          Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppColors.textWhite)),
          ),
        ],
      ),
    );
  }

  void _generateReceipt(Map<String, dynamic> tx) {
    try {
      debugPrint('📄 Creating receipt from transaction: ${json.encode(tx)}');

      // Get transaction type
      String transactionType = (tx['txn_type'] ?? tx['transactionType'] ?? '').toString();
      transactionType = _normalizeType(transactionType);

      // Get status
      final npciCode = (tx['npci_code'] ?? '').toString();
      final isSuccess = npciCode == '00' || npciCode == '000';
      final statusMessage = (tx['npci_message'] ?? tx['status'] ?? '').toString();

      // Get amount
      final amount = tx['amount']?.toString() ?? '0';
      final displayAmount = (amount == '0' || amount == 'null' || amount.isEmpty) ? '0.00' : amount;

      // Get available balance
      final availableBalance = tx['available_balance']?.toString() ?? '';

      // Get Aadhaar
      final aadhaarLast4 = tx['aadhaar_last4']?.toString() ?? '';
      final maskedAadhaar = aadhaarLast4.isNotEmpty ? 'XXXX-XXXX-$aadhaarLast4' : 'XXXX-XXXX-XXXX';

      // Get bank details
      final bankIIN = tx['bank_iin']?.toString() ?? '';
      final bankName = tx['bank_name']?.toString() ?? 'Not Available';

      // Get RRN
      final rrn = tx['rrn']?.toString() ?? '';

      // Get merchant details
      final merchantRefId = tx['merchant_ref_id']?.toString() ??
          tx['merchantRefId']?.toString() ?? rrn;
      final merchantId = tx['merchant_id']?.toString() ??
          tx['merchantId']?.toString() ?? 'N/A';

      // Get date/time
      final txnDateTime = tx['created_at']?.toString() ??
          tx['createdAt']?.toString() ?? DateTime.now().toIso8601String();

      // Get device info
      final deviceUsed = tx['device_used']?.toString() ?? 'Not Available';
      final provider = tx['provider']?.toString() ?? 'VimoPay';

      // Get mobile number
      final mobileNumber = tx['mobile_no']?.toString() ??
          tx['mobileNumber']?.toString() ??
          tx['mobile']?.toString() ?? '';

      // Get NPCI details
      final npciMessage = tx['npci_message']?.toString() ?? '';

      // Get mini statement data if available
      final miniStatement = tx['mini_statement'];
      final transactionList = tx['transaction_list'];

      // Build receipt data
      final Map<String, dynamic> receiptData = {
        'data': {
          // Status
          'status': isSuccess ? 'SUCCESS' : 'FAILED',
          'successStatus': isSuccess.toString(),
          'npciCode': npciCode,
          'npciMessage': npciMessage,
          'statusDescription': npciMessage.isNotEmpty ? npciMessage : statusMessage,

          // Transaction identifiers
          'txnRefId': rrn,
          'merchantRefId': merchantRefId,
          'merchantId': merchantId,
          'rrn': rrn,

          // Amount details
          'transactionAmount': displayAmount,
          'amount': displayAmount,
          'availableBalance': availableBalance,

          // Customer details
          'aadhaarNo': maskedAadhaar,
          'aadhaarNumber': aadhaarLast4,
          'aadhaar_last4': aadhaarLast4,

          // Bank details
          'bankIIN': bankIIN,
          'bankName': bankName,
          'bank_name': bankName,
          'bank_iin': bankIIN,

          // Date and time
          'txnDateTime': txnDateTime,
          'created_at': txnDateTime,

          // Device and provider
          'deviceUsed': deviceUsed,
          'device_used': deviceUsed,
          'provider': provider,
          'pipe': tx['pipe']?.toString() ?? '1',

          // Mobile
          'mobileNumber': mobileNumber,

          // Transaction type
          'txn_type': transactionType,
          'transactionType': transactionType,

          // Mini statement data
          'transactionList': transactionList != null ? json.encode(transactionList) : '',
          'mini_statement': miniStatement != null ? json.encode(miniStatement) : '',

          'udf1': tx['udf1']?.toString() ?? '',
          'udf2': tx['udf2']?.toString() ?? '',
          'udf3': tx['udf3']?.toString() ?? '',
        }
      };

      debugPrint('📄 Processed receipt data:');
      debugPrint('  Type: $transactionType');
      debugPrint('  Amount: $displayAmount');
      debugPrint('  RRN: $rrn');
      debugPrint('  Status: ${isSuccess ? "SUCCESS" : "FAILED"}');
      debugPrint('  Bank: $bankName');
      debugPrint('  Aadhaar: $maskedAadhaar');

      final receipt = ReceiptModel.fromApiResponse(
        receiptData,
        transactionType: transactionType,
        merchantId: merchantId,
        mobileNumber: mobileNumber,
      );

      debugPrint('📄 Receipt model created successfully');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReceiptScreen(receipt: receipt),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Receipt error: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating receipt: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getTypeLabel(String t) {
    switch (_normalizeType(t)) {
      case 'CW':
        return 'Cash Withdrawal';
      case 'BE':
        return 'Balance Enquiry';
      case 'MS':
        return 'Mini Statement';
      default:
        return t.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _fmtLong(dynamic d) {
    if (d == null) return 'N/A';
    try {
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.parse(d.toString()).toLocal());
    } catch (_) {
      return d.toString();
    }
  }
}