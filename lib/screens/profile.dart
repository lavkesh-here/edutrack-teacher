import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'leave.dart';
import 'payslip.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Hero
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0A00), Color(0xFF3D1A08)],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
                child: Stack(
                  children: [
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: AppColors.sun.withOpacity(0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.sun, AppColors.amber],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.25), width: 3),
                          ),
                          child: Center(
                            child: Text(
                              auth.initials,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          user.teacherName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.schoolName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          children: [
                            _ProfileChip(_roleLabel(user.role)),
                            _ProfileChip('🏫 ${user.schoolName}'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // My Info section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MY INFO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProfileRow(
                      icon: '👤',
                      iconColor: AppColors.sunLight,
                      label: 'Personal Details',
                      sub: 'Name, email, contact info',
                      onTap: () {},
                    ),
                    _ProfileRow(
                      icon: '🎓',
                      iconColor: AppColors.violetLight,
                      label: 'Qualifications',
                      sub: 'Degrees & certifications',
                      onTap: () {},
                    ),
                    _ProfileRow(
                      icon: '🗓️',
                      iconColor: AppColors.coralLight,
                      label: 'My Leaves',
                      sub: 'Balance, history & apply',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const LeaveScreen())),
                    ),
                    _ProfileRow(
                      icon: '💰',
                      iconColor: AppColors.greenLight,
                      label: 'Payroll History',
                      sub: 'Monthly salary & payslips',
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PayslipScreen())),
                    ),
                    _ProfileRow(
                      icon: '📋',
                      iconColor: AppColors.tealLight,
                      label: 'My Attendance',
                      sub: 'Your attendance record',
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Settings
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SETTINGS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ProfileRow(
                      icon: '🔔',
                      iconColor: AppColors.violetLight,
                      label: 'Notifications',
                      sub: 'Manage notification preferences',
                      onTap: () {},
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Danger zone
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACCOUNT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _confirmLogout(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.coral.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.coralLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                  child:
                                      Text('🚪', style: TextStyle(fontSize: 15))),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.coral,
                                  ),
                                ),
                                Text(
                                  'You will need to sign in again',
                                  style: TextStyle(
                                      fontSize: 11, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // App version — plain text at bottom
              const Center(
                child: Text(
                  'EduTrack Teacher v1.0',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'hod': return '🎓 Head of Dept';
      case 'admin': return '⚙️ Admin';
      case 'principal': return '🏛️ Principal';
      case 'director': return '🏢 Director';
      default: return '👩‍🏫 Teacher';
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) showSnack(context, 'Could not open URL', error: true);
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          'You will need to sign in again to access the app.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;
  const _ProfileChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
      );
}

class _ProfileRow extends StatelessWidget {
  final String icon;
  final Color iconColor;
  final String label;
  final String sub;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 7),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 15))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text)),
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.muted),
            ],
          ),
        ),
      );
}
