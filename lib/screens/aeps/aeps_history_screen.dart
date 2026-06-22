// lib/screens/aeps/aeps_history_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/AEPS/api_service.dart';
import '../receipt_screen.dart';
import '../../models/receipt_model.dart';

class AepsHistoryScreen extends StatefulWidget {
  const AepsHistoryScreen({Key? key}) : super(key: key);

  @override
  State<AepsHistoryScreen> createState() => _AepsHistoryScreenState();
}

class _AepsHistoryScreenState extends State<AepsHistoryScreen> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _filtered = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;

  int _offset = 0;
  static const int _limit = 20;

  // Store raw responses for debugging
  dynamic _lastRawResponse;
  dynamic _lastRawMoreResponse;

  // Filters
  String _selectedStatus = 'ALL';
  String _selectedType = 'ALL';
  String _searchQuery = '';
  bool _showFilters = false;

  final List<String> _statusFilters = ['ALL', 'SUCCESS', 'FAILED', 'PENDING'];
  final Map<String, String> _typeFilters = {
    'ALL': 'All Types',
    'CW': 'Cash Withdrawal',
    'BE': 'Balance Enquiry',
    'MS': 'Mini Statement',
    'CD': 'Cash Deposit',
    'AP': 'Aadhaar Pay',
  };

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  // ─── Print Full Response to Console ──────────────────
  void _printFullResponse(dynamic response, {String tag = 'API Response'}) {
    debugPrint('═══════════════════════════════════════');
    debugPrint('📋 $tag - Full Response:');
    debugPrint('═══════════════════════════════════════');
    debugPrint('📊 Response Type: ${response.runtimeType}');

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    try {
      final prettyString = encoder.convert(response);
      debugPrint(prettyString);
    } catch (e) {
      debugPrint('Could not format as JSON: $e');
      debugPrint(response.toString());
    }

    debugPrint('═══════════════════════════════════════');
  }

  // ─── Load History ─────────────────────────────────────
  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _offset = 0;
      _hasMore = true;
      _transactions.clear();
    });
    try {
      final response = await _apiService.getAepsHistory(
        limit: _limit,
        offset: 0,
        status: _selectedStatus != 'ALL' ? _selectedStatus : null,
        type: _selectedType != 'ALL' ? _selectedType : null,
      );

      // STORE RAW RESPONSE
      _lastRawResponse = response;

      // PRINT FULL RESPONSE TO CONSOLE
      _printFullResponse(response, tag: 'Load History Response');

      // Handle different response formats
      final list = _parseResponseToList(response);

      setState(() {
        _transactions = list;
        _offset = list.length;
        _hasMore = list.length == _limit;
        _loading = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('AEPS history load error: $e');
      setState(() => _loading = false);

      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading transactions: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // ─── Load More ────────────────────────────────────────
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final response = await _apiService.getAepsHistory(limit: _limit, offset: _offset);

      // STORE RAW MORE RESPONSE
      _lastRawMoreResponse = response;

      // PRINT FULL RESPONSE TO CONSOLE
      _printFullResponse(response, tag: 'Load More Response');

      // Handle different response formats
      final list = _parseResponseToList(response);

      setState(() {
        _transactions.addAll(list);
        _offset += list.length;
        _hasMore = list.length == _limit;
        _loadingMore = false;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Load more error: $e');
      setState(() => _loadingMore = false);
    }
  }

  // ─── Parse Response to List (Handles multiple formats) ─
  List<Map<String, dynamic>> _parseResponseToList(dynamic response) {
    // Case 1: response is already a List
    if (response is List) {
      debugPrint('✅ Response is a List with ${response.length} items');
      return response.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        } else {
          return <String, dynamic>{'value': item};
        }
      }).toList();
    }

    // Case 2: response is a Map
    if (response is Map<String, dynamic>) {
      // Check success field
      if (response["success"] != true && response["status"] != "success") {
        debugPrint('⚠️ Response indicates failure: ${response["message"] ?? "Unknown error"}');
        // Still try to extract data if present
      }

      // Try different data paths
      final data = response["data"];
      if (data is List) {
        debugPrint('✅ Found data as List in response Map with ${data.length} items');
        return data.cast<Map<String, dynamic>>();
      }
      if (data is Map && data["transactions"] is List) {
        debugPrint('✅ Found data.transactions as List with ${(data["transactions"] as List).length} items');
        return (data["transactions"] as List).cast<Map<String, dynamic>>();
      }
      if (response["transactions"] is List) {
        debugPrint('✅ Found transactions as List with ${(response["transactions"] as List).length} items');
        return (response["transactions"] as List).cast<Map<String, dynamic>>();
      }

      // If no list found, return empty
      debugPrint('⚠️ No list data found in Map response');
      return [];
    }

    // Case 3: Unknown format
    debugPrint('❌ Unknown response format: ${response.runtimeType}');
    return [];
  }

  // Keep old method for backward compatibility
  List<Map<String, dynamic>> _parseList(Map<String, dynamic> response) {
    return _parseResponseToList(response);
  }

  // ─── Apply Filters ────────────────────────────────────
  void _applyFilters() {
    setState(() {
      _filtered = _transactions.where((tx) {
        final status = (tx['status'] ?? tx['npci_code'] ?? '').toString().toUpperCase();
        final type = (tx['transactionType'] ?? tx['txn_type'] ?? '').toString().toUpperCase();
        final query = _searchQuery.toLowerCase();

        final statusMatch = _selectedStatus == 'ALL' || status == _selectedStatus;
        final typeMatch = _selectedType == 'ALL' || type == _selectedType;
        final searchMatch = query.isEmpty ||
            (tx['txnRefId'] ?? tx['merchantRefId'] ?? tx['rrn'] ?? '').toString().toLowerCase().contains(query) ||
            (tx['rrn'] ?? '').toString().toLowerCase().contains(query) ||
            (tx['bankName'] ?? tx['bank_name'] ?? '').toString().toLowerCase().contains(query) ||
            (tx['merchantRefId'] ?? '').toString().toLowerCase().contains(query) ||
            (tx['aadhaarNo'] ?? tx['aadhaar_last4'] ?? '').toString().toLowerCase().contains(query);

        return statusMatch && typeMatch && searchMatch;
      }).toList();
    });
  }

  // ─── Clear Filters ────────────────────────────────────
  void _clearFilters() {
    setState(() {
      _selectedStatus = 'ALL';
      _selectedType = 'ALL';
      _searchQuery = '';
      _showFilters = false;
    });
    _applyFilters();
  }

  // ─── Active Filters Check ─────────────────────────────
  bool get _hasActiveFilters =>
      _selectedStatus != 'ALL' || _selectedType != 'ALL' || _searchQuery.isNotEmpty;

  // ─── Build ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        title: const Text('Transaction History',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: const Color(0xFF0A0E0A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showFilters ? Icons.filter_list_off : Icons.filter_list,
                color: _showFilters ? const Color(0xFF2ECC71) : Colors.white70),
            onPressed: () => setState(() => _showFilters = !_showFilters),
            tooltip: 'Filters',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
          // Button to show full response in UI
          IconButton(
            icon: const Icon(Icons.bug_report_outlined, color: Colors.white70),
            onPressed: _showFullResponseInDialog,
            tooltip: 'View Full Response',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Filters (collapsible)
          if (_showFilters) _buildFilterSection(),

          // Active filters indicator
          if (_hasActiveFilters) _buildActiveFiltersBar(),

          // Content
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ─── Search Bar ───────────────────────────────────────
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: (v) {
          _searchQuery = v;
          _applyFilters();
        },
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search by Ref ID, RRN, Bank...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5), size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear_rounded, color: Colors.white54, size: 18),
            onPressed: () {
              _searchQuery = '';
              _applyFilters();
            },
          )
              : null,
          filled: true,
          fillColor: const Color(0xFF1A1F1A),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ─── Filter Section ───────────────────────────────────
  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Chips
          const Text('Status', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _statusFilters.map((status) {
              final isSelected = _selectedStatus == status;
              Color chipColor;
              switch (status) {
                case 'SUCCESS': chipColor = const Color(0xFF2ECC71); break;
                case 'FAILED': chipColor = const Color(0xFFEF4444); break;
                case 'PENDING': chipColor = const Color(0xFFF59E0B); break;
                default: chipColor = Colors.grey;
              }
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedStatus = status);
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? chipColor.withOpacity(0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? chipColor : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: isSelected ? chipColor : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Type Chips
          const Text('Type', style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: _typeFilters.entries.map((entry) {
              final isSelected = _selectedType == entry.key;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedType = entry.key);
                  _applyFilters();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF008169).withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF008169)
                          : Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Text(entry.value,
                      style: TextStyle(
                          color: isSelected ? const Color(0xFF1AA88A) : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // Clear & Results count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.white54),
              ),
              Text('${_filtered.length} results',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Active Filters Bar ───────────────────────────────
  Widget _buildActiveFiltersBar() {
    if (!_hasActiveFilters) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, size: 14, color: Color(0xFF2ECC71)),
          const SizedBox(width: 6),
          Text('Filters active', style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 11)),
          const Spacer(),
          GestureDetector(
            onTap: _clearFilters,
            child: const Text('Clear', style: TextStyle(color: Colors.white38, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ─── Body ─────────────────────────────────────────────
  // Replace your _buildBody method with this fixed version:

// ─── Body ─────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF008169)),
            SizedBox(height: 16),
            Text('Loading transactions...', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: SingleChildScrollView(  // 🔥 ADDED: Wrap in SingleChildScrollView
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,  // 🔥 ADDED: min size
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F1A),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
              ),
              const SizedBox(height: 20),
              Flexible(  // 🔥 ADDED: Flexible to prevent overflow
                child: Text(
                  _transactions.isEmpty ? 'No transactions yet' : 'No matching transactions',
                  style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,  // 🔥 ADDED: center text
                ),
              ),
              if (_transactions.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear Filters', style: TextStyle(color: Color(0xFF008169))),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF008169),
      backgroundColor: const Color(0xFF1A1F1A),
      onRefresh: _loadHistory,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _filtered.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _filtered.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF008169))),
            );
          }
          return _buildTransactionCard(_filtered[i]);
        },
      ),
    );
  }

  // ─── Transaction Card ─────────────────────────────────
  Widget _buildTransactionCard(Map<String, dynamic> tx) {
    // Handle different field names from API
    final status = (tx['status'] ?? tx['npci_code'] ?? '').toString().toUpperCase();
    final type = (tx['transactionType'] ?? tx['txn_type'] ?? '').toString().toUpperCase();

    // Map API status codes
    final isSuccess = status == 'SUCCESS' || status == '00' || status == '000';
    final isFailed = status == 'FAILED';

    Color statusColor;
    IconData statusIcon;
    if (isSuccess) {
      statusColor = const Color(0xFF2ECC71);
      statusIcon = Icons.check_circle_rounded;
    } else if (isFailed) {
      statusColor = const Color(0xFFEF4444);
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusIcon = Icons.access_time_rounded;
    }

    // Map transaction type
    String mappedType;
    IconData typeIcon;
    String typeLabel;

    switch (type.toUpperCase()) {
      case 'CW':
      case 'CASH_WITHDRAWAL':
        mappedType = 'CW';
        typeIcon = Icons.payments_rounded;
        typeLabel = 'Cash Withdrawal';
        break;
      case 'BE':
      case 'BALANCE_ENQUIRY':
        mappedType = 'BE';
        typeIcon = Icons.account_balance_wallet_rounded;
        typeLabel = 'Balance Enquiry';
        break;
      case 'MS':
      case 'MINI_STATEMENT':
        mappedType = 'MS';
        typeIcon = Icons.receipt_long_rounded;
        typeLabel = 'Mini Statement';
        break;
      case 'CD':
      case 'CASH_DEPOSIT':
        mappedType = 'CD';
        typeIcon = Icons.attach_money_rounded;
        typeLabel = 'Cash Deposit';
        break;
      case 'AP':
      case 'AADHAAR_PAY':
        mappedType = 'AP';
        typeIcon = Icons.credit_card_rounded;
        typeLabel = 'Aadhaar Pay';
        break;
      default:
        mappedType = type;
        typeIcon = Icons.fingerprint;
        typeLabel = type.replaceAll('_', ' ').toUpperCase();
    }

    final amount = tx['amount'] ?? tx['transactionAmount'] ?? tx['transaction_amount'];
    final txnRefId = tx['txnRefId'] ?? tx['merchantRefId'] ?? tx['merchant_ref_id'] ?? tx['rrn'] ?? 'N/A';
    final rrn = tx['rrn'] ?? 'N/A';
    final bankName = tx['bankName'] ?? tx['bank_name'] ?? tx['bankIIN'] ?? tx['bank_iin'] ?? 'N/A';
    final dateTime = tx['createdAt'] ?? tx['txnDateTime'] ?? tx['txn_date_time'] ?? tx['timestamp'] ?? tx['created_at'];
    final aadhaarNo = tx['aadhaarNo'] ?? tx['aadhaarNumber'] ?? tx['aadhaar_last4'] ?? '';

    return GestureDetector(
      onTap: () => _showTransactionDetails(tx),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1F1A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Type + Amount
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(typeIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(typeLabel,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(_formatDateShort(dateTime),
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  if (amount != null && amount.toString() != '0' && amount.toString() != 'null')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('₹$amount',
                          style: TextStyle(color: statusColor, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),

              const SizedBox(height: 10),
              Divider(color: Colors.white.withOpacity(0.05), height: 1),
              const SizedBox(height: 10),

              // Bottom row: Ref ID + Status
              Row(
                children: [
                  // Ref ID
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_outlined, size: 12, color: Colors.white38),
                        const SizedBox(width: 4),
                        Flexible(  // 🔥 Changed from Expanded to Flexible
                          child: Text(
                            'Ref: $txnRefId',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,  // 🔥 ADDED: limit to 1 line
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 10, color: statusColor),
                        const SizedBox(width: 4),
                        Flexible(  // 🔥 ADDED: Flexible for status text
                          child: Text(
                            status,
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Transaction Details Bottom Sheet ─────────────────
  void _showTransactionDetails(Map<String, dynamic> tx) {
    // Print individual transaction full data to console
    _printFullResponse(tx, tag: 'Transaction Detail');

    final status = (tx['status'] ?? tx['npci_code'] ?? '').toString().toUpperCase();
    final type = (tx['transactionType'] ?? tx['txn_type'] ?? '').toString().toUpperCase();
    final isSuccess = status == 'SUCCESS' || status == '00' || status == '000';

    Color statusColor = isSuccess ? const Color(0xFF2ECC71) : const Color(0xFFEF4444);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F1A),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Transaction Details',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Details list
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _detailRow('ID', tx['id']?.toString() ?? 'N/A'),
                    _detailRow('Status', status, valueColor: statusColor),
                    _detailRow('Type', _getTypeLabel(type)),
                    _detailRow('RRN', tx['rrn']?.toString() ?? 'N/A'),
                    _detailRow('Amount', tx['amount'] != null && tx['amount'].toString() != 'null' ? '₹${tx['amount']}' : 'N/A'),
                    _detailRow('Bank IIN', tx['bank_iin']?.toString() ?? tx['bankIIN']?.toString() ?? 'N/A'),
                    _detailRow('Bank Name', tx['bank_name']?.toString() ?? tx['bankName']?.toString() ?? 'N/A'),
                    _detailRow('Aadhaar', _maskAadhaar(tx['aadhaar_last4']?.toString() ?? tx['aadhaarNo']?.toString() ?? '')),
                    _detailRow('NPCI Code', tx['npci_code']?.toString() ?? 'N/A'),
                    _detailRow('NPCI Message', tx['npci_message']?.toString() ?? tx['npciMessage']?.toString() ?? 'N/A'),
                    _detailRow('Date & Time', _formatDate(tx['created_at'] ?? tx['createdAt'] ?? tx['txnDateTime'] ?? tx['timestamp'])),
                    _detailRow('Merchant Ref ID', tx['merchant_ref_id']?.toString() ?? tx['merchantRefId']?.toString() ?? 'N/A'),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (isSuccess)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _viewReceipt(tx);
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 18),
                        label: const Text('View Receipt'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF008169),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ─── View Receipt ─────────────────────────────────────
  // ─── View Receipt ─────────────────────────────────────
  void _viewReceipt(Map<String, dynamic> tx) {
    try {
      // 🔍 DEBUG: Print ALL keys in the transaction
      debugPrint('═══════════════════════════════════════');
      debugPrint('🔍 _viewReceipt - Transaction keys:');
      debugPrint('═══════════════════════════════════════');
      tx.forEach((key, value) {
        if (key == 'transactionList' || key == 'transaction_list') {
          debugPrint('🔑 KEY: $key | TYPE: ${value.runtimeType} | LENGTH: ${value?.toString().length ?? 0}');
          debugPrint('📦 VALUE (first 200 chars): ${value?.toString().substring(0, value.toString().length > 200 ? 200 : value.toString().length)}');
        } else {
          debugPrint('  $key: ${value?.toString().substring(0, value.toString().length > 100 ? 100 : value.toString().length)}');
        }
      });
      debugPrint('═══════════════════════════════════════');

      final Map<String, dynamic> apiResponse = {
        'data': {
          'status': tx['status'] ?? tx['npci_code'] ?? '00',
          'merchantRefId': tx['merchantRefId'] ?? tx['merchant_ref_id'] ?? '',
          'txnRefId': tx['txnRefId'] ?? tx['rrn'] ?? '',
          'merchantId': tx['merchantId'] ?? tx['merchant_id'] ?? '',
          'aadhaarNo': tx['aadhaarNo'] ?? tx['aadhaar_last4'] ?? '',
          'transactionAmount': tx['amount']?.toString() ?? '0',
          'availableBalance': tx['availableBalance']?.toString() ?? tx['available_balance']?.toString() ?? '0',
          'txnDateTime': tx['txnDateTime'] ?? tx['created_at'] ?? tx['createdAt'] ?? DateTime.now().toString(),
          'bankIIN': tx['bankIIN'] ?? tx['bank_iin'] ?? '',
          'npciMessage': tx['npciMessage'] ?? tx['npci_message'] ?? '',
          'statusDescription': tx['statusDescription'] ?? tx['npci_message'] ?? '',
          'rrn': tx['rrn'] ?? '',
          'pipe': tx['pipe'] ?? '1',
          // 🔥 Check BOTH possible field names
          'transactionList': tx['transactionList'] ?? tx['transaction_list'] ?? '',
        }
      };

      // 🔍 DEBUG: Check what was passed
      final txnList = apiResponse['data']?['transactionList'];
      debugPrint('🔍 transactionList passed to ReceiptModel: ${txnList != null && txnList.toString().isNotEmpty ? "YES (${txnList.toString().length} chars)" : "NO (empty/null)"}');

      final receipt = ReceiptModel.fromApiResponse(
        apiResponse,
        transactionType: tx['transactionType'] ?? tx['txn_type'] ?? 'CW',
        merchantId: tx['merchantId'] ?? tx['merchant_id'] ?? 'N/A',
        mobileNumber: tx['mobileNumber'] ?? tx['mobile'] ?? '',
      );

      // 🔍 DEBUG: Check parsed entries
      debugPrint('🔍 Receipt parsed - miniStatementEntries: ${receipt.miniStatementEntries?.length ?? 0} entries');
      debugPrint('🔍 Receipt - isMiniStatement: ${receipt.isMiniStatement}');
      debugPrint('🔍 Receipt - transactionType: ${receipt.transactionType}');

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReceiptScreen(receipt: receipt)),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error opening receipt: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening receipt: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Show Full Response in Dialog ─────────────────────
  void _showFullResponseInDialog() {
    // Check if we have any data at all
    if (_lastRawResponse == null && _transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data available. Please wait for data to load first.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Build the data to show
    Map<String, dynamic> dataToShow = {};

    // Add raw response if available
    if (_lastRawResponse != null) {
      dataToShow['raw_api_response'] = _lastRawResponse;
      dataToShow['raw_api_response_type'] = _lastRawResponse.runtimeType.toString();
    }

    // Add raw more response if available
    if (_lastRawMoreResponse != null) {
      dataToShow['raw_more_response'] = _lastRawMoreResponse;
    }

    // Add parsed transactions
    dataToShow['parsed_transactions_count'] = _transactions.length;
    dataToShow['parsed_transactions'] = _transactions;

    // Add filtered transactions
    dataToShow['filtered_transactions_count'] = _filtered.length;

    const JsonEncoder encoder = JsonEncoder.withIndent('  ');
    String prettyString;
    try {
      prettyString = encoder.convert(dataToShow);
    } catch (e) {
      prettyString = dataToShow.toString();
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1A1F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.data_object, color: Color(0xFF2ECC71), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Full API Response',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white54, size: 18),
                    onPressed: () {
                      _printFullResponse(dataToShow, tag: 'Full Debug Data');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Full response printed to console/debug log'),
                          backgroundColor: Color(0xFF008169),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    tooltip: 'Print to Console',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: SelectableText(
                    prettyString,
                    style: const TextStyle(
                      color: Color(0xFF1AA88A),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
            // Bottom Bar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total: ${_transactions.length} | Filtered: ${_filtered.length}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close', style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Detail Row Widget ────────────────────────────────
  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: valueColor ?? Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ─── Helper Methods ───────────────────────────────────
  String _getTypeLabel(String type) {
    switch (type.toUpperCase()) {
      case 'CW':
      case 'CASH_WITHDRAWAL':
        return 'Cash Withdrawal';
      case 'BE':
      case 'BALANCE_ENQUIRY':
        return 'Balance Enquiry';
      case 'MS':
      case 'MINI_STATEMENT':
        return 'Mini Statement';
      case 'CD':
      case 'CASH_DEPOSIT':
        return 'Cash Deposit';
      case 'AP':
      case 'AADHAAR_PAY':
        return 'Aadhaar Pay';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  String _formatDate(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime.toString();
    }
  }

  String _formatDateShort(dynamic dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime.toString()).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${dt.day} ${months[dt.month - 1]}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateTime.toString();
    }
  }

  String _maskAadhaar(String aadhaar) {
    if (aadhaar.isEmpty) return 'XXXXXXXXXXXX';
    if (aadhaar.length < 4) return aadhaar;
    if (aadhaar.length >= 8) return 'XXXX XXXX ${aadhaar.substring(aadhaar.length - 4)}';
    return aadhaar;
  }
}