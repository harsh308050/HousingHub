import 'package:flutter/material.dart';
import 'package:housinghub/config/AppConfig.dart';
import 'package:url_launcher/url_launcher.dart';

class TenantSupportScreen extends StatelessWidget {
  const TenantSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Help & Support',
            style: TextStyle(color: Colors.black87)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.support_agent,
                        color: Color(0xFF0066FF), size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'We\'re here to help',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Text(
                'Contact HousingHub support for questions about bookings, payments, or account issues.',
                style:
                    TextStyle(fontSize: 15, height: 1.5, color: Colors.black87),
              ),

              const SizedBox(height: 20),

              // Contact cards
              _ActionCard(
                icon: Icons.email_outlined,
                title: 'Email Support',
                subtitle: AppConfig.supportEmail,
                buttonLabel: 'Send Email',
                onPressed: () => _launchEmail(context),
              ),
              const SizedBox(height: 12),
              _ActionCard(
                icon: Icons.call_outlined,
                title: 'Call Helpline',
                subtitle: AppConfig.supportPhone,
                buttonLabel: 'Call Now',
                onPressed: () => _launchCall(context),
              ),

              const SizedBox(height: 24),
              const Text(
                'Quick tips',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              _TipTile(
                  icon: Icons.search,
                  text:
                      'Use filters to narrow down by budget, city, and amenities.'),
              _TipTile(
                  icon: Icons.message_outlined,
                  text: 'Use in-app chat to talk to the owner securely.'),
              _TipTile(
                  icon: Icons.receipt_long_outlined,
                  text: 'Download receipts from your booking details anytime.'),

              const SizedBox(height: 24),
              const Text(
                'FAQs',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87),
              ),
              const SizedBox(height: 8),
              const _FaqItem(
                q: 'How do I see my bookings?',
                a: 'Go to Profile → My Bookings → View All Bookings to see status and details.',
              ),
              const _FaqItem(
                q: 'Can I change my move-in date?',
                a: 'Use the chat to coordinate with the owner. Changes are subject to their approval.',
              ),
              const _FaqItem(
                q: 'Payment failed. What should I do?',
                a: 'If the amount is deducted but not reflected, contact support with the payment reference.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _launchEmail(BuildContext context) async {
    final Uri email = Uri(
      scheme: 'mailto',
      path: AppConfig.supportEmail,
      queryParameters: {
        'subject': 'HousingHub Support Request',
      },
    );
    try {
      final ok = await canLaunchUrl(email) && await launchUrl(email);
      if (!ok) _toast(context, 'Could not open email client');
    } catch (_) {
      _toast(context, 'Could not open email client');
    }
  }

  static Future<void> _launchCall(BuildContext context) async {
    final Uri tel = Uri(scheme: 'tel', path: AppConfig.supportPhone);
    try {
      final ok = await canLaunchUrl(tel) && await launchUrl(tel);
      if (!ok) _toast(context, 'Could not start a call');
    } catch (_) {
      _toast(context, 'Could not start a call');
    }
  }

  static void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFFE9EDF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F0FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0066FF), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConfig.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _TipTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _TipTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppConfig.primaryColor),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(q,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87)),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(a,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87, height: 1.5)),
            ),
          ],
        ),
      ),
    );
  }
}
