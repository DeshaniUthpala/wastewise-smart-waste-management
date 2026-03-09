import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../widgets/citizen_page_header.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          const CitizenPageHeader(
            title: 'Privacy Policy',
            subtitle: 'How we handle and protect your data',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('1. Data Collection', 'We collect your name, email, phone number, and location data to provide waste management services.'),
                  _buildSection('2. How We Use Data', 'Your data is used to coordinate waste pickups, provide rewards, and improve our services.'),
                  _buildSection('3. Data Sharing', 'We do not sell your personal data. We only share location details with authorized drivers for pickup purposes.'),
                  _buildSection('4. Security', 'We use industry-standard encryption to protect your account and data.'),
                  _buildSection('5. Your Rights', 'You can request to delete your account and personal data at any time via support.'),
                  const SizedBox(height: 40),
                  const Center(
                    child: Text(
                      'Last updated: February 2026',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
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

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
        ],
      ),
    );
  }
}
