import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/aes_encryption_service.dart';
import '../models/bank_asset_model.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class ViewBankAssetScreen extends StatefulWidget {
  final BankAssetModel asset;
  const ViewBankAssetScreen({Key? key, required this.asset}) : super(key: key);

  @override
  State<ViewBankAssetScreen> createState() => _ViewBankAssetScreenState();
}

class _ViewBankAssetScreenState extends State<ViewBankAssetScreen> {
  bool _showCredentials = false;
  String? _decryptedUsername;
  String? _decryptedPassword;
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPinAndShowCredentials() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser!;

    // Hash the entered PIN to compare with stored hashed PIN
    final enteredPinHash = sha256.convert(utf8.encode(_pinController.text)).toString();

    // Compare hashed PIN
    if (enteredPinHash != user.pin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incorrect PIN'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final encryptionService = AESEncryptionService();

      if (widget.asset.encryptedUsername != null) {
        _decryptedUsername = encryptionService.decrypt(
          widget.asset.encryptedUsername!,
          user.aesKey,
        );
      }

      if (widget.asset.encryptedPassword != null) {
        _decryptedPassword = encryptionService.decrypt(
          widget.asset.encryptedPassword!,
          user.aesKey,
        );
      }

      setState(() {
        _showCredentials = true;
      });

      Navigator.pop(context);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credentials decrypted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Decryption failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showPinDialog() {
    _pinController.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your 6-digit PIN to view encrypted credentials',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: '6-Digit PIN',
                hintText: '••••••',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _pinController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_pinController.text.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN must be 6 digits'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              _verifyPinAndShowCredentials();
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_balance,
                      size: 60,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.asset.institutionName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      label: Text(widget.asset.assetType),
                      backgroundColor: Colors.blue[50],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  if (widget.asset.accountIdentifier != null)
                    ListTile(
                      leading: const Icon(Icons.numbers),
                      title: const Text('Account Identifier'),
                      subtitle: Text(widget.asset.accountIdentifier!),
                    ),
                  if (widget.asset.estimatedValue != null) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.attach_money),
                      title: const Text('Estimated Value'),
                      subtitle: Text(widget.asset.estimatedValue!),
                    ),
                  ],
                  if (widget.asset.specialInstructions != null) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.note),
                      title: const Text('Special Instructions'),
                      subtitle: Text(widget.asset.specialInstructions!),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.asset.encryptedUsername != null ||
                widget.asset.encryptedPassword != null)
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lock, color: Colors.orange[700]),
                          const SizedBox(width: 12),
                          Text(
                            'Encrypted Credentials',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_showCredentials) ...[
                        const Text(
                          'Login credentials are encrypted for security.',
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showPinDialog,
                          icon: const Icon(Icons.visibility),
                          label: const Text('View Credentials'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                      ] else ...[
                        if (_decryptedUsername != null) ...[
                          const Text(
                            'Username',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _decryptedUsername!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () => _copyToClipboard(
                                    _decryptedUsername!,
                                    'Username',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (_decryptedPassword != null) ...[
                          const Text(
                            'Password',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SelectableText(
                                    _decryptedPassword!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 20),
                                  onPressed: () => _copyToClipboard(
                                    _decryptedPassword!,
                                    'Password',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showCredentials = false;
                              _decryptedUsername = null;
                              _decryptedPassword = null;
                            });
                          },
                          icon: const Icon(Icons.visibility_off),
                          label: const Text('Hide Credentials'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (widget.asset.encryptedUsername == null &&
                widget.asset.encryptedPassword == null)
              Card(
                color: Colors.grey[100],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No credentials stored for this asset',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
