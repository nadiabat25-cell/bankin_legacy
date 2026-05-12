import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../models/emergency_contact_model.dart';
import '../models/user_model.dart';
import 'beneficiary_dashboard_screen.dart';
import 'beneficiary_request_emergency_access_screen.dart';

class EmergencyLoginScreen extends StatefulWidget {
  const EmergencyLoginScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyLoginScreen> createState() => _EmergencyLoginScreenState();
}

class _EmergencyLoginScreenState extends State<EmergencyLoginScreen> {
  int _step = 1;

  final _formKey         = GlobalKey<FormState>();
  final _nameController  = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController   = TextEditingController();
  final _pinController   = TextEditingController();

  bool _isLoading  = false;
  bool _obscurePin = true;

  String? _verificationId;
  int?    _resendToken;

  // null = normal step flow; 'not_confirmed' | 'not_triggered' | 'request_pending' | 'request_rejected' | 'access_revoked'
  String? _accessStatus;

  EmergencyContactModel? _matchedContact;
  UserModel?             _deceasedUser;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      FirebaseAuth.instance.setSettings(appVerificationDisabledForTesting: true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  // ── Normalize phone: strip spaces/dashes, convert 01X → +601X ─────────────
  String _normalizePhone(String phone) {
    // Remove spaces, dashes, parentheses
    String p = phone.replaceAll(RegExp(r'[\s\-()]'), '');

    // If already has country code, return as-is
    if (p.startsWith('+')) return p;

    // Malaysian local format: 01X... → +601X...
    if (p.startsWith('0')) {
      return '+6$p';
    }

    // If starts with 6 (without +), add +
    if (p.startsWith('6')) {
      return '+$p';
    }

    return p;
  }

  // ── STEP 1: Look up beneficiary, check inactivity + request status ────────
  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _accessStatus = null; });

    try {
      final db = await DatabaseService.instance.database;

      // 1a. Find contact by email
      final rows = await db.query(
        'emergency_contacts',
        where: 'email = ?',
        whereArgs: [_emailController.text.trim()],
      );

      if (rows.isEmpty) {
        _showError('No beneficiary record found with this email address.');
        setState(() => _isLoading = false);
        return;
      }

      // 1b. Match full name (case-insensitive)
      final matchedRow = rows.firstWhere(
        (r) => (r['fullName'] as String).toLowerCase() ==
            _nameController.text.trim().toLowerCase(),
        orElse: () => {},
      );

      if (matchedRow.isEmpty) {
        _showError('Full name does not match our records for this email.');
        setState(() => _isLoading = false);
        return;
      }

      final contact = EmergencyContactModel.fromMap(matchedRow);

      // 1c. Normalize phones
      final registeredPhone = _normalizePhone(contact.phoneNumber);
      final enteredPhone    = _normalizePhone(_phoneController.text.trim());

      if (registeredPhone != enteredPhone) {
        _showError('Phone number does not match our records.');
        setState(() => _isLoading = false);
        return;
      }

      _matchedContact = contact;

      // 1d. Only confirmed beneficiaries may proceed
      if (contact.invitationStatus != 'confirmed') {
        setState(() { _accessStatus = 'not_confirmed'; _isLoading = false; });
        return;
      }

      // 1e. If access was previously granted → verify the latest request is still approved
      if (contact.accessGranted) {
        final latestReq = await db.query(
          'emergency_access_requests',
          columns: ['id', 'status'],
          where: 'contactId = ?',
          whereArgs: [contact.id],
          orderBy: 'requestedAt DESC',
          limit: 1,
        );
        if (latestReq.isEmpty) {
          await _doSendOtp(enteredPhone);
          return;
        }
        final latestStatus = latestReq.first['status'] as String;
        if (latestStatus == 'approved') {
          await _doSendOtp(enteredPhone);
        } else if (latestStatus == 'revoked') {
          setState(() { _accessStatus = 'access_revoked'; _isLoading = false; });
        } else if (latestStatus == 'pending') {
          setState(() { _accessStatus = 'request_pending'; _isLoading = false; });
        } else {
          setState(() { _accessStatus = 'request_rejected'; _isLoading = false; });
        }
        return;
      }

      // 1e. Calculate inactivity dynamically (same logic as admin dashboard)
      final userRows = await db.query(
        'users',
        columns: ['lastActive', 'inactivity_period_days'],
        where: 'id = ?',
        whereArgs: [contact.userId],
      );
      bool isInactive = false;
      if (userRows.isNotEmpty) {
        final lastActive = userRows.first['lastActive'] as int? ?? 0;
        final periodDays = userRows.first['inactivity_period_days'] as int? ?? 3;
        final threshold = periodDays == -1
            ? const Duration(minutes: 1)
            : Duration(days: periodDays);
        final elapsed = Duration(
            milliseconds: DateTime.now().millisecondsSinceEpoch - lastActive);
        isInactive = elapsed > threshold;
      }

      if (!isInactive) {
        setState(() { _accessStatus = 'not_triggered'; _isLoading = false; });
        return;
      }

      // 1f. Inactivity triggered — check latest access request status
      final requestRows = await db.query(
        'emergency_access_requests',
        columns: ['id', 'status'],
        where: 'contactId = ?',
        whereArgs: [contact.id],
        orderBy: 'requestedAt DESC',
        limit: 1,
      );

      if (requestRows.isEmpty) {
        // No request yet — navigate to document upload screen
        setState(() => _isLoading = false);
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BeneficiaryRequestAccessScreen(contact: contact),
          ),
        );
        return;
      }

      final reqStatus = requestRows.first['status'] as String;
      if (reqStatus == 'approved') {
        await _doSendOtp(enteredPhone);
      } else if (reqStatus == 'pending') {
        setState(() { _accessStatus = 'request_pending'; _isLoading = false; });
      } else if (reqStatus == 'revoked') {
        setState(() { _accessStatus = 'access_revoked'; _isLoading = false; });
      } else {
        // rejected
        setState(() { _accessStatus = 'request_rejected'; _isLoading = false; });
      }
    } catch (e) {
      _showError('Error: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _doSendOtp(String enteredPhone) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: enteredPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        _showError('OTP failed: ${e.message}');
        setState(() => _isLoading = false);
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _resendToken    = resendToken;
          _step           = 2;
          _isLoading      = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
      forceResendingToken: _resendToken,
    );
  }

  // ── STEP 2: Verify OTP ────────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().length != 6) {
      _showError('Please enter the 6-digit OTP.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );
      await _signInWithCredential(credential);
    } catch (e) {
      _showError('Invalid OTP. Please try again.');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = await DatabaseService.instance
          .getUserById(_matchedContact!.userId);
      if (user == null) {
        _showError('Account holder information not found.');
        setState(() => _isLoading = false);
        return;
      }
      _deceasedUser = user;
      setState(() {
        _step      = 3;
        _isLoading = false;
      });
    } catch (e) {
      _showError('Verification failed: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  // ── STEP 3: Verify PIN ────────────────────────────────────────────────────
  Future<void> _verifyPin() async {
    if (_pinController.text.trim().length != 6) {
      _showError('Please enter the 6-digit PIN.');
      return;
    }
    setState(() => _isLoading = true);

    try {
      final icNumber    = _deceasedUser!.icNumber;
      final expectedPin = icNumber.substring(icNumber.length - 6);

      if (_pinController.text.trim() != expectedPin) {
        _showError(
            'Incorrect PIN. Use the last 6 digits of the account holder\'s IC number.');
        setState(() => _isLoading = false);
        return;
      }

      await DatabaseService.instance.logActivity({
        'userId':    _matchedContact!.userId,
        'username':  _matchedContact!.fullName,
        'userType':  'beneficiary',
        'action':    'emergency_login',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BeneficiaryDashboardScreen(
            beneficiary:  _matchedContact!,
            deceasedUser: _deceasedUser!,
          ),
        ),
      );
    } catch (e) {
      _showError('Error: ${e.toString()}');
      setState(() => _isLoading = false);
    }
  }

  // ── Status view (inactivity not triggered / request pending / rejected) ───
  Widget _buildStatusView() {
    final isNotConfirmed = _accessStatus == 'not_confirmed';
    final isNotTriggered = _accessStatus == 'not_triggered';
    final isPending      = _accessStatus == 'request_pending';
    final isRevoked      = _accessStatus == 'access_revoked';

    final Color cardColor;
    final Color iconColor;
    final IconData icon;
    final String title;
    final String message;

    if (isNotConfirmed) {
      cardColor = Colors.purple[50]!;
      iconColor = Colors.purple[700]!;
      icon      = Icons.how_to_reg;
      title     = 'Beneficiary Not Yet Confirmed';
      message   = 'Your beneficiary designation has not been confirmed by the administrator yet.\n\n'
          'Please wait for the account holder\'s administrator to confirm your invitation before attempting emergency access.';
    } else if (isNotTriggered) {
      cardColor = Colors.orange[50]!;
      iconColor = Colors.orange[700]!;
      icon      = Icons.lock_clock;
      title     = 'Account Holder Is Still Active';
      message   = 'The account holder has not exceeded their inactivity period.\n\n'
          'Emergency access is only available after the account holder has been inactive for their set period. Please check back later.';
    } else if (isPending) {
      cardColor = Colors.blue[50]!;
      iconColor = Colors.blue[700]!;
      icon      = Icons.hourglass_top;
      title     = 'Request Pending Review';
      message   = 'Your access request has been submitted and is currently being reviewed by the administrator.\n\n'
          'Please check back later or wait for an email notification.';
    } else if (isRevoked) {
      cardColor = Colors.grey[100]!;
      iconColor = Colors.grey[700]!;
      icon      = Icons.lock_reset;
      title     = 'Access Revoked';
      message   = 'The account holder has logged back in, which means they are active again.\n\n'
          'Your emergency access has been automatically revoked. If you still need access, please contact the administrator.';
    } else {
      cardColor = Colors.red[50]!;
      iconColor = Colors.red[700]!;
      icon      = Icons.cancel;
      title     = 'Access Request Rejected';
      message   = 'Your emergency access request was rejected by the administrator.\n\n'
          'Please check your email for the reason. You may submit a new request with additional supporting documents.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(icon, size: 64, color: iconColor),
                const SizedBox(height: 16),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: iconColor), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                Text(message, style: TextStyle(fontSize: 14, color: iconColor, height: 1.5), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_accessStatus == 'request_rejected' || _accessStatus == 'access_revoked') ...[
          ElevatedButton.icon(
            onPressed: () {
              setState(() => _accessStatus = null);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BeneficiaryRequestAccessScreen(contact: _matchedContact!),
                ),
              );
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('Submit New Request'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton(
          onPressed: () => setState(() { _accessStatus = null; _step = 1; }),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: Colors.orange[700]!),
          ),
          child: Text('Back', style: TextStyle(color: Colors.orange[700])),
        ),
      ],
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final orange = Colors.orange[700]!;

    return Scaffold(
      backgroundColor: Colors.orange[50],
      appBar: AppBar(
        title: const Text('Emergency Access'),
        backgroundColor: orange,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    shape: BoxShape.circle,
                  ),
                  child:
                  Icon(Icons.medical_services, size: 80, color: orange),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Emergency Beneficiary Access',
                style:
                TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Only for designated beneficiaries of deceased account holders',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _buildStepIndicator(),
              const SizedBox(height: 28),
              if (_accessStatus != null) _buildStatusView() else ...[
                if (_step == 1) _buildStep1(),
                if (_step == 2) _buildStep2(),
                if (_step == 3) _buildStep3(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final labels = ['Identity', 'Verify OTP', 'PIN'];
    return Row(
      children: List.generate(3, (i) {
        final active   = i + 1 == _step;
        final done     = i + 1 < _step;
        final color    = done || active ? Colors.orange[700]! : Colors.grey[300]!;
        final txtColor = done || active ? Colors.white : Colors.grey[600]!;
        return Expanded(
          child: Row(
            children: [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: done ? Colors.orange[700] : Colors.grey[300],
                  ),
                ),
              Column(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: color,
                    child: done
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${i + 1}',
                        style: TextStyle(
                            color: txtColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  Text(labels[i],
                      style: TextStyle(
                          fontSize: 11,
                          color: active
                              ? Colors.orange[700]
                              : Colors.grey[600])),
                ],
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    color: done ? Colors.orange[700] : Colors.grey[300],
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  // ── Step 1: Identity ───────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.orange[50],
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.info, color: Colors.orange[700], size: 18),
                    const SizedBox(width: 8),
                    const Text('Required Information',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                  const SizedBox(height: 8),
                  const Text('1. Your full name (as registered)',
                      style: TextStyle(fontSize: 13)),
                  const Text('2. Your registered email address',
                      style: TextStyle(fontSize: 13)),
                  const Text('3. Your registered phone number',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name (as per MyKad)',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
            v == null || v.isEmpty ? 'Please enter your full name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
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
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone),
              hintText: '+601x-xxxxxxxx',
              helperText: 'Include country code, e.g. +6012-3456789',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            keyboardType: TextInputType.phone,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter phone number';
              return null;
            },
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _isLoading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.white)))
                : const Text('Send OTP',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.orange[700]!),
            ),
            child: Text('Back to Login',
                style: TextStyle(color: Colors.orange[700])),
          ),
        ],
      ),
    );
  }

  // ── Step 2: OTP ────────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.blue[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.sms, color: Colors.blue[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'A 6-digit OTP has been sent to\n${_normalizePhone(_phoneController.text.trim())}',
                    style: TextStyle(color: Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _otpController,
          decoration: const InputDecoration(
            labelText: 'Enter 6-digit OTP',
            prefixIcon: Icon(Icons.lock_clock),
            border: OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
            setState(() => _step = 1);
            _sendOtp();
          },
          child: Text('Resend OTP',
              style: TextStyle(color: Colors.orange[700])),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyOtp,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Verify OTP',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => setState(() => _step = 1),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: BorderSide(color: Colors.orange[700]!),
          ),
          child:
          Text('Back', style: TextStyle(color: Colors.orange[700])),
        ),
      ],
    );
  }

  // ── Step 3: PIN ────────────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.green[50],
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.verified_user, color: Colors.green[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Phone verified! Now enter the PIN to access the legacy details.',
                    style: TextStyle(color: Colors.green[900]),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          color: Colors.orange[50],
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'PIN = last 6 digits of the deceased account holder\'s IC number.',
              style: TextStyle(fontSize: 13, color: Colors.orange[900]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _pinController,
          obscureText: _obscurePin,
          decoration: InputDecoration(
            labelText: 'PIN (Last 6 digits of account holder\'s IC)',
            prefixIcon: const Icon(Icons.lock),
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePin ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _obscurePin = !_obscurePin),
            ),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyPin,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
          child: _isLoading
              ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white)))
              : const Text('Access Legacy Details',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ),
      ],
    );
  }
}
