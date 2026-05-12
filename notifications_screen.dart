import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndMarkRead();
  }

  Future<void> _loadAndMarkRead() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser!.id!;
    final notifs = await DatabaseService.instance.getNotifications(userId);
    await DatabaseService.instance.markAllNotificationsRead(userId);
    if (mounted) setState(() { _notifications = notifs; _isLoading = false; });
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'beneficiary_accepted': return Icons.check_circle;
      case 'beneficiary_declined': return Icons.cancel;
      case 'beneficiary_removed':  return Icons.person_remove;
      default:                     return Icons.notifications;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'beneficiary_accepted': return Colors.green;
      case 'beneficiary_declined': return Colors.red;
      case 'beneficiary_removed':  return Colors.orange;
      default:                     return Colors.blue;
    }
  }

  String _formatTime(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), elevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No notifications yet', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    final type = n['type'] as String;
                    final isUnread = (n['isRead'] as int) == 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      color: isUnread ? Colors.blue[50] : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _colorForType(type).withValues(alpha: 0.15),
                          child: Icon(_iconForType(type), color: _colorForType(type), size: 22),
                        ),
                        title: Text(n['title'] as String,
                            style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(n['message'] as String, style: const TextStyle(fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(_formatTime(n['createdAt'] as int),
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: isUnread
                            ? Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle))
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
