import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({Key? key}) : super(key: key);

  void _showContactDialog(BuildContext context, String title, String detail) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(detail),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.support_agent, color: Colors.blue[700], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Banking Legacy Support', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue[900])),
                          const SizedBox(height: 4),
                          Text('We are here to help you secure your digital legacy.', style: TextStyle(color: Colors.blue[800], fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Contact Us', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.blue[100], child: Icon(Icons.email, color: Colors.blue[700])),
                    title: const Text('Email Support'),
                    subtitle: const Text('support@bankinglegacy.my'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showContactDialog(context, 'Email Support',
                        'Send your enquiries to:\n\nsupport@bankinglegacy.my\n\nWe aim to respond within 1–2 business days.'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.green[100], child: Icon(Icons.phone, color: Colors.green[700])),
                    title: const Text('Phone Support'),
                    subtitle: const Text('+603-1234 5678'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showContactDialog(context, 'Phone Support',
                        'Call us at:\n\n+603-1234 5678\n\nAvailable Monday – Friday\n9:00 AM – 5:00 PM (MYT)'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.orange[100], child: Icon(Icons.chat_bubble, color: Colors.orange[700])),
                    title: const Text('WhatsApp'),
                    subtitle: const Text('+6011-1234 5678'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showContactDialog(context, 'WhatsApp Support',
                        'Message us on WhatsApp:\n\n+6011-1234 5678\n\nAvailable Monday – Friday\n9:00 AM – 5:00 PM (MYT)'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('Report & Feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.red[100], child: Icon(Icons.bug_report, color: Colors.red[700])),
                    title: const Text('Report a Bug'),
                    subtitle: const Text('Let us know about any issues'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showContactDialog(context, 'Report a Bug',
                        'To report a bug, please email:\n\nbugs@bankinglegacy.my\n\nInclude a description of the issue, steps to reproduce, and your device model.\n\nThank you for helping us improve.'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.purple[100], child: Icon(Icons.feedback, color: Colors.purple[700])),
                    title: const Text('Send Feedback'),
                    subtitle: const Text('Share your thoughts with us'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showContactDialog(context, 'Send Feedback',
                        'We value your feedback!\n\nEmail us at:\n\nfeedback@bankinglegacy.my\n\nYour suggestions help us build a better experience for everyone.'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('User Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  _buildGuideItem(context, Icons.account_balance, 'Adding Bank Assets',
                      'Go to the Assets tab and tap +. Fill in your institution name, account type, and optionally your login credentials. All credentials are AES-encrypted with your personal key.'),
                  const Divider(height: 1),
                  _buildGuideItem(context, Icons.contacts, 'Managing Beneficiaries',
                      'Go to the Contacts tab to add people who can access your assets. Each beneficiary receives a notification email. They must request emergency access through the app, which requires admin approval.'),
                  const Divider(height: 1),
                  _buildGuideItem(context, Icons.security, 'Security & PIN',
                      'Your PIN protects your account. Change it anytime under Profile > Change PIN. All sensitive data is AES-encrypted before storage.'),
                  const Divider(height: 1),
                  _buildGuideItem(context, Icons.timer, 'Inactivity Lock',
                      'Set an inactivity period under Profile > Set Inactivity Period. The app will automatically lock after the chosen idle time and require your PIN to re-enter.'),
                  const Divider(height: 1),
                  _buildGuideItem(context, Icons.admin_panel_settings, 'Emergency Access',
                      'Beneficiaries log in via the Beneficiary login screen. After OTP and PIN verification, they submit an access request that an administrator reviews before granting access.'),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const Text('Frequently Asked Questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildFaqItem(context, 'How is my data protected?',
                'All sensitive information such as usernames and passwords are encrypted using AES-256 before being stored. Your encryption key is unique to your account and is never stored in plaintext.'),
            _buildFaqItem(context, 'How do beneficiaries access my assets?',
                'Beneficiaries log in using their registered phone number and the last 6 digits of your IC number as their PIN. They must then submit an emergency access request, which an administrator reviews and approves.'),
            _buildFaqItem(context, 'Can I add multiple beneficiaries?',
                'Yes. You can add as many beneficiaries as you need. Assign each one an inheritance percentage to reflect your intended distribution.'),
            _buildFaqItem(context, 'What happens if I forget my PIN?',
                'Contact our support team at support@bankinglegacy.my with your registered email and IC number. Our team will assist you in resetting your PIN securely.'),
            _buildFaqItem(context, 'Can I delete my account?',
                'Yes. Go to Profile > Account Settings > Delete Account. This permanently removes all your data including assets and beneficiary records. This action cannot be undone.'),
            _buildFaqItem(context, 'Is this app available offline?',
                'Core data is cached locally so previously loaded information remains viewable if connectivity is temporarily unavailable. Some features require an internet connection for sync.'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideItem(BuildContext context, IconData icon, String title, String content) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
        ),
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: TextStyle(color: Colors.grey[700], fontSize: 14, height: 1.5)),
          ),
        ],
      ),
    );
  }
}