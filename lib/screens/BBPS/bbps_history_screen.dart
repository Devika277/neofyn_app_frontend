// lib/screens/history/bbps_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/BBPS/api_service.dart';

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

  String _selectedStatus = 'ALL';

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
      if (mounted) {
        setState(() { _allTransactions = list; _isLoading = false; });
        _applyFilters();
      }
    } catch (e) {
      debugPrint('BBPS History error: $e');
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isFetching = false;
    }
  }

  void _applyFilters() {
    final filtered = _allTransactions.where((tx) {
      // Category filter
      if (_selectedCategory != 'ALL') {
        final serviceType = (tx['service_type'] ?? '').toString();
        final cat = _getCategoryFromServiceType(serviceType);
        if (cat != _selectedCategory) return false;
      }

      // Status filter
      if (_selectedStatus != 'ALL') {
        final status = (tx['status'] ?? '').toString().toLowerCase();
        if (status != _selectedStatus) return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final consumerNo = (tx['consumer_number'] ?? '').toString().toLowerCase();
        final txnId = (tx['provider_txn_id'] ?? tx['id']?.toString() ?? '').toString().toLowerCase();
        final serviceType = (tx['service_type'] ?? '').toString().toLowerCase();
        if (!consumerNo.contains(q) && !txnId.contains(q) && !serviceType.contains(q)) return false;
      }

      // Date filter
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

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    try { return DateTime.parse(value.toString()).toLocal(); } catch (_) { return null; }
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategory = 'ALL'; _selectedStatus = 'ALL';
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

  // ─────────────────────────────────────────────────────────────
  //  SERVICE TYPE DETECTION
  // ─────────────────────────────────────────────────────────────
  String _getCategoryFromServiceType(String serviceType) {
    if (serviceType.isEmpty) return 'OTHER';
    final st = serviceType.toUpperCase();

    // Electricity
    if (st.contains('KSEB') || st.contains('ELEC') || st.contains('POWER') ||
        st.contains('TNEB') || st.contains('BESCOM') || st.contains('EB')) {
      return 'ELECTRICITY';
    }
    // Fastag
    if (st.contains('FASTAG') || st.contains('NETC') || st.contains('TOLL') ||
        st.contains('NATXM')) {
      return 'FASTAG';
    }
    // Gas
    if (st.contains('GAS') || st.contains('LPG') || st.contains('IGL') ||
        st.contains('MGL')) {
      return 'GAS';
    }
    // Water
    if (st.contains('WATER') || st.contains('KWA')) {
      return 'WATER';
    }
    // DTH
    if (st.contains('DTH') || st.contains('TATA') || st.contains('DISH') ||
        st.contains('SUN') || st.contains('TV')) {
      return 'DTH';
    }
    // Insurance
    if (st.contains('INSUR') || st.contains('LIC')) {
      return 'INSURANCE';
    }
    // Broadband
    if (st.contains('BROADBAND') || st.contains('WIFI') || st.contains('INTERNET') ||
        st.contains('BBPS')) {
      return 'BROADBAND';
    }
    // Education
    if (st.contains('EDU') || st.contains('SCHOOL') || st.contains('COLLEGE')) {
      return 'EDUCATION';
    }
    return 'OTHER';
  }

  // Get prefix from service type for display (e.g., "KSEBL" from "KSEBL0000KER01")
  String _getServicePrefix(String serviceType) {
    if (serviceType.isEmpty) return 'Bill';
    // Extract letters before any digits
    final match = RegExp(r'^([A-Za-z]+)').firstMatch(serviceType);
    if (match != null && match.group(1)!.length >= 2) {
      return match.group(1)!;
    }
    return serviceType.length > 4 ? serviceType.substring(0, 4) : serviceType;
  }

  Color _getCategoryColor(String? category) {
    return _categories[category ?? 'OTHER']?['color'] ?? Colors.grey;
  }

  IconData _getCategoryIcon(String? category) {
    return _categories[category ?? 'OTHER']?['icon'] ?? Iconsax.receipt_1;
  }

  String _getCategoryLabel(String? category) {
    return _categories[category ?? 'OTHER']?['label'] ?? 'Other';
  }

  // ─────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0E0A),
      appBar: AppBar(
        title: Text('BBPS History', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: Colors.white)),
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
            hintText: 'Search by Consumer No, Txn ID...',
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
        Text('Category', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white54)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: _categories.entries.where((e) => e.key != 'ALL').map((e) {
          final isSelected = _selectedCategory == e.key;
          return GestureDetector(
            onTap: () { setState(() => _selectedCategory = e.key); _applyFilters(); },
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
    if (_selectedCategory != 'ALL') parts.add(_categories[_selectedCategory]?['label'] ?? '');
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
        Icon(Iconsax.receipt_1, size: 56, color: Colors.white.withOpacity(0.15)),
        const SizedBox(height: 16),
        Text(_allTransactions.isEmpty ? 'No BBPS transactions yet' : 'No matching transactions', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white), textAlign: TextAlign.center),
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

  // ─────────────────────────────────────────────────────────────
  //  TRANSACTION CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildCard(Map<String, dynamic> tx) {
    final serviceType = tx['service_type'] ?? '';
    final category = _getCategoryFromServiceType(serviceType);

    // Show service prefix (KSEBL, THEF, etc.) or category label
    final displayLabel = _getServicePrefix(serviceType);
    final catColor = _getCategoryColor(category);
    final catIcon = _getCategoryIcon(category);

    final status = (tx['status'] ?? 'pending').toString().toLowerCase();
    final isSuccess = status == 'success';
    final isFailed = status == 'failed';

    final Color sc = isSuccess ? Color(0xFF10B981) : (isFailed ? Color(0xFFEF4444) : Color(0xFFF59E0B));

    final amount = tx['amount'] ?? '0';
    final consumerNumber = tx['consumer_number'] ?? 'N/A';
    final providerTxnId = tx['provider_txn_id'] ?? '';
    final txnId = providerTxnId.isNotEmpty ? providerTxnId : 'TX${tx['id'] ?? 'N/A'}';
    final date = tx['created_at'];

    return GestureDetector(
      onTap: () => _showDetails(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF1A1F1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Color(0xFF2A342A)),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: catColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(catIcon, color: catColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(displayLabel, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(width: 6),
                Expanded(child: Text(consumerNumber.toString(), style: GoogleFonts.poppins(fontSize: 10, color: catColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 3),
              Text(txnId.toString(), style: GoogleFonts.poppins(fontSize: 10, color: Color(0xFF6B7280)), overflow: TextOverflow.ellipsis),
              Text(_fmt(date), style: GoogleFonts.poppins(fontSize: 9, color: Color(0xFF6B7280))),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹$amount', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w600, color: sc)),
            ),
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

  // ─────────────────────────────────────────────────────────────
  //  DETAILS BOTTOM SHEET
  // ─────────────────────────────────────────────────────────────
  void _showDetails(Map<String, dynamic> tx) {
    final serviceType = tx['service_type'] ?? '';
    final category = _getCategoryFromServiceType(serviceType);
    final catLabel = _getCategoryLabel(category);
    final status = (tx['status'] ?? '').toString().toLowerCase();
    final isSuccess = status == 'success';
    final isFailed = status == 'failed';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F1A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Transaction Details', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                _detailRow('Category', catLabel),
                _detailRow('Service Type', _getServicePrefix(serviceType)),
                _detailRow('Service Code', serviceType.toString()),
                _detailRow('Consumer No.', tx['consumer_number']?.toString() ?? 'N/A'),
                _detailRow('Amount', '₹${tx['amount'] ?? '0'}'),
                _detailRow('Status', status.toUpperCase(),
                    valueColor: isSuccess ? Color(0xFF10B981) : (isFailed ? Color(0xFFEF4444) : Color(0xFFF59E0B))),
                _detailRow('Provider Txn ID', tx['provider_txn_id']?.toString() ?? 'N/A'),
                _detailRow('Transaction ID', tx['id']?.toString() ?? 'N/A'),
                _detailRow('Provider', tx['provider_name']?.toString() ?? 'N/A'),
                _detailRow('Date', _fmtLong(tx['created_at'])),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF008169),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
        SizedBox(width: 110, child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Color(0xFF9CA3AF)))),
        Expanded(child: Text(value, textAlign: TextAlign.right, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: valueColor ?? Colors.white))),
      ]),
    );
  }

  void _downloadReceipt(Map<String, dynamic> tx) {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Receipt downloaded for ${_getServicePrefix(tx['service_type'] ?? '')} bill', style: GoogleFonts.poppins(color: Colors.white, fontSize: 12))),
        ]),
        backgroundColor: Color(0xFF008169),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
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