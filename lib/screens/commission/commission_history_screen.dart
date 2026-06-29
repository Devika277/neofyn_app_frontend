// screens/commission/commission_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/bbps/api_service.dart';
import '../../services/commission/commission_service.dart';
import 'transfer_commission_dialog.dart';
import '../../providers/wallet_provider.dart';

class CommissionHistoryScreen extends StatefulWidget {
  const CommissionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CommissionHistoryScreen> createState() => _CommissionHistoryScreenState();
}

class _CommissionHistoryScreenState extends State<CommissionHistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _page = 1;
  bool _hasMore = true;
  String? _error;
  String? _selectedStatus;

  double _commissionBalance = 0.0;
  double _minTransferAmount = 100.0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    print('🔵🔵🔵 CommissionHistoryScreen INITIALIZED 🔵🔵🔵');
    
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('🔵 Post-frame callback: Starting fetch...');
        _fetchHistory();
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
        print('🔵 Scrolling: Loading more...');
        _fetchHistory();
      }
    }
  }

  Future<void> _fetchCommissionBalance() async {
    try {
      final response = await CommissionService.getBalance();
      if (response['success'] == true) {
        final data = response['data'];
        setState(() {
          _commissionBalance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        });
      }
      // Get min transfer amount - now returns immediately
      _minTransferAmount = await CommissionService.getMinTransferAmount();
      print('💰 Min transfer amount: $_minTransferAmount');
    } catch (e) {
      print('❌ Failed to fetch balance: $e');
      _minTransferAmount = 100.0;
    }
  }

  void _testTransferWithToken() async {
    try {
      print('🔵 🔵 🔵 TESTING TRANSFER DIRECTLY 🔵 🔵 🔵');
      
      // 1. Check token
      final token = await ApiService.getToken();
      print('🔑 Token: ${token != null ? "✅ Present (${token.substring(0, 10)}...)" : "❌ MISSING"}');
      
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No token found! Please login.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // 2. Make the transfer
      print('📤 Making transfer request...');
      final response = await CommissionService.transferToMain(100);
      print('📥 Transfer response: $response');
      
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Transfer successful! ₹100 moved to main wallet.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Refresh data
        _fetchCommissionBalance();
        _fetchHistory(refresh: true);
        
        // ✅ Refresh WalletProvider - handle properly
        try {
          final wp = Provider.of<WalletProvider>(context, listen: false);
          // Call the refresh method on the provider
          await wp.fetchAllWalletData();
          await wp.fetchCommissionBalance();
        } catch (e) {
          print('⚠️ Could not refresh WalletProvider: $e');
        }
        
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Transfer failed: ${response['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Transfer test error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTransferDialog() {
    if (_commissionBalance < _minTransferAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum transfer is ₹${_minTransferAmount.toStringAsFixed(0)}. '
            'Your balance: ₹${_commissionBalance.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TransferCommissionDialog(
        availableBalance: _commissionBalance,
        minTransferAmount: _minTransferAmount,
      ),
    ).then((result) {
      if (result == true) {
        // Refresh balance if transfer was successful
        _fetchCommissionBalance();
        _fetchHistory(refresh: true);
        
        // Also refresh WalletProvider
        try {
          final wp = Provider.of<WalletProvider>(context, listen: false);
          wp.fetchAllWalletData();
          wp.fetchCommissionBalance();
        } catch (e) {
          print('⚠️ Could not refresh WalletProvider: $e');
        }
      }
    });
  }

  Future<void> _fetchHistory({bool refresh = false}) async {
    print('🔵 _fetchHistory called - refresh: $refresh, page: $_page, isLoading: $_isLoading');
    
    if (_isLoading || _isLoadingMore) {
      print('🔵 Already loading, skipping...');
      return;
    }
    
    final token = await ApiService.getToken();
    print('🔑 Token status: ${token != null ? '✅ Exists (${token.substring(0, 10)}...)' : '❌ Missing'}');
    
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Please login again to view your commission history';
        _isLoading = false;
        _isLoadingMore = false;
      });
      return;
    }
    
    if (refresh) {
      setState(() {
        _history.clear();
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
      print('🔍 Calling API: /api/commission/history?page=$_page&limit=20');
      
      final response = await CommissionService.getHistory(
        page: _page,
        limit: 20,
        status: _selectedStatus,
      );

      print('✅ API Response received: ${response['success']}');

      if (response['success'] == true) {
        final List<dynamic> rawItems = response['data'] ?? [];
        
        final List<Map<String, dynamic>> cleanedItems = rawItems.map((item) {
          final Map<String, dynamic> data = item is Map 
              ? Map<String, dynamic>.from(item) 
              : <String, dynamic>{};
          
          return {
            'id': data['id'] ?? 0,
            'user_id': data['user_id'] ?? 0,
            'type': data['type']?.toString() ?? 'unknown',
            'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
            'status': data['status']?.toString() ?? 'pending',
            'description': data['description']?.toString() ?? '',
            'reference_id': data['reference_id']?.toString() ?? '',
            'balance_after': (data['balance_after'] as num?)?.toDouble() ?? 0.0,
            'created_at': data['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'updated_at': data['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
          };
        }).toList();
        
        print('📊 Received ${cleanedItems.length} items (cleaned)');
        
        setState(() {
          _history.addAll(cleanedItems);
          _hasMore = cleanedItems.length == 20;
          _page++;
          _error = null;
        });
      } else {
        setState(() {
          _error = response['message']?.toString() ?? 'Failed to load history';
        });
      }
    } catch (e) {
      print('❌ Error fetching history: $e');
      setState(() {
        if (e is ApiException) {
          _error = e.message;
          if (e.statusCode == 401) {
            _showLoginRequiredDialog();
          }
        } else {
          _error = e.toString();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Expired'),
        content: const Text('Your session has expired. Please login again to continue.'),
        actions: [
          TextButton(
            onPressed: () {
              ApiService.clearToken();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                (route) => false,
              );
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  void _filterByStatus(String? status) {
    setState(() {
      _selectedStatus = status;
      _history.clear();
      _page = 1;
      _hasMore = true;
      _error = null;
    });
    _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    print('🔵 Building CommissionHistoryScreen - history length: ${_history.length}, isLoading: $_isLoading');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Commission History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          // ✅ Transfer Button in AppBar
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: _commissionBalance >= _minTransferAmount ? _showTransferDialog : null,
            tooltip: 'Transfer to Main Wallet',
          ),
          // ✅ TEST BUTTON - Direct transfer test
          IconButton(
            icon: const Icon(Icons.play_arrow, color: Colors.green),
            onPressed: _testTransferWithToken,
            tooltip: 'Test Transfer (₹100)',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              final token = await ApiService.getToken();
              print('🔑 Debug - Token: ${token != null ? '✅ Exists (${token.substring(0, 10)}...)' : '❌ Missing'}');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    token != null 
                      ? 'Token exists: ${token.substring(0, 10)}...' 
                      : 'No token found! Please login.',
                  ),
                  backgroundColor: token != null ? Colors.green : Colors.red,
                ),
              );
              _fetchHistory(refresh: true);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('🔵 Refresh button pressed');
              _fetchHistory(refresh: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildBalanceHeader(),
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBalanceHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade200.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Available Commission',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₹${_commissionBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_commissionBalance > 0)
                Text(
                  'Min transfer: ₹${_minTransferAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          if (_commissionBalance >= _minTransferAmount)
            ElevatedButton.icon(
              onPressed: _showTransferDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text(
                'Transfer',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _commissionBalance > 0 
                    ? 'Min ₹${_minTransferAmount.toStringAsFixed(0)}' 
                    : 'No balance',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: 'All',
            isSelected: _selectedStatus == null,
            onTap: () => _filterByStatus(null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Credited',
            isSelected: _selectedStatus == 'credited',
            onTap: () => _filterByStatus('credited'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Pending',
            isSelected: _selectedStatus == 'pending',
            onTap: () => _filterByStatus('pending'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Failed',
            isSelected: _selectedStatus == 'failed',
            onTap: () => _filterByStatus('failed'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading commission history...'),
          ],
        ),
      );
    }

    if (_error != null && _history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _error!.contains('login') ? Icons.lock_outline : Icons.error_outline,
                size: 64,
                color: _error!.contains('login') ? Colors.orange : Colors.red.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchHistory(refresh: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_error!.contains('login') ? 'Go to Login' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No commission transactions',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchHistory(refresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _history.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _history.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final item = _history[index];
          return _HistoryCard(item: item);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Filter Chip Widget
// ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// History Card Widget - COMPLETE FIXED VERSION
// ─────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = item['type'] as String? ?? 'unknown';
    final isCredit = type == 'credit';
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final status = item['status'] as String? ?? 'pending';
    
    final createdAtStr = item['created_at'] as String?;
    final createdAt = createdAtStr != null 
        ? DateTime.parse(createdAtStr) 
        : DateTime.now();
    
    final date = _formatDate(createdAt);
    final statusColor = _getStatusColor(status);
    final description = item['description'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1),
                ),
                child: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? Colors.green : Colors.red,
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
                        Expanded(
                          child: Text(
                            type.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Text(
                          '${isCredit ? '+' : '-'}₹${amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isCredit ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              description,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final type = item['type'] as String? ?? 'unknown';
    final isCredit = type == 'credit';
    final amount = (item['amount'] as num?)?.toDouble() ?? 0.0;
    final status = item['status'] as String? ?? 'pending';
    
    final createdAtStr = item['created_at'] as String?;
    final createdAt = createdAtStr != null 
        ? DateTime.parse(createdAtStr) 
        : DateTime.now();
    
    final description = item['description'] as String? ?? '';
    final referenceId = item['reference_id'] as String? ?? '';
    final balanceAfter = (item['balance_after'] as num?)?.toDouble() ?? 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
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
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: isCredit ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      _formatDate(createdAt),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isCredit ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            _DetailRow('Status', status.toUpperCase()),
            if (description.isNotEmpty)
              _DetailRow('Description', description),
            if (referenceId.isNotEmpty)
              _DetailRow('Reference ID', referenceId),
            if (balanceAfter > 0)
              _DetailRow(
                'Balance After',
                '₹${balanceAfter.toStringAsFixed(2)}',
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _DetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  static Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'credited':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}