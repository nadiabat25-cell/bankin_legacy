import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import 'ekyc_status_screen.dart';

class EkycReviewScreen extends StatefulWidget {
  final UserModel user;
  final File frontIC;
  final File backIC;
  final File selfieFront;
  final File selfieLeft;
  final File selfieRight;

  const EkycReviewScreen({
    Key? key,
    required this.user,
    required this.frontIC,
    required this.backIC,
    required this.selfieFront,
    required this.selfieLeft,
    required this.selfieRight,
  }) : super(key: key);

  @override
  State<EkycReviewScreen> createState() => _EkycReviewScreenState();
}

class _EkycReviewScreenState extends State<EkycReviewScreen> {
  bool   _isLoading  = false;
  String _statusText = '';

  Future<void> _submitRegistration() async {
    setState(() {
      _isLoading  = true;
      _statusText = 'Creating account...';
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Step 1 — register user in SQLite
      final result = await authService.register(widget.user);

      if (!result['success']) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final userId = result['userId'] as int;

      // Step 2 — convert photos to Base64 and save to Firestore
      setState(() => _statusText = 'Uploading documents...');

      await FirebaseService.instance.saveEkycDocuments(
        userId:      userId,
        frontIC:     widget.frontIC,
        backIC:      widget.backIC,
        selfieFront: widget.selfieFront,
        selfieLeft:  widget.selfieLeft,
        selfieRight: widget.selfieRight,
      );

      setState(() => _statusText = 'Almost done...');

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const EkycStatusScreen(status: 'pending'),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eKYC - Review & Submit'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProgress(6),
            const SizedBox(height: 24),

            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.rate_review, size: 48, color: Colors.purple[700]),
                    const SizedBox(height: 12),
                    const Text('Review Your Submission',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(
                      'Please review all your uploaded documents before submitting.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Personal Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow('Full Name', widget.user.fullName),
                    const Divider(),
                    _buildInfoRow('IC Number', widget.user.icNumber),
                    const Divider(),
                    _buildInfoRow('Email', widget.user.email),
                    const Divider(),
                    _buildInfoRow('Phone', widget.user.phoneNumber),
                    const Divider(),
                    _buildInfoRow('Username', widget.user.username),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Uploaded Documents',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildDocPreview('IC Front', widget.frontIC)),
                const SizedBox(width: 8),
                Expanded(child: _buildDocPreview('IC Back', widget.backIC)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                    child: _buildDocPreview('Selfie Front', widget.selfieFront)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildDocPreview('Selfie Left', widget.selfieLeft)),
                const SizedBox(width: 8),
                Expanded(
                    child:
                    _buildDocPreview('Selfie Right', widget.selfieRight)),
              ],
            ),
            const SizedBox(height: 24),

            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your documents will be securely saved and reviewed by the administrator. You will receive an email once approved.',
                        style:
                        TextStyle(color: Colors.orange[900], fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _submitRegistration,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
              ),
              child: _isLoading
                  ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(_statusText,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14)),
                ],
              )
                  : const Text('Submit Registration',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Go Back'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(int step) {
    return Row(
      children: List.generate(7, (i) {
        final active  = i < step;
        final current = i == step - 1;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            height: 6,
            decoration: BoxDecoration(
              color: current
                  ? Colors.blue
                  : active
                  ? Colors.green
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDocPreview(String label, File file) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file,
              height: 80, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }
}
