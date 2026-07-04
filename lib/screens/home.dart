import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../core/auth.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'attendance.dart';
import 'timetable.dart';
import 'leave.dart';
import 'tests.dart';
import 'feed.dart';
import 'calendar_screen.dart';
import 'worklog.dart';
import 'notify_parents.dart';
import 'payslip.dart';
import 'my_students.dart';
import 'admin_parents.dart';
import 'admin_transport.dart';
import 'admin_school_settings.dart';
import 'admin_work_logs.dart';
import 'admin_attenders.dart';
import 'admin_fee_management.dart';
import 'admin_leave_config.dart';
import 'director_dashboard.dart';
import 'notifications_screen.dart';
import 'todos.dart';
import 'my_attendance.dart';
import 'qualifications.dart';
import 'syllabus.dart';
import 'notification_prefs.dart';
import 'faq_screen.dart';
import 'support_chat_screen.dart';
import '../core/recents.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _idx = 0;

  static final _attendanceKey = GlobalKey<AttendanceScreenState>();

  static final _screens = [
    _HomeTab(),
    AttendanceScreen(key: _attendanceKey),
    MyStudentsScreen(),
    FeedScreen(),
    _MoreTab(),
  ];

  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (_) {
        // If on attendance tab and in swipe mode, exit swipe instead of switching tabs
        if (_idx == 1 && (_attendanceKey.currentState?.tryExitSwipeMode() ?? false)) return;
        if (_idx != 0) {
          setState(() => _idx = 0);
          return;
        }
        // On home tab: double-tap back to exit
        final now = DateTime.now();
        if (_lastBackPress == null || now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
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
          child: MediaQuery.withNoTextScaling(
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  _NavItem(key: const Key('nav_home'), icon: '🏠', label: 'Home', index: 0, current: _idx, onTap: (i) { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _idx = i); }),
                  _NavItem(key: const Key('nav_attendance'), icon: '📋', label: 'Attendance', index: 1, current: _idx, onTap: (i) { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _idx = i); }),
                  _NavItem(key: const Key('nav_students'), icon: '👥', label: 'Students', index: 2, current: _idx, onTap: (i) { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _idx = i); }),
                  _NavItem(key: const Key('nav_forum'), icon: '📢', label: 'Forum', index: 3, current: _idx, onTap: (i) { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _idx = i); }),
                  _NavItem(key: const Key('nav_more'), icon: '☰', label: 'More', index: 4, current: _idx, onTap: (i) { FocusManager.instance.primaryFocus?.unfocus(); setState(() => _idx = i); }),
                ],
              ),
            ),
          ),
        ),
      ),
    ), // Scaffold
    ); // PopScope
  }
}

