import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();
  FirebaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<String> _compressAndEncode(File file) async {
    final compressed = await FlutterImageCompress.compressWithFile(
      file.absolute.path,
      quality: 50,
      minWidth: 800,
      minHeight: 600,
    );
    if (compressed == null) {
      return base64Encode(await file.readAsBytes());
    }
    debugPrint(
      '📦 Compressed ${file.path.split('/').last}: '
          '${(await file.length() / 1024).toStringAsFixed(1)}KB → '
          '${(compressed.length / 1024).toStringAsFixed(1)}KB',
    );
    return base64Encode(compressed);
  }

  Future<Database> get _localDb async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'secure_legacy.db');
    return openDatabase(path);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SYNC FROM FIRESTORE → LOCAL SQLITE  (called on every app startup)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> syncFromFirestore() async {
    debugPrint('🔄 Starting Firestore → SQLite sync...');
    try {
      await Future.wait([
        _pullAdmins(),           // ← NEW: ensures admin is visible on all devices
        _pullUsers(),
        _pullBankAssets(),
        _pullEmergencyContacts(),
        _pullEmergencyRequests(),
      ]);
      debugPrint('✅ Firestore → SQLite sync complete');
    } catch (e) {
      debugPrint('❌ Sync from Firestore failed: $e');
    }
  }

  // ── PULL ADMINS ────────────────────────────────────────────────────────────
  // FIX: Admin was only created in local SQLite, so other devices never saw it.
  // Now we pull the admin record from Firestore on every startup.
  Future<void> _pullAdmins() async {
    try {
      final snapshot = await _db.collection('admins').get();
      if (snapshot.docs.isEmpty) return;
      final db = await _localDb;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final adminId = data['id'];
        if (adminId == null) continue;

        final existing = await db.query(
          'admins',
          where: 'id = ?',
          whereArgs: [adminId],
        );

        if (existing.isEmpty) {
          await db.insert(
            'admins',
            {
              'id':        adminId,
              'username':  data['username'] ?? 'Admin_17',
              'password':  data['password'] ?? '',
              'secretKey': data['secretKey'] ?? '',
              'fullName':  data['fullName'] ?? 'System Administrator',
              'email':     data['email'] ?? '',
              'createdAt': data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          debugPrint('📥 Pulled admin ${data['username']} from Firestore');
        } else {
          // Update credentials in case they changed
          await db.update(
            'admins',
            {
              'username':  data['username'] ?? existing.first['username'],
              'password':  data['password'] ?? existing.first['password'],
              'secretKey': data['secretKey'] ?? existing.first['secretKey'],
            },
            where: 'id = ?',
            whereArgs: [adminId],
          );
        }
      }
    } catch (e) {
      debugPrint('❌ _pullAdmins error: $e');
    }
  }

  // ── PULL USERS ─────────────────────────────────────────────────────────────
  Future<void> _pullUsers() async {
    try {
      final snapshot = await _db.collection('users').get();
      if (snapshot.docs.isEmpty) return;
      final db = await _localDb;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['id'];
        if (userId == null) continue;

        final existing = await db.query(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
        );

        if (existing.isEmpty) {
          await db.insert(
            'users',
            {
              'id':                     userId,
              'username':               data['username'] ?? '',
              'password':               data['password_hash'] ?? '',
              'fullName':               data['fullName'] ?? '',
              'icNumber':               data['icNumber'] ?? '',
              'email':                  data['email'] ?? '',
              'phoneNumber':            data['phoneNumber'] ?? '',
              'pin':                    data['pin'] ?? '',
              'secretPhrase':           data['secretPhrase'] ?? '',
              'aesKey':                 data['aesKey'] ?? '',
              // aesKey synced so bank credentials can be decrypted on any device
              'lastActive':             data['lastActive'] ?? DateTime.now().millisecondsSinceEpoch,
              'createdAt':              data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
              'inactivity_period_days': data['inactivity_period_days'] ?? 3,
              'isInactive':             data['isInactive'] ?? 0,
              'inactiveMarkedAt':       data['inactiveMarkedAt'],
              'ekycStatus':             data['ekycStatus'] ?? 'pending',
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          debugPrint('📥 Pulled user ${data['username']} from Firestore');
        } else {
          // Update all fields so all devices stay in sync
          await db.update(
            'users',
            {
              'password':               data['password_hash'] ?? existing.first['password'],
              'icNumber':               data['icNumber'] ?? existing.first['icNumber'],
              'pin':                    data['pin'] ?? existing.first['pin'],
              'secretPhrase':           data['secretPhrase'] ?? existing.first['secretPhrase'],
              'aesKey':                 data['aesKey'] ?? existing.first['aesKey'],
              'lastActive':             data['lastActive'] ?? existing.first['lastActive'],
              'isInactive':             data['isInactive'] ?? existing.first['isInactive'],
              'inactiveMarkedAt':       data['inactiveMarkedAt'],
              'ekycStatus':             data['ekycStatus'] ?? existing.first['ekycStatus'],
              'inactivity_period_days': data['inactivity_period_days'] ?? existing.first['inactivity_period_days'],
            },
            where: 'id = ?',
            whereArgs: [userId],
          );
        }
      }
    } catch (e) {
      debugPrint('❌ _pullUsers error: $e');
    }
  }

  // ── PULL BANK ASSETS ───────────────────────────────────────────────────────
  // Note: encrypted credentials are NOT in Firestore (security by design).
  // Only metadata (bank name, account type) is synced.
  Future<void> _pullBankAssets() async {
    try {
      final snapshot = await _db.collection('bank_assets').get();
      if (snapshot.docs.isEmpty) return;
      final db = await _localDb;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final assetId = data['id'];
        if (assetId == null) continue;

        final existing = await db.query(
          'bank_assets',
          where: 'id = ?',
          whereArgs: [assetId],
        );

        if (existing.isEmpty) {
          await db.insert(
            'bank_assets',
            {
              'id':                  assetId,
              'userId':              data['userId'],
              'assetType':           data['account_type'] ?? '',
              'institutionName':     data['bank_name'] ?? '',
              'accountIdentifier':   '', // encrypted — not in Firestore
              'estimatedValue':      '',
              'encryptedUsername':   '', // encrypted — not in Firestore
              'encryptedPassword':   '', // encrypted — not in Firestore
              'specialInstructions': '',
              'createdAt':           data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          debugPrint('📥 Pulled bank asset $assetId from Firestore');
        }
      }
    } catch (e) {
      debugPrint('❌ _pullBankAssets error: $e');
    }
  }

  // ── PULL EMERGENCY CONTACTS ────────────────────────────────────────────────
  Future<void> _pullEmergencyContacts() async {
    try {
      final snapshot = await _db.collection('emergency_contacts').get();
      if (snapshot.docs.isEmpty) return;
      final db = await _localDb;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final contactId = data['id'];
        if (contactId == null) continue;

        final existing = await db.query(
          'emergency_contacts',
          where: 'id = ?',
          whereArgs: [contactId],
        );

        if (existing.isEmpty) {
          await db.insert(
            'emergency_contacts',
            {
              'id':                    contactId,
              'userId':                data['userId'],
              'fullName':              data['fullName'] ?? '',
              'icNumber':              '', // never stored in Firestore
              'relationship':          data['relationship'] ?? '',
              'email':                 data['email'] ?? '',
              'phoneNumber':           data['phoneNumber'] ?? '',
              'inheritancePercentage': data['inheritancePercentage'] ?? '',
              'accessGranted':         data['accessGranted'] ?? 0,
              'accessGrantedAt':       data['accessGrantedAt'],
              'createdAt':             data['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          debugPrint('📥 Pulled emergency contact $contactId from Firestore');
        } else {
          // Always update access status — this can change when admin approves
          await db.update(
            'emergency_contacts',
            {
              'accessGranted':   data['accessGranted'] ?? existing.first['accessGranted'],
              'accessGrantedAt': data['accessGrantedAt'] ?? existing.first['accessGrantedAt'],
            },
            where: 'id = ?',
            whereArgs: [contactId],
          );
        }
      }
    } catch (e) {
      debugPrint('❌ _pullEmergencyContacts error: $e');
    }
  }

  // ── PULL EMERGENCY REQUESTS ────────────────────────────────────────────────
  // FIX: Previously only inserted new records and never updated existing ones.
  // This caused admin on real phone to see empty list after a request was submitted
  // from another device. Now we ALWAYS update status/review fields.
  Future<void> _pullEmergencyRequests() async {
    try {
      final snapshot = await _db.collection('emergency_requests').get();
      if (snapshot.docs.isEmpty) return;
      final db = await _localDb;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final requestId = data['id'];
        if (requestId == null) continue;

        final existing = await db.query(
          'emergency_access_requests',
          where: 'id = ?',
          whereArgs: [requestId],
        );

        if (existing.isEmpty) {
          // New request from another device — insert it
          await db.insert(
            'emergency_access_requests',
            {
              'id':                  requestId,
              'contactId':           data['contactId'],
              'userId':              data['userId'],
              'reason':              data['reason'] ?? '',
              'status':              data['status'] ?? 'pending',
              'requestedAt':         data['requestedAt'] ?? DateTime.now().millisecondsSinceEpoch,
              'reviewedAt':          data['reviewedAt'],
              'reviewedBy':          data['reviewedBy'],
              'adminNotes':          data['adminNotes'],
              // Documents are stored locally only — never put in Firestore
              'deathCertBase64':     null,
              'beneficiaryICBase64': null,
              'supportingDocBase64': null,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          debugPrint('📥 Pulled emergency request $requestId from Firestore');
        } else {
          // ALWAYS update status — critical for cross-device admin visibility
          await db.update(
            'emergency_access_requests',
            {
              'status':     data['status'] ?? existing.first['status'],
              'reviewedAt': data['reviewedAt'] ?? existing.first['reviewedAt'],
              'reviewedBy': data['reviewedBy'] ?? existing.first['reviewedBy'],
              'adminNotes': data['adminNotes'] ?? existing.first['adminNotes'],
            },
            where: 'id = ?',
            whereArgs: [requestId],
          );
        }
      }
    } catch (e) {
      debugPrint('❌ _pullEmergencyRequests error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SYNC LOCAL → FIRESTORE  (push up)
  // ══════════════════════════════════════════════════════════════════════════

  // ── ADMINS ──────────────────────────────────────────────────────────────────
  // FIX: Admin record was never pushed to Firestore, so other devices had no
  // admin and couldn't see pending requests. Called from main.dart on startup.
  Future<void> syncAdmin(Map<String, dynamic> admin) async {
    try {
      await _db
          .collection('admins')
          .doc(admin['id'].toString())
          .set({
        'id':        admin['id'],
        'username':  admin['username'],
        'password':  admin['password'],   // already SHA-256 hashed
        'secretKey': admin['secretKey'] ?? '', // already SHA-256 hashed
        'fullName':  admin['fullName'],
        'email':     admin['email'],
        'createdAt': admin['createdAt'],
      }, SetOptions(merge: true));
      debugPrint('☁️  Admin ${admin['username']} synced to Firestore');
    } catch (e) {
      debugPrint('Firebase syncAdmin error: $e');
    }
  }

  // ── USERS ──────────────────────────────────────────────────────────────────
  Future<void> syncUser(Map<String, dynamic> userData) async {
    try {
      final safeData = Map<String, dynamic>.from(userData);
      // Remove plain password only — handled separately below as password_hash
      safeData.remove('password');

      // Password is already SHA-256 hashed in SQLite — store as-is for cross-device auth
      if (userData['password'] != null) {
        safeData['password_hash'] = userData['password'].toString();
      }
      // pin and secretPhrase are already SHA-256 hashed — safe to store
      // icNumber is stored for cross-device identity verification

      await _db
          .collection('users')
          .doc(userData['id'].toString())
          .set(safeData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase syncUser error: $e');
    }
  }

  // ── eKYC DOCUMENTS ────────────────────────────────────────────────────────
  Future<void> saveEkycDocuments({
    required int userId,
    required File frontIC,
    required File backIC,
    required File selfieFront,
    required File selfieLeft,
    required File selfieRight,
  }) async {
    try {
      debugPrint('📸 Compressing eKYC photos...');
      final results = await Future.wait([
        _compressAndEncode(frontIC),
        _compressAndEncode(backIC),
        _compressAndEncode(selfieFront),
        _compressAndEncode(selfieLeft),
        _compressAndEncode(selfieRight),
      ]);

      debugPrint('✅ Photos compressed. Saving to Firestore...');
      await Future.wait([
        _db.collection('ekyc_documents').doc('${userId}_ic').set({
          'userId':     userId,
          'frontIc':    results[0],
          'backIc':     results[1],
          'uploadedAt': FieldValue.serverTimestamp(),
          'status':     'pending',
        }),
        _db.collection('ekyc_documents').doc('${userId}_selfie').set({
          'userId':      userId,
          'selfieFront': results[2],
          'selfieLeft':  results[3],
          'selfieRight': results[4],
          'uploadedAt':  FieldValue.serverTimestamp(),
          'status':      'pending',
        }),
      ]);
      debugPrint('✅ eKYC documents saved for user $userId');
    } catch (e) {
      debugPrint('❌ Failed to save eKYC documents: $e');
      rethrow;
    }
  }

  Future<Map<String, String>?> getEkycDocuments(int userId) async {
    try {
      final results = await Future.wait([
        _db.collection('ekyc_documents').doc('${userId}_ic').get(),
        _db.collection('ekyc_documents').doc('${userId}_selfie').get(),
      ]);

      final icDoc     = results[0];
      final selfieDoc = results[1];
      if (!icDoc.exists || !selfieDoc.exists) return null;

      final ic     = icDoc.data()!;
      final selfie = selfieDoc.data()!;

      return {
        'frontIc':     ic['frontIc']        as String? ?? '',
        'backIc':      ic['backIc']          as String? ?? '',
        'selfieFront': selfie['selfieFront'] as String? ?? '',
        'selfieLeft':  selfie['selfieLeft']  as String? ?? '',
        'selfieRight': selfie['selfieRight'] as String? ?? '',
      };
    } catch (e) {
      debugPrint('❌ Failed to get eKYC documents: $e');
      return null;
    }
  }

  Future<void> updateEkycStatus({
    required int userId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      final docUpdate = {
        'status':     status,
        'reviewedAt': FieldValue.serverTimestamp(),
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
      };
      await Future.wait([
        _db.collection('ekyc_documents').doc('${userId}_ic').update(docUpdate),
        _db.collection('ekyc_documents').doc('${userId}_selfie').update(docUpdate),
        // Also update users collection so syncFromFirestore restores the correct status on re-login
        _db.collection('users').doc(userId.toString()).update({
          'ekycStatus': status,
          if (rejectionReason != null) 'ekycRejectionReason': rejectionReason,
        }),
      ]);
    } catch (e) {
      debugPrint('❌ Failed to update eKYC status: $e');
    }
  }

  // ── BANK ASSETS ────────────────────────────────────────────────────────────
  Future<void> syncBankAsset(Map<String, dynamic> asset) async {
    try {
      await _db
          .collection('bank_assets')
          .doc(asset['id'].toString())
          .set({
        'id':           asset['id'],
        'userId':       asset['userId'],
        'bank_name':    asset['institutionName'],
        'account_type': asset['assetType'],
        'createdAt':    asset['createdAt'],
        'last_updated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase syncBankAsset error: $e');
    }
  }

  Future<void> deleteBankAsset(String assetId) async {
    try {
      await _db.collection('bank_assets').doc(assetId).delete();
    } catch (e) {
      debugPrint('Firebase deleteBankAsset error: $e');
    }
  }

  // ── EMERGENCY CONTACTS ─────────────────────────────────────────────────────
  Future<void> syncEmergencyContact(Map<String, dynamic> contact) async {
    try {
      await _db
          .collection('emergency_contacts')
          .doc(contact['id'].toString())
          .set({
        'id':                    contact['id'],
        'userId':                contact['userId'],
        'fullName':              contact['fullName'],
        'relationship':          contact['relationship'],
        'email':                 contact['email'],
        'phoneNumber':           contact['phoneNumber'] ?? '',
        'inheritancePercentage': contact['inheritancePercentage'],
        'accessGranted':         contact['accessGranted'],
        'accessGrantedAt':       contact['accessGrantedAt'],
        'createdAt':             contact['createdAt'],
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase syncEmergencyContact error: $e');
    }
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    try {
      await _db.collection('emergency_contacts').doc(contactId).delete();
    } catch (e) {
      debugPrint('Firebase deleteEmergencyContact error: $e');
    }
  }

  // ── EMERGENCY REQUESTS ─────────────────────────────────────────────────────
  // FIX: Strip base64 document fields before pushing to Firestore.
  // Documents are large and sensitive — kept local only.
  Future<void> syncEmergencyRequest(Map<String, dynamic> request) async {
    try {
      final safeRequest = Map<String, dynamic>.from(request);
      safeRequest.remove('deathCertBase64');
      safeRequest.remove('beneficiaryICBase64');
      safeRequest.remove('supportingDocBase64');

      await _db
          .collection('emergency_requests')
          .doc(request['id'].toString())
          .set({
        ...safeRequest,
        'syncedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase syncEmergencyRequest error: $e');
    }
  }

  // ── NOTIFICATIONS ──────────────────────────────────────────────────────────
  Future<void> syncNotification(Map<String, dynamic> notif) async {
    try {
      await _db.collection('notifications').doc(notif['id'].toString()).set({
        ...notif,
        'isRead': notif['isRead'] ?? false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firebase syncNotification error: $e');
    }
  }

  Stream<int> getUnreadNotificationCountStream(int userId) {
    return _db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markAllNotificationsRead(int userId) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Firebase markAllNotificationsRead error: $e');
    }
  }

  // ── AUDIT LOGS ─────────────────────────────────────────────────────────────
  Future<void> addAuditLog(Map<String, dynamic> log) async {
    try {
      await _db.collection('audit_logs').add({
        ...log,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firebase addAuditLog error: $e');
    }
  }

  // ── INACTIVITY STATUS ──────────────────────────────────────────────────────
  Future<void> updateInactivityStatus(String userId, String status) async {
    try {
      await _db.collection('users').doc(userId).update({
        'inactivity_status': status,
        'isInactive':        status == 'inactive' ? 1 : 0,
        'last_checked':      FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Firebase updateInactivityStatus error: $e');
    }
  }

  Future<void> updateLastActive(String userId, int lastActiveMs) async {
    try {
      await _db.collection('users').doc(userId).update({
        'lastActive': lastActiveMs,
        'isInactive': 0,
      });
    } catch (e) {
      debugPrint('Firebase updateLastActive error: $e');
    }
  }
}
