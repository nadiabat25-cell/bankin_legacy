import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/database_service.dart';
import '../models/emergency_contact_model.dart';

class BeneficiaryRequestAccessScreen extends StatefulWidget {
  final EmergencyContactModel contact;

  const BeneficiaryRequestAccessScreen({
    Key? key,
    required this.contact,
  }) : super(key: key);

  @override
  State<BeneficiaryRequestAccessScreen> createState() =>
      _BeneficiaryRequestAccessScreenState();
}

class _BeneficiaryRequestAccessScreenState
    extends State<BeneficiaryRequestAccessScreen> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  File? _deathCertificate;
  File? _beneficiaryIC;
  File? _supportingDoc;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(String docType) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                );
                if (picked != null) _setFile(docType, File(picked.path));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                );
                if (picked != null) _setFile(docType, File(picked.path));
              },
            ),
          ],
        ),
      ),
    );
  }

  void _setFile(String docType, File file) {
    setState(() {
      if (docType == 'death') {
        _deathCertificate = file;
      } else if (docType == 'ic') {
        _beneficiaryIC = file;
      } else {
        _supportingDoc = file;
      }
    });
  }

  // Convert File to base64 string for DB storage
  Future<String?> _fileToBase64(File? file) async {
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> _submitRequest() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for your request'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_deathCertificate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload the Death Certificate'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_beneficiaryIC == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your IC / Identity Document'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Convert images to base64 for storage
      final deathCertBase64  = await _fileToBase64(_deathCertificate);
      final beneficiaryICBase64 = await _fileToBase64(_beneficiaryIC);
      final supportingDocBase64 = await _fileToBase64(_supportingDoc);

      await DatabaseService.instance.createEmergencyAccessRequest(
        contactId:          widget.contact.id!,
        userId:             widget.contact.userId,
        reason:             _reasonController.text.trim(),
        deathCertBase64:    deathCertBase64,
        beneficiaryICBase64: beneficiaryICBase64,
        supportingDocBase64: supportingDocBase64,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request submitted successfully. Admin will review it shortly.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Emergency Access'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 48, color: Colors.orange[700]),
                    const SizedBox(height: 12),
                    Text(
                      'Emergency Access Request',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[900],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This request will be reviewed by the administrator. '
                          'Please upload the required documents below.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Request Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ✅ FIXED: Show Phone Number instead of IC Number
            _buildInfoCard('Your Name',  widget.contact.fullName),
            _buildInfoCard('Phone',      widget.contact.phoneNumber),
            _buildInfoCard('Relationship', widget.contact.relationship),
            const SizedBox(height: 24),

            const Text('Required Documents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                '⚠️ Death Certificate and IC are required to submit this request.',
                style: TextStyle(color: Colors.red[800], fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            _buildDocumentUpload(
              title: 'Death Certificate *',
              subtitle: 'Required — Upload a clear photo of the death certificate',
              icon: Icons.description,
              iconColor: Colors.red,
              file: _deathCertificate,
              onTap: () => _pickImage('death'),
              onRemove: () => setState(() => _deathCertificate = null),
            ),
            const SizedBox(height: 12),

            _buildDocumentUpload(
              title: 'Your IC / Identity Document *',
              subtitle: 'Required — Upload a clear photo of your IC card',
              icon: Icons.credit_card,
              iconColor: Colors.blue,
              file: _beneficiaryIC,
              onTap: () => _pickImage('ic'),
              onRemove: () => setState(() => _beneficiaryIC = null),
            ),
            const SizedBox(height: 12),

            _buildDocumentUpload(
              title: 'Supporting Document (Optional)',
              subtitle: 'Marriage certificate, birth certificate, etc.',
              icon: Icons.folder_open,
              iconColor: Colors.green,
              file: _supportingDoc,
              onTap: () => _pickImage('support'),
              onRemove: () => setState(() => _supportingDoc = null),
            ),
            const SizedBox(height: 24),

            const Text('Reason for Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Please explain why you need access to the account holder\'s assets.',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText:
                'Example: The account holder has passed away and I need to access their bank accounts...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text('Submit Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 24),

            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your request will be reviewed by the administrator. '
                            'You will receive an email notification once a decision is made.',
                        style: TextStyle(color: Colors.blue[900], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentUpload({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required File? file,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (file != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      file,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Replace Photo'),
              ),
            ] else ...[
              GestureDetector(
                onTap: onTap,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.upload_file,
                            size: 32, color: Colors.grey[500]),
                        const SizedBox(height: 8),
                        Text('Tap to upload',
                            style: TextStyle(
                                color: Colors.grey[600], fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}
