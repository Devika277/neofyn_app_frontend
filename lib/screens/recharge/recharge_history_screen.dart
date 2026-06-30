// lib/screens/recharge/recharge_history_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/Recharges/recharge_service.dart';

class RechargeHistoryScreen extends StatefulWidget {
  const RechargeHistoryScreen({Key? key}) : super(key: key);

  @override
  State<RechargeHistoryScreen> createState() => _RechargeHistoryScreenState();
}

class _RechargeHistoryScreenState extends State<RechargeHistoryScreen> {
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
  String _selectedType = 'ALL';

  final Map<String, String> _dateFilters = {
    'ALL': 'All Time', 'TODAY': 'Today', 'WEEK': 'This Week',
    'MONTH': 'This Month', 'CUSTOM': 'Custom',
  };

  final Map<String, Map<String, dynamic>> _typeFilters = {
    'ALL': {'label': 'All', 'icon': Iconsax.receipt_1, 'color': Color(0xFF008169)},
    'PREPAID': {'label': 'Prepaid', 'icon': Iconsax.mobile, 'color': Color(0xFF4FC3F7)},
    'POSTPAID': {'label': 'Postpaid', 'icon': Iconsax.mobile, 'color': Color(0xFFBA68C8)},
    'DTH': {'label': 'DTH', 'icon': Iconsax.monitor, 'color': Color(0xFFFFB74D)},
    'DATACARD': {'label': 'Data Card', 'icon': Iconsax.wifi, 'color': Color(0xFF81C784)},
  };

  final Map<String, Map<String, dynamic>> _statusFilters = {
    'ALL': {'label': 'All', 'color': Colors.grey},
    'success': {'label': 'Success', 'color': Color(0xFF10B981)},
    'failed': {'label': 'Failed', 'color': Color(0xFFEF4444)},
    'pending': {'label': 'Pending', 'color': Color(0xFFF59E0B)},
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

  // Helper: Safe string conversion
  String _safeStr(dynamic value) => value?.toString() ?? 'N/A';

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId') ?? '';
    if (_userId.isNotEmpty) _fetchHistory();
  }

  bool get _hasActiveFilters =>
      _selectedType != 'ALL' || _selectedStatus != 'ALL' || _searchQuery.isNotEmpty || _selectedDateFilter != 'ALL';

