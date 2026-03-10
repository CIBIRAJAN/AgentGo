import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme/app_colors.dart';
import '../../components/common/empty_state.dart';
import '../../utils/formatters.dart';
import '../agent_connection/agent_linking_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _markAllAsReadInitially();
  }

  Future<void> _markAllAsReadInitially() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', user.id)
          .eq('is_read', false); // Only update unread ones
    } catch (_) {}
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _notifications = (res as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', id);
    _loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('notifications'.tr()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () async {
              final user = Supabase.instance.client.auth.currentUser;
              if (user == null) return;
              await Supabase.instance.client
                  .from('notifications')
                  .update({'is_read': true})
                  .eq('user_id', user.id);
              _loadNotifications();
            },
            tooltip: 'mark_all_read'.tr(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'no_notifications'.tr(),
                  subtitle: 'all_caught_up'.tr(),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.builder(
                    itemCount: _notifications.length,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final isRead = notif['is_read'] == true;
                      final type = notif['type'];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isRead ? AppColors.border : AppColors.primary.withValues(alpha: 0.3),
                            width: isRead ? 1 : 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: _getNotifColor(type).withValues(alpha: 0.1),
                            child: Icon(_getNotifIcon(type), color: _getNotifColor(type), size: 20),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notif['title'] ?? 'Notification',
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(notif['content'] ?? ''),
                              const SizedBox(height: 8),
                              Text(
                                Formatters.date(DateTime.parse(notif['created_at'])),
                                style: const TextStyle(fontSize: 10, color: AppColors.textTertiary),
                              ),
                            ],
                          ),
                          onTap: () {
                            if (!isRead) _markAsRead(notif['id']);
                            
                            if (type == 'agent_request') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AgentLinkingScreen()),
                              );
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  IconData _getNotifIcon(String? type) {
    switch (type) {
      case 'agent_request':
        return Icons.person_add_rounded;
      case 'due_reminder':
        return Icons.receipt_long_rounded;
      case 'system':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getNotifColor(String? type) {
    switch (type) {
      case 'agent_request':
        return AppColors.warning;
      case 'due_reminder':
        return AppColors.primary;
      case 'system':
        return AppColors.secondary;
      default:
        return AppColors.textTertiary;
    }
  }
}
