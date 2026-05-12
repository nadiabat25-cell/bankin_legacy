import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/email_service.dart';
import '../models/emergency_contact_model.dart';

class AddBeneficiaryScreen extends StatefulWidget {
  const AddBeneficiaryScreen({Key? key}) : super(key: key);

  @override
  State<AddBeneficiaryScreen> createState() => _AddBeneficiaryScreenState();
}

class _AddBeneficiaryScreenState extends State<AddBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRelationship = 'Spouse';
  bool _isLoading = false;
  final List<String> _relationships = ['Spouse', 'Child', 'Parent', 'Sibling', 'Other Family', 'Friend', 'Other'];

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveBeneficiary() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser!;
      final beneficiary = EmergencyContactModel(
        userId: currentUser.id!,
        fullName: _fullNameController.text.trim(),
        icNumber: '',
        relationship: _selectedRelationship,
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        inheritancePercentage: '',
        accessGranted: false,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      await DatabaseService.instance.createEmergencyContact(beneficiary);
      await EmailService.sendBeneficiaryNotification(
        beneficiaryEmail: _emailController.text.trim(),
        beneficiaryName: _fullNameController.text.trim(),
        ownerName: currentUser.fullName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beneficiary added & notified successfully!'), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add beneficiary: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Beneficiary'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Add trusted people who can access your assets in emergencies', style: TextStyle(color: Colors.green[900]))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name (as per MyKad)', prefixIcon: Icon(Icons.person), hintText: 'Enter beneficiary\'s full name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.isEmpty ? 'Please enter full name' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRelationship,
                decoration: const InputDecoration(labelText: 'Relationship', prefixIcon: Icon(Icons.family_restroom)),
                items: _relationships.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _selectedRelationship = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email), hintText: 'beneficiary@example.com'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number', prefixIcon: Icon(Icons.phone), hintText: '+601x-xxxxxxxx', helperText: 'Include country code, e.g. +6012-3456789'),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter phone number';
                  if (!v.startsWith('+')) return 'Include country code, e.g. +6012-3456789';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.warning, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Text('Important Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange[900])),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '• A notification email will be sent to the beneficiary to accept or decline\n'
                            '• Beneficiary info is only saved permanently when they accept and admin confirms\n'
                            '• If the beneficiary declines, you will be notified and their record will be removed\n'
                            '• Accepted beneficiaries can access your assets after administrator approval\n'
                            '• They will use the last 6 digits of YOUR IC number as PIN',
                        style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveBeneficiary,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Text('Add Beneficiary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: const Text('Cancel'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}