import 'database_service.dart';
import '../models/user_model.dart';

class LegacyService {
  // Fixed: Added const constructor
  const LegacyService();

  static const int inactivityThresholdDays = 3;

  static Future<List<UserModel>> checkInactiveUsers() async {
    final users = await DatabaseService.instance.getAllUsers();
    final now = DateTime.now();
    const threshold = Duration(days: inactivityThresholdDays);
    return users.where((user) {
      final lastActive = DateTime.fromMillisecondsSinceEpoch(user.lastActive);
      final difference = now.difference(lastActive);
      return difference > threshold;
    }).toList();
  }

  static Future<bool> shouldTriggerEmergencyAccess(int userId) async {
    final user = await DatabaseService.instance.getUserById(userId);
    if (user == null) return false;
    final lastActive = DateTime.fromMillisecondsSinceEpoch(user.lastActive);
    final now = DateTime.now();
    final daysSinceActive = now.difference(lastActive).inDays;
    return daysSinceActive >= inactivityThresholdDays;
  }

  static Future<Map<String, dynamic>> triggerEmergencyAccess(int userId) async {
    try {
      final contacts = await DatabaseService.instance.getEmergencyContactsByUserId(userId);
      if (contacts.isEmpty) {
        return {
          'success': false,
          'message': 'No emergency contacts found for this user'
        };
      }

      int grantedCount = 0;
      for (final contact in contacts) {
        await DatabaseService.instance.grantEmergencyAccess(contact.id!);
        grantedCount++;
      }

      return {
        'success': true,
        'message': 'Emergency access granted to $grantedCount contacts',
        'count': grantedCount
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to trigger emergency access: ${e.toString()}'
      };
    }
  }

  static String getInactivityStatus(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);
    if (difference.inDays >= inactivityThresholdDays) {
      return 'INACTIVE - Emergency Access Active';
    }
    if (difference.inDays >= 2) {
      return 'Warning - Approaching Threshold';
    }
    if (difference.inHours >= 24) {
      return 'Active - ${difference.inDays} day(s) ago';
    }
    if (difference.inHours >= 1) {
      return 'Active - ${difference.inHours} hour(s) ago';
    }
    return 'Active - ${difference.inMinutes} minute(s) ago';
  }
}

