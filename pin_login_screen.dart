import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'user_home_screen.dart';

class PinLoginScreen extends StatefulWidget {
  const PinLoginScreen({Key? key}) : super(key: key);

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  // Modes:
  // 'verify_pin'    — returning user enters existing PIN
  // 'verify_phrase' — first login, user enters secret phrase
  // 'setup_pin'     — phrase verified, user sets new PIN
  String _mode = 'verify_pin';
  bool _isLoading = true;

  final _pinController        = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _phraseController     = TextEditingController();
  bool _obscurePin     = true;
  bool _obscureConfirm = true;
  bool _obscurePhrase  = true;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _checkPinStatus() async {
    // Always start with secret phrase verification on every login
    setState(() {
      _mode = 'verify_phrase';
      _isLoading = false;
    });
  }

  // ── VERIFY SECRET PHRASE (first login) ────────────────────────────────────
  void _verifyPhrase() {
    final entered = _phraseController.text.trim().toLowerCase();
    if (entered.isEmpty) {
      _showError('Please enter your secret phrase.');
      return;
    }
    final authService   = Provider.of<AuthService>(context, listen: false);
    final storedHash    = authService.currentUser?.secretPhrase ?? '';
    final enteredHash   = _hashPin(entered); // reuse same SHA-256 hash

    if (enteredHash != storedHash) {
      _showError('Incorrect secret phrase. Please try again.');
      _phraseController.clear();
      return;
    }
    // Phrase correct → setup PIN (first login) or go straight to dashboard (returning user)
    final pin = authService.currentUser?.pin ?? '';
    if (pin.isEmpty) {
      setState(() => _mode = 'setup_pin');
    } else {
      _goHome();
    }
  }

  String _hashPin(String pin) {
    return sha256.convert(utf8.encode(pin)).toString();
  }

  // ── SET PIN (after OTP verified) ─────────────────────────────────────────
  Future<void> _saveNewPin() async {
    final pin     = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    if (pin.length != 6) {
      _showError('PIN must be exactly 6 digits.');
      return;
    }
    if (pin != confirm) {
      _showError('PINs do not match. Please try again.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user        = authService.currentUser!;
      final hashedPin   = _hashPin(pin);

      final updatedUser = user.copyWith(pin: hashedPin);
      await DatabaseService.instance.updateUser(updatedUser);
      authService.updateCurrentUser(updatedUser);

      if (!mounted) return;
      _goHome();
    } catch (e) {
      _showError('Failed to save PIN: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  // ── VERIFY PIN (returning user) ────────────────────────────────────────────
  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();

    if (pin.length != 6) {
      _showError('Please enter your 6-digit PIN.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final storedPin   = authService.currentUser!.pin;
      final enteredHash = _hashPin(pin);

      if (enteredHash != storedPin) {
        _showError('Incorrect PIN. Please try again.');
        _pinController.clear();
        setState(() => _isLoading = false);
        return;
      }

      if (!mounted) return;
      _goHome();
    } catch (e) {
      _showError('Error: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const UserHomeScreen()),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // ── Logout and go back to login ────────────────────────────────────────────
  void _logout() {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.logout();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final authService  = Provider.of<AuthService>(context, listen: false);
    final userName     = authService.currentUser?.fullName ?? 'User';
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _logout,
          tooltip: 'Back to Login',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _mode == 'verify_phrase' ? Icons.key
                          : _mode == 'setup_pin' ? Icons.pin
                          : Icons.lock,
                          size: 64,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── SECRET PHRASE (first login step 1) ──────────────
                      if (_mode == 'verify_phrase') ...[
                        const Text('Verify Secret Phrase', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('Welcome, $userName!\nEnter the secret phrase you set during registration.', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Card(
                          color: Colors.orange[50],
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Icon(Icons.key, color: Colors.orange[700], size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(
                                'This verifies you are the real account owner before setting your PIN.',
                                style: TextStyle(fontSize: 13, color: Colors.orange[900]),
                              )),
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
                            filled: true,
                            fillColor: Colors.white,
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
                          child: const Text('Verify Phrase', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],

                      // ── PIN SETUP (first login step 2) ───────────────────
                      if (_mode == 'setup_pin') ...[
                        const Text('Set Your PIN', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('Email verified! Now set your 6-digit PIN.', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Card(
                          color: Colors.blue[50],
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(
                                'Your PIN is required every login and for sensitive actions like editing or deleting assets.',
                                style: TextStyle(fontSize: 13, color: Colors.blue[900]),
                              )),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          obscureText: _obscurePin,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'New PIN',
                            prefixIcon: const Icon(Icons.pin),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPinController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          obscureText: _obscureConfirm,
                          decoration: InputDecoration(
                            labelText: 'Confirm PIN',
                            prefixIcon: const Icon(Icons.pin),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _saveNewPin,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('Set PIN & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],

                      // ── PIN VERIFY (returning user) ──────────────────────
                      if (_mode == 'verify_pin') ...[
                        const Text('Enter Your PIN', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        Text('Welcome back, $userName!', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Card(
                          color: Colors.green[50],
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Icon(Icons.verified_user, color: Colors.green[700], size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(
                                'Enter your 6-digit PIN to access your account.',
                                style: TextStyle(fontSize: 13, color: Colors.green[900]),
                              )),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _pinController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          obscureText: _obscurePin,
                          autofocus: true,
                          decoration: InputDecoration(
                            labelText: 'PIN',
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePin = !_obscurePin),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _verifyPin,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: const Text('Confirm PIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],

                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text('Back to Login'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
