// lib/screens/history/bbps_history_screen.dart

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
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/BBPS/api_service.dart';

class BbpsReceiptModel {
  final String transactionId;
  final String providerTxnId;
  final String category;
  final String serviceType;
  final String consumerNumber;
  final String amount;
  final String status;
  final String providerName;
  final DateTime transactionDate;

  BbpsReceiptModel({
    required this.transactionId,
    required this.providerTxnId,
    required this.category,
    required this.serviceType,
    required this.consumerNumber,
    required this.amount,
    required this.status,
    required this.providerName,
    required this.transactionDate,
  });

  String get formattedDate => DateFormat('dd-MM-yyyy hh:mm a').format(transactionDate);
  String get formattedDateShort => DateFormat('dd-MM-yyyy').format(transactionDate);
  String get formattedTime => DateFormat('hh:mm a').format(transactionDate);
  String get fileNameDate => DateFormat('yyyyMMdd_HHmmss').format(transactionDate);
  bool get isSuccess => status.toLowerCase() == 'success';

  String get categoryLabel {
    switch (category.toUpperCase()) {
      case 'ELECTRICITY': return 'Electricity Bill';
      case 'GAS': return 'Gas Bill';
      case 'FASTAG': return 'Fastag Recharge';
      case 'WATER': return 'Water Bill';
      case 'DTH': return 'DTH Recharge';
      case 'INSURANCE': return 'Insurance Payment';
      case 'BROADBAND': return 'Broadband Bill';
      case 'EDUCATION': return 'Education Fee';
      default: return 'Bill Payment';
    }
  }
}

class BbpsHistoryScreen extends StatefulWidget {
  const BbpsHistoryScreen({Key? key}) : super(key: key);

  @override
  State<BbpsHistoryScreen> createState() => _BbpsHistoryScreenState();
}

class _BbpsHistoryScreenState extends State<BbpsHistoryScreen> {
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
  String _selectedCategory = 'ALL';
  String _selectedStatus = 'ALL';

  final Map<String, String> _dateFilters = {
    'ALL': 'All Time', 'TODAY': 'Today', 'WEEK': 'This Week',
    'MONTH': 'This Month', 'CUSTOM': 'Custom',
  };

  final Map<String, Map<String, dynamic>> _categories = {
    'ALL': {'label': 'All', 'icon': Iconsax.receipt_1, 'color': Color(0xFF008169)},
    'ELECTRICITY': {'label': 'Electricity', 'icon': Iconsax.flash, 'color': Color(0xFFFFB74D)},
    'GAS': {'label': 'Gas', 'icon': Iconsax.gas_station, 'color': Color(0xFF4FC3F7)},
    'FASTAG': {'label': 'Fastag', 'icon': Iconsax.car, 'color': Color(0xFF81C784)},
    'WATER': {'label': 'Water', 'icon': Iconsax.drop, 'color': Color(0xFF64B5F6)},
    'DTH': {'label': 'DTH', 'icon': Iconsax.monitor, 'color': Color(0xFFBA68C8)},
    'INSURANCE': {'label': 'Insurance', 'icon': Iconsax.shield_tick, 'color': Color(0xFFE57373)},
    'BROADBAND': {'label': 'Broadband', 'icon': Iconsax.wifi, 'color': Color(0xFF4DB6AC)},
    'EDUCATION': {'label': 'Education', 'icon': Iconsax.book, 'color': Color(0xFF7986CB)},
    'OTHER': {'label': 'Other', 'icon': Iconsax.more, 'color': Colors.grey},
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

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId') ?? '';
    if (_userId.isNotEmpty) _fetchHistory();
  }

  bool get _hasActiveFilters =>
      _selectedCategory != 'ALL' || _selectedStatus != 'ALL' || _searchQuery.isNotEmpty || _selectedDateFilter != 'ALL';

