// lib/widgets/payment_link_widget.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentLinkWidget extends StatelessWidget {
  final String url;
  final String label;

  const PaymentLinkWidget({
    Key? key,
    required this.url,
    this.label = 'Payment Link',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _launchLink(context, url),
            child: Row(
              children: [
                const Icon(Icons.link_rounded, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    url,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.open_in_new, color: Colors.blue, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchLink(BuildContext context, String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw 'Could not launch';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}