import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/email_service.dart';
import 'package:intl/intl.dart';

class AdminEmergencyRequestsScreen extends StatefulWidget {
  const AdminEmergencyRequestsScreen({Key? key}) : super(key: key);

  @override
  State<AdminEmergencyRequestsScreen> createState() =>
      _AdminEmergencyRequestsScreenState();
}

class _AdminEmergencyRequestsScreenState
    extends State<AdminEmergencyRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final requests = await DatabaseService.instance.getPendingEmergencyRequests();
      setState(() { _requests = requests; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final adminId = Provider.of<AuthService>(context, listen: false).currentAdmin!.id!;
    final notes = await _showNotesDialog('Approve Request', 'Add approval notes (optional)');
    if (notes == null) return;
    try {
      await DatabaseService.instance.approveEmergencyRequest(request['id'] as int, adminId, notes.isEmpty ? null : notes);
      await EmailService.sendAccessApproved(
        beneficiaryEmail: request['contactEmail'] as String? ?? '',
        beneficiaryName: request['contactName'] as String? ?? '',
        ownerName: request['ownerName'] as String? ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Access granted & email sent!'), backgroundColor: Colors.green));
        _loadRequests();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final adminId = Provider.of<AuthService>(context, listen: false).currentAdmin!.id!;
    final notes = await _showNotesDialog('Reject Request', 'Add rejection reason (required)');
    if (notes == null) return;
    try {
      await DatabaseService.instance.rejectEmergencyRequest(request['id'] as int, adminId, notes.isEmpty ? null : notes);
      await EmailService.sendAccessRejected(
        beneficiaryEmail: request['contactEmail'] as String? ?? '',
        beneficiaryName: request['contactName'] as String? ?? '',
        ownerName: request['ownerName'] as String? ?? '',
        rejectReason: notes.isEmpty ? 'No reason provided' : notes,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rejected & email sent!'), backgroundColor: Colors.orange));
        _loadRequests();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<String?> _showNotesDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()), maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Continue')),
        ],
      ),
    );
  }

  void _viewDocument(String base64String, String title) {
    final imageBytes = base64Decode(base64String);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
            ),
            InteractiveViewer(child: Image.memory(imageBytes, fit: BoxFit.contain)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency Access Requests'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
        const SizedBox(height: 16),
        Text('No Pending Requests', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
      ]))
          : RefreshIndicator(
        onRefresh: _loadRequests,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _requests.length,
          itemBuilder: (context, index) => _buildRequestCard(_requests[index]),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final requestedAt = DateTime.fromMillisecondsSinceEpoch(request['requestedAt'] as int);
    final formattedDate = DateFormat('MMM dd, yyyy HH:mm').format(requestedAt);
    final deathCert  = request['deathCertBase64'] as String?;
    final benefIC    = request['beneficiaryICBase64'] as String?;
    final supportDoc = request['supportingDocBase64'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)), child: Icon(Icons.emergency, color: Colors.red[700])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(request['contactName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(request['contactEmail'] ?? '-', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ])),
            ]),
            const Divider(height: 24),
            _buildInfoRow('Account Owner', request['ownerName']),
            _buildInfoRow('Owner Email',   request['ownerEmail']),
            _buildInfoRow('Relationship',  request['relationship']),
            _buildInfoRow('Requested',     formattedDate),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(request['reason'] ?? 'No reason provided', style: const TextStyle(fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Submitted Documents ───────────────────────────────────
            const Text('Submitted Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _buildDocPreview(label: 'Death Certificate', base64: deathCert,
                  onTap: deathCert != null ? () => _viewDocument(deathCert, 'Death Certificate') : null)),
              const SizedBox(width: 8),
              Expanded(child: _buildDocPreview(label: 'Beneficiary IC', base64: benefIC,
                  onTap: benefIC != null ? () => _viewDocument(benefIC, 'Beneficiary IC') : null)),
              const SizedBox(width: 8),
              Expanded(child: _buildDocPreview(label: 'Supporting Doc', base64: supportDoc,
                  onTap: supportDoc != null ? () => _viewDocument(supportDoc, 'Supporting Doc') : null)),
            ]),
            const SizedBox(height: 16),

            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _rejectRequest(request),
                icon: const Icon(Icons.close), label: const Text('Reject'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _approveRequest(request),
                icon: const Icon(Icons.check), label: const Text('Approve'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              )),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDocPreview({required String label, required String? base64, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: base64 != null ? Colors.green : Colors.grey.shade300, width: base64 != null ? 2 : 1),
          ),
          child: base64 != null
              ? ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.memory(base64Decode(base64), fit: BoxFit.cover, width: double.infinity))
              : Center(child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 28)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
        if (base64 != null) Text('tap to view', style: TextStyle(fontSize: 9, color: Colors.green[600]), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14))),
        Expanded(child: Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
      ]),
    );
  }
}
