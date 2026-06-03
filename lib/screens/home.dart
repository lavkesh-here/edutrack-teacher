import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'attendance.dart';
import 'timetable.dart';
import 'leave.dart';
import 'tests.dart';
import 'profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  static const _screens = [
    _HomeTab(),
    AttendanceScreen(),
    TimetableScreen(),
    LeaveScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x14F97316),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                _NavItem(icon: '🏠', label: 'Home', index: 0, current: _idx, onTap: (i) => setState(() => _idx = i)),
                _NavItem(icon: '📋', label: 'Attendance', index: 1, current: _idx, onTap: (i) => setState(() => _idx = i)),
                _NavItem(icon: '🕐', label: 'Timetable', index: 2, current: _idx, onTap: (i) => setState(() => _idx = i)),
                _NavItem(icon: '🗓️', label: 'Leave', index: 3, current: _idx, onTap: (i) => setState(() => _idx = i)),
                _NavItem(icon: '👤', label: 'Profile', index: 4, current: _idx, onTap: (i) => setState(() => _idx = i)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        child: Container(
          color: Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: active ? AppColors.sunLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  icon,
                  style: TextStyle(
                    fontSize: active ? 24 : 22,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: active ? AppColors.sun : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Home Tab ─────────────────────────────────────────────────────────────────

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  List<TimetableSlot>? _todaySlots;
  List<LeaveRequest>? _recentLeaves;
  bool _loadingTimetable = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final slots = await ApiClient.getMyTimetable();
      final today = DateTime.now().weekday; // Mon=1 … Sun=7
      setState(() {
        _todaySlots = slots.where((s) => s.dayOfWeek == today).toList()
          ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
        _loadingTimetable = false;
      });
    } catch (_) {
      setState(() => _loadingTimetable = false);
    }
    try {
      final leaves = await ApiClient.getMyLeaves();
      setState(() => _recentLeaves = leaves.take(3).toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final dateStr = '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.sun,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // Hero header
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.sun, Color(0xFFEA580C), AppColors.coral],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${greeting()} 👋',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.teacherName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _HeroChip('📅 $dateStr'),
                        _HeroChip('🏫 ${user.schoolName}'),
                        _HeroChip(_roleLabel(user.role)),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Stat tiles
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: '📝',
                        label: 'My Tests',
                        color: AppColors.sun,
                        lightColor: AppColors.sunLight,
                        onTap: () => _navigateTo(context, 2), // tests in more
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        icon: '🗓️',
                        label: 'Apply Leave',
                        color: AppColors.violet,
                        lightColor: AppColors.violetLight,
                        onTap: () => _navigateTab(context, 3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        icon: '📋',
                        label: 'Attendance',
                        color: AppColors.teal,
                        lightColor: AppColors.tealLight,
                        onTap: () => _navigateTab(context, 1),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Today's schedule
            SliverToBoxAdapter(
              child: SectionHeader(
                title: "Today's Schedule",
                action: 'Full Week →',
                onAction: () => _navigateTab(context, 2),
              ),
            ),
            SliverToBoxAdapter(
              child: _loadingTimetable
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.sun)),
                    )
                  : _todaySlots == null || _todaySlots!.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          child: AppCard(
                            child: const Center(
                              child: Text(
                                'No classes today 🎉',
                                style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: _todaySlots!.asMap().entries.map((e) {
                                final slot = e.value;
                                final isLast = e.key == _todaySlots!.length - 1;
                                return _PeriodRow(slot: slot, isLast: isLast);
                              }).toList(),
                            ),
                          ),
                        ),
            ),

            // Recent leave alerts
            if (_recentLeaves != null && _recentLeaves!.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: SectionHeader(title: '🔔 Leave Status'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    children: _recentLeaves!.map((l) => _LeaveAlert(leave: l)).toList(),
                  ),
                ),
              ),
            ],

            // Open assessment studio
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: InkWell(
                  onTap: () => _openTests(context),
                  borderRadius: BorderRadius.circular(20),
                  child: AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.violet, Color(0xFF7C3AED)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Center(
                              child: Text('🧠', style: TextStyle(fontSize: 22))),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assessment Studio',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                              Text(
                                'Generate tests, view scores & AI analysis',
                                style: TextStyle(fontSize: 11, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTab(BuildContext context, int tab) {
    final home = context.findAncestorStateOfType<_HomeScreenState>();
    home?.setState(() => home._idx = tab);
  }

  void _navigateTo(BuildContext context, int tab) {
    final home = context.findAncestorStateOfType<_HomeScreenState>();
    home?.setState(() => home._idx = tab);
  }

  void _openTests(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TestsScreen()));
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'hod': return '🎓 HOD';
      case 'admin': return '⚙️ Admin';
      case 'principal': return '🏛️ Principal';
      default: return '👩‍🏫 Teacher';
    }
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  const _HeroChip(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
      );
}

class _StatTile extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final Color lightColor;
  final VoidCallback onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.lightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      );
}

class _PeriodRow extends StatelessWidget {
  final TimetableSlot slot;
  final bool isLast;

  const _PeriodRow({required this.slot, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final timeStr = slot.startTime != null && slot.endTime != null
        ? '${slot.startTime}\n${slot.endTime}'
        : 'P${slot.periodNumber}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              timeStr,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
                height: 1.5,
              ),
            ),
          ),
          Container(
            width: 2,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.sun.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.subjectName ?? 'Subject',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  slot.sectionLabel,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveAlert extends StatelessWidget {
  final LeaveRequest leave;
  const _LeaveAlert({required this.leave});

  @override
  Widget build(BuildContext context) {
    final isApproved = leave.status == 'approved';
    final isRejected = leave.status == 'rejected';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isApproved
            ? AppColors.greenLight
            : isRejected
                ? AppColors.coralLight
                : AppColors.amberLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isApproved
              ? AppColors.green.withOpacity(0.3)
              : isRejected
                  ? AppColors.coral.withOpacity(0.3)
                  : AppColors.amber.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            isApproved ? '✅' : isRejected ? '❌' : '⏳',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_leaveLabel(leave.leaveType)} — ${leave.daysCount} day${leave.daysCount > 1 ? "s" : ""}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  '${fmtDate(leave.startDate)} → ${fmtDate(leave.endDate)} · ${_statusLabel(leave.status)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _leaveLabel(String t) {
    switch (t) {
      case 'sick': return '🤒 Sick Leave';
      case 'casual': return '🌴 Casual Leave';
      case 'earned': return '⭐ Earned Leave';
      default: return '📋 ${t[0].toUpperCase()}${t.substring(1)} Leave';
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'approved': return 'Approved by Principal';
      case 'rejected': return 'Rejected';
      default: return 'Pending approval';
    }
  }
}
