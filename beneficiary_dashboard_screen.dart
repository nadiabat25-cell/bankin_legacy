import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../services/aes_encryption_service.dart';
import '../models/emergency_contact_model.dart';
import '../models/user_model.dart';
import '../models/bank_asset_model.dart';
import 'login_screen.dart';

class BeneficiaryDashboardScreen extends StatefulWidget {
  final EmergencyContactModel beneficiary;
  final UserModel deceasedUser;

  const BeneficiaryDashboardScreen({
    Key? key,
    required this.beneficiary,
    required this.deceasedUser,
  }) : super(key: key);

  @override
  State<BeneficiaryDashboardScreen> createState() =>
      _BeneficiaryDashboardScreenState();
}

class _BeneficiaryDashboardScreenState
    extends State<BeneficiaryDashboardScreen> {
  List<BankAssetModel> _assets = [];
  List<EmergencyContactModel> _beneficiaries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final assets = await DatabaseService.instance
        .getBankAssetsByUserId(widget.deceasedUser.id!);
    final beneficiaries = await DatabaseService.instance
        .getEmergencyContactsByUserId(widget.deceasedUser.id!);

    setState(() {
      _assets = assets;
      _beneficiaries = beneficiaries;
      _isLoading = false;
    });
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beneficiary Access'),
        backgroundColor: Colors.orange[700],
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Read-Only Notice
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Read-Only Access: You can view information but cannot make changes',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Beneficiary Info Card
            Card(
              color: Colors.orange[50],
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.orange[200],
                      child: Text(
                        widget.beneficiary.fullName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[900],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.beneficiary.fullName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[700],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.beneficiary.relationship,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.orange[300]),
                    const SizedBox(height: 8),
                    Text(
                      'Account Holder: ${widget.deceasedUser.fullName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Relationship: ${widget.beneficiary.relationship}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Access Status
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Access Granted',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Granted on: ${_formatDate(widget.beneficiary.accessGrantedAt!)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Assets Section
            Row(
              children: [
                Icon(Icons.account_balance, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Bank Assets',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text('${_assets.length} Total'),
                  backgroundColor: Colors.blue[100],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_assets.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.account_balance_outlined,
                        size: 60,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No bank assets recorded',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._assets.map((asset) => _buildAssetCard(asset)),

            const SizedBox(height: 24),

            // Other Beneficiaries Section
            Row(
              children: [
                Icon(Icons.people, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text(
                  'All Beneficiaries',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text('${_beneficiaries.length} Total'),
                  backgroundColor: Colors.green[100],
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._beneficiaries.map((beneficiary) =>
                _buildBeneficiaryCard(beneficiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetCard(BankAssetModel asset) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(Icons.account_balance, color: Colors.blue[700]),
        ),
        title: Text(
          asset.institutionName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(asset.assetType),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (asset.accountIdentifier != null) ...[
                  _buildDetailRow(
                    Icons.numbers,
                    'Account Identifier',
                    asset.accountIdentifier!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (asset.estimatedValue != null) ...[
                  _buildDetailRow(
                    Icons.attach_money,
                    'Estimated Value',
                    asset.estimatedValue!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (asset.specialInstructions != null) ...[
                  _buildDetailRow(
                    Icons.note,
                    'Special Instructions',
                    asset.specialInstructions!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (asset.encryptedUsername != null ||
                    asset.encryptedPassword != null) ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Login credentials available',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _showCredentials(asset),
                    icon: const Icon(Icons.visibility),
                    label: const Text('View Login Credentials'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ] else ...[
                  const Divider(),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'No login credentials stored',
                            style: TextStyle(fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeneficiaryCard(EmergencyContactModel beneficiary) {
    final isCurrentUser = beneficiary.id == widget.beneficiary.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCurrentUser ? Colors.orange[50] : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrentUser ? Colors.orange[200] : Colors.green[100],
          child: Text(
            beneficiary.fullName[0].toUpperCase(),
            style: TextStyle(
              color: isCurrentUser ? Colors.orange[900] : Colors.green[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(beneficiary.fullName)),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[700],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          beneficiary.relationship,
        ),
        trailing: Icon(
          beneficiary.accessGranted ? Icons.check_circle : Icons.pending,
          color: beneficiary.accessGranted ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () => _copyToClipboard(value, label),
            tooltip: 'Copy',
            color: Colors.blue[700],
          ),
        ],
      ),
    );
  }

  void _showCredentials(BankAssetModel asset) {
    // Require PIN (last 6 digits of deceased IC) before revealing credentials
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.lock, color: Colors.orange[700]),
          const SizedBox(width: 8),
          const Text('Verify Identity'),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter the last 6 digits of ${widget.deceasedUser.fullName}\'s IC number to view credentials.',
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Last 6 digits of IC',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final entered = pinController.text.trim();
              final ic = widget.deceasedUser.icNumber.replaceAll(RegExp(r'\D'), '');
              final expectedPin = ic.length >= 6 ? ic.substring(ic.length - 6) : ic;
              if (entered == expectedPin) {
                Navigator.pop(ctx);
                _revealCredentials(asset);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700]),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _revealCredentials(BankAssetModel asset) {
    try {
      final encryptionService = AESEncryptionService();
      String? username;
      String? password;

      if (asset.encryptedUsername != null) {
        username = encryptionService.decrypt(
          asset.encryptedUsername!,
          widget.deceasedUser.aesKey,
        );
      }

      if (asset.encryptedPassword != null) {
        password = encryptionService.decrypt(
          asset.encryptedPassword!,
          widget.deceasedUser.aesKey,
        );
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.lock_open, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Login Credentials',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Read-only access. Tap to copy.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (username != null) ...[
                  const Text(
                    'Username',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _copyToClipboard(username!, 'Username'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              username,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Icon(Icons.copy, size: 18, color: Colors.blue[700]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (password != null) ...[
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => _copyToClipboard(password!, 'Password'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              password,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Icon(Icons.copy, size: 18, color: Colors.blue[700]),
                        ],
                      ),
                    ),
                  ),
                ],
                if (username == null && password == null)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No credentials available',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to decrypt: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
