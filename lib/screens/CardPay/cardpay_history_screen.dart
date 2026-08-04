// lib/screens/cardpay/cardpay_history_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/cardpay_provider.dart';

class CardPayReceiptModel {
  final String transactionId;
  final String merchantRefId;
  final double amount;
  final String status;
  final String cardLastFour;
  final String cardNetwork;
  final String? rrn;
  final double? charges;
  final String? customerName;
  final String? customerMobile;
  final String? customerEmail;
  final DateTime transactionDate;

  CardPayReceiptModel({
    required this.transactionId,
    required this.merchantRefId,
    required this.amount,
    required this.status,
    this.cardLastFour = '',
    this.cardNetwork = '',
    this.rrn,
    this.charges,
    this.customerName,
    this.customerMobile,
    this.customerEmail,
    required this.transactionDate,
  });

  String get formattedDate => DateFormat('dd-MM-yyyy hh:mm a').format(transactionDate);
  String get formattedDateShort => DateFormat('dd-MM-yyyy').format(transactionDate);
  String get formattedTime => DateFormat('hh:mm a').format(transactionDate);
  String get fileNameDate => DateFormat('yyyyMMdd_HHmmss').format(transactionDate);
}

class CardPayHistoryScreen extends StatefulWidget {
  const CardPayHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CardPayHistoryScreen> createState() => _CardPayHistoryScreenState();
}

