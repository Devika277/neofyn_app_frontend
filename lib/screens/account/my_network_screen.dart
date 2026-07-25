// lib/screens/employee/my_network_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';

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

  final List<String> _roles = ['', 'master_distributor', 'distributor', 'retailer'];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore) {
        _loadMore();
      }
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

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _members = List<Map<String, dynamic>>.from(data['members'] ?? []);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching members: $e');
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

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newMembers = List<Map<String, dynamic>>.from(data['members'] ?? []);
        setState(() {
          _members.addAll(newMembers);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      _currentPage--;
      setState(() => _isLoadingMore = false);
    }
  }

  String _getRoleDisplay(String role) {
    switch (role) {
      case 'admin': return 'Admin';
      case 'master_distributor': return 'Master Distributor';
      case 'distributor': return 'Distributor';
      case 'retailer': return 'Retailer';
      case 'whitelabel': return 'White Label';
      default: return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return const Color(0xFFFF5252);
      case 'master_distributor': return const Color(0xFF7B4FDB);
      case 'distributor': return const Color(0xFF1AA88A);
      case 'retailer': return const Color(0xFFFFB74D);
      default: return const Color(0xFF9CA3AF);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF151915),
        title: const Text('My Network', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF151915),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Column(
              children: [
                // Search Field
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or ID...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                        _fetchMembers();
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (value) {
                    setState(() => _searchQuery = value);
                    _fetchMembers();
                  },
                ),
                const SizedBox(height: 12),
                // Role Filter Chips
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _roles.map((role) {
                      final isSelected = _selectedRole == role;
                      final label = role.isEmpty ? 'All' : _getRoleDisplay(role);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedRole = role);
                            _fetchMembers();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF008169).withOpacity(0.2)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF008169)
                                    : Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFF00C897) : const Color(0xFF9CA3AF),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Members List
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00C897)),
            )
                : _members.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, color: Colors.white.withOpacity(0.2), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'No members found',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchMembers,
              color: const Color(0xFF00C897),
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _members.length + (_isLoadingMore ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index == _members.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: Color(0xFF00C897), strokeWidth: 2),
                      ),
                    );
                  }

                  final member = _members[index];
                  final role = member['role'] ?? '';
                  final name = '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'.trim();

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151915),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: _getRoleColor(role).withOpacity(0.2),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: _getRoleColor(role),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      title: Text(
                        name.isNotEmpty ? name : 'Unknown',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'ID: ${member['member_id'] ?? 'N/A'}',
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                          ),
                          if (member['phone'] != null)
                            Text(
                              '📱 ${member['phone']}',
                              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11),
                            ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getRoleDisplay(role),
                          style: TextStyle(
                            color: _getRoleColor(role),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
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