import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../core/permission_gate.dart';

class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> with WidgetsBindingObserver {
  final Map<AppPermission, PermissionStatus> _statuses = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the OS Settings app is the one time a status can
    // change without this screen doing the asking — re-check on resume.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final loc = await Permission.locationWhenInUse.status;
    final notif = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _statuses[AppPermission.location] = loc;
        _statuses[AppPermission.notifications] = notif;
        _loading = false;
      });
    }
  }

  Future<void> _handleTap(AppPermission permission) async {
    final status = _statuses[permission];
    if (status == PermissionStatus.permanentlyDenied || status == PermissionStatus.restricted) {
      await openAppSettings();
    } else {
      await ensurePermission(context, permission);
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Permissions'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.text,
          elevation: 0,
          bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: AppColors.border)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'These are the only permissions this app ever asks for, and exactly what each is used for.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  _PermissionTile(
                    icon: Icons.location_on_outlined,
                    permission: AppPermission.location,
                    status: _statuses[AppPermission.location],
                    onTap: () => _handleTap(AppPermission.location),
                  ),
                  const SizedBox(height: 10),
                  _PermissionTile(
                    icon: Icons.notifications_outlined,
                    permission: AppPermission.notifications,
                    status: _statuses[AppPermission.notifications],
                    onTap: () => _handleTap(AppPermission.notifications),
                  ),
                ],
              ),
      );
}

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final AppPermission permission;
  final PermissionStatus? status;
  final VoidCallback onTap;

  const _PermissionTile({
    required this.icon, required this.permission, required this.status, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final granted = status == PermissionStatus.granted || status == PermissionStatus.limited;
    final permanentlyDenied = status == PermissionStatus.permanentlyDenied || status == PermissionStatus.restricted;
    final (label, color, bg) = granted
        ? ('Enabled', AppColors.teal, const Color(0xFFD1FAE5))
        : permanentlyDenied
            ? ('Blocked', AppColors.coral, AppColors.coralLight)
            : ('Not enabled', AppColors.muted, const Color(0xFFF3F4F6));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: context.primaryLight, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: context.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appPermissionLabel(permission), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(appPermissionRationale(permission), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
                  child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
                ),
              ],
            ),
          ),
          if (!granted) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(permanentlyDenied ? 'Open Settings' : 'Enable', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}
