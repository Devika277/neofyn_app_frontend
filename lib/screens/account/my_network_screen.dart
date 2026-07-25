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
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  String _selectedRole = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _roles = [
    {'value': '', 'label': 'All'},
    {'value': 'master_distributor', 'label': 'MD'},
    {'value': 'distributor', 'label': 'Dist'},
    {'value': 'retailer', 'label': 'Retail'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 150) {
      if (!_isLoadingMore) _loadMore();
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('accessToken');
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
    });
    try {
      final token = await _getToken();
      if (token == null) return;
      String url = '${ApiConfig.baseUrl}/api/members/all?page=$_currentPage';
      if (_selectedRole.isNotEmpty) url += '&role=$_selectedRole';
      if (_searchQuery.isNotEmpty) url += '&search=$_searchQuery';

      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _members = List<Map<String, dynamic>>.from(data['members'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final token = await _getToken();
      if (token == null) return;
      _currentPage++;
      String url = '${ApiConfig.baseUrl}/api/members/all?page=$_currentPage';
      if (_selectedRole.isNotEmpty) url += '&role=$_selectedRole';
      if (_searchQuery.isNotEmpty) url += '&search=$_searchQuery';

      final response = await http.get(Uri.parse(url), headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _members.addAll(List<Map<String, dynamic>>.from(data['members'] ?? []));
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      _currentPage--;
      setState(() => _isLoadingMore = false);
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
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Color(0xFF00C897), size: 20),
            tooltip: 'Create Account',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CreateAccountScreen(userId: widget.userId)),
              );
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
                      hintText: 'Search...',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                      prefixIcon:
                      const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetchMembers();
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
                    onSubmitted: (v) {
                      _searchQuery = v;
                      _fetchMembers();
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
                          _fetchMembers();
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
          // Count bar
          if (!_isLoading)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text('${_members.length} members',
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
                : _members.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline_rounded,
                      color: Colors.white.withOpacity(0.15), size: 48),
                  const SizedBox(height: 10),
                  Text('No members found',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 13)),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchMembers,
              color: const Color(0xFF00C897),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _members.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index == _members.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Color(0xFF00C897), strokeWidth: 2)),
                      ),
                    );
                  }
                  final m = _members[index];
                  final role = m['role'] ?? '';
                  final name =
                  '${m['first_name'] ?? ''} ${m['last_name'] ?? ''}'.trim();
                  return _memberCard(
                      name, role, m['member_id'] ?? '', m['phone'] ?? '');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberCard(String name, String role, String memberId, String phone) {
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
                    Text(memberId,
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