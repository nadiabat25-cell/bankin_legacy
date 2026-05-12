import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/auth_service.dart';
import 'admin_home_screen.dart';
import 'register_screen.dart';
import 'emergency_login_screen.dart';
import 'help_support_screen.dart';
import 'pin_login_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _secretKeyController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureSecretKey = true;
  bool _isAdminUsername = false;

  // Lockout countdown
  int _lockoutSeconds = 0;
  Timer? _countdownTimer;

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _lockoutSeconds = seconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_lockoutSeconds <= 1) {
        t.cancel();
        if (mounted) setState(() => _lockoutSeconds = 0);
      } else {
        if (mounted) setState(() => _lockoutSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _secretKeyController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    Map<String, dynamic> result;
    if (username == 'Admin_17') {
      result = await authService.loginAdmin(username, password, _secretKeyController.text.trim());
    } else {
      result = await authService.loginUser(username, password);
    }

    setState(() => _isLoading = false);

    if (!mounted) return;

    // Handle lockout
    if (result['lockoutSeconds'] != null) {
      _startCountdown(result['lockoutSeconds'] as int);
    }

    if (result['success']) {
      final isAdmin = authService.isAdmin;
      final displayName = isAdmin
          ? authService.currentAdmin?.fullName ?? 'Admin'
          : authService.currentUser?.fullName ?? 'User';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome back, $displayName!'),
          backgroundColor: Colors.green,
        ),
      );

      if (isAdmin) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        );
      } else {
        // Route through PIN screen — user must enter/set PIN before home
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PinLoginScreen()),
        );
      }
    } else {
      // ── Show special dialog for eKYC status issues ─────────────────────
      final message = result['message'] ?? 'Login failed';
      final isPending  = message.contains('pending admin verification');
      final isRejected = message.contains('rejected by the administrator');

      if (isPending || isRejected) {
        _showEkycStatusDialog(
          isPending: isPending,
          message: message,
        );
      } else {
        // Normal login error — plain snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEkycStatusDialog({
    required bool isPending,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isPending ? Icons.pending : Icons.cancel,
              color: isPending ? Colors.orange : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              isPending ? 'Account Pending' : 'Account Rejected',
              style: TextStyle(
                color: isPending ? Colors.orange[800] : Colors.red[800],
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isPending
                    ? Colors.orange.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isPending
                      ? Colors.orange.shade200
                      : Colors.red.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.email_outlined,
                    size: 18,
                    color: isPending
                        ? Colors.orange[700]
                        : Colors.red[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isPending
                          ? 'You will receive an email when your account is approved.'
                          : 'Check your email for the rejection reason and register again.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isPending
                            ? Colors.orange[900]
                            : Colors.red[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isPending)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const RegisterScreen()),
                );
              },
              child: const Text('Register Again'),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor:
              isPending ? Colors.orange : Colors.red,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── NEW: AppBar with Help button ──────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Help & Support',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const HelpSupportScreen()),
            ),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.account_balance,
                      size: 80,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Banking Legacy',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your Digital Legacy Vault',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Username Field
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person),
                        hintText: 'Enter your username',
                      ),
                      onChanged: (v) => setState(() => _isAdminUsername = v == 'Admin_17'),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please enter username'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock),
                        hintText: 'Enter your password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Please enter password'
                          : null,
                    ),

                    // Admin Secret Key Field (only shown for Admin_17)
                    if (_isAdminUsername) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _secretKeyController,
                        obscureText: _obscureSecretKey,
                        decoration: InputDecoration(
                          labelText: 'Secret Key',
                          prefixIcon: const Icon(Icons.vpn_key),
                          hintText: 'Enter admin secret key',
                          suffixIcon: IconButton(
                            icon: Icon(_obscureSecretKey
                                ? Icons.visibility_off
                                : Icons.visibility),
                            onPressed: () => setState(
                                () => _obscureSecretKey = !_obscureSecretKey),
                          ),
                        ),
                        validator: (v) => _isAdminUsername && (v == null || v.isEmpty)
                            ? 'Please enter secret key'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Lockout Banner
                    if (_lockoutSeconds > 0)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_clock, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Too many failed attempts. Try again in $_lockoutSeconds second${_lockoutSeconds == 1 ? '' : 's'}.',
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Login Button
                    ElevatedButton(
                      onPressed: (_isLoading || _lockoutSeconds > 0) ? null : _handleLogin,
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
                        'Login',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                                ),
                        child: const Text('Forgot Password?'),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Register Button
                    OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RegisterScreen()),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Create New Account'),
                    ),
                    const SizedBox(height: 24),

                    const Divider(),
                    const SizedBox(height: 16),

                    // Emergency Access Button
                    TextButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EmergencyLoginScreen()),
                      ),
                      icon: const Icon(Icons.emergency, color: Colors.orange),
                      label: const Text('Emergency Beneficiary Access', style: TextStyle(color: Colors.orange)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
