import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:async';
import '../models/user_model.dart';
import '../models/admin_model.dart';
import 'database_service.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  AdminModel? _currentAdmin;
  bool _isEmergencyMode = false;

  // ── Inactivity auto-logout ─────────────────────────────────────────────────
  Timer? _inactivityTimer;
  bool _wasAutoLoggedOut = false;
  bool get wasAutoLoggedOut => _wasAutoLoggedOut;
  void clearAutoLogoutFlag() => _wasAutoLoggedOut = false;

  void resetInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!isLoggedIn) return;
    _inactivityTimer = Timer(const Duration(minutes: 1), () {
      _wasAutoLoggedOut = true;
      logout();
    });
  }

  // ── Login attempt limiting ─────────────────────────────────────────────────
  final Map<String, int> _failedAttempts = {};
  final Map<String, DateTime> _lockUntil = {};

  bool _isLocked(String key) {
    final lockTime = _lockUntil[key];
    if (lockTime == null) return false;
    if (DateTime.now().isAfter(lockTime)) {
      _lockUntil.remove(key);
      _failedAttempts.remove(key);
      return false;
    }
    return true;
  }

  int remainingLockSeconds(String key) {
    final lockTime = _lockUntil[key];
    if (lockTime == null) return 0;
    return lockTime.difference(DateTime.now()).inSeconds.clamp(0, 60);
  }

  void _recordFailure(String key) {
    _failedAttempts[key] = (_failedAttempts[key] ?? 0) + 1;
    if (_failedAttempts[key]! >= 3) {
      _lockUntil[key] = DateTime.now().add(const Duration(minutes: 1));
    }
  }

  void _clearAttempts(String key) {
    _failedAttempts.remove(key);
    _lockUntil.remove(key);
  }

  UserModel? get currentUser => _currentUser;
  AdminModel? get currentAdmin => _currentAdmin;
  bool get isLoggedIn => _currentUser != null || _currentAdmin != null;
  bool get isAdmin => _currentAdmin != null;
  bool get isEmergencyMode => _isEmergencyMode;

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  void updateCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  // ── LOGIN USER ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginUser(
      String username, String password) async {
    try {
      // Check lockout
      if (_isLocked(username)) {
        final secs = remainingLockSeconds(username);
        return {
          'success': false,
          'message': 'Too many failed attempts. Try again in $secs seconds.',
          'lockoutSeconds': secs,
        };
      }

      final user = await DatabaseService.instance.getUserByUsername(username);
      if (user == null) {
        _recordFailure(username);
        return {'success': false, 'message': 'User not found'};
      }

      final hashedPassword = _hashPassword(password);
      if (user.password != hashedPassword) {
        _recordFailure(username);
        final locked = _isLocked(username);
        return {
          'success': false,
          'message': locked
              ? 'Too many failed attempts. Try again in ${remainingLockSeconds(username)} seconds.'
              : 'Incorrect password. ${3 - (_failedAttempts[username] ?? 0)} attempt(s) remaining.',
          if (locked) 'lockoutSeconds': remainingLockSeconds(username),
        };
      }

      // ── eKYC STATUS GATE ──────────────────────────────────────────────────
      final ekycStatus = user.ekycStatus; // ← FIXED: removed redundant ?? 'pending'

      if (ekycStatus == 'pending') {
        return {
          'success': false,
          'message':
          'Your account is pending admin verification.\n\nYou will receive an email once your registration is approved.',
        };
      }

      if (ekycStatus == 'rejected') {
        return {
          'success': false,
          'message':
          'Your registration was rejected by the administrator.\n\nPlease check your email for the reason and register again.',
        };
      }
      // ─────────────────────────────────────────────────────────────────────

      _clearAttempts(username);
      _currentUser = user;
      _isEmergencyMode = false;
      resetInactivityTimer();
      // Push local SQLite data to Firestore so other devices always get the
      // correct (single-hashed) password and all sensitive fields.
      DatabaseService.instance.syncUserToFirestore(user.id!);
      await DatabaseService.instance.updateUserLastActive(user.id!);
      await DatabaseService.instance.logActivity({
        'userId':     user.id,
        'adminId':    null,
        'username':   username,
        'userType':   'user',
        'action':     'login',
        'ipAddress':  'local',
        'deviceInfo': 'mobile',
        'timestamp':  DateTime.now().millisecondsSinceEpoch,
      });

      // Revoke any emergency access that was granted while user was inactive
      final revoked = await DatabaseService.instance.revokeEmergencyAccessOnLogin(user.id!);
      if (revoked.isNotEmpty) {
        final names = revoked.join(', ');
        await DatabaseService.instance.createNotification(
          userId:  user.id!,
          title:   'Emergency Access Revoked',
          message: 'You have logged back in. Emergency access granted to $names has been automatically revoked.',
          type:    'emergency_revoked',
        );
      }

      notifyListeners();
      return {'success': true, 'message': 'Login successful', 'user': user};
    } catch (e) {
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  // ── LOGIN ADMIN ────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> loginAdmin(
      String username, String password, String secretKey) async {
    const lockKey = 'admin';
    try {
      // Check lockout
      if (_isLocked(lockKey)) {
        final secs = remainingLockSeconds(lockKey);
        return {
          'success': false,
          'message': 'Too many failed attempts. Try again in $secs seconds.',
          'lockoutSeconds': secs,
        };
      }

      final admin = await DatabaseService.instance.getAdminByUsername(username);
      if (admin == null) {
        _recordFailure(lockKey);
        return {'success': false, 'message': 'Admin not found'};
      }

      final hashedPassword = _hashPassword(password);
      if (admin.password != hashedPassword) {
        _recordFailure(lockKey);
        final locked = _isLocked(lockKey);
        return {
          'success': false,
          'message': locked
              ? 'Too many failed attempts. Try again in ${remainingLockSeconds(lockKey)} seconds.'
              : 'Incorrect password. ${3 - (_failedAttempts[lockKey] ?? 0)} attempt(s) remaining.',
          if (locked) 'lockoutSeconds': remainingLockSeconds(lockKey),
        };
      }

      final hashedKey = _hashPassword(secretKey);
      if (admin.secretKey != hashedKey) {
        _recordFailure(lockKey);
        final locked = _isLocked(lockKey);
        return {
          'success': false,
          'message': locked
              ? 'Too many failed attempts. Try again in ${remainingLockSeconds(lockKey)} seconds.'
              : 'Incorrect secret key. ${3 - (_failedAttempts[lockKey] ?? 0)} attempt(s) remaining.',
          if (locked) 'lockoutSeconds': remainingLockSeconds(lockKey),
        };
      }

      _clearAttempts(lockKey);
      _currentAdmin = admin;
      resetInactivityTimer();

      await DatabaseService.instance.logActivity({
        'userId':     null,
        'adminId':    admin.id,
        'username':   username,
        'userType':   'admin',
        'action':     'login',
        'ipAddress':  'local',
        'deviceInfo': 'mobile',
        'timestamp':  DateTime.now().millisecondsSinceEpoch,
      });

      notifyListeners();
      return {
        'success': true,
        'message': 'Admin login successful',
        'admin': admin
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Admin login failed: ${e.toString()}'
      };
    }
  }

  // ── EMERGENCY LOGIN ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> emergencyLogin(
      String fullName, String icNumber, String pin) async {
    try {
      final contacts = await DatabaseService.instance
          .getEmergencyContactsByIcNumber(icNumber);
      if (contacts.isEmpty) {
        return {
          'success': false,
          'message': 'No emergency access found for this IC number',
        };
      }

      final matchingContact = contacts.firstWhere(
            (c) => c.fullName.toLowerCase() == fullName.toLowerCase(),
        orElse: () => contacts.first,
      );

      if (!matchingContact.accessGranted) {
        return {
          'success': false,
          'message':
          'Emergency access not yet granted. Please contact administrator.',
        };
      }

      final user = await DatabaseService.instance
          .getUserById(matchingContact.userId);
      if (user == null) {
        return {
          'success': false,
          'message': 'Associated user account not found'
        };
      }

      if (user.icNumber.length >= 6) {
        final expectedPin =
        user.icNumber.substring(user.icNumber.length - 6);
        if (pin != expectedPin) {
          return {
            'success': false,
            'message':
            'Incorrect PIN. Use last 6 digits of deceased user\'s IC number.',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Invalid user IC number format'
        };
      }

      _currentUser = user;
      _isEmergencyMode = true;
      resetInactivityTimer();

      await DatabaseService.instance.logActivity({
        'userId':     user.id,
        'adminId':    null,
        'username':   fullName,
        'userType':   'emergency',
        'action':     'emergency_login',
        'ipAddress':  'local',
        'deviceInfo': 'mobile',
        'timestamp':  DateTime.now().millisecondsSinceEpoch,
      });

      notifyListeners();
      return {
        'success': true,
        'message': 'Emergency access granted',
        'user': user,
        'contact': matchingContact,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Emergency login failed: ${e.toString()}'
      };
    }
  }

  // ── REGISTER ───────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> register(UserModel user) async {
    try {
      final existing =
      await DatabaseService.instance.getUserByUsername(user.username);
      if (existing != null) {
        return {'success': false, 'message': 'Username already exists'};
      }

      final hashedPassword = _hashPassword(user.password);
      final newUser = user.copyWith(
        password: hashedPassword,
        ekycStatus: 'pending', // always starts as pending
      );
      final userId = await DatabaseService.instance.createUser(newUser);
      return {
        'success': true,
        'message': 'Registration submitted. Please wait for admin approval.',
        'userId': userId,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration failed: ${e.toString()}'
      };
    }
  }

  // ── LOGOUT ─────────────────────────────────────────────────────────────────
  void logout() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _currentUser = null;
    _currentAdmin = null;
    _isEmergencyMode = false;
    notifyListeners();
  }
}