class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final int index;
  final int current;
  final void Function(int) onTap;

  const _NavItem({
    super.key,
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
  List<TodoItem>? _activeTodos;
  List<RecentScreen> _recents = [];
  List<SpacedRepChapter> _spacedRep = [];
  bool _loadingTimetable = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final slots = await ApiClient.getMyTimetable();
      final today = DateTime.now().weekday;
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
    try {
      final todos = await ApiClient.getTodos();
      final todayStr = _isoToday();
      final relevant = todos.where((t) =>
        t.status != 'done' &&
        (t.status == 'in_progress' ||
         (t.dueDate != null && t.dueDate!.compareTo(todayStr) <= 0))
      ).toList();
      setState(() => _activeTodos = relevant);
    } catch (_) {}
    try {
      final r = await RecentsManager.load();
      if (mounted) setState(() => _recents = r);
    } catch (_) {}
    try {
      final sr = await ApiClient.getSpacedRepetition();
      if (mounted) setState(() => _spacedRep = sr);
    } catch (_) {}
  }

  static String _isoToday() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
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
      body: SafeArea(
        child: Column(
          children: [
            // Static hero header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.sun, Color(0xFFEA580C), AppColors.coral],
                ),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${greeting()} 👋',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user.teacherName,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      if (auth.features.aiSupportChat) ...[
                        GestureDetector(
                          onTap: () => _openScreen(context, const SupportChatScreen()),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.headset_mic_outlined, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      GestureDetector(
                        onTap: () => _openScreen(context, const NotificationsScreen()),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                        ),
                      ),
                    ],
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
            Expanded(child: RefreshIndicator(
              color: AppColors.sun,
              onRefresh: _load,
              child: CustomScrollView(
          slivers: [

            // Recently viewed chips — only More-tab-exclusive items (max 3)
            if (_recents.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recently Viewed',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: Builder(builder: (context) {
                          final filtered = _recents.take(3).toList();
                          return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final r = filtered[i];
                            return GestureDetector(
                              onTap: () => _openRecent(context, r.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: AppColors.border, width: 1.5),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(r.emoji,
                                        style: const TextStyle(fontSize: 13)),
                                    const SizedBox(width: 5),
                                    Text(
                                      r.label,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                        }),
                      ),
                    ],
                  ),
                ),
              ),

            // 2 Stat tiles (1x2 row)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, _recents.isEmpty ? 14 : 10, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatTile(
                        icon: '📅',
                        label: 'Events',
                        color: AppColors.sky,
                        lightColor: AppColors.skyLight,
                        onTap: () => _openScreen(context, const CalendarScreen()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        icon: '✅',
                        label: 'To-Do List',
                        count: _activeTodos == null ? null : _activeTodos!.length,
                        color: AppColors.teal,
                        lightColor: AppColors.tealLight,
                        onTap: () => _openScreen(context, const TodosScreen(), recentId: 'todos'),
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
                onAction: () => _openScreen(context, const TimetableScreen()),
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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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

            // Today's tasks (due today, overdue, or in-progress)
            if (_activeTodos != null && _activeTodos!.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: "Today's Tasks",
                  action: 'View All →',
                  onAction: () => _openScreen(context, const TodosScreen()),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Column(
                    children: _activeTodos!.take(5).map((t) => _TodoMiniTile(todo: t, onTap: () => _showTodoStatusSheet(t))).toList(),
                  ),
                ),
              ),
            ],

            // Quick actions
            const SliverToBoxAdapter(
              child: SectionHeader(title: 'Quick Actions'),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _QuickPill(
                      label: '📋 Mark Attendance',
                      color: AppColors.sun,
                      onTap: () => _navigateTab(context, 1, recentId: 'attendance'),
                    ),
                    _QuickPill(
                      label: '📚 Add Homework',
                      color: AppColors.coral,
                      onTap: () => _openScreen(context, const WorkLogScreen(), recentId: 'worklog'),
                    ),
                    _QuickPill(
                      label: '📝 Apply Leave',
                      color: AppColors.violet,
                      onTap: () => _openScreen(context, const LeaveScreen(), recentId: 'leaves'),
                    ),
                    _QuickPill(
                      label: '🔔 Notify Parents',
                      color: AppColors.teal,
                      onTap: () => _openScreen(context, const NotifyParentsScreen(), recentId: 'notify'),
                    ),
                    _QuickPill(
                      label: '📊 Post Results',
                      color: AppColors.amber,
                      onTap: () => _openScreen(context, const TestsScreen(), recentId: 'results'),
                    ),
                    _QuickPill(
                      label: '🕐 Sign In',
                      color: AppColors.sky,
                      onTap: () => _openScreen(context, const MyAttendanceScreen()),
                    ),
                  ],
                ),
              ),
            ),

            // D3 — Revision reminders (spaced repetition)
            if (_spacedRep.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: '🔁 Revision Reminders',
                  action: 'Web Studio →',
                  onAction: () {},
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'These chapters need attention based on class performance:',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _spacedRep.take(6).map((c) {
                            final isLowScore = c.urgency == 'low_score';
                            final bg = isLowScore ? AppColors.coralLight : AppColors.amberLight;
                            final fg = isLowScore ? AppColors.coral : AppColors.amber;
                            final label = c.avgPct != null
                                ? '${c.chapterName} · ${c.avgPct!.toStringAsFixed(0)}%'
                                : '${c.chapterName} · Stale';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                label,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generate revision tests in Assessment Studio on web.',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Admin features section (admin/principal/director only)
            if (user.role == 'admin' || user.role == 'principal' || user.role == 'director') Builder(builder: (ctx) {
              final flags = ctx.read<AuthProvider>().features;
              final isAdminRole = user.role == 'admin';
              return SliverList(delegate: SliverChildListDelegate([
                const SectionHeader(title: '⚙️ Admin'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Column(
                    children: [
                      if (user.role == 'director')
                        _FeatureRow(icon: '📊', iconBg: AppColors.violetLight, title: 'Director Analytics', sub: 'School KPIs, class & teacher performance',
                            onTap: () => _openScreen(context, const DirectorDashboardScreen(), recentId: 'director_analytics')),
                      _FeatureRow(icon: '👨‍👩‍👦', iconBg: AppColors.tealLight, title: 'Parent Accounts', sub: 'Create, link & manage parent access',
                          onTap: () => _openScreen(context, const AdminParentsScreen(), recentId: 'parents')),
                      if (flags.transport)
                        _FeatureRow(icon: '🚌', iconBg: AppColors.skyLight, title: 'Transport', sub: 'Routes, stops & student assignments',
                            onTap: () => _openScreen(context, const AdminTransportScreen(), recentId: 'transport')),
                      _FeatureRow(icon: '🏫', iconBg: AppColors.violetLight, title: 'School Settings', sub: 'Contact info, branding & preferences',
                          onTap: () => _openScreen(context, const AdminSchoolSettingsScreen(), recentId: 'school_settings')),
                      if (flags.workLogs)
                        _FeatureRow(icon: '📋', iconBg: AppColors.amberLight, title: 'Work Log Overview', sub: 'All classes & acknowledgment stats',
                            onTap: () => _openScreen(context, const AdminWorkLogsScreen(), recentId: 'admin_worklogs')),
                      _FeatureRow(icon: '👤', iconBg: AppColors.coralLight, title: 'Attenders', sub: 'Authorized pickup persons',
                          onTap: () => _openScreen(context, const AdminAttendersScreen(), recentId: 'attenders')),
                      if (flags.fees)
                        _FeatureRow(icon: '💰', iconBg: AppColors.amberLight, title: 'Fee Management', sub: 'Fee components & payment status',
                            onTap: () => _openScreen(context, const AdminFeeManagementScreen(), recentId: 'fees')),
                      if (flags.payroll)
                        _FeatureRow(icon: '💳', iconBg: AppColors.tealLight, title: 'Payroll', sub: 'Teacher salary & auto-calculation',
                            onTap: () => _openScreen(context, const PayslipScreen(), recentId: 'payroll')),
                      // Leave Config: admin only
                      if (isAdminRole)
                        _FeatureRow(icon: '⚙️', iconBg: AppColors.skyLight, title: 'Leave Config', sub: 'Casual, sick & working day settings',
                            onTap: () => _openScreen(context, const AdminLeaveConfigScreen(), recentId: 'leave_config')),
                    ],
                  ),
                ),
              ]));
            }),

            // Leave alerts — pending only
            if (_recentLeaves != null && _recentLeaves!.any((l) => l.status == 'pending')) ...[
              const SliverToBoxAdapter(
                child: SectionHeader(title: '🔔 Leave Status'),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    children: _recentLeaves!.where((l) => l.status == 'pending').map((l) => _LeaveAlert(leave: l)).toList(),
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      )), // RefreshIndicator + Expanded
          ],
        ), // Column
      ), // SafeArea
    );
  }

  Future<void> _setTodoStatus(TodoItem todo, String status) async {
    try {
      await ApiClient.updateTodo(todo.id, status: status);
      await _load();
      if (mounted) {
        final msg = switch (status) {
          'in_progress' => 'Moved to In Progress',
          'done' => 'Marked as Done ✓',
          _ => 'Moved to To Do',
        };
        showSnack(context, msg);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Update failed', error: true);
    }
  }

  void _showTodoStatusSheet(TodoItem todo) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text(todo.title,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            const Text('Update status', style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            ...['todo', 'in_progress', 'done'].map((s) {
              final (label, color, bg) = switch (s) {
                'in_progress' => ('In Progress', const Color(0xFFB45309), const Color(0xFFFEF3C7)),
                'done'        => ('Done', AppColors.teal, const Color(0xFFD1FAE5)),
                _             => ('To Do', AppColors.muted, const Color(0xFFF3F4F6)),
              };
              final isSelected = todo.status == s;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () { Navigator.pop(context); _setTodoStatus(todo, s); },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: color, width: 2) : null,
                    ),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                        const Spacer(),
                        if (isSelected) Icon(Icons.check, color: color, size: 18),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _navigateTab(BuildContext context, int tab, {String? recentId}) async {
    if (recentId != null) {
      await RecentsManager.record(recentId);
      if (mounted) {
        final r = await RecentsManager.load();
        if (mounted) setState(() => _recents = r);
      }
    }
    if (!context.mounted) return;
    final home = context.findAncestorStateOfType<_HomeScreenState>();
    home?.setState(() => home._idx = tab);
  }

  Future<void> _openScreen(BuildContext context, Widget screen, {String? recentId}) async {
    if (recentId != null) await RecentsManager.record(recentId);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted && recentId != null) {
      final r = await RecentsManager.load();
      if (mounted) setState(() => _recents = r);
    }
  }

  void _openRecent(BuildContext context, String id) {
    switch (id) {
      case 'schedule':        _openScreen(context, const TimetableScreen(), recentId: id);
      case 'parents':         _openScreen(context, const AdminParentsScreen(), recentId: id);
      case 'transport':       _openScreen(context, const AdminTransportScreen(), recentId: id);
      case 'school_settings': _openScreen(context, const AdminSchoolSettingsScreen(), recentId: id);
      case 'admin_worklogs':  _openScreen(context, const AdminWorkLogsScreen(), recentId: id);
      case 'attenders':       _openScreen(context, const AdminAttendersScreen(), recentId: id);
      case 'fees':            _openScreen(context, const AdminFeeManagementScreen(), recentId: id);
      case 'leave_config':         _openScreen(context, const AdminLeaveConfigScreen(), recentId: id);
      case 'director_analytics':   _openScreen(context, const DirectorDashboardScreen(), recentId: id);
      case 'leaves':          _openScreen(context, const LeaveScreen(), recentId: id);
      case 'payroll':         _openScreen(context, const PayslipScreen(), recentId: id);
      case 'todos':           _openScreen(context, const TodosScreen(), recentId: id);
      case 'qualifications':  _openScreen(context, const QualificationsScreen(), recentId: id);
      case 'syllabus':        _openScreen(context, const SyllabusScreen(), recentId: id);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'hod': return '🎓 HOD';
      case 'admin': return '⚙️ Admin';
      case 'principal': return '🏛️ Principal';
      case 'director': return '🏢 Director';
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
  final int? count;
  final Color color;
  final Color lightColor;
  final VoidCallback onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    this.count,
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
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: lightColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                    if (count != null)
                      Text('$count', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 14, color: color.withOpacity(0.5)),
            ],
          ),
        ),
      );
}

