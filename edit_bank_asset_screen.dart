import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/aes_encryption_service.dart';
import '../models/bank_asset_model.dart';

class EditBankAssetScreen extends StatefulWidget {
  final BankAssetModel asset;
  const EditBankAssetScreen({Key? key, required this.asset}) : super(key: key);

  @override
  State<EditBankAssetScreen> createState() => _EditBankAssetScreenState();
}

class _EditBankAssetScreenState extends State<EditBankAssetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _institutionNameController = TextEditingController();
  final _accountIdentifierController = TextEditingController();
  final _estimatedValueController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _specialInstructionsController = TextEditingController();
  String _selectedAssetType = 'Bank Account';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _changeCredentials = false;
  final List<String> _assetTypes = ['Bank Account', 'Savings Account', 'Fixed Deposit', 'Investment Account', 'Credit Card', 'Insurance Policy', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadAssetData();
  }

  void _loadAssetData() {
    _selectedAssetType = widget.asset.assetType;
    _institutionNameController.text = widget.asset.institutionName;
    _accountIdentifierController.text = widget.asset.accountIdentifier ?? '';
    _estimatedValueController.text = widget.asset.estimatedValue ?? '';
    _specialInstructionsController.text = widget.asset.specialInstructions ?? '';
  }

  @override
  void dispose() {
    _institutionNameController.dispose();
    _accountIdentifierController.dispose();
    _estimatedValueController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _specialInstructionsController.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  // PIN verification dialog — returns true if PIN is correct
  Future<bool> _verifyPin({required String actionLabel}) async {
    final pinController = TextEditingController();
    bool obscure = true;
    bool? result;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Verify PIN'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your 6-digit PIN to $actionLabel.',
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: const Icon(Icons.pin),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[50],
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () { result = false; Navigator.pop(ctx); },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final authService = Provider.of<AuthService>(context, listen: false);
                final enteredHash = _hashPin(pinController.text.trim());
                if (enteredHash != authService.currentUser!.pin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Incorrect PIN. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                result = true;
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
              ),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _updateAsset() async {
    if (!_formKey.currentState!.validate()) return;

    // Capture context-dependent values before any await
    final authService = Provider.of<AuthService>(context, listen: false);
    final aesKey = authService.currentUser!.aesKey;

    // Require PIN before saving changes
    final verified = await _verifyPin(actionLabel: 'update this bank asset');
    if (!verified) return;

    setState(() => _isLoading = true);
    try {
      String? encryptedUsername = widget.asset.encryptedUsername;
      String? encryptedPassword = widget.asset.encryptedPassword;
      if (_changeCredentials) {
        final encryptionService = AESEncryptionService();
        encryptedUsername = _usernameController.text.isNotEmpty ? encryptionService.encrypt(_usernameController.text, aesKey) : null;
        encryptedPassword = _passwordController.text.isNotEmpty ? encryptionService.encrypt(_passwordController.text, aesKey) : null;
      }
      final updatedAsset = BankAssetModel(
        id: widget.asset.id,
        userId: widget.asset.userId,
        assetType: _selectedAssetType,
        institutionName: _institutionNameController.text.trim(),
        accountIdentifier: _accountIdentifierController.text.trim().isNotEmpty ? _accountIdentifierController.text.trim() : null,
        estimatedValue: _estimatedValueController.text.trim().isNotEmpty ? _estimatedValueController.text.trim() : null,
        encryptedUsername: encryptedUsername,
        encryptedPassword: encryptedPassword,
        specialInstructions: _specialInstructionsController.text.trim().isNotEmpty ? _specialInstructionsController.text.trim() : null,
        createdAt: widget.asset.createdAt,
      );
      await DatabaseService.instance.updateBankAsset(updatedAsset);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank asset updated successfully!'), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update asset: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAsset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Asset'),
        content: const Text('Are you sure you want to delete this asset? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    // Require PIN before deleting
    final verified = await _verifyPin(actionLabel: 'delete this bank asset');
    if (!verified) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.deleteBankAsset(widget.asset.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank asset deleted successfully!'), backgroundColor: Colors.orange));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete asset: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Bank Asset'),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _isLoading ? null : _deleteAsset, tooltip: 'Delete Asset')],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Update your asset information', style: TextStyle(color: Colors.blue[900]))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                initialValue: _selectedAssetType,
                decoration: const InputDecoration(labelText: 'Asset Type', prefixIcon: Icon(Icons.category)),
                items: _assetTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState(() => _selectedAssetType = value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _institutionNameController,
                decoration: const InputDecoration(labelText: 'Institution Name', prefixIcon: Icon(Icons.business), hintText: 'e.g., Maybank, CIMB, Public Bank'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.isEmpty ? 'Please enter institution name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _accountIdentifierController, decoration: const InputDecoration(labelText: 'Account Number (Optional)', prefixIcon: Icon(Icons.numbers), hintText: 'Last 4 digits or account ID')),
              const SizedBox(height: 16),
              TextFormField(controller: _estimatedValueController, decoration: const InputDecoration(labelText: 'Estimated Value (Optional)', prefixIcon: Icon(Icons.account_balance_wallet_outlined), prefixText: 'RM ', hintText: 'e.g., 50,000')),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Update Access Credentials'),
                subtitle: Text(
                  widget.asset.encryptedUsername != null ? 'Credentials are currently stored (encrypted)' : 'No credentials stored',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                value: _changeCredentials,
                onChanged: (value) => setState(() => _changeCredentials = value ?? false),
              ),
              const SizedBox(height: 16),
              if (_changeCredentials) ...[
                Text('Access Credentials (Encrypted)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                const SizedBox(height: 16),
                TextFormField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username/Login (Optional)', prefixIcon: Icon(Icons.person), hintText: 'Online banking username')),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password (Optional)',
                    prefixIcon: const Icon(Icons.lock),
                    hintText: 'Online banking password',
                    suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              const Divider(),
              const SizedBox(height: 8),
              TextFormField(
                controller: _specialInstructionsController,
                decoration: const InputDecoration(labelText: 'Special Instructions (Optional)', prefixIcon: Icon(Icons.note), hintText: 'Any special instructions for beneficiaries', alignLabelWithHint: true),
                maxLines: 4,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateAsset,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Text('Update Asset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}