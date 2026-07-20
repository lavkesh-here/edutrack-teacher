import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class DirectorDashboardScreen extends StatefulWidget {
  const DirectorDashboardScreen({super.key});

  @override
  State<DirectorDashboardScreen> createState() => _DirectorDashboardScreenState();
}

class _DirectorDashboardScreenState extends State<DirectorDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _dash;
  Map<String, dynamic>? _classData;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiClient.directorDashboard(),
        ApiClient.directorClassAnalytics(),
      ]);
      if (mounted) {
        setState(() {
          _dash = results[0];
          _classData = results[1];
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Director Analytics'),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: null,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: null,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Classes'),
            Tab(text: 'Teachers'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _OverviewTab(dash: _dash!),
                    _ClassesTab(dash: _dash!, classData: _classData!),
                    _TeachersTab(dash: _dash!),
                  ],
                ),
    );
  }
}

// ── Overview Tab ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.dash});
  final Map<String, dynamic> dash;

  @override
  Widget build(BuildContext context) {
    final riskBreakdown = (dash['risk_breakdown'] as Map<String, dynamic>? ?? {});
    final pendingLeaves = (dash['pending_leave_requests'] as List<dynamic>? ?? []);
    final subjectPerf = (dash['subject_performance'] as List<dynamic>? ?? []);

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI Grid
          _SectionLabel('Key Performance Indicators'),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.6,
            children: [
              _KpiCard(icon: '👨‍🎓', label: 'Students', value: '${dash['total_students'] ?? 0}', color: AppColors.sky),
              _KpiCard(icon: '👩‍🏫', label: 'Teachers', value: '${dash['total_teachers'] ?? 0}', color: AppColors.teal),
              _KpiCard(icon: '⚠️', label: 'At Risk', value: '${dash['at_risk_students'] ?? 0}', color: AppColors.coral),
              _KpiCard(icon: '💰', label: 'Fee Defaulters', value: '${dash['fee_defaulter_count'] ?? 0}', color: AppColors.amber),
              _KpiCard(icon: '🏖️', label: 'Pending Leaves', value: '${dash['pending_leaves'] ?? 0}', color: AppColors.violet),
              _KpiCard(icon: '📝', label: 'Follow-Through', value: '${dash['follow_through_pct'] ?? 0}%', color: AppColors.green),
            ],
          ),

          // Test Stats
          const SizedBox(height: 20),
          _SectionLabel('Test Activity'),
          const SizedBox(height: 8),
          _InfoCard(children: [
            _StatRow('Total Tests', '${dash['total_tests'] ?? 0}'),
            _StatRow('Tests This Month', '${dash['tests_this_month'] ?? 0}'),
            _StatRow('Tests with Scores', '${(dash['total_tests'] as int? ?? 0) == 0 ? 0 : (((dash['total_tests'] as int? ?? 0) * (dash['follow_through_pct'] as int? ?? 0)) / 100).round()}'),
          ]),

          // Risk Breakdown
          if (riskBreakdown.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('Student Risk Breakdown'),
            const SizedBox(height: 8),
            _InfoCard(children: [
              for (final entry in riskBreakdown.entries)
                _StatRow(_riskLabel(entry.key), '${entry.value}'),
            ]),
          ],

          // Subject Performance (weakest first)
          if (subjectPerf.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('Subject Performance (Weakest First)'),
            const SizedBox(height: 8),
            ...subjectPerf.map((s) {
              final pct = (s['avg_pct'] as num?)?.toDouble() ?? 0;
              return _SubjectBar(
                subject: s['subject'] as String? ?? '—',
                pct: pct,
                testCount: s['test_count'] as int? ?? 0,
              );
            }),
          ],

          // Pending Leaves
          if (pendingLeaves.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel('Pending Leave Requests'),
            const SizedBox(height: 8),
            ...pendingLeaves.map((l) => _LeaveCard(leave: l as Map<String, dynamic>)),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _riskLabel(String key) {
    switch (key) {
      case 'high': return '🔴 High Risk';
      case 'medium': return '🟡 Medium Risk';
      case 'low': return '🟢 Low Risk';
      default: return key;
    }
  }
}

// ── Classes Tab ───────────────────────────────────────────────────────────────

class _ClassesTab extends StatelessWidget {
  const _ClassesTab({required this.dash, required this.classData});
  final Map<String, dynamic> dash;
  final Map<String, dynamic> classData;

