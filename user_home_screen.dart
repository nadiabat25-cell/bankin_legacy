import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/bank_asset_model.dart';
import '../models/emergency_contact_model.dart';
import 'login_screen.dart';
import 'add_bank_asset_screen.dart';
import 'add_beneficiary_screen.dart';
import 'account_settings_screen.dart';
import 'change_pin_screen.dart';
import 'help_support_screen.dart';
import 'view_bank_asset_screen.dart';
import 'edit_bank_asset_screen.dart';
import 'view_beneficiary_screen.dart';
import 'edit_beneficiary_screen.dart';
import 'set_inactivity_period_screen.dart';
import 'notifications_screen.dart';
import '../services/firebase_service.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({Key? key}) : super(key: key);

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  int _selectedIndex = 0;
  List<BankAssetModel> _bankAssets = [];
  List<EmergencyContactModel> _emergencyContacts = [];
  bool _isLoading = true;
  Stream<int>? _notifStream;

  final _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToFirestoreChanges();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id ?? 0;
      setState(() {
        _notifStream = FirebaseService.instance.getUnreadNotificationCountStream(userId);
      });
    });
  }

  void _listenToFirestoreChanges() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser!.id!;
    _firestore.collection('bank_assets').where('userId', isEqualTo: userId).snapshots().listen((_) { if (mounted) _loadData(); });
    _firestore.collection('emergency_contacts').where('userId', isEqualTo: userId).snapshots().listen((_) { if (mounted) _loadData(); });
  }

  Future<void> _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser!.id!;
    final assets = await DatabaseService.instance.getBankAssetsByUserId(userId);
    final contacts = await DatabaseService.instance.getEmergencyContactsByUserId(userId);
    if (mounted) {
      setState(() {
        _bankAssets = assets;
        _emergencyContacts = contacts;
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToAddBankAsset() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBankAssetScreen()));
    if (result == true) _loadData();
  }

  Future<void> _navigateToAddBeneficiary() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddBeneficiaryScreen()));
    if (result == true) _loadData();
  }

  void _navigateToAccountSettings() => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
  void _navigateToChangePin() => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePinScreen()));
  void _navigateToSetInactivityPeriod() => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetInactivityPeriodScreen()));
  void _navigateToHelpSupport() => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpSupportScreen()));

  void _handleLogout() {
    final authService = Provider.of<AuthService>(context, listen: false);
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
    authService.logout();
  }

  Future<void> _viewBankAsset(BankAssetModel asset) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ViewBankAssetScreen(asset: asset)));
  }

  Future<void> _editBankAsset(BankAssetModel asset) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditBankAssetScreen(asset: asset)));
    if (result == true) _loadData();
  }

  String _hashPin(String pin) => sha256.convert(utf8.encode(pin)).toString();

  Future<bool> _verifyPin() async {
    // Store PIN value before dialog to avoid context-across-async-gap issues
    final authService = Provider.of<AuthService>(context, listen: false);
    final storedPin = authService.currentUser?.pin ?? '';
    bool result = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final pinController = TextEditingController();
        bool obscure = true;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Row(children: [
              Icon(Icons.lock, color: Colors.blue[700]),
              const SizedBox(width: 8),
              const Text('Verify PIN'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter your 6-digit PIN to confirm this action.', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                const SizedBox(height: 16),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  obscureText: obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    prefixIcon: const Icon(Icons.pin),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[50],
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_hashPin(pinController.text.trim()) != storedPin) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Incorrect PIN. Please try again.'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  result = true;
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );
      },
    );
    return result;
  }

  Future<void> _deleteBankAsset(BankAssetModel asset) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Asset'),
        content: Text('Are you sure you want to delete ${asset.institutionName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final verified = await _verifyPin();
    if (!verified) return;
    if (!mounted) return;

    try {
      await DatabaseService.instance.deleteBankAsset(asset.id!);
      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Asset deleted successfully'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  Future<void> _viewBeneficiary(EmergencyContactModel beneficiary) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ViewBeneficiaryScreen(beneficiary: beneficiary)));
  }

  Future<void> _editBeneficiary(EmergencyContactModel beneficiary) async {
    final verified = await _verifyPin();
    if (!verified) return;
    if (!mounted) return;
    final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditBeneficiaryScreen(beneficiary: beneficiary)));
    if (result == true) _loadData();
  }

  Future<void> _deleteBeneficiary(EmergencyContactModel contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Beneficiary'),
        content: Text('Are you sure you want to remove ${contact.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    final verified = await _verifyPin();
    if (!verified) return;
    if (!mounted) return;

    try {
      await DatabaseService.instance.deleteEmergencyContact(contact.id!);
      if (!mounted) return;
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beneficiary removed successfully'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Banking Legacy'),
        actions: [
          StreamBuilder<int>(
            stream: _notifStream,
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Notifications',
                icon: Badge(
                  label: Text('$count'),
                  isLabelVisible: count > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                },
              );
            },
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
          IconButton(icon: const Icon(Icons.logout), onPressed: _handleLogout),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
        index: _selectedIndex,
        children: [
          _buildDashboard(user),
          _buildBankAssets(),
          _buildEmergencyContacts(),
          _buildProfile(user),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance), label: 'Assets'),
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: 'Contacts'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDashboard(user) {

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(user.fullName[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.account_balance, size: 40, color: Colors.blue[700]),
                        const SizedBox(height: 8),
                        Text('${_bankAssets.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[700])),
                        const Text('Bank Assets'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Icon(Icons.contacts, size: 40, color: Colors.green[700]),
                        const SizedBox(height: 8),
                        Text('${_emergencyContacts.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700])),
                        const Text('Beneficiaries'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Empty state prompts
          if (_bankAssets.isEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_outlined, color: Colors.blue[700], size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No bank assets yet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[900])),
                          const SizedBox(height: 4),
                          Text('Add your first bank asset to start building your legacy vault.', style: TextStyle(fontSize: 13, color: Colors.blue[800])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_emergencyContacts.isEmpty) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.contacts_outlined, color: Colors.green[700], size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('No beneficiaries added', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[900])),
                          const SizedBox(height: 4),
                          Text('Add beneficiaries so your assets are protected and allocated.', style: TextStyle(fontSize: 13, color: Colors.green[800])),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToAddBankAsset,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Asset'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _navigateToAddBeneficiary,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Add Beneficiary'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBankAssets() {
    return _bankAssets.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No bank assets added yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: _navigateToAddBankAsset, icon: const Icon(Icons.add), label: const Text('Add Your First Asset')),
        ],
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bankAssets.length,
      itemBuilder: (context, index) {
        final asset = _bankAssets[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Colors.blue[100], child: Icon(Icons.account_balance, color: Colors.blue[700])),
            title: Text(asset.institutionName),
            subtitle: Text(asset.assetType),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'view') { _viewBankAsset(asset); }
                else if (value == 'edit') { _editBankAsset(asset); }
                else if (value == 'delete') { _deleteBankAsset(asset); }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 20), SizedBox(width: 8), Text('View')])),
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyContacts() {
    return _emergencyContacts.isEmpty
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No beneficiaries added yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 24),
          ElevatedButton.icon(onPressed: _navigateToAddBeneficiary, icon: const Icon(Icons.person_add), label: const Text('Add First Beneficiary')),
        ],
      ),
    )
        : ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _emergencyContacts.length,
      itemBuilder: (context, index) {
        final contact = _emergencyContacts[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[100],
              child: Text(contact.fullName[0].toUpperCase(), style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
            ),
            title: Text(contact.fullName),
            subtitle: Text(contact.relationship),
            trailing: PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'view') { _viewBeneficiary(contact); }
                else if (value == 'edit') { _editBeneficiary(contact); }
                else if (value == 'delete') { _deleteBeneficiary(contact); }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 20), SizedBox(width: 8), Text('View')])),
                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Edit')])),
                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfile(user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(user.fullName[0].toUpperCase(), style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
          Text(user.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text('@${user.username}', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          const SizedBox(height: 24),
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'For security purposes, personal details such as your email, phone number, and IC number are not displayed here.\n\nTo update your contact information, please visit a bank branch in person with valid identification.',
                      style: TextStyle(fontSize: 13, color: Colors.blue[900], height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(leading: const Icon(Icons.settings), title: const Text('Account Settings'), trailing: const Icon(Icons.chevron_right), onTap: _navigateToAccountSettings),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.security), title: const Text('Change PIN'), trailing: const Icon(Icons.chevron_right), onTap: _navigateToChangePin),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.timer), title: const Text('Set Inactivity Period'), trailing: const Icon(Icons.chevron_right), onTap: _navigateToSetInactivityPeriod),
                const Divider(height: 1),
                ListTile(leading: const Icon(Icons.help), title: const Text('Help & Support'), trailing: const Icon(Icons.chevron_right), onTap: _navigateToHelpSupport),
              ],
            ),
          ),
        ],
      ),
    );
  }
}