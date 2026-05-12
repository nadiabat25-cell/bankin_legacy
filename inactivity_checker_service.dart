import 'dart:async';
import 'package:flutter/foundation.dart';
import 'database_service.dart';
import 'email_service.dart';

class InactivityCheckerService {
  static final InactivityCheckerService instance =
  InactivityCheckerService._init();
  Timer? _timer;

  InactivityCheckerService._init();

  void startChecking() {
    _checkInactiveUsers();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkInactiveUsers();
    });
  }

  void stopChecking() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkInactiveUsers() async {
    try {
      final newlyInactiveUsers =
      await DatabaseService.instance.checkAndMarkInactiveUsers();

      if (newlyInactiveUsers.isNotEmpty) {
        debugPrint(
            '🔴 Found ${newlyInactiveUsers.length} newly inactive users');

        for (var user in newlyInactiveUsers) {
          debugPrint('   - ${user['username']} (${user['email']})');

          // Get beneficiaries for this user
          final contacts = await DatabaseService.instance
              .getEmergencyContactsByUserId(user['id'] as int);

          // Notify each beneficiary via email to confirm inactivity
          for (var contact in contacts) {
            await EmailService.sendInactivityConfirmation(
              beneficiaryEmail: contact.email,
              beneficiaryName: contact.fullName,
              ownerName: user['fullName'] as String,
            );
            debugPrint(
                '✅ Inactivity email sent to beneficiary: ${contact.fullName}');
          }

          // Admin is notified via in-app dashboard badge only (no email)
          debugPrint(
              'ℹ️ Admin will see ${user['fullName']} in dashboard Inactive tab');
        }
      }
    } catch (e) {
      debugPrint('Error checking inactive users: $e');
    }
  }

  Future<void> checkNow() async {
    await _checkInactiveUsers();
  }
}
