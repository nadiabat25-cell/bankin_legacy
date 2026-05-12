import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({Key? key}) : super(key: key);

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPin = true;
  bool _obscureNewPin = true;
  bool _obscureConfirmPin = true;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser!;

      // Hash the entered current PIN to compare with stored hashed PIN
      final currentPinHash = sha256.convert(utf8.encode(_currentPinController.text)).toString();

      // Verify current PIN
      if (currentPinHash != currentUser.pin) {
        throw Exception('Current PIN is incorrect');
      }

      // Verify new PIN confirmation
      if (_newPinController.text != _confirmPinController.text) {
        throw Exception('New PIN and confirmation do not match');
      }

      // Hash the new PIN before storing
      final newPinHash = sha256.convert(utf8.encode(_newPinController.text)).toString();

      // Update PIN with hashed value
      final updatedUser = currentUser.copyWith(
        pin: newPinHash,
      );

      await DatabaseService.instance.updateUser(updatedUser);

      // Update the auth service with new user data
      authService.updateCurrentUser(updatedUser);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN changed successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change PIN'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Security Icon
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 50,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Change Your PIN',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your PIN is used to secure your account',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'PIN must be exactly 6 digits',
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Current PIN
              TextFormField(
                controller: _currentPinController,
                obscureText: _obscureCurrentPin,
                decoration: InputDecoration(
                  labelText: 'Current PIN',
                  prefixIcon: const Icon(Icons.lock_outline),
                  hintText: 'Enter your current PIN',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrentPin
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () {
                      setState(() => _obscureCurrentPin = !_obscureCurrentPin);
                    },
                  ),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter current PIN';
                  }
                  if (v.length != 6) {
                    return 'PIN must be 6 digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // New PIN
              TextFormField(
                controller: _newPinController,
                obscureText: _obscureNewPin,
                decoration: InputDecoration(
                  labelText: 'New PIN',
                  prefixIcon: const Icon(Icons.lock),
                  hintText: 'Enter your new PIN',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNewPin
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () {
                      setState(() => _obscureNewPin = !_obscureNewPin);
                    },
                  ),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please enter new PIN';
                  }
                  if (v.length != 6) {
                    return 'PIN must be 6 digits';
                  }
                  if (v == _currentPinController.text) {
                    return 'New PIN must be different from current PIN';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Confirm New PIN
              TextFormField(
                controller: _confirmPinController,
                obscureText: _obscureConfirmPin,
                decoration: InputDecoration(
                  labelText: 'Confirm New PIN',
                  prefixIcon: const Icon(Icons.lock),
                  hintText: 'Re-enter your new PIN',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPin
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () {
                      setState(() => _obscureConfirmPin = !_obscureConfirmPin);
                    },
                  ),
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: (v) {
                  if (v == null || v.isEmpty) {
                    return 'Please confirm new PIN';
                  }
                  if (v.length != 6) {
                    return 'PIN must be 6 digits';
                  }
                  if (v != _newPinController.text) {
                    return 'PINs do not match';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Change PIN Button
              ElevatedButton(
                onPressed: _isLoading ? null : _changePin,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                    : const Text(
                  'Change PIN',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              // Cancel Button
              OutlinedButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
