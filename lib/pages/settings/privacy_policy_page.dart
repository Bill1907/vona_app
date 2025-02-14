import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Last updated: March 20, 2024',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'Introduction',
              'Welcome to Vona. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
            ),
            _buildSection(
              'Information We Collect',
              'We collect information that you provide directly to us, including:\n\n'
                  '• Account information (email, name)\n'
                  '• Journal entries and conversations\n'
                  '• Voice recordings for AI chat features\n'
                  '• User preferences and settings',
            ),
            _buildSection(
              'How We Use Your Information',
              'We use the information we collect to:\n\n'
                  '• Provide and maintain our services\n'
                  '• Improve and personalize your experience\n'
                  '• Communicate with you about updates and changes\n'
                  '• Ensure the security of our services',
            ),
            _buildSection(
              'Data Storage and Security',
              'We implement appropriate technical and organizational measures to protect your personal information. Your data is stored securely using industry-standard encryption.',
            ),
            _buildSection(
              'Your Rights',
              'You have the right to:\n\n'
                  '• Access your personal data\n'
                  '• Request correction of your data\n'
                  '• Request deletion of your data\n'
                  '• Withdraw consent at any time',
            ),
            _buildSection(
              'Contact Us',
              'If you have any questions about this Privacy Policy, please contact us at:\n\n'
                  'support@vona.app',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
