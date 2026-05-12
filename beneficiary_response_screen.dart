import 'package:flutter/material.dart';
import '../services/database_service.dart';

class BeneficiaryResponseScreen extends StatefulWidget {
  const BeneficiaryResponseScreen({Key? key}) : super(key: key);

  @override
  State<BeneficiaryResponseScreen> createState() => _BeneficiaryResponseScreenState();
}

class _BeneficiaryResponseScreenState extends State<BeneficiaryResponseScreen> {
  final _emailController = TextEditingController();
  bool _isSearching = false;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _invitations = [];
  bool _searched = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchInvitations() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address'), backgroundColor: Colors.red),
      );
      return;
    }
    setState(() { _isSearching = true; _searched = false; });
    try {
      final db = await DatabaseService.instance.database;
      final results = await db.rawQuery('''
        SELECT ec.*, u.fullName AS ownerName, u.email AS ownerEmail, u.id AS ownerId
        FROM emergency_contacts ec
        INNER JOIN users u ON ec.userId = u.id
        WHERE ec.email = ? AND ec.invitationStatus = 'pending'
        ORDER BY ec.createdAt DESC
      ''', [email]);
      setState(() { _invitations = results; _searched = true; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _respond(Map<String, dynamic> invitation, String decision) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(decision == 'accepted' ? 'Accept Invitation' : 'Decline Invitation'),
        content: Text(
          decision == 'accepted'
              ? 'You are accepting to be a beneficiary for ${invitation['ownerName']}. The administrator will be notified.'
              : 'You are declining to be a beneficiary for ${invitation['ownerName']}. The administrator will be notified and your record will be removed.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: decision == 'accepted' ? Colors.green : Colors.red),
            child: Text(decision == 'accepted' ? 'Accept' : 'Decline'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final contactId = invitation['id'] as int;

      await DatabaseService.instance.updateInvitationStatus(contactId, decision);

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(children: [
            Icon(decision == 'accepted' ? Icons.check_circle : Icons.cancel,
                color: decision == 'accepted' ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(decision == 'accepted' ? 'Accepted!' : 'Declined'),
          ]),
          content: Text(
            decision == 'accepted'
                ? 'You have accepted the invitation. The administrator has been notified and will confirm your role.'
                : 'You have declined the invitation. The administrator has been notified and will remove your record.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Respond to Invitation'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Your Email Address',
                prefixIcon: Icon(Icons.email),
                hintText: 'Enter the email that received the invitation',
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSearching ? null : _searchInvitations,
              icon: _isSearching
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search),
              label: const Text('Find Invitation'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            if (_searched && _invitations.isEmpty)
              Card(
                color: Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text('No pending invitations found for this email.', style: TextStyle(color: Colors.grey[600]), textAlign: TextAlign.center),
                      const SizedBox(height: 4),
                      Text('Make sure you enter the exact email that received the invitation.', style: TextStyle(fontSize: 12, color: Colors.grey[500]), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            if (_invitations.isNotEmpty) ...[
              Text('${_invitations.length} Pending Invitation${_invitations.length > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._invitations.map((inv) => _buildInvitationCard(inv)).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationCard(Map<String, dynamic> inv) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.teal[100],
                  child: Text((inv['ownerName'] as String)[0].toUpperCase(), style: TextStyle(color: Colors.teal[700], fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Invited by ${inv['ownerName']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Relationship: ${inv['relationship']}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _infoRow(Icons.percent, 'Inheritance Allocation', '${inv['inheritancePercentage']}%'),
            const SizedBox(height: 6),
            _infoRow(Icons.info_outline, 'Your Role', 'You will be a beneficiary and may request emergency access to their digital assets.'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _respond(inv, 'accepted'),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : () => _respond(inv, 'declined'),
                    icon: const Icon(Icons.close),
                    label: const Text('Decline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              children: [
                TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
