import 'package:flutter/material.dart';
import '../models/emergency_contact_model.dart';

class ViewBeneficiaryScreen extends StatelessWidget {
  final EmergencyContactModel beneficiary;

  const ViewBeneficiaryScreen({Key? key, required this.beneficiary})
      : super(key: key);

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$day $month $year, $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beneficiary Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.green[200],
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.green[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      beneficiary.fullName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        beneficiary.relationship,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Personal Information
            _buildSectionTitle('Personal Information'),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildInfoRow(
                Icons.email,
                'Email Address',
                beneficiary.email,
              ),
              const Divider(),
              _buildInfoRow(
                Icons.phone,
                'Phone Number',
                beneficiary.phoneNumber,
              ),
            ]),
            const SizedBox(height: 24),

            // Added date
            _buildSectionTitle('Details'),
            const SizedBox(height: 12),
            _buildInfoCard([
              _buildInfoRow(
                Icons.calendar_today,
                'Added On',
                _formatDate(beneficiary.createdAt),
              ),
            ]),
            const SizedBox(height: 24),

            // Invitation Status
            _buildSectionTitle('Invitation Status'),
            const SizedBox(height: 12),
            _buildInvitationStatusCard(),
            const SizedBox(height: 16),

            // Info about accept/decline flow
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text('How It Works', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Beneficiary is only confirmed when they accept the invitation\n'
                          '• If they decline, you will receive a notification and their record will be removed\n'
                          '• Once confirmed by admin, they can access your assets after inactivity is detected\n'
                          '• They will use the last 6 digits of YOUR IC number as their PIN',
                      style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                    ),
                  ],
                ),
              ),
            ),

            // Emergency Access Status (only shown when invitation confirmed)
            if (beneficiary.invitationStatus == 'confirmed') ...[
              const SizedBox(height: 24),
              _buildSectionTitle('Emergency Access Status'),
              const SizedBox(height: 12),
              Card(
                color: beneficiary.accessGranted ? Colors.green[50] : Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        beneficiary.accessGranted ? Icons.check_circle : Icons.lock,
                        color: beneficiary.accessGranted ? Colors.green[700] : Colors.orange[700],
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              beneficiary.accessGranted ? 'Access Granted' : 'Access Pending',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: beneficiary.accessGranted ? Colors.green[900] : Colors.orange[900],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              beneficiary.accessGranted
                                  ? 'Granted on: ${_formatDate(beneficiary.accessGrantedAt!)}'
                                  : 'Awaiting administrator approval after inactivity detected',
                              style: TextStyle(
                                fontSize: 13,
                                color: beneficiary.accessGranted ? Colors.green[700] : Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Close Button
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: const Text(
                'Close',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationStatusCard() {
    final status = beneficiary.invitationStatus;
    Color cardColor;
    Color iconColor;
    IconData icon;
    String title;
    String subtitle;

    switch (status) {
      case 'confirmed':
        cardColor = Colors.green[50]!;
        iconColor = Colors.green[700]!;
        icon = Icons.verified;
        title = 'Confirmed Beneficiary';
        subtitle = 'Admin has confirmed this beneficiary. They are officially registered.';
        break;
      case 'accepted':
        cardColor = Colors.teal[50]!;
        iconColor = Colors.teal[700]!;
        icon = Icons.check_circle_outline;
        title = 'Invitation Accepted';
        subtitle = 'Beneficiary accepted. Waiting for administrator confirmation.';
        break;
      case 'declined':
        cardColor = Colors.red[50]!;
        iconColor = Colors.red[700]!;
        icon = Icons.cancel_outlined;
        title = 'Invitation Declined';
        subtitle = 'Beneficiary declined the invitation. Admin will remove this record.';
        break;
      default:
        cardColor = Colors.orange[50]!;
        iconColor = Colors.orange[700]!;
        icon = Icons.hourglass_empty;
        title = 'Invitation Pending';
        subtitle = 'Waiting for the beneficiary to accept or decline the invitation.';
    }

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: iconColor)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: iconColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[800],
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[600], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
