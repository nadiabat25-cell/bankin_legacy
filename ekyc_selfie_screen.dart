import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import 'ekyc_review_screen.dart';

class EkycSelfieScreen extends StatefulWidget {
  final UserModel user;
  final File frontIC;
  final File backIC;

  const EkycSelfieScreen({
    Key? key,
    required this.user,
    required this.frontIC,
    required this.backIC,
  }) : super(key: key);

  @override
  State<EkycSelfieScreen> createState() => _EkycSelfieScreenState();
}

class _EkycSelfieScreenState extends State<EkycSelfieScreen> {
  File? _selfieFront;
  File? _selfieLeft;
  File? _selfieRight;
  final ImagePicker _picker = ImagePicker();

  Future<void> _takeSelfie(String type) async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        if (type == 'front') {
          _selfieFront = File(picked.path);
        } else if (type == 'left') {
          _selfieLeft = File(picked.path);
        } else {
          _selfieRight = File(picked.path);
        }
      });
    }
  }

  void _next() {
    if (_selfieFront == null || _selfieLeft == null || _selfieRight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please take all 3 selfie photos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EkycReviewScreen(
          user: widget.user,
          frontIC: widget.frontIC,
          backIC: widget.backIC,
          selfieFront: _selfieFront!,
          selfieLeft: _selfieLeft!,
          selfieRight: _selfieRight!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eKYC - Selfie Verification'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProgress(4),
            const SizedBox(height: 24),

            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.face, size: 48, color: Colors.green[700]),
                    const SizedBox(height: 12),
                    const Text(
                      'Selfie Verification',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Take 3 selfie photos — front, left, and right — for identity verification.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Selfie Front
            _buildSelfieCard(
              title: 'Selfie — Face Front *',
              subtitle: 'Look straight at the camera',
              icon: Icons.face,
              file: _selfieFront,
              onTap: () => _takeSelfie('front'),
              onRemove: () => setState(() => _selfieFront = null),
            ),
            const SizedBox(height: 12),

            // Selfie Left
            _buildSelfieCard(
              title: 'Selfie — Face Left *',
              subtitle: 'Turn your face slightly to the left',
              icon: Icons.face_retouching_natural,
              file: _selfieLeft,
              onTap: () => _takeSelfie('left'),
              onRemove: () => setState(() => _selfieLeft = null),
            ),
            const SizedBox(height: 12),

            // Selfie Right
            _buildSelfieCard(
              title: 'Selfie — Face Right *',
              subtitle: 'Turn your face slightly to the right',
              icon: Icons.face_retouching_natural,
              file: _selfieRight,
              onTap: () => _takeSelfie('right'),
              onRemove: () => setState(() => _selfieRight = null),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Next → Review & Submit',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(int step) {
    return Row(
      children: List.generate(7, (i) {
        final active = i < step;
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

  Widget _buildSelfieCard({
    required String title,
    required String subtitle,
    required IconData icon,
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
                Icon(icon, color: Colors.green[700], size: 20),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (file != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(file,
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: onTap,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retake'),
              ),
            ] else ...[
              GestureDetector(
                onTap: onTap,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt,
                            size: 32, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('Tap to take selfie',
                            style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13)),
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
}