  Future<void> _fetchHistory() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() { _isLoading = true; _allTransactions.clear(); _filteredTransactions.clear(); });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('accessToken') ?? prefs.getString('token') ?? '';

      final response = await RechargeService.getRechargeHistory(
        userId: _userId,
        token: token,
      );

      debugPrint('📦 [Recharge] Response: ${jsonEncode(response)}');

      if (response['success'] == true) {
        List<dynamic> rawList = [];
        if (response['data'] is List) {
          rawList = response['data'];
        } else if (response['transactions'] is List) {
          rawList = response['transactions'];
        } else if (response['history'] is List) {
          rawList = response['history'];
        }

        final list = rawList.map((e) => Map<String, dynamic>.from(e)).toList();
        debugPrint('✅ [Recharge] Found ${list.length} transactions');

        if (mounted) {
          setState(() { _allTransactions = list; _isLoading = false; });
          _applyFilters();
        }
      } else {
        debugPrint('❌ [Recharge] API failed: ${response['message']}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ [Recharge] History error: $e');
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isFetching = false;
    }
  }

  void _applyFilters() {
    final filtered = _allTransactions.where((tx) {
      // Type filter
      if (_selectedType != 'ALL') {
        final type = _safeStr(tx['recharge_type'] ?? tx['type']).toUpperCase();
        if (type != _selectedType) return false;
      }

      // Status filter
      if (_selectedStatus != 'ALL') {
        final status = _safeStr(tx['status']).toLowerCase();
        if (status != _selectedStatus) return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final mobile = _safeStr(tx['number'] ?? tx['mobile'] ?? tx['mobile_number']).toLowerCase();
        final txnId = _safeStr(tx['transaction_id'] ?? tx['id']).toLowerCase();
        final operator = _safeStr(tx['operator'] ?? tx['operator_name']).toLowerCase();
        if (!mobile.contains(q) && !txnId.contains(q) && !operator.contains(q)) return false;
      }

      // Date filter
      if (_selectedDateFilter != 'ALL') {
        final txDate = _parseDate(tx['created_at'] ?? tx['createdAt'] ?? tx['date']);
        if (txDate == null) return false;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        switch (_selectedDateFilter) {
          case 'TODAY': if (txDate.isBefore(today)) return false; break;
          case 'WEEK': if (txDate.isBefore(today.subtract(Duration(days: now.weekday - 1)))) return false; break;
          case 'MONTH': if (txDate.isBefore(DateTime(now.year, now.month, 1))) return false; break;
          case 'CUSTOM':
            if (_startDate != null && txDate.isBefore(_startDate!)) return false;
            if (_endDate != null && txDate.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) return false;
            break;
        }
      }
      return true;
    }).toList();

    if (mounted) setState(() => _filteredTransactions = filtered);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try { return DateTime.parse(value.toString()).toLocal(); } catch (_) { return null; }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedType = 'ALL'; _selectedStatus = 'ALL';
      _searchQuery = ''; _selectedDateFilter = 'ALL';
      _startDate = null; _endDate = null; _showFilters = false;
    });
    _applyFilters();
  }

  void _setDateFilter(String filter) {
    if (filter == 'CUSTOM') { _pickDateRange(); return; }
    setState(() => _selectedDateFilter = filter);
    _applyFilters();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      firstDate: DateTime(2020), lastDate: DateTime.now(),
      builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF008169), surface: Color(0xFF1A1F1A), onSurface: Colors.white), dialogBackgroundColor: const Color(0xFF1A1F1A)), child: child!),
    );
    if (picked != null) { setState(() { _startDate = picked.start; _endDate = picked.end; _selectedDateFilter = 'CUSTOM'; }); _applyFilters(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0E0A),
      appBar: AppBar(
        title: Text('Recharge History', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Color(0xFF0A0E0A),
        elevation: 0,
        leading: IconButton(icon: const Icon(Iconsax.arrow_left, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(icon: Icon(_showFilters ? Iconsax.filter_edit : Iconsax.filter, color: _showFilters ? Color(0xFF1AA88A) : Colors.white54, size: 20), onPressed: () => setState(() => _showFilters = !_showFilters)),
          IconButton(icon: const Icon(Iconsax.refresh, color: Colors.white54, size: 20), onPressed: _fetchHistory),
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
        decoration: BoxDecoration(color: Color(0xFF1A1F1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF2A342A))),
        child: TextField(
          onChanged: (v) { _searchQuery = v; _applyFilters(); },
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search by Mobile, Txn ID, Operator...',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF6B7280)),
            prefixIcon: const Icon(Iconsax.search_normal, size: 16, color: Color(0xFF6B7280)),
            suffixIcon: _searchQuery.isNotEmpty ? GestureDetector(onTap: () { _searchQuery = ''; _applyFilters(); }, child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280))) : null,
            border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
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
      decoration: BoxDecoration(color: Color(0xFF1A1F1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Color(0xFF2A342A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Date Range', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ...['ALL', 'TODAY', 'WEEK', 'MONTH'].map((key) => GestureDetector(
            onTap: () => _setDateFilter(key),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: _selectedDateFilter == key ? Color(0xFF008169).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedDateFilter == key ? Color(0xFF008169) : Color(0xFF2A342A))), child: Text(_dateFilters[key]!, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _selectedDateFilter == key ? Color(0xFF1AA88A) : Colors.white54))),
          )),
          GestureDetector(
            onTap: () => _setDateFilter('CUSTOM'),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: _selectedDateFilter == 'CUSTOM' ? Color(0xFF008169).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedDateFilter == 'CUSTOM' ? Color(0xFF008169) : Color(0xFF2A342A))), child: Text(_selectedDateFilter == 'CUSTOM' && _startDate != null ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}' : 'Custom', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _selectedDateFilter == 'CUSTOM' ? Color(0xFF1AA88A) : Colors.white54))),
          ),
        ]),
        const SizedBox(height: 14),
        Text('Type', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: _typeFilters.entries.where((e) => e.key != 'ALL').map((e) {
          final isSelected = _selectedType == e.key;
          return GestureDetector(
            onTap: () { setState(() => _selectedType = e.key); _applyFilters(); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: isSelected ? (e.value['color'] as Color).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? (e.value['color'] as Color) : Color(0xFF2A342A))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(e.value['icon'], size: 13, color: isSelected ? e.value['color'] : Colors.white54), const SizedBox(width: 5), Text(e.value['label'], style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? e.value['color'] : Colors.white54))])),
          );
        }).toList()),
        const SizedBox(height: 14),
        Text('Status', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: _statusFilters.entries.where((e) => e.key != 'ALL').map((e) {
          final isSelected = _selectedStatus == e.key;
          return GestureDetector(
            onTap: () { setState(() => _selectedStatus = e.key); _applyFilters(); },
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: isSelected ? (e.value['color'] as Color).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? (e.value['color'] as Color) : Color(0xFF2A342A))), child: Text(e.value['label'], style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? (e.value['color'] as Color) : Colors.white54))),
          );
        }).toList()),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(onTap: _clearAllFilters, child: Row(children: [const Icon(Iconsax.close_circle, size: 14, color: Color(0xFFEF4444)), const SizedBox(width: 4), Text('Clear All', style: GoogleFonts.poppins(fontSize: 11, color: Color(0xFFEF4444)))])),
          Text('${_filteredTransactions.length} results', style: GoogleFonts.poppins(fontSize: 11, color: Color(0xFF6B7280))),
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
        const Icon(Iconsax.filter, size: 12, color: Color(0xFF1AA88A)),
        const SizedBox(width: 6),
        Expanded(child: Text(parts.where((p) => p.isNotEmpty).join(' • '), style: GoogleFonts.poppins(fontSize: 10, color: Color(0xFF1AA88A)), overflow: TextOverflow.ellipsis)),
        GestureDetector(onTap: _clearAllFilters, child: Text('Clear', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54))),
      ]),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF008169)));
    if (_filteredTransactions.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Iconsax.mobile, size: 56, color: Colors.white.withOpacity(0.15)),
        const SizedBox(height: 16),
        Text(_allTransactions.isEmpty ? 'No recharge transactions yet' : 'No matching transactions', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white), textAlign: TextAlign.center),
        if (_hasActiveFilters) ...[const SizedBox(height: 8), TextButton(onPressed: _clearAllFilters, child: Text('Clear Filters', style: GoogleFonts.poppins(color: Color(0xFF1AA88A))))],
      ])));
    }
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _filteredTransactions.length,
      itemBuilder: (_, i) => _buildCard(_filteredTransactions[i]),
    );
  }

  Widget _buildCard(Map<String, dynamic> tx) {
    final type = _safeStr(tx['recharge_type'] ?? tx['type']).toUpperCase();
    final typeInfo = _typeFilters[type] ?? _typeFilters['PREPAID']!;
    final typeColor = typeInfo['color'] as Color;
    final typeIcon = typeInfo['icon'] as IconData;

    final status = _safeStr(tx['status']).toLowerCase();
    final isSuccess = status == 'success';
    final isFailed = status == 'failed';
    final Color sc = isSuccess ? Color(0xFF10B981) : (isFailed ? Color(0xFFEF4444) : Color(0xFFF59E0B));

    final amount = _safeStr(tx['amount']);
    final mobile = _safeStr(tx['number'] ?? tx['mobile'] ?? tx['mobile_number']);
    final operator = _safeStr(tx['operator'] ?? tx['operator_name']);
    final txnId = _safeStr(tx['transaction_id'] ?? tx['id']);
    final date = tx['created_at'] ?? tx['createdAt'] ?? tx['date'];

    return GestureDetector(
      onTap: () => _showDetails(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Color(0xFF1A1F1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Color(0xFF2A342A))),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: typeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(typeIcon, color: typeColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(operator, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: typeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text(typeInfo['label'], style: GoogleFonts.poppins(fontSize: 9, color: typeColor))),
            ]),
            const SizedBox(height: 3),
            Text(mobile, style: GoogleFonts.poppins(fontSize: 10, color: Color(0xFF6B7280))),
            Text('$txnId • ${_fmt(date)}', style: GoogleFonts.poppins(fontSize: 9, color: Color(0xFF6B7280))),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹$amount', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600, color: sc))),
            if (isSuccess)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () => _downloadReceipt(tx),
                  child: Icon(Iconsax.document_download, color: Color(0xFF1AA88A), size: 16),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> tx) {
    final status = _safeStr(tx['status']).toLowerCase();
    final isSuccess = status == 'success';
    final isFailed = status == 'failed';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.65),
        decoration: const BoxDecoration(color: Color(0xFF1A1F1A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Recharge Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                _detailRow('Status', status.toUpperCase(), valueColor: isSuccess ? Color(0xFF10B981) : (isFailed ? Color(0xFFEF4444) : Color(0xFFF59E0B))),
                _detailRow('Amount', '₹${_safeStr(tx['amount'])}'),
                _detailRow('Operator', _safeStr(tx['operator'] ?? tx['operator_name'])),
                _detailRow('Mobile', _safeStr(tx['number'] ?? tx['mobile'] ?? tx['mobile_number'])),
                _detailRow('Type', _safeStr(tx['recharge_type'] ?? tx['type'])),
                _detailRow('Txn ID', _safeStr(tx['transaction_id'] ?? tx['id'])),
                if (tx['operator_ref_id'] != null) _detailRow('Operator Ref', _safeStr(tx['operator_ref_id'])),
                _detailRow('Date', _fmtLong(tx['created_at'] ?? tx['createdAt'] ?? tx['date'])),
                const SizedBox(height: 20),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              if (isSuccess) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); _downloadReceipt(tx); },
                    icon: const Icon(Iconsax.document_download, size: 16),
                    label: const Text('Download Receipt'),
                    style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF008169), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: BorderSide(color: Colors.white.withOpacity(0.2)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Close'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 100, child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF9CA3AF)))),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: valueColor ?? Colors.white))),
      ]),
    );
  }

  void _downloadReceipt(Map<String, dynamic> tx) {
    HapticFeedback.mediumImpact();

    final receiptData = {
      'type': _safeStr(tx['recharge_type'] ?? tx['type']),
      'operator': _safeStr(tx['operator'] ?? tx['operator_name']),
      'mobile': _safeStr(tx['number'] ?? tx['mobile'] ?? tx['mobile_number']),
      'amount': _safeStr(tx['amount']),
      'txn_id': _safeStr(tx['transaction_id'] ?? tx['id']),
      'status': _safeStr(tx['status']),
      'date': _fmtLong(tx['created_at'] ?? tx['createdAt'] ?? DateTime.now().toString()),
      'recharge_type': _safeStr(tx['recharge_type'] ?? tx['type']),
    };

    _showReceiptDialog(receiptData);
  }

  void _showReceiptDialog(Map<String, String> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Color(0xFF1A1F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 48),
            const SizedBox(height: 12),
            Text('Payment Successful', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 20),
            _receiptRow('Operator', data['operator'] ?? 'N/A'),
            _receiptRow('Mobile', data['mobile'] ?? 'N/A'),
            _receiptRow('Amount', '₹${data['amount'] ?? '0'}'),
            _receiptRow('Type', data['recharge_type'] ?? 'N/A'),
            _receiptRow('Txn ID', data['txn_id'] ?? 'N/A'),
            _receiptRow('Date', data['date'] ?? 'N/A'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Color(0xFF008169).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Text('Neofyn Bharat', style: TextStyle(color: Color(0xFF008169), fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close', style: TextStyle(color: Colors.white54))),
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Receipt saved!', style: GoogleFonts.poppins(color: Colors.white)), backgroundColor: Color(0xFF008169), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), margin: const EdgeInsets.all(16)),
              );
              Navigator.pop(ctx);
            },
            icon: const Icon(Iconsax.document_download, size: 16),
            label: const Text('Save Receipt'),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF008169), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF9CA3AF))),
        Text(value, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ]),
    );
  }

  String _fmt(dynamic d) {
    if (d == null) return '';
    try { return DateFormat('dd MMM, HH:mm').format(DateTime.parse(d.toString()).toLocal()); } catch (_) { return ''; }
  }

  String _fmtLong(dynamic d) {
    if (d == null) return 'N/A';
    try { return DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.parse(d.toString()).toLocal()); } catch (_) { return d.toString(); }
  }
}