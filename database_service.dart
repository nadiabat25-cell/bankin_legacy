import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user_model.dart';
import '../models/admin_model.dart';
import '../models/bank_asset_model.dart';
import '../models/emergency_contact_model.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'firebase_service.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;
  final _firebase = FirebaseService.instance;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('secure_legacy.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CREATE + UPGRADE
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _createDB(Database db, int version) async {
    const idType   = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType  = 'INTEGER NOT NULL';

    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType,
        password $textType,
        fullName $textType,
        icNumber $textType,
        email $textType,
        phoneNumber $textType,
        pin $textType,
        secretPhrase TEXT NOT NULL DEFAULT '',
        aesKey $textType,
        lastActive $intType,
        createdAt $intType,
        inactivity_period_days INTEGER DEFAULT 3,
        isInactive INTEGER DEFAULT 0,
        inactiveMarkedAt INTEGER,
        ekycStatus TEXT DEFAULT 'pending'
      )
    ''');

    await db.execute('''
      CREATE TABLE admins (
        id $idType,
        username $textType UNIQUE,
        password $textType,
        fullName $textType,
        email $textType,
        createdAt $intType
      )
    ''');

    await db.execute('''
      CREATE TABLE bank_assets (
        id $idType,
        userId $intType,
        assetType $textType,
        institutionName $textType,
        accountIdentifier TEXT,
        estimatedValue TEXT,
        encryptedUsername TEXT,
        encryptedPassword TEXT,
        specialInstructions TEXT,
        createdAt $intType,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE emergency_contacts (
        id $idType,
        userId $intType,
        fullName $textType,
        icNumber $textType,
        relationship $textType,
        email $textType,
        phoneNumber TEXT NOT NULL DEFAULT '',
        inheritancePercentage TEXT,
        accessGranted INTEGER DEFAULT 0,
        accessGrantedAt INTEGER,
        createdAt $intType,
        invitationStatus TEXT DEFAULT 'pending',
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE notifications (
        id $idType,
        userId $intType,
        title $textType,
        message $textType,
        type $textType,
        isRead INTEGER DEFAULT 0,
        createdAt $intType,
        relatedId INTEGER,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE emergency_access_requests (
        id $idType,
        contactId $intType,
        userId $intType,
        reason $textType,
        status TEXT DEFAULT 'pending',
        requestedAt $intType,
        reviewedAt INTEGER,
        reviewedBy INTEGER,
        adminNotes TEXT,
        deathCertBase64 TEXT,
        beneficiaryICBase64 TEXT,
        supportingDocBase64 TEXT,
        FOREIGN KEY (contactId) REFERENCES emergency_contacts (id) ON DELETE CASCADE,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE,
        FOREIGN KEY (reviewedBy) REFERENCES admins (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE login_activity (
        id $idType,
        userId INTEGER,
        adminId INTEGER,
        username $textType,
        userType $textType,
        action $textType,
        ipAddress TEXT,
        deviceInfo TEXT,
        timestamp $intType
      )
    ''');

    await _createDefaultAdmin(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE users ADD COLUMN inactivity_period_days INTEGER DEFAULT 3');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE users ADD COLUMN isInactive INTEGER DEFAULT 0');
      await db.execute(
          'ALTER TABLE users ADD COLUMN inactiveMarkedAt INTEGER');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS emergency_access_requests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          contactId INTEGER NOT NULL,
          userId INTEGER NOT NULL,
          reason TEXT NOT NULL,
          status TEXT DEFAULT 'pending',
          requestedAt INTEGER NOT NULL,
          reviewedAt INTEGER,
          reviewedBy INTEGER,
          adminNotes TEXT,
          FOREIGN KEY (contactId) REFERENCES emergency_contacts (id) ON DELETE CASCADE,
          FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE,
          FOREIGN KEY (reviewedBy) REFERENCES admins (id)
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute(
          "ALTER TABLE users ADD COLUMN ekycStatus TEXT DEFAULT 'approved'");
    }
    if (oldVersion < 5) {
      await db.execute(
          "ALTER TABLE emergency_contacts ADD COLUMN phoneNumber TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 6) {
      await db.execute(
          "ALTER TABLE emergency_access_requests ADD COLUMN deathCertBase64 TEXT");
      await db.execute(
          "ALTER TABLE emergency_access_requests ADD COLUMN beneficiaryICBase64 TEXT");
      await db.execute(
          "ALTER TABLE emergency_access_requests ADD COLUMN supportingDocBase64 TEXT");
    }
    if (oldVersion < 7) {
      await db.execute(
          "ALTER TABLE emergency_contacts ADD COLUMN invitationStatus TEXT DEFAULT 'pending'");
      await db.execute('''
        CREATE TABLE IF NOT EXISTS notifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId INTEGER NOT NULL,
          title TEXT NOT NULL,
          message TEXT NOT NULL,
          type TEXT NOT NULL,
          isRead INTEGER DEFAULT 0,
          createdAt INTEGER NOT NULL,
          relatedId INTEGER,
          FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute(
          "ALTER TABLE users ADD COLUMN secretPhrase TEXT NOT NULL DEFAULT ''");
    }
    if (oldVersion < 9) {
      // Update existing admin credentials to new username/password
      final hashedPassword = sha256.convert(utf8.encode('Admin@579')).toString();
      await db.update(
        'admins',
        {'username': 'Admin_17', 'password': hashedPassword},
        where: 'username = ?',
        whereArgs: ['admin'],
      );
    }
    if (oldVersion < 10) {
      // Add secretKey column to admins
      await db.execute("ALTER TABLE admins ADD COLUMN secretKey TEXT NOT NULL DEFAULT ''");
      // Set hashed secret key for existing admin
      final hashedKey = sha256.convert(utf8.encode('appleberry')).toString();
      await db.update('admins', {'secretKey': hashedKey});
    }
  }

  Future<void> _createDefaultAdmin(Database db) async {
    final hashedPassword  = sha256.convert(utf8.encode('Admin@579')).toString();
    final hashedSecretKey = sha256.convert(utf8.encode('appleberry')).toString();
    await db.insert('admins', {
      'username':  'Admin_17',
      'password':  hashedPassword,
      'secretKey': hashedSecretKey,
      'fullName':  'System Administrator',
      'email':     'admin@securelegacy.com',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADMIN METHODS
  // ══════════════════════════════════════════════════════════════════════════

  Future<AdminModel?> getAdminByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'admins',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) return AdminModel.fromMap(maps.first);
    return null;
  }

  // FIX: Pushes all local admin records to Firestore so every device gets
  // the admin account on startup. Called from main.dart after syncFromFirestore().
  Future<void> syncAdminToFirestore() async {
    try {
      final db = await database;
      final admins = await db.query('admins');
      for (final admin in admins) {
        await _firebase.syncAdmin(admin);
      }
      debugPrint('☁️  Admin records pushed to Firestore');
    } catch (e) {
      debugPrint('syncAdminToFirestore error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // USER METHODS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> createUser(UserModel user) async {
    final db = await database;
    final id = await db.insert('users', user.toMap());
    _firebase.syncUser({...user.toMap(), 'id': id});
    return id;
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (maps.isNotEmpty) return UserModel.fromMap(maps.first);
    return null;
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return UserModel.fromMap(maps.first);
    return null;
  }

  Future<int> updateUser(UserModel user) async {
    final db = await database;
    final result = await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
    _firebase.syncUser(user.toMap());
    return result;
  }

  /// Force-push the current local SQLite data for a user to Firestore.
  /// Call this after a successful login so stale / double-hashed Firestore
  /// records get overwritten with the correct local values.
  Future<void> syncUserToFirestore(int userId) async {
    try {
      final db = await database;
      final rows = await db.query('users', where: 'id = ?', whereArgs: [userId]);
      if (rows.isNotEmpty) {
        await _firebase.syncUser({...rows.first, 'id': userId});
        debugPrint('☁️  User $userId synced to Firestore after login');
      }
    } catch (e) {
      debugPrint('syncUserToFirestore error: $e');
    }
  }

  Future<int> updateUserLastActive(int userId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    _firebase.updateLastActive(userId.toString(), now);
    return await db.update(
      'users',
      {
        'lastActive': now,
        'isInactive': 0,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: 'createdAt DESC');
    return result.map((map) => UserModel.fromMap(map)).toList();
  }

  Future<int?> getUserInactivityPeriod(int userId) async {
    final db = await database;
    final result = await db.query(
      'users',
      columns: ['inactivity_period_days'],
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (result.isNotEmpty) {
      return result.first['inactivity_period_days'] as int?;
    }
    return 3;
  }

  Future<int> updateUserInactivityPeriod(int userId, int days) async {
    final db = await database;
    return await db.update(
      'users',
      {'inactivity_period_days': days},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> updateUserEkycStatus(int userId, String status) async {
    final db = await database;
    final result = await db.update(
      'users',
      {'ekycStatus': status},
      where: 'id = ?',
      whereArgs: [userId],
    );
    // Also sync the updated status to Firestore
    final user = await getUserById(userId);
    if (user != null) _firebase.syncUser(user.toMap());
    return result;
  }

  Future<List<Map<String, dynamic>>> checkAndMarkInactiveUsers() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, dynamic>> newlyInactiveUsers = [];

    final users = await db.query(
      'users',
      where: 'isInactive = ?',
      whereArgs: [0],
    );

    for (var userMap in users) {
      final userId               = userMap['id'] as int;
      final lastActive           = userMap['lastActive'] as int;
      final inactivityPeriodDays = userMap['inactivity_period_days'] as int? ?? 3;

      final threshold = inactivityPeriodDays == -1
          ? const Duration(minutes: 1)
          : Duration(days: inactivityPeriodDays);

      final inactiveDuration = Duration(milliseconds: now - lastActive);

      if (inactiveDuration > threshold) {
        await db.update(
          'users',
          {
            'isInactive':       1,
            'inactiveMarkedAt': now,
          },
          where: 'id = ?',
          whereArgs: [userId],
        );
        _firebase.updateInactivityStatus(userId.toString(), 'inactive');
        newlyInactiveUsers.add(userMap);
      }
    }

    return newlyInactiveUsers;
  }

  Future<int> markUserAsInactive(int userId) async {
    final db = await database;
    _firebase.updateInactivityStatus(userId.toString(), 'inactive');
    return await db.update(
      'users',
      {
        'isInactive':       1,
        'inactiveMarkedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> markUserAsActive(int userId) async {
    final db = await database;
    _firebase.updateInactivityStatus(userId.toString(), 'active');
    return await db.update(
      'users',
      {
        'isInactive':       0,
        'inactiveMarkedAt': null,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EMERGENCY ACCESS REQUEST METHODS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> createEmergencyAccessRequest({
    required int contactId,
    required int userId,
    required String reason,
    String? deathCertBase64,
    String? beneficiaryICBase64,
    String? supportingDocBase64,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = await db.insert('emergency_access_requests', {
      'contactId':            contactId,
      'userId':               userId,
      'reason':               reason,
      'status':               'pending',
      'requestedAt':          now,
      'deathCertBase64':      deathCertBase64,
      'beneficiaryICBase64':  beneficiaryICBase64,
      'supportingDocBase64':  supportingDocBase64,
    });

    // Sync metadata only to Firestore (documents stay local)
    _firebase.syncEmergencyRequest({
      'id':          id,
      'contactId':   contactId,
      'userId':      userId,
      'reason':      reason,
      'status':      'pending',
      'requestedAt': now,
    });

    return id;
  }

  // Returns pending requests — excludes base64 image columns to avoid CursorWindow overflow.
  Future<List<Map<String, dynamic>>> getPendingEmergencyRequests() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        ear.id, ear.contactId, ear.userId, ear.reason, ear.status,
        ear.requestedAt, ear.reviewedBy, ear.reviewedAt, ear.adminNotes,
        ec.fullName   AS contactName,
        ec.icNumber   AS contactIcNumber,
        ec.email      AS contactEmail,
        ec.phoneNumber AS contactPhone,
        ec.relationship,
        u.username,
        u.fullName    AS ownerName,
        u.email       AS ownerEmail
      FROM emergency_access_requests ear
      INNER JOIN emergency_contacts ec ON ear.contactId = ec.id
      INNER JOIN users u ON ear.userId = u.id
      WHERE ear.status = 'pending'
      ORDER BY ear.requestedAt DESC
    ''');
  }

  // Loads document images one column at a time to avoid CursorWindow overflow.
  Future<Map<String, String?>> getRequestDocuments(int requestId) async {
    final db = await database;

    Future<String?> loadOne(String col) async {
      try {
        final rows = await db.query(
          'emergency_access_requests',
          columns: [col],
          where: 'id = ?',
          whereArgs: [requestId],
        );
        return rows.isEmpty ? null : rows.first[col] as String?;
      } catch (_) {
        return null;
      }
    }

    final deathCert  = await loadOne('deathCertBase64');
    final benefIC    = await loadOne('beneficiaryICBase64');
    final supportDoc = await loadOne('supportingDocBase64');

    return {
      'deathCertBase64':     deathCert,
      'beneficiaryICBase64': benefIC,
      'supportingDocBase64': supportDoc,
    };
  }

  // Returns ALL requests (pending + reviewed) for history view — no image columns.
  Future<List<Map<String, dynamic>>> getAllEmergencyRequests() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        ear.id, ear.contactId, ear.userId, ear.reason, ear.status,
        ear.requestedAt, ear.reviewedBy, ear.reviewedAt, ear.adminNotes,
        ec.fullName   AS contactName,
        ec.icNumber   AS contactIcNumber,
        ec.email      AS contactEmail,
        ec.phoneNumber AS contactPhone,
        ec.relationship,
        u.username,
        u.fullName    AS ownerName,
        u.email       AS ownerEmail
      FROM emergency_access_requests ear
      INNER JOIN emergency_contacts ec ON ear.contactId = ec.id
      INNER JOIN users u ON ear.userId = u.id
      ORDER BY ear.requestedAt DESC
    ''');
  }

  Future<int> approveEmergencyRequest(
      int requestId,
      int adminId,
      String? adminNotes,
      ) async {
    final db = await database;

    final request = await db.query(
      'emergency_access_requests',
      columns: ['id', 'contactId'],
      where: 'id = ?',
      whereArgs: [requestId],
    );
    if (request.isEmpty) return 0;

    final contactId = request.first['contactId'] as int;
    final now       = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'emergency_access_requests',
      {
        'status':     'approved',
        'reviewedAt': now,
        'reviewedBy': adminId,
        'adminNotes': adminNotes,
      },
      where: 'id = ?',
      whereArgs: [requestId],
    );

    _firebase.syncEmergencyRequest({
      'id':         requestId,
      'status':     'approved',
      'reviewedAt': now,
      'reviewedBy': adminId,
      'adminNotes': adminNotes,
    });

    return await grantEmergencyAccess(contactId);
  }

  Future<int> rejectEmergencyRequest(
      int requestId,
      int adminId,
      String? adminNotes,
      ) async {
    final db  = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    _firebase.syncEmergencyRequest({
      'id':         requestId,
      'status':     'rejected',
      'reviewedAt': now,
      'reviewedBy': adminId,
      'adminNotes': adminNotes,
    });

    return await db.update(
      'emergency_access_requests',
      {
        'status':     'rejected',
        'reviewedAt': now,
        'reviewedBy': adminId,
        'adminNotes': adminNotes,
      },
      where: 'id = ?',
      whereArgs: [requestId],
    );
  }

  // Called when account holder logs back in — revokes any active emergency access.
  // Returns the names of beneficiaries whose access was revoked (for notification).
  Future<List<String>> revokeEmergencyAccessOnLogin(int userId) async {
    final db  = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Find all approved requests for this user (no image columns)
    final approvedRequests = await db.rawQuery('''
      SELECT ear.id, ear.contactId, ec.fullName AS contactName
      FROM emergency_access_requests ear
      INNER JOIN emergency_contacts ec ON ear.contactId = ec.id
      WHERE ear.userId = ? AND (ear.status = 'approved' OR ear.status = 'pending')
    ''', [userId]);

    if (approvedRequests.isEmpty) return [];

    final revokedNames = <String>[];
    for (final req in approvedRequests) {
      final reqId     = req['id'] as int;
      final contactId = req['contactId'] as int;
      final name      = req['contactName'] as String;

      // Mark request as revoked
      await db.update(
        'emergency_access_requests',
        {'status': 'revoked', 'reviewedAt': now},
        where: 'id = ?',
        whereArgs: [reqId],
      );

      // Remove access from the contact
      await db.update(
        'emergency_contacts',
        {'accessGranted': 0, 'accessGrantedAt': null},
        where: 'id = ?',
        whereArgs: [contactId],
      );

      revokedNames.add(name);
    }
    return revokedNames;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BANK ASSET METHODS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> createBankAsset(BankAssetModel asset) async {
    final db = await database;
    final id = await db.insert('bank_assets', asset.toMap());
    _firebase.syncBankAsset({...asset.toMap(), 'id': id});
    return id;
  }

  Future<List<BankAssetModel>> getBankAssetsByUserId(int userId) async {
    final db = await database;
    final result = await db.query(
      'bank_assets',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => BankAssetModel.fromMap(map)).toList();
  }

  Future<int> updateBankAsset(BankAssetModel asset) async {
    final db = await database;
    final result = await db.update(
      'bank_assets',
      asset.toMap(),
      where: 'id = ?',
      whereArgs: [asset.id],
    );
    _firebase.syncBankAsset(asset.toMap());
    return result;
  }

  Future<int> deleteBankAsset(int id) async {
    final db = await database;
    _firebase.deleteBankAsset(id.toString());
    return await db.delete('bank_assets', where: 'id = ?', whereArgs: [id]);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EMERGENCY CONTACT METHODS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> createEmergencyContact(EmergencyContactModel contact) async {
    final db = await database;
    final id = await db.insert('emergency_contacts', contact.toMap());
    _firebase.syncEmergencyContact({...contact.toMap(), 'id': id});
    return id;
  }

  Future<List<EmergencyContactModel>> getEmergencyContactsByUserId(
      int userId) async {
    final db = await database;
    final result = await db.query(
      'emergency_contacts',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );
    return result.map((map) => EmergencyContactModel.fromMap(map)).toList();
  }

  Future<List<EmergencyContactModel>> getEmergencyContactsByIcNumber(
      String icNumber) async {
    final db = await database;
    final result = await db.query(
      'emergency_contacts',
      where: 'icNumber = ?',
      whereArgs: [icNumber],
    );
    return result.map((map) => EmergencyContactModel.fromMap(map)).toList();
  }

  Future<int> updateEmergencyContact(EmergencyContactModel contact) async {
    final db = await database;
    final result = await db.update(
      'emergency_contacts',
      contact.toMap(),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
    _firebase.syncEmergencyContact(contact.toMap());
    return result;
  }

  Future<int> grantEmergencyAccess(int contactId) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Update local SQLite
    final result = await db.update(
      'emergency_contacts',
      {
        'accessGranted':   1,
        'accessGrantedAt': now,
      },
      where: 'id = ?',
      whereArgs: [contactId],
    );

    // Sync updated access status to Firestore
    final contacts = await db.query(
      'emergency_contacts',
      where: 'id = ?',
      whereArgs: [contactId],
    );
    if (contacts.isNotEmpty) {
      _firebase.syncEmergencyContact(contacts.first);
    }

    return result;
  }

  Future<int> deleteEmergencyContact(int id) async {
    final db = await database;
    _firebase.deleteEmergencyContact(id.toString());
    return await db.delete(
      'emergency_contacts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ACTIVITY LOG METHODS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> logActivity(Map<String, dynamic> activity) async {
    final db = await database;
    _firebase.addAuditLog(activity);
    return await db.insert('login_activity', activity);
  }

  Future<List<Map<String, dynamic>>> getLoginActivity({
    int? userId,
    int limit = 50,
  }) async {
    final db = await database;
    if (userId != null) {
      return await db.query(
        'login_activity',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'timestamp DESC',
        limit: limit,
      );
    }
    return await db.query(
      'login_activity',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTIFICATION METHODS
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> createNotification({
    required int userId,
    required String title,
    required String message,
    required String type,
    int? relatedId,
  }) async {
    final db = await database;
    final id = await db.insert('notifications', {
      'userId':    userId,
      'title':     title,
      'message':   message,
      'type':      type,
      'isRead':    0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'relatedId': relatedId,
    });
    _firebase.syncNotification({
      'id': id, 'userId': userId, 'title': title,
      'message': message, 'type': type, 'isRead': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  Future<List<Map<String, dynamic>>> getNotifications(int userId) async {
    final db = await database;
    return await db.query('notifications',
        where: 'userId = ?', whereArgs: [userId], orderBy: 'createdAt DESC');
  }

  Future<int> getUnreadNotificationCount(int userId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM notifications WHERE userId = ? AND isRead = 0',
        [userId]);
    return result.first['count'] as int;
  }

  Future<void> markAllNotificationsRead(int userId) async {
    final db = await database;
    await db.update('notifications', {'isRead': 1},
        where: 'userId = ? AND isRead = 0', whereArgs: [userId]);
    _firebase.markAllNotificationsRead(userId);
  }

  // Returns contacts that responded (accepted/declined) but admin hasn't confirmed yet
  Future<List<Map<String, dynamic>>> getPendingBeneficiaryDecisions() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT ec.*, u.fullName AS ownerName, u.email AS ownerEmail
      FROM emergency_contacts ec
      INNER JOIN users u ON ec.userId = u.id
      WHERE ec.invitationStatus IN ('accepted', 'declined')
      ORDER BY ec.createdAt DESC
    ''');
  }

  Future<int> updateInvitationStatus(int contactId, String status) async {
    final db = await database;
    final result = await db.update(
      'emergency_contacts', {'invitationStatus': status},
      where: 'id = ?', whereArgs: [contactId],
    );
    final rows = await db.query('emergency_contacts', where: 'id = ?', whereArgs: [contactId]);
    if (rows.isNotEmpty) _firebase.syncEmergencyContact(rows.first);
    return result;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DATABASE CLEANUP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