  Future<void> _fetchHistory() async {
    if (_isFetching) return;
    _isFetching = true;
    setState(() { _isLoading = true; _allTransactions.clear(); _filteredTransactions.clear(); });
    try {
      final list = await _apiService.getBbpsHistory(userId: _userId);
      if (mounted) { setState(() { _allTransactions = list; _isLoading = false; }); _applyFilters(); }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isFetching = false;
    }
  }

  void _applyFilters() {
    final filtered = _allTransactions.where((tx) {
      if (_selectedCategory != 'ALL') {
        final serviceType = (tx['service_type'] ?? '').toString();
        if (_getCategoryFromServiceType(serviceType) != _selectedCategory) return false;
      }
      if (_selectedStatus != 'ALL') {
        if ((tx['status'] ?? '').toString().toLowerCase() != _selectedStatus) return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final cn = (tx['consumer_number'] ?? '').toString().toLowerCase();
        final tid = (tx['provider_txn_id'] ?? tx['id']?.toString() ?? '').toString().toLowerCase();
        if (!cn.contains(q) && !tid.contains(q)) return false;
      }
      if (_selectedDateFilter != 'ALL') {
        final txDate = _parseDate(tx['created_at']);
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

  DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    try { return DateTime.parse(v.toString()).toLocal(); } catch (_) { return null; }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategory = 'ALL'; _selectedStatus = 'ALL'; _searchQuery = '';
      _selectedDateFilter = 'ALL'; _startDate = null; _endDate = null; _showFilters = false;
    });
    _applyFilters();
  }

  void _setDateFilter(String f) {
    if (f == 'CUSTOM') { _pickDateRange(); return; }
    setState(() => _selectedDateFilter = f);
    _applyFilters();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      firstDate: DateTime(2020), lastDate: DateTime.now(),
      builder: (c, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: Color(0xFF008169), surface: Color(0xFF1A1F1A), onSurface: Colors.white), dialogBackgroundColor: const Color(0xFF1A1F1A)), child: child!),
    );
    if (picked != null) { setState(() { _startDate = picked.start; _endDate = picked.end; _selectedDateFilter = 'CUSTOM'; }); _applyFilters(); }
  }

  String _getCategoryFromServiceType(String st) {
    if (st.isEmpty) return 'OTHER';
    final s = st.toUpperCase();
    if (s.contains('ELEC') || s.contains('POWER') || s.contains('KSEB') || s.contains('TNEB') || s.contains('BESCOM') || s.contains('EB')) return 'ELECTRICITY';
    if (s.contains('FASTAG') || s.contains('NETC') || s.contains('TOLL')) return 'FASTAG';
    if (s.contains('GAS') || s.contains('LPG') || s.contains('IGL') || s.contains('MGL')) return 'GAS';
    if (s.contains('WATER') || s.contains('KWA')) return 'WATER';
    if (s.contains('DTH') || s.contains('TATA') || s.contains('DISH') || s.contains('SUN')) return 'DTH';
    if (s.contains('INSUR') || s.contains('LIC')) return 'INSURANCE';
    if (s.contains('BROADBAND') || s.contains('WIFI') || s.contains('INTERNET')) return 'BROADBAND';
    if (s.contains('EDU') || s.contains('SCHOOL') || s.contains('COLLEGE')) return 'EDUCATION';
    return 'OTHER';
  }

  String _getServicePrefix(String st) {
    if (st.isEmpty) return 'Bill';
    final m = RegExp(r'^([A-Za-z]+)').firstMatch(st);
    if (m != null && m.group(1)!.length >= 2) return m.group(1)!;
    return st.length > 4 ? st.substring(0, 4) : st;
  }

  Color _getCatColor(String? c) => _categories[c ?? 'OTHER']?['color'] ?? Colors.grey;
  IconData _getCatIcon(String? c) => _categories[c ?? 'OTHER']?['icon'] ?? Iconsax.receipt_1;
  String _getCatLabel(String? c) => _categories[c ?? 'OTHER']?['label'] ?? 'Other';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0E0A),
      appBar: AppBar(
        title: Text('BBPS History', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
        centerTitle: true, backgroundColor: Color(0xFF0A0E0A), elevation: 0,
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
      child: Container(height: 44, decoration: BoxDecoration(color: Color(0xFF1A1F1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Color(0xFF2A342A))),
        child: TextField(
          onChanged: (v) { _searchQuery = v; _applyFilters(); },
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search by Consumer No, Txn ID...', hintStyle: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF6B7280)),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Color(0xFF1A1F1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Color(0xFF2A342A))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Date Range', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ...['ALL', 'TODAY', 'WEEK', 'MONTH'].map((key) => GestureDetector(
            onTap: () => _setDateFilter(key),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: _selectedDateFilter == key ? Color(0xFF008169).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedDateFilter == key ? Color(0xFF008169) : Color(0xFF2A342A))), child: Text(_dateFilters[key]!, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _selectedDateFilter == key ? Color(0xFF1AA88A) : Colors.white54))),
          )),
          GestureDetector(onTap: () => _setDateFilter('CUSTOM'), child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: _selectedDateFilter == 'CUSTOM' ? Color(0xFF008169).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _selectedDateFilter == 'CUSTOM' ? Color(0xFF008169) : Color(0xFF2A342A))), child: Text(_selectedDateFilter == 'CUSTOM' && _startDate != null ? '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}' : 'Custom', style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: _selectedDateFilter == 'CUSTOM' ? Color(0xFF1AA88A) : Colors.white54)))),
        ]),
        const SizedBox(height: 14),
        Text('Category', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: _categories.entries.where((e) => e.key != 'ALL').map((e) {
          final sel = _selectedCategory == e.key;
          return GestureDetector(onTap: () { setState(() => _selectedCategory = e.key); _applyFilters(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: sel ? (e.value['color'] as Color).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? (e.value['color'] as Color) : Color(0xFF2A342A))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(e.value['icon'], size: 13, color: sel ? e.value['color'] : Colors.white54), const SizedBox(width: 5), Text(e.value['label'], style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? e.value['color'] : Colors.white54))])));
        }).toList()),
        const SizedBox(height: 14),
        Text('Status', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: _statusFilters.entries.where((e) => e.key != 'ALL').map((e) {
          final sel = _selectedStatus == e.key;
          return GestureDetector(onTap: () { setState(() => _selectedStatus = e.key); _applyFilters(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: sel ? (e.value['color'] as Color).withOpacity(0.15) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? (e.value['color'] as Color) : Color(0xFF2A342A))), child: Text(e.value['label'], style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: sel ? (e.value['color'] as Color) : Colors.white54))));
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
    final p = <String>[];
    if (_selectedCategory != 'ALL') p.add(_categories[_selectedCategory]?['label'] ?? '');
    if (_selectedStatus != 'ALL') p.add(_statusFilters[_selectedStatus]?['label'] ?? '');
    if (_selectedDateFilter != 'ALL') p.add(_dateFilters[_selectedDateFilter] ?? '');
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: Row(children: [const Icon(Iconsax.filter, size: 12, color: Color(0xFF1AA88A)), const SizedBox(width: 6), Expanded(child: Text(p.where((x) => x.isNotEmpty).join(' • '), style: GoogleFonts.poppins(fontSize: 10, color: Color(0xFF1AA88A)), overflow: TextOverflow.ellipsis)), GestureDetector(onTap: _clearAllFilters, child: Text('Clear', style: GoogleFonts.poppins(fontSize: 10, color: Colors.white54)))]));
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF008169)));
    if (_filteredTransactions.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Iconsax.receipt_1, size: 56, color: Colors.white.withOpacity(0.15)), const SizedBox(height: 16), Text(_allTransactions.isEmpty ? 'No BBPS transactions yet' : 'No matching transactions', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white), textAlign: TextAlign.center), if (_hasActiveFilters) ...[const SizedBox(height: 8), TextButton(onPressed: _clearAllFilters, child: Text('Clear Filters', style: GoogleFonts.poppins(color: Color(0xFF1AA88A))))]])));
    return ListView.builder(controller: _scrollController, physics: const BouncingScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), itemCount: _filteredTransactions.length, itemBuilder: (_, i) => _buildCard(_filteredTransactions[i]));
  }

  Widget _buildCard(Map<String, dynamic> tx) {
    final st = tx['service_type'] ?? '';
    final cat = _getCategoryFromServiceType(st);
    final dl = _getServicePrefix(st);
    final cc = _getCatColor(cat);
    final ci = _getCatIcon(cat);
    final status = (tx['status'] ?? 'pending').toString().toLowerCase();
    final isS = status == 'success';
    final isF = status == 'failed';
    final sc = isS ? Color(0xFF10B981) : (isF ? Color(0xFFEF4444) : Color(0xFFF59E0B));
    final amt = tx['amount'] ?? '0';
    final cn = tx['consumer_number'] ?? 'N/A';
    final ptid = tx['provider_txn_id'] ?? '';
    final tid = ptid.isNotEmpty ? ptid : 'TX${tx['id'] ?? 'N/A'}';
    return GestureDetector(
      onTap: () => _showDetails(tx),
      child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Color(0xFF1A1F1A), borderRadius: BorderRadius.circular(14), border: Border.all(color: Color(0xFF2A342A))),
        child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: cc.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(ci, color: cc, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text(dl, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)), const SizedBox(width: 6), Expanded(child: Text(cn.toString(), style: GoogleFonts.poppins(fontSize: 10, color: cc), maxLines: 1, overflow: TextOverflow.ellipsis))]),
            const SizedBox(height: 3),
            Text(tid.toString(), style: GoogleFonts.poppins(fontSize: 10, color: Color(0xFF6B7280))),
            Text(_fmt(tx['created_at']), style: GoogleFonts.poppins(fontSize: 9, color: Color(0xFF6B7280))),
          ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹$amt', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)), child: Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600, color: sc))),
            if (isS) Padding(padding: const EdgeInsets.only(top: 6), child: GestureDetector(onTap: () => _downloadReceipt(tx), child: Icon(Iconsax.document_download, color: Color(0xFF1AA88A), size: 16))),
          ]),
        ]),
      ),
    );
  }

  void _showDetails(Map<String, dynamic> tx) {
    final st = tx['service_type'] ?? '';
    final cat = _getCategoryFromServiceType(st);
    final status = (tx['status'] ?? '').toString().toLowerCase();
    final isS = status == 'success';
    final isF = status == 'failed';
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (c) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(color: Color(0xFF1A1F1A), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Transaction Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 16),
          Flexible(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
            _dRow('Category', _getCatLabel(cat)),
            _dRow('Service Type', _getServicePrefix(st)),
            _dRow('Consumer No.', tx['consumer_number']?.toString() ?? 'N/A'),
            _dRow('Amount', '₹${tx['amount'] ?? '0'}'),
            _dRow('Status', status.toUpperCase(), vc: isS ? Color(0xFF10B981) : (isF ? Color(0xFFEF4444) : Color(0xFFF59E0B))),
            _dRow('Provider Txn ID', tx['provider_txn_id']?.toString() ?? 'N/A'),
            _dRow('Transaction ID', tx['id']?.toString() ?? 'N/A'),
            _dRow('Provider', tx['provider_name']?.toString() ?? 'N/A'),
            _dRow('Date', _fmtLong(tx['created_at'])),
            const SizedBox(height: 20),
          ]))),
          Padding(padding: const EdgeInsets.all(20), child: Row(children: [
            if (isS) ...[Expanded(child: ElevatedButton.icon(onPressed: () { Navigator.pop(context); _downloadReceipt(tx); }, icon: const Icon(Iconsax.document_download, size: 16), label: const Text('Download Receipt'), style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF008169), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))), const SizedBox(width: 12)],
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: BorderSide(color: Colors.white.withOpacity(0.2)), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Close'))),
          ])),
        ]),
      ),
    );
  }

  Widget _dRow(String l, String v, {Color? vc}) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(l, style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF9CA3AF)))), Expanded(child: Text(v, textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: vc ?? Colors.white)))]));

  void _downloadReceipt(Map<String, dynamic> tx) async {
    HapticFeedback.mediumImpact();
    try {
      final st = tx['service_type'] ?? '';
      final cat = _getCategoryFromServiceType(st);
      DateTime txDate;
      try { txDate = DateTime.parse((tx['created_at'] ?? DateTime.now().toString()).toString()).toLocal(); } catch (_) { txDate = DateTime.now(); }

      final model = BbpsReceiptModel(
        transactionId: (tx['id'] ?? 'N/A').toString(),
        providerTxnId: (tx['provider_txn_id'] ?? '').toString(),
        category: cat,
        serviceType: st.toString(),
        consumerNumber: (tx['consumer_number'] ?? 'N/A').toString(),
        amount: (tx['amount'] ?? '0').toString(),
        status: (tx['status'] ?? 'success').toString(),
        providerName: (tx['provider_name'] ?? 'N/A').toString(),
        transactionDate: txDate,
      );

      final file = await _generateBbpsPdf(model);
      if (mounted) {
        String dp = file.path.replaceAll('/storage/emulated/0/', 'Internal Storage/');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Iconsax.tick_circle, color: Color(0xFF10B981), size: 20), SizedBox(width: 8), Expanded(child: Text('Receipt saved!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)))]),
            const SizedBox(height: 6), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Iconsax.folder_2, color: Colors.white70, size: 14), const SizedBox(width: 8), Expanded(child: Text(dp, style: GoogleFonts.poppins(fontSize: 10, color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis))])),
          ]),
          backgroundColor: const Color(0xFF1A1F1A), behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), margin: const EdgeInsets.all(16), duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'OPEN', textColor: const Color(0xFF1AA88A), onPressed: () { try { OpenFile.open(file.path); } catch (_) {} }),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e', style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
    }
  }

  // ─── PDF Generation ───────────────────────────────────────
  Future<Directory> _getBbpsFolderPath() async {
    Directory? d;
    if (Platform.isAndroid) {
      for (final p in ['/storage/emulated/0/Documents/NEOFYN/BBPS', '/storage/emulated/0/Download/NEOFYN/BBPS']) {
        try { final dir = Directory(p); if (!await dir.exists()) await dir.create(recursive: true); return dir; } catch (_) {}
      }
      try { final ed = await getExternalStorageDirectory(); if (ed != null) { d = Directory('${ed.path}/NEOFYN/BBPS'); if (!await d!.exists()) await d.create(recursive: true); return d; } } catch (_) {}
    }
    final ad = await getApplicationDocumentsDirectory();
    d = Directory('${ad.path}/NEOFYN/BBPS');
    if (!await d!.exists()) await d.create(recursive: true);
    return d;
  }

  Future<File> _generateBbpsPdf(BbpsReceiptModel r) async {
    final pdf = pw.Document();
    PdfColor pc(Color c) => PdfColor.fromInt(c.value);
    final f = await PdfGoogleFonts.poppinsRegular();
    final fb = await PdfGoogleFonts.poppinsBold();

    // Load logo
    pw.ImageProvider? logo;
    try {
      final logoData = await rootBundle.load('assets/images/logo_white.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, margin: const pw.EdgeInsets.all(30), build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Header with Logo
      pw.Center(child: pw.Column(children: [
        if (logo != null) pw.Container(width: 60, height: 60, decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14))), padding: const pw.EdgeInsets.all(8), child: pw.Image(logo, fit: pw.BoxFit.contain))
        else pw.Container(width: 60, height: 60, decoration: pw.BoxDecoration(color: pc(const Color(0xFF008169)), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(14))), child: pw.Center(child: pw.Text('NB', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.white, font: fb)))),
        pw.SizedBox(height: 8),
        pw.Text('NEOFYN BHARATH', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, font: fb)),
        pw.SizedBox(height: 4),
        pw.Text(r.categoryLabel, style: pw.TextStyle(fontSize: 11, color: pc(const Color(0xFF1AA88A)), font: fb)),
        pw.SizedBox(height: 2),
        pw.Text('${r.formattedDateShort}  ${r.formattedTime}', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: f)),
      ])),
      pw.SizedBox(height: 16),
      // Status
      pw.Container(width: double.infinity, padding: const pw.EdgeInsets.all(12), decoration: pw.BoxDecoration(color: pc(const Color(0xFF10B981).withOpacity(0.08)), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)), border: pw.Border.all(color: pc(const Color(0xFF10B981).withOpacity(0.2)), width: 0.5)), child: pw.Row(children: [pw.Container(width: 30, height: 30, decoration: pw.BoxDecoration(color: pc(const Color(0xFF10B981)), shape: pw.BoxShape.circle), child: pw.Center(child: pw.Text('✓', style: pw.TextStyle(color: PdfColors.white, fontSize: 14, font: fb)))), pw.SizedBox(width: 10), pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text('Bill Payment Successful', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: fb)), pw.Text('Amount: ₹${r.amount}', style: pw.TextStyle(fontSize: 11, color: pc(const Color(0xFF10B981)), font: fb))]))])),
      pw.SizedBox(height: 16),
      // Details
      _pr(f, fb, 'Category', r.categoryLabel),
      _pr(f, fb, 'Service Type', r.serviceType),
      _pr(f, fb, 'Consumer Number', r.consumerNumber),
      _pr(f, fb, 'Amount', '₹${r.amount}', vc: pc(const Color(0xFF10B981))),
      _pr(f, fb, 'Provider Txn ID', r.providerTxnId.isNotEmpty ? r.providerTxnId : 'N/A'),
      _pr(f, fb, 'Transaction ID', r.transactionId),
      _pr(f, fb, 'Provider', r.providerName),
      _pr(f, fb, 'Date & Time', r.formattedDate),
      _pr(f, fb, 'Status', 'SUCCESS', vc: pc(const Color(0xFF10B981))),
      pw.SizedBox(height: 10),
      pw.Container(padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(color: pc(const Color(0xFF1AA88A).withOpacity(0.06)), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)), border: pw.Border.all(color: pc(const Color(0xFF1AA88A).withOpacity(0.15)), width: 0.5)), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Amount : ₹${r.amount}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: fb))])),
      pw.SizedBox(height: 20), pw.Divider(),
      pw.Center(child: pw.Text('© 2025 NEOFYN Bharath - All Rights Reserved', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500, font: f))),
      pw.SizedBox(height: 2),
      pw.Center(child: pw.Text('System generated receipt - No signature required', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500, font: f))),
    ])));

    final dir = await _getBbpsFolderPath();
    final file = File('${dir.path}/BBPS_Receipt_${r.transactionId}_${r.fileNameDate}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  pw.Widget _pr(pw.Font f, pw.Font fb, String l, String v, {PdfColor? vc}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.SizedBox(width: 110, child: pw.Text('$l :', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, font: f))), pw.Expanded(child: pw.Text(v, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: fb, color: vc ?? PdfColors.black)))]));

  String _fmt(dynamic d) { if (d == null) return ''; try { return DateFormat('dd MMM, HH:mm').format(DateTime.parse(d.toString()).toLocal()); } catch (_) { return ''; } }
  String _fmtLong(dynamic d) { if (d == null) return 'N/A'; try { return DateFormat('dd MMM yyyy, HH:mm:ss').format(DateTime.parse(d.toString()).toLocal()); } catch (_) { return d.toString(); } }
}