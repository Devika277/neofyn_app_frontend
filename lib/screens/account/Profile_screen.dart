// lib/screens/profile_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../screens/account/set_tpin_screen.dart'; // adjust path as needed

class ProfilePage extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfilePage({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;
    final hasTpin = user?.tpinSet ?? false;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            "Profile",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 30),
          // Profile Card
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1A1A1A),
                  Color(0xFF111111),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00FF9D),
                        Color(0xFF00D9FF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Devika M S",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "+91 98765 43210",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 14,
                            color: hasTpin ? const Color(0xFF00FF9D) : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasTpin ? "TPIN Set" : "TPIN Not Set",
                            style: TextStyle(
                              color: hasTpin ? const Color(0xFF00FF9D) : Colors.grey,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            "Settings",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          _settingItem(
            context,
            Icons.lock_rounded,
            "Security",
            Icons.chevron_right_rounded,
            onTap: () {
              // Navigate to Set/Change TPIN screen
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SetTPINScreen()),
              );
            },
          ),
          _settingItem(
            context,
            Icons.notifications_rounded,
            "Notifications",
            Icons.chevron_right_rounded,
            onTap: () {
              // TODO: notifications settings
            },
          ),
          _settingItem(
            context,
            Icons.language_rounded,
            "Language",
            Icons.chevron_right_rounded,
            onTap: () {
              // TODO: language selection
            },
          ),
          _settingItem(
            context,
            Icons.help_rounded,
            "Help Center",
            Icons.chevron_right_rounded,
            onTap: () {
              // TODO: help center
            },
          ),
          const SizedBox(height: 40),
          Center(
            child: TextButton(
              onPressed: () => _showLogoutDialog(context),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFF3B30).withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                  side: BorderSide(color: const Color(0xFFFF3B30).withOpacity(0.3)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFFF3B30)),
                  SizedBox(width: 10),
                  Text(
                    "Sign Out",
                    style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingItem(
    BuildContext context,
    IconData icon,
    String title,
    IconData trailingIcon, {
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white.withOpacity(0.7)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        trailing: Icon(trailingIcon, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Sign Out?", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure?", style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onLogout();
            },
            child: const Text("Sign Out", style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
  }
}