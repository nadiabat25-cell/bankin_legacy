import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/aes_encryption_service.dart';
import '../models/user_model.dart';
import 'ekyc_upload_id_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _icNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController        = TextEditingController();
  final _secretPhraseController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _icNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _secretPhraseController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final aesKey = AESEncryptionService.generateKey();
    final hashedPhrase = sha256
        .convert(utf8.encode(_secretPhraseController.text.trim().toLowerCase()))
        .toString();

    final user = UserModel(
      username:     _usernameController.text.trim(),
      password:     _passwordController.text,
      fullName:     _fullNameController.text.trim(),
      icNumber:     _icNumberController.text.trim(),
      email:        _emailController.text.trim(),
      phoneNumber:  _phoneController.text.trim(),
      pin:          '', // PIN will be set on first login after eKYC approval
      secretPhrase: hashedPhrase,
      aesKey:       AESEncryptionService.keyToString(aesKey),
      lastActive:   DateTime.now().millisecondsSinceEpoch,
      createdAt:    DateTime.now().millisecondsSinceEpoch,
    );

    // ✅ Navigate to eKYC instead of registering directly
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EkycUploadIdScreen(user: user),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register New Account'),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withAlpha(25),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create Your Secure Account',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All information is encrypted and secure',
                    style:
                    TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name (as per MyKad)',
                      prefixIcon: Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Please enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _icNumberController,
                    decoration: const InputDecoration(
                      labelText: 'IC Number (12 digits)',
                      prefixIcon: Icon(Icons.credit_card),
                      hintText: 'e.g., 990123105678',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Please enter IC number'
                        : v.length != 12
                        ? 'IC number must be 12 digits'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Please enter email'
                        : !v.contains('@')
                        ? 'Please enter valid email'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: Icon(Icons.phone),
                      hintText: 'e.g., 0123456789',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.isEmpty
                        ? 'Please enter phone number'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.account_circle),
                      helperText: '6–16 chars · letters, numbers, dot (.) and underscore (_) allowed',
                      helperMaxLines: 2,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter username';
                      if (v.length < 6 || v.length > 16) return 'Username must be 6–16 characters';
                      if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(v)) return 'Only letters, numbers, dots (.) and underscores (_) allowed';
                      if (!v.contains(RegExp(r'[a-zA-Z]'))) return 'Username must include at least one letter';
                      if (!v.contains(RegExp(r'[0-9]'))) return 'Username must include at least one number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      helperText: '8–12 chars · uppercase · lowercase · number · special character',
                      helperMaxLines: 2,
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter password';
                      if (v.length < 8 || v.length > 12) return 'Password must be 8–12 characters';
                      if (!v.contains(RegExp(r'[A-Z]'))) return 'Password must include at least one uppercase letter';
                      if (!v.contains(RegExp(r'[a-z]'))) return 'Password must include at least one lowercase letter';
                      if (!v.contains(RegExp(r'[0-9]'))) return 'Password must include at least one number';
                      if (!v.contains(RegExp(r"[!@#$%^&*()\[\]{}|<>,.?:;'`~_\-+=\\/@]"))) return 'Password must include at least one special character';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() =>
                        _obscureConfirmPassword =
                        !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Please confirm password'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  // Secret Phrase info card
                  Card(
                    color: Colors.orange[50],
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Secret Phrase is used to verify your identity on first login. '
                              'Choose something memorable but hard to guess (e.g. "MyFirstCar2010").',
                              style: TextStyle(fontSize: 12, color: Colors.orange[900]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _secretPhraseController,
                    decoration: const InputDecoration(
                      labelText: 'Secret Phrase',
                      prefixIcon: Icon(Icons.key),
                      hintText: 'e.g. MyFirstCar2010',
                      helperText: 'You will need this on your first login',
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Please enter a secret phrase'
                        : v.trim().length < 6
                        ? 'Secret phrase must be at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white),
                      ),
                    )
                        : const Text(
                      'Next → Verify Identity (eKYC)',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already have an account? Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
