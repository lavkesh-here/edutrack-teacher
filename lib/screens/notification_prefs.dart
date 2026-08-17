import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class NotificationPrefsScreen extends StatefulWidget {
  const NotificationPrefsScreen({super.key});

  @override
  State<NotificationPrefsScreen> createState() => _NotificationPrefsScreenState();
}

class _NotificationPrefsScreenState extends State<NotificationPrefsScreen> {
  bool _loading = true;
  String? _error;
  Map<String, bool> _prefs = {};

  static const _prefMeta = [
    (key: 'leave_reviewed',         icon: '🗓️', title: 'Leave Status',           sub: 'Get notified when your leave is approved or rejected'),
    (key: 'attendance_alerts',      icon: '📋', title: 'Attendance Alerts',       sub: 'Alerts related to your attendance records'),
    (key: 'forum_comments',         icon: '💬', title: 'Forum Replies',           sub: 'When someone replies to your announcements or posts'),
    (key: 'homework',               icon: '📚', title: 'Homework',                sub: 'New homework, work log activity, and reviews'),
    (key: 'fees',                   icon: '💳', title: 'Fees',                    sub: 'Fee reminders and payment updates'),
    (key: 'circulars',              icon: '📰', title: 'Circulars',               sub: 'New school circulars'),
    (key: 'ptm',                    icon: '🤝', title: 'PTM',                     sub: 'Parent-teacher meeting registrations and updates'),
    (key: 'tests',                  icon: '📝', title: 'Tests',                   sub: 'Test results and grading updates'),
    (key: 'payroll',                icon: '💰', title: 'Payroll',                 sub: 'Payslip and payroll updates'),
    (key: 'transport',              icon: '🚌', title: 'Transport',               sub: 'Transport route and assignment updates'),
    (key: 'predictive_alerts',      icon: '⚠️', title: 'Predictive Alerts',       sub: 'Early-warning alerts for at-risk students'),
    (key: 'custom_notifications',   icon: '🔔', title: 'Custom Notifications',    sub: 'General school notifications and admin messages'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getNotificationPrefs();
      if (mounted) {
        setState(() {
          _prefs = {
            for (final m in _prefMeta)
              m.key: (data[m.key] as bool?) ?? true,
          };
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggle(String key, bool value) async {
    // Optimistic update
    setState(() => _prefs[key] = value);
    try {
      final updated = await ApiClient.updateNotificationPrefs({key: value});
      if (mounted) {
        setState(() {
          for (final m in _prefMeta) {
            if (updated.containsKey(m.key)) {
              _prefs[m.key] = (updated[m.key] as bool?) ?? true;
            }
          }
        });
      }
    } on ApiError catch (e) {
      // Revert on failure
      setState(() => _prefs[key] = !value);
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : _body(),
    );
  }

  Widget _body() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.skyLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sky.withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              Text('ℹ️', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Control which notifications you receive from Edtrack.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.sky),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section label
        const Text(
          'NOTIFICATION TYPES',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),

        // Preference rows
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: _prefMeta.asMap().entries.map((entry) {
              final i = entry.key;
              final m = entry.value;
              final isLast = i == _prefMeta.length - 1;
              final value = _prefs[m.key] ?? true;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: value ? context.primaryLight : AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(m.icon, style: const TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: value ? AppColors.text : AppColors.muted,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                m.sub,
                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          key: Key('notif_pref_${m.key}'),
                          value: value,
                          onChanged: (v) => _toggle(m.key, v),
                          activeColor: context.primary,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast) const Divider(height: 1, color: AppColors.border, indent: 14, endIndent: 14),
                ],
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Note about push notifications
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.amberLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.amber.withOpacity(0.3)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⚠️', style: TextStyle(fontSize: 16)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Disabling a notification type here prevents in-app alerts. Device-level notification settings in your phone\'s Settings app also apply.',
                  style: TextStyle(fontSize: 11, color: AppColors.text2, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.muted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
