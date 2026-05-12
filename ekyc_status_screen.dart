import 'package:flutter/material.dart';
import 'login_screen.dart';

class EkycStatusScreen extends StatelessWidget {
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;

  const EkycStatusScreen({
    Key? key,
    this.status = 'pending',
    this.rejectionReason,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon — changes by status
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    color: _iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, size: 80, color: _iconColor),
                ),
              ),

              Text(
                _title,
                style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Status card
              Card(
                color: _cardBgColor,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_statusIcon, color: _statusIconColor, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            _statusLabel,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _statusIconColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),

                      // Show rejection reason if rejected
                      if (status == 'rejected' &&
                          rejectionReason != null &&
                          rejectionReason!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Reason:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[800],
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                rejectionReason!,
                                style: TextStyle(color: Colors.red[900]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // What happens next card — only for pending
              if (status == 'pending')
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What happens next?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[800],
                                fontSize: 15)),
                        const SizedBox(height: 12),
                        _buildStep(
                            '1', 'Admin reviews your IC and selfie photos'),
                        _buildStep(
                            '2', 'You will receive an email once reviewed'),
                        _buildStep(
                            '3', 'Login and start using Banking Legacy'),
                      ],
                    ),
                  ),
                ),

              // What to do card — only for rejected
              if (status == 'rejected')
                Card(
                  color: Colors.orange[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('What can you do?',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                                fontSize: 15)),
                        const SizedBox(height: 12),
                        _buildStep(
                            '1', 'Read the rejection reason above carefully'),
                        _buildStep(
                            '2',
                            'Prepare a clearer photo of your MyKad (front & back)'),
                        _buildStep(
                            '3',
                            'Make sure selfie photos are well-lit and clear'),
                        _buildStep('4', 'Register again with correct documents'),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor:
                  status == 'rejected' ? Colors.red : null,
                ),
                child: Text(
                  status == 'rejected' ? 'Register Again' : 'Go to Login',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Computed properties based on status ───────────────────────────────────

  String get _title {
    switch (status) {
      case 'approved': return 'Account Approved!';
      case 'rejected': return 'Registration Rejected';
      default:         return 'Registration Submitted!';
    }
  }

  IconData get _icon {
    switch (status) {
      case 'approved': return Icons.verified_user;
      case 'rejected': return Icons.cancel;
      default:         return Icons.check_circle;
    }
  }

  Color get _iconBgColor {
    switch (status) {
      case 'approved': return Colors.green.shade100;
      case 'rejected': return Colors.red.shade100;
      default:         return Colors.orange.shade100;
    }
  }

  Color get _iconColor {
    switch (status) {
      case 'approved': return Colors.green.shade700;
      case 'rejected': return Colors.red.shade700;
      default:         return Colors.orange.shade700;
    }
  }

  Color get _cardBgColor {
    switch (status) {
      case 'approved': return Colors.green.shade50;
      case 'rejected': return Colors.red.shade50;
      default:         return Colors.orange.shade50;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case 'approved': return Icons.check_circle;
      case 'rejected': return Icons.close;
      default:         return Icons.pending;
    }
  }

  Color get _statusIconColor {
    switch (status) {
      case 'approved': return Colors.green.shade700;
      case 'rejected': return Colors.red.shade700;
      default:         return Colors.orange.shade700;
    }
  }

  String get _statusLabel {
    switch (status) {
      case 'approved': return 'Verified & Approved';
      case 'rejected': return 'Not Approved';
      default:         return 'Verification Pending';
    }
  }

  String get _statusDescription {
    switch (status) {
      case 'approved':
        return 'Your identity has been verified. You can now sign in and start using Banking Legacy.';
      case 'rejected':
        return 'Your registration was not approved by the administrator. Please check the reason below and try again.';
      default:
        return 'Your account has been created and your identity documents are being reviewed by our administrator.';
    }
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: status == 'rejected'
                ? Colors.orange[700]
                : Colors.blue[700],
            child: Text(number,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: status == 'rejected'
                        ? Colors.orange[900]
                        : Colors.blue[900])),
          ),
        ],
      ),
    );
  }
}
