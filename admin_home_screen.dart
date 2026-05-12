import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/inactivity_checker_service.dart';
import '../services/email_service.dart';
import '../services/firebase_service.dart';
import '../models/emergency_contact_model.dart';
import 'login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({Key? key}) : super(key: key);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _inactiveUsers = [];
  List<Map<String, dynamic>> _recentActivity = [];
  List<Map<String, dynamic>> _pendingRegistrations = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _confirmedBeneficiaries = [];
  bool _isLoading = true;

  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initAdmin();
    _listenToFirestoreChanges();
  }

  // ── Pull from Firestore first, then load local SQLite ─────────────────────
  Future<void> _initAdmin() async {
    setState(() => _isLoading = true);
    // Sync Firestore → SQLite so admin sees all users regardless of device
    await FirebaseService.instance.syncFromFirestore();
    await _loadData();
  }

  void _listenToFirestoreChanges() {
    _firestore.collection('users').snapshots().listen((_) async {
      if (mounted) {
        await FirebaseService.instance.syncFromFirestore();
        _loadData();
      }
    });

    _firestore.collection('emergency_requests').snapshots().listen((_) async {
      if (mounted) {
        await FirebaseService.instance.syncFromFirestore();
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final db = await DatabaseService.instance.database;
      final usersData = await db.query('users', orderBy: 'createdAt DESC');

      final allUsers = <Map<String, dynamic>>[];
      final inactiveUsers = <Map<String, dynamic>>[];
      final pendingRegistrations = <Map<String, dynamic>>[];

      for (var user in usersData) {
        allUsers.add(user);
        if (user['isInactive'] == 1) inactiveUsers.add(user);
        final status = user['ekycStatus'] as String? ?? 'pending';
        if (status == 'pending') pendingRegistrations.add(user);
      }

      final activity = await DatabaseService.instance.getLoginActivity(limit: 20);
      final pendingRequests = await DatabaseService.instance.getPendingEmergencyRequests();
      final db2 = await DatabaseService.instance.database;
      final confirmedBeneficiaries = await db2.rawQuery('''
        SELECT ear.id, ec.fullName, ec.relationship, ec.email, u.fullName AS ownerName, ear.reviewedAt
        FROM emergency_access_requests ear
        INNER JOIN emergency_contacts ec ON ear.contactId = ec.id
        INNER JOIN users u ON ear.userId = u.id
        WHERE ear.status = 'approved'
        ORDER BY ear.reviewedAt DESC
      ''');

      if (mounted) {
        setState(() {
          _allUsers = allUsers;
          _inactiveUsers = inactiveUsers;
          _pendingRegistrations = pendingRegistrations;
          _recentActivity = activity;
          _pendingRequests = pendingRequests;
          _confirmedBeneficiaries = confirmedBeneficiaries;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkInactivityNow() async {
    setState(() => _isLoading = true);
    await FirebaseService.instance.syncFromFirestore();
    await InactivityCheckerService.instance.checkNow();
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inactivity check completed'), backgroundColor: Colors.green),
      );
    }
  }

  int get _activeUsersCount => _allUsers.length - _inactiveUsers.length;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _checkInactivityNow),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              authService.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(),
          _buildUsersTab(),
          _buildInactiveUsersTab(),
          _buildRequestsTab(),
          _buildRegistrationsTab(),
          _buildActiveBeneficiariesTab(),
          _buildActivityLogTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(
            icon: _inactiveUsers.isNotEmpty
                ? Badge(label: Text('${_inactiveUsers.length}'), child: const Icon(Icons.warning))
                : const Icon(Icons.warning),
            label: 'Inactive User',
          ),
          BottomNavigationBarItem(
            icon: _pendingRequests.isNotEmpty
                ? Badge(label: Text('${_pendingRequests.length}'), child: const Icon(Icons.emergency))
                : const Icon(Icons.emergency),
            label: 'Requests',
          ),
          BottomNavigationBarItem(
            icon: _pendingRegistrations.isNotEmpty
                ? Badge(label: Text('${_pendingRegistrations.length}'), child: const Icon(Icons.how_to_reg))
                : const Icon(Icons.how_to_reg),
            label: 'eKYC',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.verified_user),
            label: 'Beneficiaries',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Activity'),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Users', '${_allUsers.length}', Icons.people, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Inactive', '${_inactiveUsers.length}', Icons.warning, Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard('Active Users', '$_activeUsersCount', Icons.check_circle, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Pending eKYC', '${_pendingRegistrations.length}', Icons.how_to_reg, Colors.purple)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard('Access Requests', '${_pendingRequests.length}', Icons.emergency_share, Colors.red)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Active Beneficiaries', '${_confirmedBeneficiaries.length}', Icons.verified_user, Colors.teal)),
            ],
          ),
          const SizedBox(height: 24),

          if (_pendingRegistrations.isNotEmpty) ...[
            Card(
              color: Colors.purple[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.how_to_reg, color: Colors.purple[700]),
                      const SizedBox(width: 8),
                      Text('Pending Registrations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purple[700])),
                    ]),
                    const SizedBox(height: 8),
                    Text('${_pendingRegistrations.length} user(s) waiting for eKYC approval', style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _selectedIndex = 4),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                      child: const Text('Review Registrations'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_pendingRequests.isNotEmpty) ...[
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.emergency, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Text('Emergency Requests Pending', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red[700])),
                    ]),
                    const SizedBox(height: 8),
                    Text('${_pendingRequests.length} request(s) need your attention', style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _selectedIndex = 3),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Review Requests'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],


          if (_inactiveUsers.isNotEmpty) ...[
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.warning, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Text('Inactive Users Detected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[700])),
                    ]),
                    const SizedBox(height: 8),
                    Text('${_inactiveUsers.length} user(s) marked as inactive', style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _selectedIndex = 2),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: const Text('View Inactive Users'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return _allUsers.isEmpty
        ? const Center(child: Text('No users registered yet'))
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _allUsers.length,
      itemBuilder: (context, index) {
        final user = _allUsers[index];
        final lastActive = DateTime.fromMillisecondsSinceEpoch(user['lastActive'] as int);
        final isInactive = user['isInactive'] == 1;
        final inactivityPeriod = user['inactivity_period_days'] as int? ?? 3;
        final ekycStatus = user['ekycStatus'] as String? ?? 'pending';

        Color statusColor;
        switch (ekycStatus) {
          case 'approved': statusColor = Colors.green; break;
          case 'rejected': statusColor = Colors.red; break;
          default: statusColor = Colors.orange;
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isInactive ? Colors.orange[50] : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: isInactive ? Colors.orange : Theme.of(context).colorScheme.primary,
                      child: Text((user['fullName'] as String)[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user['fullName'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text(user['email'] as String, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          Row(children: [
                            Text(
                              isInactive ? 'INACTIVE - ${_formatTime(lastActive)}' : 'Active - ${_formatTime(lastActive)}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isInactive ? Colors.red : Colors.green),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                              child: Text('eKYC: $ekycStatus', style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                            ),
                          ]),
                          Text('Inactivity: ${inactivityPeriod == -1 ? "1 min" : "$inactivityPeriod days"}',
                              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    if (isInactive) const Icon(Icons.warning, color: Colors.orange),
                  ],
                ),
                // All designated beneficiaries
                FutureBuilder<List<EmergencyContactModel>>(
                  future: DatabaseService.instance.getEmergencyContactsByUserId(user['id'] as int),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                    final contacts = snapshot.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 20),
                        Text('Designated Beneficiaries (${contacts.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        ...contacts.map((c) => _buildInviteDecisionRow(c, user)),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInviteDecisionRow(EmergencyContactModel contact, Map<String, dynamic> user) {
    final status = contact.invitationStatus;
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'accepted':
        statusColor = Colors.green;
        statusLabel = 'ACCEPTED';
        break;
      case 'declined':
        statusColor = Colors.red;
        statusLabel = 'DECLINED';
        break;
      case 'confirmed':
        statusColor = Colors.teal;
        statusLabel = 'CONFIRMED';
        break;
      default:
        statusColor = Colors.orange;
        statusLabel = 'PENDING';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: statusColor.withValues(alpha: 0.3))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(contact.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(contact.relationship, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Text(contact.email, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text(statusLabel,
                      style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          if (status != 'confirmed')
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => _confirmBeneficiary(contact, user),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero),
                  child: const Text('Accept', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(height: 4),
                ElevatedButton(
                  onPressed: () => _removeBeneficiary(contact, user),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero),
                  child: const Text('Decline', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _confirmBeneficiary(EmergencyContactModel contact, Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Beneficiary'),
        content: Text('Confirm ${contact.fullName} as a beneficiary for ${user['fullName']}?\n\nThe account holder will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await DatabaseService.instance.updateInvitationStatus(contact.id!, 'confirmed');
      await DatabaseService.instance.createNotification(
        userId: contact.userId,
        title: 'Beneficiary Accepted',
        message: '${contact.fullName} has accepted your invitation and is now confirmed as your beneficiary.',
        type: 'beneficiary_accepted',
        relatedId: contact.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${contact.fullName} confirmed!'), backgroundColor: Colors.green));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _removeBeneficiary(EmergencyContactModel contact, Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Beneficiary'),
        content: Text('Remove ${contact.fullName} from ${user['fullName']}\'s beneficiaries?\n\nThe account holder will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await DatabaseService.instance.deleteEmergencyContact(contact.id!);
      await DatabaseService.instance.createNotification(
        userId: contact.userId,
        title: 'Beneficiary Declined',
        message: '${contact.fullName} has declined your invitation and has been removed from your beneficiaries.',
        type: 'beneficiary_declined',
        relatedId: contact.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${contact.fullName} removed.'), backgroundColor: Colors.orange));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildInactiveUsersTab() {
    return _inactiveUsers.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
          const SizedBox(height: 16),
          Text('All users are active', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        ],
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _inactiveUsers.length,
      itemBuilder: (context, index) => _buildInactiveUserCard(_inactiveUsers[index]),
    );
  }

  Widget _buildInactiveUserCard(Map<String, dynamic> user) {
    final lastActive = DateTime.fromMillisecondsSinceEpoch(user['lastActive'] as int);
    final inactivityPeriod = user['inactivity_period_days'] as int? ?? 3;
    final duration = DateTime.now().difference(lastActive);
    final durationText = inactivityPeriod == -1 ? '${duration.inMinutes} minutes' : '${duration.inDays} days';

    return Card(
      color: Colors.orange[50],
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.warning, color: Colors.white)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['fullName'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user['email'] as String, style: TextStyle(color: Colors.grey[600])),
                      Text('Inactive for $durationText', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  // ── Requests Tab ─────────────────────────────────────────────────────────
  Widget _buildRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text('No Pending Access Requests', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) => _buildRequestCard(_pendingRequests[index]),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final requestedAt = DateTime.fromMillisecondsSinceEpoch(request['requestedAt'] as int? ?? 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.emergency, color: Colors.red[700]),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(request['contactName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(request['contactEmail'] ?? '-', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ])),
            ]),
            const Divider(height: 20),
            _buildReqInfoRow('Account Owner', request['ownerName']),
            _buildReqInfoRow('Relationship', request['relationship']),
            _buildReqInfoRow('Requested', _formatDateTime(requestedAt)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reason:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text(request['reason'] ?? 'No reason provided', style: const TextStyle(fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 12),
            const Text('Submitted Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            // Load images lazily to avoid CursorWindow overflow on Android
            FutureBuilder<Map<String, String?>>(
              future: DatabaseService.instance.getRequestDocuments(request['id'] as int),
              builder: (context, snapshot) {
                final deathCert  = snapshot.data?['deathCertBase64'];
                final benefIC    = snapshot.data?['beneficiaryICBase64'];
                final supportDoc = snapshot.data?['supportingDocBase64'];
                return Row(children: [
                  Expanded(child: _buildDocPreview('Death Certificate', deathCert)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDocPreview('Beneficiary IC', benefIC)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildDocPreview('Supporting Doc', supportDoc)),
                ]);
              },
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _rejectRequest(request),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _approveRequest(request),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildDocPreview(String label, String? base64) {
    return GestureDetector(
      onTap: base64 != null ? () => _viewDocument(base64, label) : null,
      child: Column(children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: base64 != null ? Colors.green : Colors.grey.shade300, width: base64 != null ? 2 : 1),
          ),
          child: base64 != null
              ? ClipRRect(borderRadius: BorderRadius.circular(7),
                  child: Image.memory(base64Decode(base64), fit: BoxFit.cover, width: double.infinity))
              : Center(child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: 28)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
        if (base64 != null)
          Text('tap to view', style: TextStyle(fontSize: 9, color: Colors.green[600]), textAlign: TextAlign.center),
      ]),
    );
  }

  void _viewDocument(String base64, String title) {
    final bytes = base64Decode(base64);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))],
            ),
            InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
          ],
        ),
      ),
    );
  }

  Widget _buildReqInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 110, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
        Expanded(child: Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
      ]),
    );
  }


  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final adminId = Provider.of<AuthService>(context, listen: false).currentAdmin!.id!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Access Request'),
        content: Text('Approve emergency access for ${request['contactName']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await DatabaseService.instance.approveEmergencyRequest(
          request['id'] as int, adminId, null);
      await EmailService.sendAccessApproved(
        beneficiaryEmail: request['contactEmail'] as String? ?? '',
        beneficiaryName: request['contactName'] as String? ?? '',
        ownerName: request['ownerName'] as String? ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Access approved & email sent to ${request['contactName']}!'), backgroundColor: Colors.green));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final adminId2 = Provider.of<AuthService>(context, listen: false).currentAdmin!.id!;
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Access Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject access request from ${request['contactName']}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Rejection reason (required)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirm != true || reasonController.text.trim().isEmpty) return;
    try {
      await DatabaseService.instance.rejectEmergencyRequest(
          request['id'] as int, adminId2, reasonController.text.trim());
      await EmailService.sendAccessRejected(
        beneficiaryEmail: request['contactEmail'] as String? ?? '',
        beneficiaryName: request['contactName'] as String? ?? '',
        ownerName: request['ownerName'] as String? ?? '',
        rejectReason: reasonController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rejected & email sent to ${request['contactName']}'), backgroundColor: Colors.orange));
        _loadData();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _buildRegistrationsTab() {
    if (_pendingRegistrations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.green[300]),
            const SizedBox(height: 16),
            Text('No pending registrations', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingRegistrations.length,
      itemBuilder: (context, index) => _buildRegistrationCard(_pendingRegistrations[index]),
    );
  }

  Widget _buildRegistrationCard(Map<String, dynamic> user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: Colors.purple, child: Text((user['fullName'] as String)[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['fullName'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user['email'] as String, style: TextStyle(color: Colors.grey[600])),
                      Text('IC: ${user['icNumber'] as String? ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text('Phone: ${user['phoneNumber'] as String? ?? '-'}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(12)),
                  child: Text('Pending', style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('eKYC Documents', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            FutureBuilder<Map<String, String>?>(
              future: FirebaseService.instance.getEkycDocuments(user['id'] as int),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                    child: Row(children: [Icon(Icons.warning, color: Colors.red[700], size: 18), const SizedBox(width: 8), Text('Documents not uploaded yet.', style: TextStyle(color: Colors.red[800], fontSize: 13))]),
                  );
                }
                final docs = snapshot.data!;
                return Column(
                  children: [
                    Row(children: [
                      Expanded(child: _buildBase64ImagePreview('IC Front', docs['frontIc'] ?? '')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildBase64ImagePreview('IC Back', docs['backIc'] ?? '')),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: _buildBase64ImagePreview('Selfie Front', docs['selfieFront'] ?? '')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildBase64ImagePreview('Selfie Left', docs['selfieLeft'] ?? '')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildBase64ImagePreview('Selfie Right', docs['selfieRight'] ?? '')),
                    ]),
                  ],
                );
              },
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: () => _approveRegistration(user), icon: const Icon(Icons.check), label: const Text('Approve'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton.icon(onPressed: () => _rejectRegistration(user), icon: const Icon(Icons.close), label: const Text('Reject'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBase64ImagePreview(String label, String base64String) {
    if (base64String.isEmpty) {
      return Column(
        children: [
          Container(height: 80, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey))),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      );
    }
    final imageBytes = base64Decode(base64String);
    return Column(
      children: [
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (_) => Dialog(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppBar(title: Text(label), automaticallyImplyLeading: false, actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]),
                    InteractiveViewer(child: Image.memory(imageBytes, fit: BoxFit.contain)),
                  ],
                ),
              ),
            );
          },
          child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(imageBytes, height: 80, width: double.infinity, fit: BoxFit.cover)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600]), textAlign: TextAlign.center),
        Text('tap to enlarge', style: TextStyle(fontSize: 9, color: Colors.grey[400]), textAlign: TextAlign.center),
      ],
    );
  }

  Future<void> _approveRegistration(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Registration'),
        content: Text('Approve ${user['fullName']}?\n\nThey will receive an email to sign in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Approve')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final db = await DatabaseService.instance.database;
        await db.update('users', {'ekycStatus': 'approved'}, where: 'id = ?', whereArgs: [user['id']]);
        await FirebaseService.instance.updateEkycStatus(userId: user['id'] as int, status: 'approved');
        await EmailService.sendRegistrationApproved(userEmail: user['email'] as String, userName: user['fullName'] as String);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user['fullName']} approved & email sent!'), backgroundColor: Colors.green));
          await _loadData();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rejectRegistration(Map<String, dynamic> user) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rejecting registration for ${user['fullName']}.'),
            const SizedBox(height: 12),
            const Text('Reason for rejection:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: reasonController, maxLines: 3, decoration: const InputDecoration(hintText: 'e.g. IC photo is blurry, selfie does not match IC...', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { if (reasonController.text.trim().isEmpty) return; Navigator.pop(context, true); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject & Notify'),
          ),
        ],
      ),
    );
    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      try {
        final db = await DatabaseService.instance.database;
        await db.update('users', {'ekycStatus': 'rejected'}, where: 'id = ?', whereArgs: [user['id']]);
        await FirebaseService.instance.updateEkycStatus(userId: user['id'] as int, status: 'rejected', rejectionReason: reasonController.text.trim());
        await EmailService.sendRegistrationRejected(userEmail: user['email'] as String, userName: user['fullName'] as String, rejectionReason: reasonController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user['fullName']} rejected & email sent!'), backgroundColor: Colors.red));
          await _loadData();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildActiveBeneficiariesTab() {
    return _confirmedBeneficiaries.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('No approved beneficiaries yet', style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                const SizedBox(height: 8),
                Text('Beneficiaries appear here after\nadmin approves their access request',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[400])),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _confirmedBeneficiaries.length,
            itemBuilder: (context, index) {
              final b = _confirmedBeneficiaries[index];
              final reviewedAt = b['reviewedAt'] as int?;
              final approvedTime = reviewedAt != null
                  ? _formatTime(DateTime.fromMillisecondsSinceEpoch(reviewedAt))
                  : '-';
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal,
                    radius: 24,
                    child: Text((b['fullName'] as String)[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  title: Text(b['fullName'] as String,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${b['relationship']} of ${b['ownerName']}',
                      style: TextStyle(color: Colors.grey[600])),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.teal[50], borderRadius: BorderRadius.circular(12)),
                        child: Text('Approved',
                            style: TextStyle(fontSize: 11, color: Colors.teal[700], fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 4),
                      Text(approvedTime, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildActivityLogTab() {
    return _recentActivity.isEmpty
        ? const Center(child: Text('No activity recorded yet'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _recentActivity.length,
            itemBuilder: (context, index) {
              final activity = _recentActivity[index];
              final timestamp = DateTime.fromMillisecondsSinceEpoch(activity['timestamp'] as int);
              final timeAgo = _formatTime(timestamp);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getActivityColor(activity['action']),
                    child: Icon(_getActivityIcon(activity['action']), color: Colors.white, size: 20),
                  ),
                  title: Text(activity['username'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${_formatActionLabel(activity['action'])} · ${activity['userType']}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(timeAgo,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                              color: _getActivityColor(activity['action']))),
                      Text(_formatDateTime(timestamp),
                          style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),
                ),
              );
            },
          );
  }

  String _formatActionLabel(String action) {
    switch (action) {
      case 'login': return 'Logged in';
      case 'logout': return 'Logged out';
      case 'emergency_login': return 'Emergency access';
      default: return action;
    }
  }

  Color _getActivityColor(String action) {
    switch (action) {
      case 'login': return Colors.green;
      case 'emergency_login': return Colors.orange;
      case 'logout': return Colors.grey;
      default: return Colors.blue;
    }
  }

  IconData _getActivityIcon(String action) {
    switch (action) {
      case 'login': return Icons.login;
      case 'emergency_login': return Icons.emergency;
      case 'logout': return Icons.logout;
      default: return Icons.info;
    }
  }

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
