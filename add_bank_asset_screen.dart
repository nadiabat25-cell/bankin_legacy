import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/aes_encryption_service.dart';
import '../models/bank_asset_model.dart';

class AddBankAssetScreen extends StatefulWidget {
  const AddBankAssetScreen({Key? key}) : super(key: key);

  @override
  State<AddBankAssetScreen> createState() => _AddBankAssetScreenState();
}

class _AddBankAssetScreenState extends State<AddBankAssetScreen> {
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

  final List<String> _assetTypes = [
    'Bank Account', 'Savings Account', 'Fixed Deposit',
    'Investment Account', 'Credit Card', 'Insurance Policy', 'Other',
  ];

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

  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser!.id!;
      final aesKey = authService.currentUser!.aesKey;
      String? encryptedUsername;
      String? encryptedPassword;
      if (_usernameController.text.isNotEmpty) {
        final encryptionService = AESEncryptionService();
        encryptedUsername = encryptionService.encrypt(_usernameController.text, aesKey);
      }
      if (_passwordController.text.isNotEmpty) {
        final encryptionService = AESEncryptionService();
        encryptedPassword = encryptionService.encrypt(_passwordController.text, aesKey);
      }
      final asset = BankAssetModel(
        userId: userId,
        assetType: _selectedAssetType,
        institutionName: _institutionNameController.text.trim(),
        accountIdentifier: _accountIdentifierController.text.trim().isNotEmpty ? _accountIdentifierController.text.trim() : null,
        estimatedValue: _estimatedValueController.text.trim().isNotEmpty ? _estimatedValueController.text.trim() : null,
        encryptedUsername: encryptedUsername,
        encryptedPassword: encryptedPassword,
        specialInstructions: _specialInstructionsController.text.trim().isNotEmpty ? _specialInstructionsController.text.trim() : null,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await DatabaseService.instance.createBankAsset(asset);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bank asset added successfully!'), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add asset: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Bank Asset'), elevation: 0),
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
                      Icon(Icons.info, color: Colors.blue[700]),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Add your financial assets to secure your legacy', style: TextStyle(color: Colors.blue[900]))),
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
              TextFormField(
                controller: _accountIdentifierController,
                decoration: const InputDecoration(labelText: 'Account Number (Optional)', prefixIcon: Icon(Icons.numbers), hintText: 'Last 4 digits or account ID'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _estimatedValueController,
                decoration: const InputDecoration(labelText: 'Estimated Value (Optional)', prefixIcon: Icon(Icons.account_balance_wallet_outlined), prefixText: 'RM ', hintText: 'e.g., 50,000'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text('Access Credentials (Encrypted)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[700])),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username/Login (Optional)', prefixIcon: Icon(Icons.person), hintText: 'Online banking username'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password (Optional)',
                  prefixIcon: const Icon(Icons.lock),
                  hintText: 'Online banking password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              TextFormField(
                controller: _specialInstructionsController,
                decoration: const InputDecoration(labelText: 'Special Instructions (Optional)', prefixIcon: Icon(Icons.note), hintText: 'Any special instructions for beneficiaries', alignLabelWithHint: true),
                maxLines: 4,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveAsset,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Text('Save Asset', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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