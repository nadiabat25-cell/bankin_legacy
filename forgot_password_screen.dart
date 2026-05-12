import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/database_service.dart';
import '../models/user_model.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Steps: 'verify_identity' → 'verify_phrase' → 'set_password'
  String _step = 'verify_identity';
  bool _isLoading = false;

  // Step 1 controllers
  final _usernameController = TextEditingController();
  final _icNumberController  = TextEditingController();

  // Step 2 controller
  final _phraseController = TextEditingController();
  bool _obscurePhrase = true;

  // Step 3 controllers
  final _newPasswordController     = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword     = true;
  bool _obscureConfirmPassword = true;

  // The user found in step 1 — carried through to step 3
  UserModel? _foundUser;

  @override
  void dispose() {
    _usernameController.dispose();
    _icNumberController.dispose();
    _phraseController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  // ── STEP 1: Verify Username + IC Number ────────────────────────────────────
  Future<void> _verifyIdentity() async {
    final username = _usernameController.text.trim();
    final ic       = _icNumberController.text.trim();

    if (username.isEmpty || ic.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }
    if (ic.length != 12) {
      _showError('IC number must be 12 digits.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await DatabaseService.instance.getUserByUsername(username);
      if (user == null || user.icNumber != ic) {
        _showError('Username or IC number does not match our records.');
        return;
      }
      _foundUser = user;
      setState(() => _step = 'verify_phrase');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── STEP 2: Verify Secret Phrase ───────────────────────────────────────────
  void _verifyPhrase() {
    final entered     = _phraseController.text.trim().toLowerCase();
    final storedHash  = _foundUser?.secretPhrase ?? '';

    if (entered.isEmpty) {
      _showError('Please enter your secret phrase.');
      return;
    }
    if (_hash(entered) != storedHash) {
      _showError('Incorrect secret phrase. Please try again.');
      _phraseController.clear();
      return;
    }
    setState(() => _step = 'set_password');
  }

  // ── STEP 3: Set New Password ───────────────────────────────────────────────
  Future<void> _resetPassword() async {
    final newPass     = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    // Password validation — same rules as registration
    if (newPass.length < 8 || newPass.length > 12) {
      _showError('Password must be 8–12 characters.');
      return;
    }
    if (!newPass.contains(RegExp(r'[A-Z]'))) {
      _showError('Password must include at least one uppercase letter.');
      return;
    }
    if (!newPass.contains(RegExp(r'[a-z]'))) {
      _showError('Password must include at least one lowercase letter.');
      return;
    }
    if (!newPass.contains(RegExp(r'[0-9]'))) {
      _showError('Password must include at least one number.');
      return;
    }
    if (!newPass.contains(RegExp(r"[!@#$%^&*()\[\]{}|<>,.?:;'`~_\-+=\\/@]"))) {
      _showError('Password must include at least one special character.');
      return;
    }
    if (newPass != confirmPass) {
      _showError('Passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final updatedUser = _foundUser!.copyWith(password: _hash(newPass));
      await DatabaseService.instance.updateUser(updatedUser);
      if (!mounted) return;
      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to reset password: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 8),
          Text('Password Reset!'),
        ]),
        content: const Text(
          'Your password has been reset successfully.\nPlease log in with your new password.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // back to login
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password'), elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress indicator
            _buildStepIndicator(),
            const SizedBox(height: 32),

            if (_step == 'verify_identity') _buildStep1(),
            if (_step == 'verify_phrase')  _buildStep2(),
            if (_step == 'set_password')   _buildStep3(),
          ],
        ),
      ),
    );
  }

  // Step indicator at top
  Widget _buildStepIndicator() {
    final steps = ['Verify Identity', 'Secret Phrase', 'New Password'];
    final currentIndex = _step == 'verify_identity' ? 0 : _step == 'verify_phrase' ? 1 : 2;
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive   = i == currentIndex;
        final isComplete = i < currentIndex;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: isComplete
                          ? Colors.green
                          : isActive
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300],
                      child: isComplete
                          ? const Icon(Icons.check, color: Colors.white, size: 16)
                          : Text('${i + 1}',
                              style: TextStyle(
                                color: isActive ? Colors.white : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              )),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[i],
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey[500],
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Divider(
                    color: isComplete ? Colors.green : Colors.grey[300],
                    thickness: 2,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ── Step 1 UI ──────────────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.person_search, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        const Text('Verify Your Identity', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Enter your username and IC number to continue.', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.blue[700], size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Both must match exactly what you registered with.', style: TextStyle(fontSize: 13, color: Colors.blue[900]))),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'Username',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _icNumberController,
          keyboardType: TextInputType.number,
          maxLength: 12,
          decoration: const InputDecoration(
            labelText: 'IC Number (12 digits)',
            prefixIcon: Icon(Icons.credit_card),
            hintText: 'e.g., 990123105678',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyIdentity,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ── Step 2 UI ──────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.key, size: 64, color: Colors.orange),
        const SizedBox(height: 16),
        const Text('Verify Secret Phrase', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Enter the secret phrase you set during registration.', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        Card(
          color: Colors.orange[50],
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.lock_outline, color: Colors.orange[700], size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('This confirms you are the real account owner.', style: TextStyle(fontSize: 13, color: Colors.orange[900]))),
            ]),
          ),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _phraseController,
          obscureText: _obscurePhrase,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Secret Phrase',
            prefixIcon: const Icon(Icons.key),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscurePhrase ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePhrase = !_obscurePhrase),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _verifyPhrase,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // ── Step 3 UI ──────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        const Text('Set New Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text('Choose a strong new password for your account.', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
        const SizedBox(height: 24),
        TextField(
          controller: _newPasswordController,
          obscureText: _obscureNewPassword,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'New Password',
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            helperText: '8–12 chars · uppercase · lowercase · number · special character',
            helperMaxLines: 2,
            suffixIcon: IconButton(
              icon: Icon(_obscureNewPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirmPassword,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _resetPassword,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
