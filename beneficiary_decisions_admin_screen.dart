import 'package:flutter/material.dart';
import '../services/database_service.dart';

class BeneficiaryDecisionsAdminScreen extends StatefulWidget {
  const BeneficiaryDecisionsAdminScreen({Key? key}) : super(key: key);

  @override
  State<BeneficiaryDecisionsAdminScreen> createState() => _BeneficiaryDecisionsAdminScreenState();
}

class _BeneficiaryDecisionsAdminScreenState extends State<BeneficiaryDecisionsAdminScreen> {
  List<Map<String, dynamic>> _decisions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDecisions();
  }

  Future<void> _loadDecisions() async {
    setState(() => _isLoading = true);
    final data = await DatabaseService.instance.getPendingBeneficiaryDecisions();
    if (mounted) setState(() { _decisions = data; _isLoading = false; });
  }

  Future<void> _processDecision(Map<String, dynamic> contact) async {
    final status = contact['invitationStatus'] as String;
    final isAccepted = status == 'accepted';
    final beneficiaryName = contact['fullName'] as String;
    final ownerName = contact['ownerName'] as String;
    final ownerId = contact['userId'] as int;
    final contactId = contact['id'] as int;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isAccepted ? 'Confirm Acceptance' : 'Confirm Removal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Beneficiary: $beneficiaryName'),
            const SizedBox(height: 4),
            Text('Account holder: $ownerName'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAccepted ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isAccepted ? Colors.green.shade200 : Colors.red.shade200),
              ),
              child: Text(
                isAccepted
                    ? 'This will confirm $beneficiaryName as a beneficiary. The account holder will be notified.'
                    : 'This will permanently remove $beneficiaryName from the system. The account holder will be notified.',
                style: TextStyle(fontSize: 13, color: isAccepted ? Colors.green[900] : Colors.red[900]),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isAccepted ? Colors.green : Colors.red),
            child: Text(isAccepted ? 'Confirm & Notify' : 'Remove & Notify'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (isAccepted) {
        // Keep the record — mark as confirmed
        await DatabaseService.instance.updateInvitationStatus(contactId, 'confirmed');
        // Create in-app notification for owner
        await DatabaseService.instance.createNotification(
          userId: ownerId,
          title: 'Beneficiary Accepted',
          message: '$beneficiaryName has accepted your invitation and is now confirmed as your beneficiary.',
          type: 'beneficiary_accepted',
          relatedId: contactId,
        );
      } else {
        // Remove the record entirely
        await DatabaseService.instance.deleteEmergencyContact(contactId);
        // Create in-app notification for owner
        await DatabaseService.instance.createNotification(
          userId: ownerId,
          title: 'Beneficiary Declined',
          message: '$beneficiaryName has declined your invitation and has been removed from your beneficiaries.',
          type: 'beneficiary_declined',
          relatedId: contactId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isAccepted ? '$beneficiaryName confirmed & owner notified!' : '$beneficiaryName removed & owner notified!'),
          backgroundColor: isAccepted ? Colors.green : Colors.orange,
        ));
        await _loadDecisions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beneficiary Decisions'),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadDecisions)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _decisions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.how_to_reg, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No pending decisions', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('Beneficiary responses will appear here.', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _decisions.length,
                  itemBuilder: (context, index) => _buildDecisionCard(_decisions[index]),
                ),
    );
  }

  Widget _buildDecisionCard(Map<String, dynamic> contact) {
    final status = contact['invitationStatus'] as String;
    final isAccepted = status == 'accepted';
    final statusColor = isAccepted ? Colors.green : Colors.red;
    final statusIcon = isAccepted ? Icons.check_circle : Icons.cancel;
    final statusLabel = isAccepted ? 'ACCEPTED' : 'DECLINED';

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
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Text((contact['fullName'] as String)[0].toUpperCase(),
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(contact['fullName'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(contact['email'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _infoRow('Account Holder', contact['ownerName'] as String),
            const SizedBox(height: 4),
            _infoRow('Relationship', contact['relationship'] as String),
            const SizedBox(height: 4),
            _infoRow('Inheritance', '${contact['inheritancePercentage']}%'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _processDecision(contact),
                icon: Icon(isAccepted ? Icons.check_circle_outline : Icons.delete_outline),
                label: Text(isAccepted ? 'Confirm Acceptance & Notify Owner' : 'Confirm Removal & Notify Owner'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAccepted ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text('$label:', style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }
}
