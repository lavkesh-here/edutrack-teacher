import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.getTeacherNotifications();
      if (mounted) setState(() { _notifications = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(int id) async {
    try {
      await ApiClient.markNotificationRead(id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1) _notifications[idx] = {..._notifications[idx], 'is_read': true};
      });
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => !(n['is_read'] as bool? ?? false)).toList();
    for (final n in unread) {
      try { await ApiClient.markNotificationRead(n['id'] as int); } catch (_) {}
    }
    setState(() {
      _notifications = _notifications.map((n) => {...n, 'is_read': true}).toList();
    });
  }

  String _icon(String type) {
    switch (type) {
      case 'leave_reviewed': return '🗓️';
      case 'comment_posted': return '💬';
      case 'attendance_absent': return '📋';
      default: return '🔔';
    }
  }

  Color _iconBg(String type) {
    switch (type) {
      case 'leave_reviewed': return AppColors.violetLight;
      case 'comment_posted': return AppColors.tealLight;
      case 'attendance_absent': return AppColors.coralLight;
      default: return AppColors.skyLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !(n['is_read'] as bool? ?? false)).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: false,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read',
                  style: TextStyle(fontSize: 12, color: AppColors.sun, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
          : _notifications.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔔', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('No notifications yet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                      SizedBox(height: 6),
                      Text('Leave reviews and forum replies will appear here',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                          textAlign: TextAlign.center),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.sun,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final id = n['id'] as int;
                      final title = n['title'] as String? ?? '';
                      final body = n['body'] as String? ?? '';
                      final type = n['notification_type'] as String? ?? '';
                      final isRead = n['is_read'] as bool? ?? false;
                      final date = (n['created_at'] as String? ?? '').split('T').first;

                      return GestureDetector(
                        onTap: isRead ? null : () => _markRead(id),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isRead ? Colors.white : AppColors.sunLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: isRead ? AppColors.border : AppColors.sun.withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                    color: _iconBg(type),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Center(
                                    child: Text(_icon(type),
                                        style: const TextStyle(fontSize: 18))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isRead
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            color: AppColors.text)),
                                    if (body.isNotEmpty && body != title) ...[
                                      const SizedBox(height: 2),
                                      Text(body,
                                          style: const TextStyle(
                                              fontSize: 12, color: AppColors.muted)),
                                    ],
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(fmtDate(date),
                                            style: const TextStyle(
                                                fontSize: 10, color: AppColors.muted)),
                                        if (!isRead) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 6, height: 6,
                                            decoration: const BoxDecoration(
                                                color: AppColors.sun,
                                                shape: BoxShape.circle),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text('Tap to mark read',
                                              style: TextStyle(
                                                  fontSize: 9, color: AppColors.sun)),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
