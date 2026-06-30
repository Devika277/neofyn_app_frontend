// lib/screens/history/dmt_history_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../services/AEPS/api_service.dart';
import '../receipt_screen.dart';
import '../../models/receipt_model.dart';

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
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _isFetching = false;

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

  final Map<String, Map<String, dynamic>> _statusFilters = {
    'ALL': {'label': 'All', 'color': AppColors.textDarkSecondary},
    'SUCCESS': {'label': 'Success', 'color': AppColors.success},
    'FAILED': {'label': 'Failed', 'color': AppColors.error},
    'PENDING': {'label': 'Pending', 'color': AppColors.warning},
  };

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId') ?? '';
    if (_userId.isNotEmpty) _fetchHistory();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingMore || !_hasMore || _isFetching) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  bool get _hasActiveFilters =>
      _selectedStatus != 'ALL' || _searchQuery.isNotEmpty || _selectedDateFilter != 'ALL';

  Future<void> _fetchHistory() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() { _isLoading = true; _allTransactions.clear(); _filteredTransactions.clear(); });

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('https://api.myneofyn.com/api/dmt/history?userId=$_userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> list = [];
        if (data['transactions'] is List) {
          list = (data['transactions'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        } else if (data['data'] is List) {
          list = (data['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
        }

        if (mounted) {
          setState(() {
            _allTransactions = list;
            _isLoading = false;
          });
          _applyFilters();
        }
      }
    } catch (e) {
      debugPrint('DMT History error: $e');
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isFetching = false;
    }
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken') ?? prefs.getString('token') ?? '';
  }

  Future<void> _loadMore() async {
    // Implement if API supports pagination
    setState(() => _hasMore = false);
  }

  void _applyFilters() {
    final filtered = _allTransactions.where((tx) {
      // Status filter
      final status = (tx['status'] ?? '').toString().toUpperCase();
      if (_selectedStatus == 'SUCCESS' && status != 'SUCCESS') return false;
      if (_selectedStatus == 'FAILED' && status != 'FAILED') return false;
      if (_selectedStatus == 'PENDING' && status != 'PENDING') return false;

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final ref = (tx['transactionId'] ?? tx['txnRefId'] ?? '').toString().toLowerCase();
        final bene = (tx['beneficiaryName'] ?? '').toString().toLowerCase();
        if (!ref.contains(q) && !bene.contains(q)) return false;
      }

      // Date filter
      if (_selectedDateFilter != 'ALL') {
        final txDate = _parseDate(tx['createdAt'] ?? tx['created_at'] ?? tx['date']);
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
            if (_startDate != null && txDate.isBefore(_startDate!)) return false;
            if (_endDate != null && txDate.isAfter(_endDate!)) return false;
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
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF008169), surface: Color(0xFF1A1F1A), onSurface: Colors.white),
          dialogBackgroundColor: const Color(0xFF1A1F1A),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; _selectedDateFilter = 'CUSTOM'; });
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text('DMT History', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textWhite)),
        centerTitle: true,
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Iconsax.filter_edit : Iconsax.filter, color: _showFilters ? AppColors.primaryLight : AppColors.textDarkSecondary, size: 20),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(icon: const Icon(Iconsax.refresh, color: AppColors.textDarkSecondary, size: 20), onPressed: _fetchHistory),
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
        decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderDark)),
        child: TextField(
          onChanged: (v) { _searchQuery = v; _applyFilters(); },
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textWhite),
          decoration: InputDecoration(
            hintText: 'Search by Transaction ID, Beneficiary...',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDarkHint),
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
      decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Date Range', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ...['ALL', 'TODAY', 'WEEK', 'MONTH'].map((key) {
            final isSelected = _selectedDateFilter == key;
            return GestureDetector(
              onTap: () => _setDateFilter(key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderDark)),
                child: Text(_dateFilters[key]!, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? AppColors.primaryLight : AppColors.textDarkSecondary)),
              ),
            );
          }),
          GestureDetector(
            onTap: () => _setDateFilter('CUSTOM'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: _selectedDateFilter == 'CUSTOM' ? AppColors.primary.withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedDateFilter == 'CUSTOM' ? AppColors.primary : AppColors.borderDark)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Iconsax.calendar_edit, size: 12, color: _selectedDateFilter == 'CUSTOM' ? AppColors.primaryLight : AppColors.textDarkSecondary),
                const SizedBox(width: 4),
                Text(_selectedDateFilter == 'CUSTOM' && _startDate != null ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}' : 'Custom', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _selectedDateFilter == 'CUSTOM' ? AppColors.primaryLight : AppColors.textDarkSecondary)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text('Status', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: _statusFilters.entries.map((e) {
          final isSelected = _selectedStatus == e.key;
          return GestureDetector(
            onTap: () { setState(() => _selectedStatus = e.key); _applyFilters(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: isSelected ? (e.value['color'] as Color).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: isSelected ? (e.value['color'] as Color) : AppColors.borderDark)),
              child: Text(e.value['label'], style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? (e.value['color'] as Color) : AppColors.textDarkSecondary)),
            ),
          );
        }).toList()),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(onTap: _clearAllFilters, child: Row(children: [const Icon(Iconsax.close_circle, size: 14, color: AppColors.error), const SizedBox(width: 4), Text('Clear All', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.error))])),
          Text('${_filteredTransactions.length} results', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkHint)),
        ]),
      ]),
    );
  }

  Widget _buildActiveFiltersBar() {
    final parts = <String>[];
    if (_selectedStatus != 'ALL') parts.add(_statusFilters[_selectedStatus]?['label'] ?? '');
    if (_selectedDateFilter != 'ALL') parts.add(_dateFilters[_selectedDateFilter] ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Iconsax.filter, size: 12, color: Color(0xFF1AA88A)),
        const SizedBox(width: 6),
        Expanded(child: Text(parts.where((p) => p.isNotEmpty).join(' • '), style: GoogleFonts.poppins(fontSize: 10, color: AppColors.primaryLight), overflow: TextOverflow.ellipsis)),
        GestureDetector(onTap: _clearAllFilters, child: Text('Clear', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkSecondary))),
      ]),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF008169)));
    if (_filteredTransactions.isEmpty) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Iconsax.receipt_1, size: 56, color: AppColors.textDarkHint.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(_allTransactions.isEmpty ? 'No DMT transactions yet' : 'No matching transactions', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textWhite), textAlign: TextAlign.center),
        ])),
      );
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
    final status = (tx['status'] ?? 'PENDING').toString().toUpperCase();
    final isSuccess = status == 'SUCCESS';
    final isFailed = status == 'FAILED';
    final Color sc = isSuccess ? AppColors.success : (isFailed ? AppColors.error : AppColors.warning);
    final IconData si = isSuccess ? Iconsax.tick_circle : (isFailed ? Iconsax.close_circle : Iconsax.clock);
    final amount = tx['amount'] ?? tx['transactionAmount'] ?? '0';
    final beneName = tx['beneficiaryName'] ?? tx['beneficiary_name'] ?? 'N/A';
    final txnId = tx['transactionId'] ?? tx['txnRefId'] ?? tx['id'] ?? 'N/A';
    final date = tx['createdAt'] ?? tx['created_at'] ?? tx['date'];

    return GestureDetector(
      onTap: () => _showDetails(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: const Color(0xFF7B9FE0).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Iconsax.money_send, color: Color(0xFF7B9FE0), size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(beneName.toString(), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textWhite), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(txnId.toString(), style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkHint), overflow: TextOverflow.ellipsis),
            Text(_fmt(date), style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkHint)),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹$amount', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textWhite)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(si, size: 8, color: sc), const SizedBox(width: 3), Text(status, style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600, color: sc))])),
          ]),
        ]),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> tx) {
    final status = (tx['status'] ?? '').toString().toUpperCase();
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
          Text('Transaction Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textWhite)),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                _row('Status', status, vc: status == 'SUCCESS' ? AppColors.success : AppColors.error),
                _row('Transaction ID', tx['transactionId']?.toString() ?? 'N/A'),
                _row('Amount', '₹${tx['amount'] ?? '0'}'),
                _row('Beneficiary', tx['beneficiaryName']?.toString() ?? 'N/A'),
                _row('Account', tx['accountNumber']?.toString() ?? 'N/A'),
                _row('IFSC', tx['ifscCode']?.toString() ?? 'N/A'),
                _row('Bank', tx['bankName']?.toString() ?? 'N/A'),
                _row('UTR', tx['utrNumber']?.toString() ?? 'N/A'),
                _row('Date', _fmtLong(tx['createdAt'] ?? tx['created_at'] ?? tx['date'])),
                const SizedBox(height: 20),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              if (status == 'SUCCESS') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () { Navigator.pop(context); _downloadReceipt(tx); },
                    icon: const Icon(Iconsax.document_download, size: 16),
                    label: const Text('Receipt'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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

  void _downloadReceipt(Map<String, dynamic> tx) {
    try {
      final receipt = ReceiptModel.fromApiResponse({
        'data': {
          'status': tx['status'] ?? 'SUCCESS',
          'merchantRefId': tx['transactionId'] ?? '',
          'txnRefId': tx['utrNumber'] ?? tx['txnRefId'] ?? '',
          'transactionAmount': tx['amount']?.toString() ?? '0',
          'txnDateTime': tx['createdAt'] ?? DateTime.now().toString(),
          'rrn': tx['utrNumber'] ?? '',
        }
      }, transactionType: 'DMT', merchantId: 'N/A', mobileNumber: '');
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)));
    } catch (e) {
      debugPrint('Receipt error: $e');
    }
  }

  Widget _row(String l, String v, {Color? vc}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 100, child: Text(l, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDarkSecondary))),
      Expanded(child: Text(v, textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: vc ?? AppColors.textWhite))),
    ]),
  );

  String _fmt(dynamic d) {
    if (d == null) return '';
    try { return DateFormat('dd MMM, HH:mm').format(DateTime.parse(d.toString()).toLocal()); } catch (_) { return ''; }
  }

  String _fmtLong(dynamic d) {
    if (d == null) return 'N/A';
    try { return DateFormat('dd-MM-yyyy HH:mm:ss').format(DateTime.parse(d.toString()).toLocal()); } catch (_) { return d.toString(); }
  }
}