import 'package:flutter/material.dart';



class SupportPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text(
            "Support",
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            "Get help anytime, anywhere",
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 40),
          _supportCard(
            Icons.chat_bubble_rounded,
            "Live Chat",
            "Chat with our support team",
            Color(0xFF00FF9D),
            () {},
          ),
          _supportCard(
            Icons.call_rounded,
            "Call Support",
            "+91 1800-XXX-XXXX",
            Color(0xFF3B82F6),
            () {},
          ),
          _supportCard(
            Icons.mail_rounded,
            "Email",
            "support@myapp.com",
            Color(0xFF9D4EDD),
            () {},
          ),
          _supportCard(
            Icons.help_rounded,
            "FAQ",
            "Frequently asked questions",
            Color(0xFFFF6B35),
            () {},
          ),
        ],
      ),
    );
  }

  Widget _supportCard(IconData icon, String title, String subtitle, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.05),
            Colors.white.withOpacity(0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
        onTap: onTap,
      ),
    );
  }
}