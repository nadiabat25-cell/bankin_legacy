import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/emergency_contact_model.dart';

class EditBeneficiaryScreen extends StatefulWidget {
  final EmergencyContactModel beneficiary;
  const EditBeneficiaryScreen({Key? key, required this.beneficiary}) : super(key: key);

  @override
  State<EditBeneficiaryScreen> createState() => _EditBeneficiaryScreenState();
}

class _EditBeneficiaryScreenState extends State<EditBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedRelationship = 'Spouse';
  bool _isLoading = false;
  final List<String> _relationships = ['Spouse', 'Child', 'Parent', 'Sibling', 'Other Family', 'Friend', 'Other'];

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.beneficiary.fullName;
    _emailController.text = widget.beneficiary.email;
    _phoneController.text = widget.beneficiary.phoneNumber;
    _selectedRelationship = widget.beneficiary.relationship;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<bool> _verifyPin({required String actionLabel}) async {
    final storedPin = Provider.of<AuthService>(context, listen: false).currentUser?.pin ?? '';
    bool result = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final pinController = TextEditingController();
        bool obscure = true;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Row(children: [
              Icon(Icons.lock, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Verify PIN'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter your 6-digit PIN to $actionLabel.', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_hashPin(pinController.text.trim()) != storedPin) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Incorrect PIN. Please try again.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  result = true;
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );
    return result;
  }

  Future<void> _updateBeneficiary() async {
    if (!_formKey.currentState!.validate()) return;

    final verified = await _verifyPin(actionLabel: 'update this beneficiary');
    if (!verified) return;

    setState(() => _isLoading = true);
    try {
      final updatedBeneficiary = EmergencyContactModel(
        id: widget.beneficiary.id,
        userId: widget.beneficiary.userId,
        fullName: _fullNameController.text.trim(),
        icNumber: widget.beneficiary.icNumber,
        relationship: _selectedRelationship,
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        inheritancePercentage: '',
        accessGranted: widget.beneficiary.accessGranted,
        accessGrantedAt: widget.beneficiary.accessGrantedAt,
        createdAt: widget.beneficiary.createdAt,
      );
      await DatabaseService.instance.updateEmergencyContact(updatedBeneficiary);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beneficiary updated successfully!'), backgroundColor: Colors.green));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update beneficiary: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteBeneficiary() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Beneficiary'),
        content: const Text('Are you sure you want to remove this beneficiary? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final verified = await _verifyPin(actionLabel: 'delete this beneficiary');
    if (!verified) return;

    setState(() => _isLoading = true);
    try {
      await DatabaseService.instance.deleteEmergencyContact(widget.beneficiary.id!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beneficiary deleted successfully!'), backgroundColor: Colors.orange));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete beneficiary: ${e.toString()}'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Beneficiary'),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _isLoading ? null : _deleteBeneficiary, tooltip: 'Delete Beneficiary')],
      ),
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
                      Icon(Icons.edit, color: Colors.green[700]),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Update beneficiary information', style: TextStyle(color: Colors.green[900]))),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name (as per MyKad)', prefixIcon: Icon(Icons.person)),
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
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email)),
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
              if (widget.beneficiary.accessGranted)
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Access has been granted to this beneficiary', style: TextStyle(color: Colors.green[900]))),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
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
                        '• Beneficiaries can access your assets after administrator approval\n'
                            '• They will use the last 6 digits of YOUR IC number as PIN\n'
                            '• Their phone number is used for OTP verification\n'
                            '• Make sure to inform them about this system',
                        style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateBeneficiary,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.green),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                    : const Text('Update Beneficiary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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