class _CardPayHistoryScreenState extends State<CardPayHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _showFilters = false;
  String _selectedStatus = 'ALL';
  String _selectedDateFilter = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;

  final Map<String, String> _dateFilters = {
    'ALL': 'All Time',
    'TODAY': 'Today',
    'WEEK': 'This Week',
    'MONTH': 'This Month',
    'CUSTOM': 'Custom',
  };

  final Map<String, Map<String, dynamic>> _statusFilters = {
    'ALL': {'label': 'All', 'color': Colors.grey},
    'success': {'label': 'Success', 'color': Color(0xFF10B981)},
    'failed': {'label': 'Failed', 'color': Color(0xFFEF4444)},
    'pending': {'label': 'Pending', 'color': Color(0xFFF59E0B)},
  };

  final Map<String, Map<String, dynamic>> _cardNetworkFilters = {
    'ALL': {'label': 'All', 'icon': Iconsax.card, 'color': Color(0xFF9B59B6)},
    'VISA': {'label': 'Visa', 'icon': Iconsax.card, 'color': Color(0xFF1A73E8)},
    'MASTERCARD': {'label': 'Mastercard', 'icon': Iconsax.card, 'color': Color(0xFFEB001B)},
    'RUPAY': {'label': 'RuPay', 'icon': Iconsax.card, 'color': Color(0xFF00A651)},
    'AMEX': {'label': 'Amex', 'icon': Iconsax.card, 'color': Color(0xFF0077B6)},
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final provider = Provider.of<CardPayProvider>(context, listen: false);
    await provider.fetchUserHistory(
      status: _selectedStatus != 'ALL' ? _selectedStatus : null,
      startDate: _startDate?.toIso8601String().split('T').first,
      endDate: _endDate?.toIso8601String().split('T').first,
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
    );
  }

  bool get _hasActiveFilters =>
      _selectedStatus != 'ALL' ||
          _searchController.text.isNotEmpty ||
          _selectedDateFilter != 'ALL';

  void _applyFilters() {
    // The provider handles filtering, just reload
    _loadHistory();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedStatus = 'ALL';
      _searchController.clear();
      _selectedDateFilter = 'ALL';
      _startDate = null;
      _endDate = null;
      _showFilters = false;
    });
    _loadHistory();
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
            primary: Color(0xFF9B59B6),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        title: Text(
          'CardPay History',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A0E0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Iconsax.filter_edit : Iconsax.filter,
              color: _showFilters ? const Color(0xFF9B59B6) : Colors.white54,
              size: 20,
            ),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(
            icon: const Icon(Iconsax.refresh, color: Colors.white54, size: 20),
            onPressed: _loadHistory,
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
          color: const Color(0xFF1A1F1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A342A)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => _applyFilters(),
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search by Reference ID, Card...',
            hintStyle: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
            prefixIcon: const Icon(
              Iconsax.search_normal,
              size: 16,
              color: Color(0xFF6B7280),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
              onTap: () {
                _searchController.clear();
                _applyFilters();
              },
              child: const Icon(
                Icons.close,
                size: 16,
                color: Color(0xFF6B7280),
              ),
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
        color: const Color(0xFF1A1F1A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A342A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date Range',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...['ALL', 'TODAY', 'WEEK', 'MONTH'].map((key) => GestureDetector(
                onTap: () => _setDateFilter(key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _selectedDateFilter == key
                        ? const Color(0xFF9B59B6).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedDateFilter == key
                          ? const Color(0xFF9B59B6)
                          : const Color(0xFF2A342A),
                    ),
                  ),
                  child: Text(
                    _dateFilters[key]!,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _selectedDateFilter == key
                          ? const Color(0xFF9B59B6)
                          : Colors.white54,
                    ),
                  ),
                ),
              )),
              GestureDetector(
                onTap: () => _setDateFilter('CUSTOM'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _selectedDateFilter == 'CUSTOM'
                        ? const Color(0xFF9B59B6).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedDateFilter == 'CUSTOM'
                          ? const Color(0xFF9B59B6)
                          : const Color(0xFF2A342A),
                    ),
                  ),
                  child: Text(
                    _selectedDateFilter == 'CUSTOM' && _startDate != null
                        ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}'
                        : 'Custom',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _selectedDateFilter == 'CUSTOM'
                          ? const Color(0xFF9B59B6)
                          : Colors.white54,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Status',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white54,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _statusFilters.entries.where((e) => e.key != 'ALL').map((e) {
              final isSelected = _selectedStatus == e.key;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStatus = e.key);
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (e.value['color'] as Color).withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? (e.value['color'] as Color)
                          : const Color(0xFF2A342A),
                    ),
                  ),
                  child: Text(
                    e.value['label'],
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? (e.value['color'] as Color)
                          : Colors.white54,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _clearAllFilters,
                child: Row(
                  children: [
                    const Icon(Iconsax.close_circle, size: 14, color: Color(0xFFEF4444)),
                    const SizedBox(width: 4),
                    Text(
                      'Clear All',
                      style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFEF4444)),
                    ),
                  ],
                ),
              ),
              Consumer<CardPayProvider>(
                builder: (context, provider, child) {
                  return Text(
                    '${provider.transactions.length} results',
                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF6B7280)),
                  );
                },
              ),
            ],
          ),
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
      child: Row(
        children: [
          const Icon(Iconsax.filter, size: 12, color: Color(0xFF9B59B6)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              parts.where((p) => p.isNotEmpty).join(' • '),
              style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF9B59B6)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: _clearAllFilters,
            child: Text(
              'Clear',
              style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Consumer<CardPayProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.transactions.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF9B59B6)),
          );
        }

        if (provider.transactions.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.card,
                    size: 56,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.transactions.isEmpty && !_hasActiveFilters
                        ? 'No CardPay transactions yet'
                        : 'No matching transactions',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_hasActiveFilters) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _clearAllFilters,
                      child: Text(
                        'Clear Filters',
                        style: GoogleFonts.poppins(color: const Color(0xFF9B59B6)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadHistory,
          color: const Color(0xFF9B59B6),
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: provider.transactions.length,
            itemBuilder: (_, index) {
              final txn = provider.transactions[index];
              return _buildCard(txn);
            },
          ),
        );
      },
    );
  }

  Widget _buildCard(dynamic txn) {
    final status = txn.txnStatus.toLowerCase();
    final isSuccess = status == 'success';
    final isFailed = status == 'failed';
    final Color sc = isSuccess
        ? const Color(0xFF10B981)
        : (isFailed ? const Color(0xFFEF4444) : const Color(0xFFF59E0B));

    final cardNetwork = txn.cardNetwork ?? 'UNKNOWN';
    final networkInfo = _cardNetworkFilters[cardNetwork.toUpperCase()] ??
        _cardNetworkFilters['ALL']!;
    final networkColor = networkInfo['color'] as Color;

    return GestureDetector(
      onTap: () => _showTransactionDetails(context, txn),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A342A)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: networkColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Iconsax.card,
                color: networkColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Card ${txn.cardLastFour ?? ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: networkColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          txn.cardNetwork ?? 'N/A',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: networkColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    txn.merchantRefId ?? 'N/A',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  Text(
                    _formatDate(txn.createdAt),
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatAmount(txn.amount),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: sc.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: sc,
                    ),
                  ),
                ),
                if (isSuccess)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: () => _downloadReceipt(txn),
                      child: const Icon(
                        Iconsax.document_download,
                        color: Color(0xFF9B59B6),
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, dynamic txn) {
    final status = txn.txnStatus.toLowerCase();
    final isSuccess = status == 'success';
    final isFailed = status == 'failed';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            Text(
              'CardPay Details',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _detailRow(
                      'Status',
                      status.toUpperCase(),
                      valueColor: isSuccess
                          ? const Color(0xFF10B981)
                          : (isFailed ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
                    ),
                    _detailRow('Amount', _formatAmount(txn.amount)),
                    _detailRow('Reference ID', txn.merchantRefId ?? 'N/A'),
                    if (txn.cardLastFour != null)
                      _detailRow('Card', '****${txn.cardLastFour}'),
                    if (txn.cardNetwork != null)
                      _detailRow('Network', txn.cardNetwork!),
                    if (txn.rrn != null) _detailRow('RRN', txn.rrn!),
                    if (txn.charges != null)
                      _detailRow('Charges', _formatAmount(txn.charges)),
                    if (txn.customerName != null)
                      _detailRow('Customer', txn.customerName!),
                    if (txn.customerMobile != null)
                      _detailRow('Mobile', txn.customerMobile!),
                    if (txn.customerEmail != null)
                      _detailRow('Email', txn.customerEmail!),
                    _detailRow('Date', _formatDate(txn.createdAt)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (isSuccess) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _downloadReceipt(txn);
                        },
                        icon: const Icon(Iconsax.document_download, size: 16),
                        label: const Text('Download Receipt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9B59B6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
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

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF9CA3AF),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: valueColor ?? Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _downloadReceipt(dynamic txn) {
    HapticFeedback.mediumImpact();

    // Prepare receipt data as Map
    final receiptData = {
      'txn_id': txn.merchantRefId?.toString() ?? 'N/A',
      'amount': txn.amount?.toString() ?? '0',
      'status': txn.txnStatus?.toString() ?? 'success',
      'card_last_four': txn.cardLastFour?.toString() ?? '',
      'card_network': txn.cardNetwork?.toString() ?? '',
      'rrn': txn.rrn?.toString() ?? '',
      'charges': txn.charges?.toString() ?? '',
      'customer_name': txn.customerName?.toString() ?? '',
      'customer_mobile': txn.customerMobile?.toString() ?? '',
      'customer_email': txn.customerEmail?.toString() ?? '',
      'date': txn.createdAt?.toString() ?? DateTime.now().toString(),
    };

    // Show receipt dialog with the data
    _showReceiptDialog(receiptData.cast<String, String>());
  }

  void _showReceiptDialog(Map<String, String> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 48),
            const SizedBox(height: 12),
            Text(
              'Payment Successful',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            _receiptRow('Card', '****${data['card_last_four'] ?? ''}'),
            _receiptRow('Network', data['card_network'] ?? 'N/A'),
            _receiptRow('Amount', '₹${data['amount'] ?? '0'}'),
            _receiptRow('Reference ID', data['txn_id'] ?? 'N/A'),
            if (data['rrn']?.isNotEmpty ?? false)
              _receiptRow('RRN', data['rrn']!),
            if (data['customer_name']?.isNotEmpty ?? false)
              _receiptRow('Customer', data['customer_name']!),
            _receiptRow('Date', data['date'] ?? 'N/A'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF9B59B6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Neofyn Bharat',
                style: TextStyle(
                  color: Color(0xFF9B59B6),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.lightImpact();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Saving receipt...',
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFF1A1F1A),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );

              try {
                DateTime txDate;
                try {
                  txDate = DateTime.parse(
                      (data['date'] ?? DateTime.now().toString()).toString()
                  ).toLocal();
                } catch (_) {
                  txDate = DateTime.now();
                }

                final model = CardPayReceiptModel(
                  transactionId: data['txn_id'] ?? 'N/A',
                  merchantRefId: data['txn_id'] ?? 'N/A',
                  amount: double.tryParse(data['amount'] ?? '0') ?? 0,
                  status: data['status'] ?? 'success',
                  cardLastFour: data['card_last_four'] ?? '',
                  cardNetwork: data['card_network'] ?? '',
                  rrn: data['rrn'],
                  charges: double.tryParse(data['charges'] ?? ''),
                  customerName: data['customer_name'],
                  customerMobile: data['customer_mobile'],
                  customerEmail: data['customer_email'],
                  transactionDate: txDate,
                );

                final file = await _generateCardPayPdf(model);

                if (mounted) {
                  String displayPath = file.path;
                  if (displayPath.contains('/storage/emulated/0/')) {
                    displayPath = displayPath.replaceAll('/storage/emulated/0/', 'Internal Storage/');
                  }

                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Receipt saved!',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Iconsax.folder_2, color: Colors.white70, size: 14),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    displayPath,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.white70,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1A1F1A),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'OPEN',
                        textColor: const Color(0xFF9B59B6),
                        onPressed: () {
                          try {
                            OpenFile.open(file.path);
                          } catch (_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No app found to open PDF'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Iconsax.close_circle, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Failed: $e',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: const Color(0xFF1A1F1A),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Iconsax.document_download, size: 16),
            label: const Text('Save Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9B59B6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF9CA3AF)),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(dateTimeString).toLocal();
      return DateFormat('dd MMM yyyy, HH:mm:ss').format(dateTime);
    } catch (_) {
      return dateTimeString;
    }
  }

  String _formatAmount(double? amount) {
    if (amount == null) return '₹0.00';
    try {
      return '₹${amount.toStringAsFixed(2)}';
    } catch (_) {
      return '₹0.00';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return const Color(0xFF10B981);
      case 'pending':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFFEF4444);
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'success':
        return Icons.check_circle_rounded;
      case 'pending':
        return Icons.pending_rounded;
      default:
        return Icons.error_rounded;
    }
  }

  // ─────────────────────────────────────────────────────────────
  Future<Directory> _getCardPayFolderPath() async {
    Directory? directory;
    if (Platform.isAndroid) {
      final paths = [
        '/storage/emulated/0/Documents/NEOFYN/CardPay',
        '/storage/emulated/0/Download/NEOFYN/CardPay'
      ];
      for (final path in paths) {
        try {
          final dir = Directory(path);
          if (!await dir.exists()) await dir.create(recursive: true);
          return dir;
        } catch (_) {}
      }
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          directory = Directory('${extDir.path}/NEOFYN/CardPay');
          if (!await directory!.exists()) await directory.create(recursive: true);
          return directory;
        }
      } catch (_) {}
    }
    final appDir = await getApplicationDocumentsDirectory();
    directory = Directory('${appDir.path}/NEOFYN/CardPay');
    if (!await directory!.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> _generateCardPayPdf(CardPayReceiptModel r) async {
    final pdf = pw.Document();
    PdfColor pc(Color c) => PdfColor.fromInt(c.value);
    final f = await PdfGoogleFonts.poppinsRegular();
    final fb = await PdfGoogleFonts.poppinsBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Container(
                    width: 60,
                    height: 60,
                    decoration: pw.BoxDecoration(
                      color: pc(const Color(0xFF9B59B6)),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14)),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'NB',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          font: fb,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'NEOFYN BHARATH',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      font: fb,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Card Payment Receipt',
                    style: pw.TextStyle(
                      fontSize: 11,
                      color: pc(const Color(0xFF9B59B6)),
                      font: fb,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '${r.formattedDateShort}  ${r.formattedTime}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: f),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            _pdfRow(f, fb, 'Card', '****${r.cardLastFour}'),
            _pdfRow(f, fb, 'Network', r.cardNetwork),
            _pdfRow(f, fb, 'Amount', '₹${r.amount.toStringAsFixed(2)}', vc: pc(const Color(0xFF10B981))),
            _pdfRow(f, fb, 'Reference ID', r.merchantRefId),
            if (r.rrn != null && r.rrn!.isNotEmpty)
              _pdfRow(f, fb, 'RRN', r.rrn!),
            if (r.customerName != null && r.customerName!.isNotEmpty)
              _pdfRow(f, fb, 'Customer', r.customerName!),
            if (r.customerMobile != null && r.customerMobile!.isNotEmpty)
              _pdfRow(f, fb, 'Mobile', r.customerMobile!),
            if (r.customerEmail != null && r.customerEmail!.isNotEmpty)
              _pdfRow(f, fb, 'Email', r.customerEmail!),
            if (r.charges != null)
              _pdfRow(f, fb, 'Charges', '₹${r.charges!.toStringAsFixed(2)}'),
            _pdfRow(f, fb, 'Date & Time', r.formattedDate),
            _pdfRow(f, fb, 'Status', 'SUCCESS', vc: pc(const Color(0xFF10B981))),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: pc(const Color(0xFF9B59B6).withOpacity(0.06)),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(
                  color: pc(const Color(0xFF9B59B6).withOpacity(0.15)),
                  width: 0.5,
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Amount : ₹${r.amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      font: fb,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                '© 2025 NEOFYN Bharath - All Rights Reserved',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, font: f),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Center(
              child: pw.Text(
                'System generated receipt - No signature required',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, font: f),
              ),
            ),
          ],
        ),
      ),
    );

    final dir = await _getCardPayFolderPath();
    final file = File(
      '${dir.path}/CardPay_Receipt_${r.transactionId}_${r.fileNameDate}.pdf',
    );
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _pdfRow(pw.Font f, pw.Font fb, String label, String value, {PdfColor? vc}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              '$label :',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: f),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                font: fb,
                color: vc ?? PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}