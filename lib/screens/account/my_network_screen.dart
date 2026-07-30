// lib/screens/employee/my_network_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import 'create_account_screen.dart';

class MyNetworkScreen extends StatefulWidget {
  final String userId;
  const MyNetworkScreen({super.key, required this.userId});

  @override
  State<MyNetworkScreen> createState() => _MyNetworkScreenState();
}

class _MyNetworkScreenState extends State<MyNetworkScreen> {
  // Hierarchy data
  Map<String, dynamic>? _treeData;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _downline = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  // View mode: 'children' (direct) or 'downline' (full tree)
  String _viewMode = 'children';

  // Search (client-side since hierarchy APIs don't support search)
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Role filter (client-side)
  String _selectedRole = '';

  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _roles = [
    {'value': '', 'label': 'All'},
    {'value': 'master_distributor', 'label': 'MD'},
    {'value': 'distributor', 'label': 'Dist'},
    {'value': 'retailer', 'label': 'Retail'},
    {'value': 'employee', 'label': 'Emp'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchHierarchyData();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      // Hierarchy APIs return all data at once, so pagination might not be needed
      // But you can implement if your API supports limit/offset
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> _fetchHierarchyData() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      if (token == null) return;

      if (_viewMode == 'children') {
        // Fetch direct children only
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/hierarchy/children'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _children = List<Map<String, dynamic>>.from(data['children'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      } else {
        // Fetch full downline tree
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/hierarchy/downline'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _downline = List<Map<String, dynamic>>.from(data['downline'] ?? []);
            _isLoading = false;
          });
        } else {
          setState(() => _isLoading = false);
        }
      }

      // Also fetch tree summary for counts
      _fetchTreeSummary();
    } catch (e) {
      debugPrint('Error fetching hierarchy: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchTreeSummary() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/hierarchy/tree'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _treeData = data;
        });
      }
    } catch (e) {
      debugPrint('Error fetching tree summary: $e');
    }
  }

  // Get filtered list based on view mode, search, and role filter
  List<Map<String, dynamic>> get _filteredMembers {
    List<Map<String, dynamic>> source = _viewMode == 'children' ? _children : _downline;

    return source.where((member) {
      final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.toLowerCase();
      final memberId = (member['member_id'] ?? '').toString().toLowerCase();
      final phone = (member['phone'] ?? '').toString().toLowerCase();
      final role = (member['role'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      // Search filter
      if (query.isNotEmpty) {
        if (!name.contains(query) &&
            !memberId.contains(query) &&
            !phone.contains(query)) {
          return false;
        }
      }

      // Role filter
      if (_selectedRole.isNotEmpty && role != _selectedRole.toLowerCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  int get _totalCount {
    if (_viewMode == 'children') {
      return _treeData?['directChildrenCount'] ?? _children.length;
    } else {
      return _treeData?['downlineCount'] ?? _downline.length;
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'master_distributor':
        return 'MD';
      case 'distributor':
        return 'Dist';
      case 'retailer':
        return 'Retail';
      case 'employee':
        return 'Emp';
      case 'whitelabel':
        return 'WL';
      default:
        return role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFFF5252);
      case 'master_distributor':
        return const Color(0xFF7B4FDB);
      case 'distributor':
        return const Color(0xFF1AA88A);
      case 'retailer':
        return const Color(0xFFFFB74D);
      case 'employee':
        return const Color(0xFF42A5F5);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151915),
        title: const Text('My Network',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // View mode toggle
          Container(
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _viewModeButton('children', 'Direct'),
                _viewModeButton('downline', 'Tree'),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Color(0xFF00C897), size: 20),
            tooltip: 'Create Account',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CreateAccountScreen(userId: widget.userId)),
              ).then((_) => _fetchHierarchyData()); // Refresh on return
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search + Filter
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            color: const Color(0xFF151915),
            child: Column(
              children: [
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by name, ID or phone...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                      prefixIcon:
                      const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Icon(Icons.close_rounded,
                            color: Color(0xFF6B7280), size: 16),
                      )
                          : null,
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _roles.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final role = _roles[i];
                      final isSelected = _selectedRole == role['value'];
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedRole = role['value']!);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF008169).withOpacity(0.25)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF008169)
                                  : Colors.white.withOpacity(0.08),
                              width: 0.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              role['label']!,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF00C897)
                                    : const Color(0xFF9CA3AF),
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Stats bar
          if (!_isLoading && _treeData != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _statChip('Direct', _treeData?['directChildrenCount'] ?? 0, const Color(0xFF7B4FDB)),
                  const SizedBox(width: 8),
                  _statChip('Downline', _treeData?['downlineCount'] ?? 0, const Color(0xFF1AA88A)),
                  const Spacer(),
                  Text('${_filteredMembers.length} shown',
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                ],
              ),
            ),

          // Count bar
          if (!_isLoading && _treeData == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text('${_filteredMembers.length} members',
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11)),
                  const Spacer(),
                  if (_selectedRole.isNotEmpty)
                    Text(_roleLabel(_selectedRole),
                        style: const TextStyle(
                            color: Color(0xFF00C897), fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),

          // List
          Expanded(
            child: _isLoading
                ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00C897), strokeWidth: 2))
                : _filteredMembers.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline_rounded,
                      color: Colors.white.withOpacity(0.15), size: 48),
                  const SizedBox(height: 10),
                  Text(
                    _viewMode == 'children'
                        ? 'No direct members yet'
                        : 'No downline members',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 13),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchHierarchyData,
              color: const Color(0xFF00C897),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _filteredMembers.length,
                itemBuilder: (_, index) {
                  final m = _filteredMembers[index];
                  final role = m['role'] ?? '';
                  final name =
                  '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
                  final level = m['level'] ?? m['depth'];
                  return _memberCard(
                      name, role, m['member_id'] ?? '', m['phone'] ?? '', level);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewModeButton(String mode, String label) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        if (_viewMode != mode) {
          setState(() {
            _viewMode = mode;
            _isLoading = true;
          });
          _fetchHierarchyData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF008169) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _statChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count ',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(String name, String role, String memberId, String phone, dynamic level) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF151915),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          // Level indicator for tree view
          if (_viewMode == 'downline' && level != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1AA88A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'L$level',
                style: const TextStyle(
                  color: Color(0xFF1AA88A),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _roleColor(role).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style:
                TextStyle(color: _roleColor(role), fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isNotEmpty ? name : 'Unknown',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(memberId.isNotEmpty ? memberId : 'Pending',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 10)),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.phone_rounded, size: 10, color: Colors.white.withOpacity(0.3)),
                      const SizedBox(width: 3),
                      Text(phone,
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _roleColor(role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _roleLabel(role),
              style: TextStyle(
                  color: _roleColor(role), fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}