  @override
  Widget build(BuildContext context) {
    final classes = (classData['classes'] as List<dynamic>? ?? []);
    final classPerf = (dash['class_performance'] as List<dynamic>? ?? []);
    final perfByClass = {for (final c in classPerf) c['class_name'] as String: (c['avg_pct'] as num?)?.toDouble()};

    if (classes.isEmpty && classPerf.isEmpty) {
      return const Center(child: Text('No class data yet.', style: TextStyle(color: AppColors.muted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classes.isNotEmpty ? classes.length : classPerf.length,
      itemBuilder: (context, i) {
        if (classes.isNotEmpty) {
          final cls = classes[i] as Map<String, dynamic>;
          final avgPct = perfByClass[cls['class_name'] as String?];
          return _ClassCard(cls: cls, avgPct: avgPct);
        } else {
          final cp = classPerf[i] as Map<String, dynamic>;
          return _SimpleClassCard(
            className: cp['class_name'] as String? ?? '—',
            avgPct: (cp['avg_pct'] as num?)?.toDouble(),
            testCount: cp['test_count'] as int? ?? 0,
          );
        }
      },
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.cls, this.avgPct});
  final Map<String, dynamic> cls;
  final double? avgPct;

  @override
  Widget build(BuildContext context) {
    final dist = cls['distribution'] as Map<String, dynamic>? ?? {};
    final topStudents = cls['top_students'] as List<dynamic>? ?? [];
    final actions = cls['teacher_actions'] as Map<String, dynamic>? ?? {};
    final improvement = cls['improvement'] as Map<String, dynamic>? ?? {};
    final studentCount = cls['student_count'] as int? ?? 0;
    final className = cls['class_name'] as String? ?? '—';

    Color bandColor = AppColors.green;
    if (avgPct != null) {
      if (avgPct! < 60) bandColor = AppColors.coral;
      else if (avgPct! < 80) bandColor = AppColors.amber;
      else if (avgPct! < 90) bandColor = AppColors.sky;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bandColor.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(className, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                if (avgPct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: bandColor, borderRadius: BorderRadius.circular(20)),
                    child: Text('${avgPct!.toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                const SizedBox(width: 8),
                Text('$studentCount students', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Band distribution
                Row(
                  children: [
                    _BandChip('< 60', dist['below_60'] as int? ?? 0, AppColors.coral),
                    const SizedBox(width: 6),
                    _BandChip('60–80', dist['band_60_80'] as int? ?? 0, AppColors.amber),
                    const SizedBox(width: 6),
                    _BandChip('80–90', dist['band_80_90'] as int? ?? 0, AppColors.sky),
                    const SizedBox(width: 6),
                    _BandChip('90+', dist['above_90'] as int? ?? 0, AppColors.green),
                  ],
                ),

                // Top students
                if (topStudents.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Top Students', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text2)),
                  const SizedBox(height: 4),
                  ...topStudents.asMap().entries.map((e) {
                    final s = e.value as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Text('${e.key + 1}. ', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          Expanded(child: Text(s['student_name'] as String? ?? '—', style: const TextStyle(fontSize: 12))),
                          Text('${(s['avg_pct'] as num?)?.toStringAsFixed(1) ?? '—'}%',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.sun)),
                        ],
                      ),
                    );
                  }),
                ],

                // Teacher actions
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _ActionChip('🔁 ${actions['remedial_tests'] ?? 0} remedial'),
                    _ActionChip('📋 ${actions['work_logs_with_remarks'] ?? 0} work logs'),
                    _ActionChip('📣 ${actions['parent_notifications'] ?? 0} notifs'),
                    _ActionChip('⚠️ ${actions['total_below_avg'] ?? 0} below 60'),
                  ],
                ),

                // Improvement
                if ((improvement['improved'] as int? ?? 0) > 0 || (improvement['declined'] as int? ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if ((improvement['improved'] as int? ?? 0) > 0)
                        _TrendChip('↑ ${improvement['improved']} improved', AppColors.green),
                      const SizedBox(width: 6),
                      if ((improvement['declined'] as int? ?? 0) > 0)
                        _TrendChip('↓ ${improvement['declined']} declined', AppColors.coral),
                      const SizedBox(width: 6),
                      if ((improvement['stable'] as int? ?? 0) > 0)
                        _TrendChip('→ ${improvement['stable']} stable', AppColors.muted),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleClassCard extends StatelessWidget {
  const _SimpleClassCard({required this.className, this.avgPct, required this.testCount});
  final String className;
  final double? avgPct;
  final int testCount;

  @override
  Widget build(BuildContext context) {
    Color bandColor = AppColors.green;
    if (avgPct != null) {
      if (avgPct! < 60) bandColor = AppColors.coral;
      else if (avgPct! < 80) bandColor = AppColors.amber;
      else if (avgPct! < 90) bandColor = AppColors.sky;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: Text(className, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text('$testCount tests', style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(width: 12),
          if (avgPct != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: bandColor, borderRadius: BorderRadius.circular(20)),
              child: Text('${avgPct!.toStringAsFixed(1)}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            )
          else
            const Text('No data', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Teachers Tab ──────────────────────────────────────────────────────────────

class _TeachersTab extends StatefulWidget {
  const _TeachersTab({required this.dash});
  final Map<String, dynamic> dash;

  @override
  State<_TeachersTab> createState() => _TeachersTabState();
}

class _TeachersTabState extends State<_TeachersTab> {
  late List<Map<String, dynamic>> _teachers;

  @override
  void initState() {
    super.initState();
    _teachers = (widget.dash['teacher_metrics'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _unlock(String teacherId, String teacherName) async {
    try {
      await ApiClient.adminUnlockTeacher(teacherId);
      setState(() {
        final idx = _teachers.indexWhere((t) => t['teacher_id'] == teacherId);
        if (idx >= 0) _teachers[idx] = {..._teachers[idx], 'is_locked': false};
      });
      if (mounted) showSnack(context, '$teacherName unlocked successfully');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_teachers.isEmpty) {
      return const Center(child: Text('No teacher data yet.', style: TextStyle(color: AppColors.muted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teachers.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('Teacher Performance (sorted by test count)'),
              const SizedBox(height: 8),
            ],
          );
        }
        final t = _teachers[i - 1];
        final followPct = t['follow_through_pct'] as int? ?? 0;
        final attendPct = t['attendance_pct'] as int? ?? 0;
        final isLocked = t['is_locked'] as bool? ?? false;
        final teacherId = t['teacher_id'] as String? ?? '';
        final teacherName = t['teacher_name'] as String? ?? '—';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isLocked ? AppColors.coralLight : AppColors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isLocked ? AppColors.coral.withOpacity(0.4) : AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(teacherName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (isLocked)
                    GestureDetector(
                      onTap: () => _unlock(teacherId, teacherName),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.coral,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('🔒 Unlock',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    )
                  else
                    _RoleBadge(t['role'] as String? ?? ''),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _MiniStat('Tests', '${t['test_count'] ?? 0}')),
                  Expanded(child: _MiniStat('Scored', '${t['scored_tests'] ?? 0}')),
                  Expanded(child: _MiniStat('Follow-Through', '$followPct%',
                      color: followPct >= 70 ? AppColors.green : (followPct >= 40 ? AppColors.amber : AppColors.coral))),
                  Expanded(child: _MiniStat('Attendance', '$attendPct%',
                      color: attendPct >= 80 ? AppColors.green : (attendPct >= 60 ? AppColors.amber : AppColors.coral))),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Reusable Widgets ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.text2));
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.icon, required this.label, required this.value, required this.color});
  final String icon, label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SubjectBar extends StatelessWidget {
  const _SubjectBar({required this.subject, required this.pct, required this.testCount});
  final String subject;
  final double pct;
  final int testCount;

  @override
  Widget build(BuildContext context) {
    Color barColor = AppColors.green;
    if (pct < 60) barColor = AppColors.coral;
    else if (pct < 80) barColor = AppColors.amber;
    else if (pct < 90) barColor = AppColors.sky;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(subject, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
              Text('${pct.toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: barColor, fontSize: 13)),
              const SizedBox(width: 8),
              Text('($testCount tests)', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.leave});
  final Map<String, dynamic> leave;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.amberLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.amber.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Text('🏖️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leave['teacher_name'] as String? ?? '—',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(
                  '${leave['leave_type'] ?? ''} · ${leave['start_date'] ?? ''} → ${leave['end_date'] ?? ''} (${leave['days_count'] ?? 0}d)',
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                if ((leave['reason'] as String?)?.isNotEmpty == true)
                  Text(leave['reason'] as String, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BandChip extends StatelessWidget {
  const _BandChip(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text('$label: $count', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: AppColors.text2)),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, {this.color});
  final String label, value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color ?? AppColors.text)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.muted), textAlign: TextAlign.center),
      ],
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge(this.role);
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.skyLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 10, color: AppColors.sky, fontWeight: FontWeight.bold)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
