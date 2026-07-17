// screens/commission/commission_history_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/bbps/api_service.dart';
import '../../services/commission/commission_service.dart';
import 'transfer_commission_dialog.dart';
import '../../providers/wallet_provider.dart';

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

class CommissionHistoryScreen extends StatefulWidget {
  const CommissionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CommissionHistoryScreen> createState() => _CommissionHistoryScreenState();
}

class _CommissionHistoryScreenState extends State<CommissionHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  String? _error;

  String _searchQuery = '';
  bool _showFilters = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedDateFilter = 'ALL';
  String _selectedType = 'ALL';

  double _commissionBalance = 0.0;
  double _minTransferAmount = 100.0;

  final Map<String, String> _dateFilters = {
    'ALL': 'All Time',
    'TODAY': 'Today',
    'WEEK': 'This Week',
    'MONTH': 'This Month',
    'CUSTOM': 'Custom',
  };

  // ✅ Map the 'type' field values (renamed from service_type by CommissionService)
  static const Map<String, Map<String, dynamic>> _serviceTypeMap = {
    'dmt_smart': {'label': 'DMT Smart', 'color': Color(0xFF3B82F6), 'icon': Iconsax.money_send},
    'dmt': {'label': 'DMT', 'color': Color(0xFF6366F1), 'icon': Iconsax.money_send},
    'aeps': {'label': 'AEPS', 'color': Color(0xFFF59E0B), 'icon': Iconsax.card},
    'mobile': {'label': 'Mobile Recharge', 'color': Color(0xFF10B981), 'icon': Iconsax.mobile},
    'transfer_to_main': {'label': 'Wallet Transfer', 'color': Color(0xFF8B5CF6), 'icon': Iconsax.convert},
    'test': {'label': 'Test', 'color': Color(0xFF6B7280), 'icon': Iconsax.info_circle},
  };

  Map<String, Map<String, dynamic>> get _typeFilters {
    final filters = <String, Map<String, dynamic>>{
      'ALL': {'label': 'All Services', 'color': AppColors.textDarkSecondary, 'icon': Iconsax.wallet_money},
    };
    filters.addAll(_serviceTypeMap);
    return filters;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchHistory(refresh: true);
        _fetchCommissionBalance();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _fetchHistory();
      }
    }
  }

  bool get _hasActiveFilters =>
      _selectedType != 'ALL' || _searchQuery.isNotEmpty || _selectedDateFilter != 'ALL';

  Future<void> _fetchCommissionBalance() async {
    try {
      final response = await CommissionService.getBalance();
      if (response['success'] == true) {
        final data = response['data'];
        if (mounted) {
          setState(() {
            _commissionBalance = (data['balance'] as num?)?.toDouble() ?? 0.0;
          });
        }
      }
      _minTransferAmount = await CommissionService.getMinTransferAmount();
    } catch (e) {
      debugPrint('❌ Failed to fetch balance: $e');
      _minTransferAmount = 100.0;
    }
  }

  Future<void> _fetchHistory({bool refresh = false}) async {
    if (_isLoadingMore) return;

    if (refresh) {
      setState(() {
        _allTransactions.clear();
        _filteredTransactions.clear();
        _page = 1;
        _hasMore = true;
        _error = null;
      });
    }

    setState(() {
      if (_page == 1) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final response = await CommissionService.getHistory(
        page: _page,
        limit: 20,
        status: null,
      );

      if (response['success'] == true) {
        final List<dynamic> rawItems = response['data'] ?? [];

        // ✅ CommissionService already maps fields:
        // 'type' (from service_type), 'amount' (from txn_amount),
        // 'description' (from transaction_ref), 'reference_id' (from transaction_ref)
        final List<Map<String, dynamic>> items = rawItems.map((item) {
          return Map<String, dynamic>.from(item as Map);
        }).toList();

        // Remove duplicates
        final seenIds = <int>{};
        final uniqueItems = <Map<String, dynamic>>[];
        for (final item in items) {
          final id = (item['id'] as num?)?.toInt() ?? 0;
          if (!seenIds.contains(id)) {
            seenIds.add(id);
            uniqueItems.add(item);
          }
        }

        debugPrint('✅ Added ${uniqueItems.length} items');

        if (mounted) {
          setState(() {
            _allTransactions.addAll(uniqueItems);
            _hasMore = rawItems.length == 20;
            _page++;
            _error = null;
          });
          _applyFilters();
        }
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        setState(() {
          if (e is ApiException) {
            _error = e.message;
            if (e.statusCode == 401) _showLoginRequiredDialog();
          } else {
            _error = e.toString();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  // ✅ Read 'type' field (not service_type)
  String _getType(Map<String, dynamic> tx) => tx['type']?.toString() ?? 'unknown';

  double _getAmount(Map<String, dynamic> tx) => (tx['amount'] as num?)?.toDouble() ?? 0.0;
  double _getCommissionAmount(Map<String, dynamic> tx) => (tx['commission_amount'] as num?)?.toDouble() ?? 0.0;
  double _getCommissionRate(Map<String, dynamic> tx) => (tx['commission_rate'] as num?)?.toDouble() ?? 0.0;
  String _getDescription(Map<String, dynamic> tx) => tx['description']?.toString() ?? '';
  String _getReferenceId(Map<String, dynamic> tx) => tx['reference_id']?.toString() ?? '';
  double _getBalanceAfter(Map<String, dynamic> tx) => (tx['balance_after'] as num?)?.toDouble() ?? 0.0;

  String _getServiceLabel(String type) {
    if (type.isEmpty || type == 'unknown') return 'Commission';
    return _serviceTypeMap[type]?['label'] ?? type.replaceAll('_', ' ').toUpperCase();
  }

  Color _getServiceColor(String type) {
    return _serviceTypeMap[type]?['color'] as Color? ?? AppColors.success;
  }

  IconData _getServiceIcon(String type) {
    return _serviceTypeMap[type]?['icon'] as IconData? ?? Iconsax.wallet_money;
  }

  void _applyFilters() {
    final filtered = _allTransactions.where((tx) {
      // ✅ Filter by 'type' field
      if (_selectedType != 'ALL') {
        final t = _getType(tx);
        if (t != _selectedType) return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final sl = _getServiceLabel(_getType(tx)).toLowerCase();
        final fields = [
          tx['id']?.toString(),
          _getReferenceId(tx),
          _getDescription(tx),
          sl,
          tx['status']?.toString(),
          _getCommissionAmount(tx).toString(),
          _getAmount(tx).toString(),
        ];
        if (!fields.any((f) => f.toString().toLowerCase().contains(q))) return false;
      }

      if (_selectedDateFilter != 'ALL') {
        final d = _parseDate(tx['created_at']);
        if (d == null) return false;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        switch (_selectedDateFilter) {
          case 'TODAY': if (d.isBefore(today)) return false; break;
          case 'WEEK': if (d.isBefore(today.subtract(Duration(days: now.weekday - 1)))) return false; break;
          case 'MONTH': if (d.isBefore(DateTime(now.year, now.month, 1))) return false; break;
          case 'CUSTOM':
            if (_startDate != null && d.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) return false;
            if (_endDate != null && d.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) return false;
            break;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final da = _parseDate(a['created_at']) ?? DateTime(2000);
      final db = _parseDate(b['created_at']) ?? DateTime(2000);
      return db.compareTo(da);
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
      _selectedType = 'ALL';
      _searchQuery = '';
      _selectedDateFilter = 'ALL';
      _startDate = null;
      _endDate = null;
      _showFilters = false;
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

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkSurface,
        title: Text('Session Expired', style: GoogleFonts.poppins(color: AppColors.textWhite)),
        content: Text('Your session has expired.', style: GoogleFonts.poppins(color: AppColors.textDarkSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              ApiService.clearToken();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: Text('Login', style: GoogleFonts.poppins(color: AppColors.primaryLight)),
          ),
        ],
      ),
    );
  }

  void _showTransferDialog() {
    if (_commissionBalance < _minTransferAmount) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Min transfer: ₹${_minTransferAmount.toStringAsFixed(0)}. Balance: ₹${_commissionBalance.toStringAsFixed(2)}'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TransferCommissionDialog(availableBalance: _commissionBalance, minTransferAmount: _minTransferAmount),
    ).then((result) {
      if (result == true) {
        _fetchCommissionBalance();
        _fetchHistory(refresh: true);
        try {
          final wp = Provider.of<WalletProvider>(context, listen: false);
          wp.fetchAllWalletData();
          wp.fetchCommissionBalance();
        } catch (e) {}
      }
    });
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$label copied'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 1),
    ));
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today ${DateFormat('hh:mm a').format(date)}';
    if (diff.inDays == 1) return 'Yesterday ${DateFormat('hh:mm a').format(date)}';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM, hh:mm a').format(date);
  }

  String _truncateRef(String ref) {
    if (ref.length <= 24) return ref;
    return '${ref.substring(0, 21)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: Text('Commission History',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18, color: AppColors.textWhite)),
        centerTitle: true,
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(icon: const Icon(Iconsax.arrow_left, color: AppColors.textWhite), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_commissionBalance >= _minTransferAmount)
            IconButton(icon: const Icon(Iconsax.convert, color: AppColors.primaryLight, size: 20),
                onPressed: _showTransferDialog, tooltip: 'Transfer'),
          IconButton(
            icon: Icon(_showFilters ? Iconsax.filter_edit : Iconsax.filter,
                color: _showFilters ? AppColors.primaryLight : AppColors.textDarkSecondary, size: 20),
            onPressed: () => setState(() => _showFilters = !_showFilters),
          ),
          IconButton(icon: const Icon(Iconsax.refresh, color: AppColors.textDarkSecondary, size: 20),
              onPressed: () => _fetchHistory(refresh: true)),
        ],
      ),
      body: Column(children: [
        _buildBalanceHeader(),
        _buildSearchBar(),
        if (_showFilters) _buildFilterSection(),
        if (_hasActiveFilters) _buildActiveFiltersBar(),
        Expanded(child: _buildContent()),
      ]),
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Available Commission', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('₹${_commissionBalance.toStringAsFixed(2)}',
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          if (_commissionBalance > 0)
            Text('Min transfer: ₹${_minTransferAmount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10)),
        ]),
        if (_commissionBalance >= _minTransferAmount)
          ElevatedButton.icon(
            onPressed: _showTransferDialog,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
            icon: const Icon(Iconsax.convert, size: 16),
            label: Text('Transfer', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12)),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
            child: Text(_commissionBalance > 0 ? 'Min ₹${_minTransferAmount.toStringAsFixed(0)}' : 'No balance',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          ),
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
            hintText: 'Search by service, ref ID, amount...',
            hintStyle: GoogleFonts.poppins(fontSize: 12, color: AppColors.textDarkHint),
            prefixIcon: const Icon(Iconsax.search_normal, size: 16, color: Color(0xFF6B7280)),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(onTap: () { setState(() => _searchQuery = ''); _applyFilters(); },
                child: const Icon(Icons.close, size: 16, color: Color(0xFF6B7280)))
                : null,
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
            final sel = _selectedDateFilter == key;
            return GestureDetector(
              onTap: () => _setDateFilter(key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.borderDark),
                ),
                child: Text(_dateFilters[key]!, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600,
                    color: sel ? AppColors.primaryLight : AppColors.textDarkSecondary)),
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
                style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600,
                    color: _selectedDateFilter == 'CUSTOM' ? AppColors.primaryLight : AppColors.textDarkSecondary),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        Text('Service Type', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDarkSecondary)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: _typeFilters.entries.map((e) {
          final sel = _selectedType == e.key;
          final color = e.value['color'] as Color;
          return GestureDetector(
            onTap: () { setState(() => _selectedType = e.key); _applyFilters(); },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: sel ? color : AppColors.borderDark),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(e.value['icon'] as IconData, size: 12, color: sel ? color : AppColors.textDarkSecondary),
                const SizedBox(width: 4),
                Text(e.value['label'] as String, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600,
                    color: sel ? color : AppColors.textDarkSecondary)),
              ]),
            ),
          );
        }).toList()),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(onTap: _clearAllFilters, child: Row(children: [
            const Icon(Iconsax.close_circle, size: 14, color: AppColors.error),
            const SizedBox(width: 4),
            Text('Clear All', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.error)),
          ])),
          Text('${_filteredTransactions.length} results', style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textDarkHint)),
        ]),
      ]),
    );
  }

  Widget _buildActiveFiltersBar() {
    final parts = <String>[];
    if (_selectedType != 'ALL') parts.add(_typeFilters[_selectedType]?['label'] ?? '');
    if (_selectedDateFilter != 'ALL') parts.add(_dateFilters[_selectedDateFilter] ?? '');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(children: [
        const Icon(Iconsax.filter, size: 12, color: AppColors.primaryLight),
        const SizedBox(width: 6),
        Expanded(child: Text(parts.where((p) => p.isNotEmpty).join(' • '),
            style: GoogleFonts.poppins(fontSize: 10, color: AppColors.primaryLight), overflow: TextOverflow.ellipsis)),
        GestureDetector(onTap: _clearAllFilters,
            child: Text('Clear', style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkSecondary))),
      ]),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _allTransactions.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null && _allTransactions.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(_error!.contains('login') ? Iconsax.lock : Iconsax.warning_2, size: 56,
            color: _error!.contains('login') ? AppColors.warning : AppColors.textDarkHint.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text(_error!, style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textDarkSecondary, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: () => _fetchHistory(refresh: true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(_error!.contains('login') ? 'Go to Login' : 'Retry')),
      ])));
    }
    if (_filteredTransactions.isEmpty && !_isLoading) {
      return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Iconsax.receipt_1, size: 56, color: AppColors.textDarkHint.withOpacity(0.3)),
        const SizedBox(height: 16),
        Text(_allTransactions.isEmpty ? 'No commission transactions yet' : 'No matching transactions',
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textWhite), textAlign: TextAlign.center),
        if (_hasActiveFilters) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: _clearAllFilters, child: Text('Clear Filters', style: GoogleFonts.poppins(color: AppColors.primaryLight))),
        ],
      ])));
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchHistory(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: _filteredTransactions.length + (_hasMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _filteredTransactions.length) {
            return const Padding(padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))));
          }
          return _buildCard(_filteredTransactions[i]);
        },
      ),
    );
  }

  // ✅ BUILD CARD - reads 'type', 'amount', 'description', 'reference_id' from service
  Widget _buildCard(Map<String, dynamic> tx) {
    final type = _getType(tx);                          // 'type' field (was service_type)
    final amount = _getAmount(tx);                       // 'amount' field (was txn_amount)
    final commissionAmount = _getCommissionAmount(tx);   // 'commission_amount'
    final commissionRate = _getCommissionRate(tx);       // 'commission_rate'
    final description = _getDescription(tx);             // 'description' (was transaction_ref)
    final referenceId = _getReferenceId(tx);             // 'reference_id'
    final status = tx['status']?.toString() ?? 'credited';
    final createdAtStr = tx['created_at']?.toString();
    final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();

    final serviceLabel = _getServiceLabel(type);
    final serviceColor = _getServiceColor(type);
    final serviceIcon = _getServiceIcon(type);

    return GestureDetector(
      onTap: () => _showDetail(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.darkSurface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.borderDark)),
        child: Column(children: [
          Row(children: [
            Container(width: 42, height: 42,
                decoration: BoxDecoration(color: serviceColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(serviceIcon, color: serviceColor, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(serviceLabel,
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textWhite),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(amount > 0 ? 'Txn: ₹${amount.toStringAsFixed(2)}' : (description.isNotEmpty ? description : 'Commission earned'),
                  style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkHint),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(child: Text(
                    referenceId.isNotEmpty ? 'Ref: ${_truncateRef(referenceId)}' : 'ID: #${tx['id']}',
                    style: GoogleFonts.poppins(fontSize: 10, color: AppColors.textDarkHint), maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (referenceId.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  GestureDetector(onTap: () => _copyToClipboard(referenceId, 'Reference ID'),
                      child: Icon(Iconsax.copy, size: 10, color: AppColors.textDarkHint)),
                ],
              ]),
            ])),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('+ ₹${commissionAmount.toStringAsFixed(2)}',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('EARNED', style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w600, color: AppColors.success)),
              ),
            ]),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Iconsax.calendar, size: 10, color: AppColors.textDarkHint),
            const SizedBox(width: 4),
            Text(_formatDate(createdAt), style: GoogleFonts.poppins(fontSize: 9, color: AppColors.textDarkHint)),
            if (commissionRate > 0) ...[
              const SizedBox(width: 12),
              Container(width: 3, height: 3, decoration: BoxDecoration(color: AppColors.textDarkHint, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Text('Rate: ${commissionRate}%', style: GoogleFonts.poppins(fontSize: 9, color: AppColors.primaryLight)),
            ],
            const Spacer(),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(status.toUpperCase(), style: GoogleFonts.poppins(fontSize: 7, fontWeight: FontWeight.w600, color: AppColors.success))),
            const SizedBox(width: 4),
            Icon(Iconsax.arrow_right_3, size: 12, color: AppColors.textDarkHint),
          ]),
        ]),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> tx) {
    final type = _getType(tx);
    final amount = _getAmount(tx);
    final commissionAmount = _getCommissionAmount(tx);
    final commissionRate = _getCommissionRate(tx);
    final description = _getDescription(tx);
    final referenceId = _getReferenceId(tx);
    final balanceAfter = _getBalanceAfter(tx);
    final status = tx['status']?.toString() ?? 'credited';
    final createdAtStr = tx['created_at']?.toString();
    final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
    final updatedAtStr = tx['updated_at']?.toString();
    final updatedAt = updatedAtStr != null ? DateTime.parse(updatedAtStr) : null;

    final serviceLabel = _getServiceLabel(type);
    final serviceColor = _getServiceColor(type);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkSurface,
      isScrollControlled: true, // ✅ Allow bottom sheet to take more height
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7, // ✅ 70% of screen height
        maxChildSize: 0.9,     // ✅ Can expand to 90%
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView( // ✅ Make it scrollable
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textDarkHint.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: serviceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getServiceIcon(type), color: serviceColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceLabel,
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textWhite)),
                      Text(_formatDate(createdAt),
                          style: GoogleFonts.poppins(
                              color: AppColors.textDarkSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Text('+ ₹${commissionAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(
                        fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success)),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.darkBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // _detailRow('Transaction ID', '#${tx['id']}', AppColors.textDarkSecondary),
                    // const SizedBox(height: 12),
                    _detailRow('Service', serviceLabel, serviceColor),
                    const SizedBox(height: 12),
                    _detailRow('Status', status.toUpperCase(), AppColors.success),
                    const SizedBox(height: 12),
                    _detailRow('Commission', '₹${commissionAmount.toStringAsFixed(2)}', AppColors.success),
                    if (amount > 0) ...[
                      const SizedBox(height: 12),
                      _detailRow('Txn Amount', '₹${amount.toStringAsFixed(2)}', AppColors.textDarkSecondary),
                    ],
                    if (commissionRate > 0) ...[
                      const SizedBox(height: 12),
                      _detailRow('Commission Rate', '${commissionRate}%', AppColors.textDarkSecondary),
                    ],
                    // if (description.isNotEmpty) ...[
                    //   const SizedBox(height: 12),
                    //   _detailRow('Description', description, AppColors.textDarkSecondary),
                    // ],
                    if (referenceId.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _detailRow('Reference ID', referenceId, AppColors.textDarkSecondary),
                    ],
                    if (balanceAfter > 0) ...[
                      const SizedBox(height: 12),
                      _detailRow('Balance After', '₹${balanceAfter.toStringAsFixed(2)}', AppColors.textDarkSecondary),
                    ],
                    const SizedBox(height: 12),
                    _detailRow('Created', _formatDate(createdAt), AppColors.textDarkSecondary),
                    if (updatedAt != null) ...[
                      const SizedBox(height: 12),
                      _detailRow('Updated', _formatDate(updatedAt), AppColors.textDarkSecondary),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 110, child: Text(label,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: AppColors.textDarkHint, fontSize: 13))),
      Expanded(child: Text(value, style: GoogleFonts.poppins(fontSize: 13, color: color, fontWeight: FontWeight.w500))),
    ]);
  }
}