class _TodoMiniTile extends StatelessWidget {
  final TodoItem todo;
  final VoidCallback? onTap;
  const _TodoMiniTile({required this.todo, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOverdue = todo.dueDate != null &&
        DateTime.tryParse(todo.dueDate!)?.isBefore(DateTime.now()) == true &&
        todo.status != 'done';
    final (chipLabel, chipBg, chipFg) = switch (todo.status) {
      'in_progress' => ('IN PROGRESS', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      _             => (isOverdue ? 'OVERDUE' : 'TODO',
                        isOverdue ? const Color(0xFFFFEDED) : const Color(0xFFF3F4F6),
                        isOverdue ? AppColors.coral : AppColors.muted),
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOverdue ? AppColors.coral.withOpacity(0.3) : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(todo.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(6)),
              child: Text(chipLabel,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: chipFg)),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.muted),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickPill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      );
}

class _FeatureRow extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String sub;
  final VoidCallback onTap;

  const _FeatureRow({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                    ),
                    Text(
                      sub,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.muted),
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

// ── More Tab ─────────────────────────────────────────────────────────────────

class _MoreTab extends StatefulWidget {
  const _MoreTab();

  @override
  State<_MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<_MoreTab> {
  bool _bioEnabled = false;
  bool _uploadingPhoto = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadBioState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = '${info.version}+${info.buildNumber}');
    });
  }

  Future<void> _loadBioState() async {
    final auth = context.read<AuthProvider>();
    final enabled = await auth.isBiometricEnabled;
    if (mounted) setState(() => _bioEnabled = enabled);
  }

  Future<void> _setBioEnabled(bool value) async {
    final auth = context.read<AuthProvider>();
    final confirmed = await auth.authenticateBiometric(
      value ? 'Confirm your biometric to enable quick unlock' : 'Confirm your biometric to disable quick unlock',
    );
    if (!confirmed || !mounted) return;

    if (value) {
      await auth.enableBiometric();
      if (mounted) {
        setState(() => _bioEnabled = true);
        showSnack(context, 'Biometric unlock enabled');
      }
    } else {
      await auth.disableBiometric();
      if (mounted) setState(() => _bioEnabled = false);
    }
  }

  Future<void> _push(BuildContext context, Widget screen, {String? recentId}) async {
    if (recentId != null) await RecentsManager.record(recentId);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _pickAndUploadPhoto(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'Image must be under 5MB', error: true);
      return;
    }
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => _uploadingPhoto = true);
    try {
      final resp = await ApiClient.getPhotoUploadUrl(file.name, contentType, bytes.lengthInBytes);
      final uploadUrl = resp['upload_url'] as String;
      final photoUrl = resp['photo_url'] as String;
      final putRes = await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': contentType}, body: bytes);
      if (putRes.statusCode >= 400) throw Exception('Could not upload to storage (${putRes.statusCode}). Try again.');
      await ApiClient.savePhotoUrl(photoUrl);
      if (mounted) await context.read<AuthProvider>().updatePhotoUrl(photoUrl);
      if (mounted) showSnack(context, 'Photo updated');
    } catch (e) {
      if (mounted) {
        final msg = e is ApiError ? e.message : e.toString().replaceFirst('Exception: ', '');
        showSnack(context, msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _showPersonalDetailsSheet(BuildContext context, AuthUser user) {
    final nameCtrl = TextEditingController(text: user.teacherName);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final emailCtrl = TextEditingController(text: user.email ?? '');
    bool saving = false;
    bool fetchDone = false;
    String? nameError;
    String? phoneError;

    void fetchFresh(StateSetter setSheet) {
      if (fetchDone) return;
      fetchDone = true;
      ApiClient.getMyProfile().then((data) {
        setSheet(() {
          nameCtrl.text = data['name'] as String? ?? nameCtrl.text;
          phoneCtrl.text = data['phone'] as String? ?? phoneCtrl.text;
          emailCtrl.text = data['email'] as String? ?? emailCtrl.text;
        });
      }).catchError((_) {});
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          fetchFresh(setSheet);
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Personal Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 14),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  maxLength: 30,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    errorText: nameError,
                    counterText: '',
                  ),
                  onChanged: (_) { if (nameError != null) setSheet(() => nameError = null); },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    errorText: phoneError,
                    counterText: '',
                  ),
                  onChanged: (_) { if (phoneError != null) setSheet(() => phoneError = null); },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: saving ? null : () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      String? nErr;
                      String? pErr;
                      if (name.isEmpty) nErr = 'Name is required';
                      else if (name.length > 30) nErr = 'Max 30 characters';
                      if (phone.isNotEmpty && phone.length != 10) pErr = 'Must be exactly 10 digits';
                      if (nErr != null || pErr != null) {
                        setSheet(() { nameError = nErr; phoneError = pErr; });
                        return;
                      }
                      setSheet(() => saving = true);
                      try {
                        final email = emailCtrl.text.trim();
                        await ApiClient.updateMyProfile(
                          name: name.isNotEmpty ? name : null,
                          phone: phone.isNotEmpty ? phone : null,
                          email: email.isNotEmpty ? email : null,
                        );
                        if (ctx.mounted) {
                          await ctx.read<AuthProvider>().updateProfile(
                            name: name.isNotEmpty ? name : null,
                            phone: phone.isNotEmpty ? phone : null,
                            email: email.isNotEmpty ? email : null,
                          );
                          Navigator.pop(ctx);
                          if (mounted) showSnack(context, 'Profile updated');
                        }
                      } catch (e) {
                        setSheet(() => saving = false);
                        if (ctx.mounted) {
                          final msg = e is ApiError ? e.message : 'Could not update profile. Try again.';
                          showSnack(ctx, msg, error: true);
                        }
                      }
                    },
                    child: saving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You will need to sign in again to access the app.',
            style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Pop all routes to root so LoginScreen shows cleanly
              Navigator.of(context).popUntil((route) => route.isFirst);
              context.read<AuthProvider>().logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user!;
    final flags = auth.features;
    final isAdmin = user.role == 'admin';
    final isAdminOrAbove = user.role == 'admin' || user.role == 'principal' || user.role == 'director';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile card — tap avatar to change photo
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.sun, AppColors.coral],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _pickAndUploadPhoto(context),
                      child: Stack(
                        children: [
                          Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.25),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.4), width: 2),
                            ),
                            child: ClipOval(
                              child: _uploadingPhoto
                                  ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : user.photoUrl != null
                                      ? Image.network(user.photoUrl!, width: 50, height: 50, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Center(child: Text(auth.initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))))
                                      : Center(child: Text(auth.initials, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
                            ),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 18, height: 18,
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, size: 10, color: AppColors.sun),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.teacherName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(user.schoolName, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── MY INFO ───────────────────────────────────────────────
                    const Text('MY INFO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    _FeatureRow(icon: '👤', iconBg: AppColors.sunLight, title: 'Personal Details', sub: 'Name, email, contact info',
                        onTap: () => _showPersonalDetailsSheet(context, user)),
                    _FeatureRow(icon: '🗓️', iconBg: AppColors.coralLight, title: 'My Leaves', sub: 'Balance, history & apply',
                        onTap: () => _push(context, const LeaveScreen(), recentId: 'leaves')),
                    _FeatureRow(icon: '📋', iconBg: AppColors.tealLight, title: 'My Attendance', sub: 'Your attendance record',
                        onTap: () => _push(context, const MyAttendanceScreen())),
                    if (flags.payroll)
                      _FeatureRow(icon: '💰', iconBg: AppColors.greenLight, title: 'Payroll History', sub: 'Monthly salary & payslips',
                          onTap: () => _push(context, const PayslipScreen(), recentId: 'payroll')),
                    _FeatureRow(icon: '🎓', iconBg: AppColors.violetLight, title: 'Qualifications', sub: 'Degrees & certifications',
                        onTap: () => _push(context, const QualificationsScreen(), recentId: 'qualifications')),

                    const SizedBox(height: 16),

                    // ── MORE ──────────────────────────────────────────────────
                    const Text('MORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    _FeatureRow(icon: '🕐', iconBg: AppColors.sunLight, title: 'My Schedule', sub: 'Weekly timetable',
                        onTap: () => _push(context, const TimetableScreen(), recentId: 'schedule')),
                    _FeatureRow(icon: '📖', iconBg: AppColors.greenLight, title: 'Syllabus Progress', sub: 'Chapters completed, in progress & pending',
                        onTap: () => _push(context, const SyllabusScreen(), recentId: 'syllabus')),
                    _FeatureRow(icon: '✅', iconBg: AppColors.tealLight, title: 'My Todos', sub: 'Tasks, reminders & personal notes',
                        onTap: () => _push(context, const TodosScreen(), recentId: 'todos')),
                    _FeatureRow(icon: '❓', iconBg: AppColors.skyLight, title: 'Help & FAQ', sub: 'Browse common questions',
                        onTap: () => _push(context, const FaqScreen())),

                    if (isAdminOrAbove) ...[
                      const SizedBox(height: 16),
                      const Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      _FeatureRow(icon: '👨‍👩‍👦', iconBg: AppColors.tealLight, title: 'Parent Accounts', sub: 'Create, link & manage parent access',
                          onTap: () => _push(context, const AdminParentsScreen(), recentId: 'parents')),
                      if (flags.transport)
                        _FeatureRow(icon: '🚌', iconBg: AppColors.skyLight, title: 'Transport', sub: 'Routes, stops & student assignments',
                            onTap: () => _push(context, const AdminTransportScreen(), recentId: 'transport')),
                      _FeatureRow(icon: '🏫', iconBg: AppColors.violetLight, title: 'School Settings', sub: 'Contact info, branding & preferences',
                          onTap: () => _push(context, const AdminSchoolSettingsScreen(), recentId: 'school_settings')),
                      if (flags.workLogs)
                        _FeatureRow(icon: '📋', iconBg: AppColors.amberLight, title: 'Work Log Overview', sub: 'All classes & acknowledgment stats',
                            onTap: () => _push(context, const AdminWorkLogsScreen(), recentId: 'admin_worklogs')),
                      _FeatureRow(icon: '👤', iconBg: AppColors.coralLight, title: 'Attenders', sub: 'Authorized pickup persons',
                          onTap: () => _push(context, const AdminAttendersScreen(), recentId: 'attenders')),
                      if (flags.fees)
                        _FeatureRow(icon: '💰', iconBg: AppColors.amberLight, title: 'Fee Management', sub: 'Fee components & payment status',
                            onTap: () => _push(context, const AdminFeeManagementScreen(), recentId: 'fees')),
                      // Leave Config: admin only (not principal/director/hod)
                      if (isAdmin)
                        _FeatureRow(icon: '⚙️', iconBg: AppColors.skyLight, title: 'Leave Config', sub: 'Casual, sick & working day settings',
                            onTap: () => _push(context, const AdminLeaveConfigScreen(), recentId: 'leave_config')),
                    ],

                    const SizedBox(height: 16),

                    // ── SETTINGS ──────────────────────────────────────────────
                    const Text('SETTINGS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
                    const SizedBox(height: 8),

                    // Notification preferences
                    _FeatureRow(
                      icon: '🔔',
                      iconBg: AppColors.violetLight,
                      title: 'Notification Preferences',
                      sub: 'Manage what you receive',
                      onTap: () => _push(context, const NotificationPrefsScreen()),
                    ),

                    // Biometric unlock toggle
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.violetLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(child: Text('🔑', style: TextStyle(fontSize: 18))),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Biometric Unlock', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                                Text('Use Face ID / fingerprint to sign in', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _bioEnabled,
                            onChanged: _setBioEnabled,
                            activeColor: AppColors.sun,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── ACCOUNT ───────────────────────────────────────────────
                    const Text('ACCOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: () => _confirmSignOut(context),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.coral.withOpacity(0.3), width: 1.5),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppColors.coralLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(child: Text('🚪', style: TextStyle(fontSize: 18))),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sign Out', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.coral)),
                                Text('You will need to sign in again', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    Center(
                      child: Text(
                        _appVersion.isEmpty ? 'EduTrack Teacher' : 'EduTrack Teacher v$_appVersion',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
