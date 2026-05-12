import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import 'ekyc_selfie_screen.dart';

class EkycUploadIdScreen extends StatefulWidget {
  final UserModel user;

  const EkycUploadIdScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EkycUploadIdScreen> createState() => _EkycUploadIdScreenState();
}

class _EkycUploadIdScreenState extends State<EkycUploadIdScreen> {
  File? _frontIC;
  File? _backIC;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String side) async {
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
                    source: ImageSource.camera, imageQuality: 80);
                if (picked != null) {
                  setState(() {
                    if (side == 'front') {
                      _frontIC = File(picked.path);
                    } else {
                      _backIC = File(picked.path);
                    }
                  });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await _picker.pickImage(
                    source: ImageSource.gallery, imageQuality: 80);
                if (picked != null) {
                  setState(() {
                    if (side == 'front') {
                      _frontIC = File(picked.path);
                    } else {
                      _backIC = File(picked.path);
                    }
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _next() {
    if (_frontIC == null || _backIC == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload both front and back of your IC'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EkycSelfieScreen(
          user: widget.user,
          frontIC: _frontIC!,
          backIC: _backIC!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('eKYC - Upload ID'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress indicator
            _buildProgress(2),
            const SizedBox(height: 24),

            // Header
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.credit_card,
                        size: 48, color: Colors.blue[700]),
                    const SizedBox(height: 12),
                    const Text(
                      'Upload Your IC / MyKad',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please upload a clear photo of both sides of your IC card.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Front IC
            const Text('Front of IC *',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildUploadBox(
              file: _frontIC,
              hint: 'Tap to upload front of IC',
              icon: Icons.credit_card,
              onTap: () => _pickImage('front'),
              onRemove: () => setState(() => _frontIC = null),
            ),
            const SizedBox(height: 16),

            // Back IC
            const Text('Back of IC *',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildUploadBox(
              file: _backIC,
              hint: 'Tap to upload back of IC',
              icon: Icons.credit_card_outlined,
              onTap: () => _pickImage('back'),
              onRemove: () => setState(() => _backIC = null),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Next → Take Selfie',
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

  Widget _buildUploadBox({
    required File? file,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    required VoidCallback onRemove,
  }) {
    if (file != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(file,
                height: 180,
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
                    color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(hint,
                  style: TextStyle(color: Colors.grey[500], fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
