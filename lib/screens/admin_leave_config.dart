import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminLeaveConfigScreen extends StatefulWidget {
  const AdminLeaveConfigScreen({super.key});

  @override
  State<AdminLeaveConfigScreen> createState() => _AdminLeaveConfigScreenState();
}

class _AdminLeaveConfigScreenState extends State<AdminLeaveConfigScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Leave Config'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabs,
          labelColor: null,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: null,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'School Defaults'),
            Tab(text: 'Per Teacher'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _RequestsTab(),
          _GlobalConfigTab(),
          _PerTeacherTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: Global School Defaults ────────────────────────────────────────────

class _GlobalConfigTab extends StatefulWidget {
  const _GlobalConfigTab();

  @override
  State<_GlobalConfigTab> createState() => _GlobalConfigTabState();
}

class _GlobalConfigTabState extends State<_GlobalConfigTab> {
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _casualCtrl;
  late TextEditingController _sickCtrl;
  late TextEditingController _earnedCtrl;
  late TextEditingController _workingDaysCtrl;
  late TextEditingController _probationCtrl;

  @override
  void initState() {
    super.initState();
    _casualCtrl = TextEditingController();
    _sickCtrl = TextEditingController();
    _earnedCtrl = TextEditingController();
    _workingDaysCtrl = TextEditingController();
    _probationCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _casualCtrl.dispose();
    _sickCtrl.dispose();
    _earnedCtrl.dispose();
    _workingDaysCtrl.dispose();
    _probationCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminGetLeaveConfig();
      setState(() {
        _casualCtrl.text = (data['casual_per_year'] ?? 12).toString();
        _sickCtrl.text = (data['sick_per_year'] ?? 12).toString();
        _earnedCtrl.text = (data['earned_per_year'] ?? 0).toString();
        _workingDaysCtrl.text = (data['working_days_per_month'] ?? 26).toString();
        _probationCtrl.text = (data['probation_months'] ?? 0).toString();
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.adminUpdateLeaveConfig({
        'casual_per_year': int.tryParse(_casualCtrl.text) ?? 12,
        'sick_per_year': int.tryParse(_sickCtrl.text) ?? 12,
        'earned_per_year': int.tryParse(_earnedCtrl.text) ?? 0,
        'working_days_per_month': int.tryParse(_workingDaysCtrl.text) ?? 26,
        'probation_months': int.tryParse(_probationCtrl.text) ?? 0,
      });
      if (mounted) showSnack(context, 'Leave config saved');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.skyLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'These are the default settings for all teachers. You can override them per teacher in the "Per Teacher" tab.',
              style: TextStyle(fontSize: 12, color: AppColors.sky),
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Annual Leave Allowances'),
          const SizedBox(height: 12),
          _ConfigField(fieldKey: const Key('casual_leave_field'), ctrl: _casualCtrl, label: 'Casual Leave (days/year)', keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _ConfigField(fieldKey: const Key('sick_leave_field'), ctrl: _sickCtrl, label: 'Sick Leave (days/year)', keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _ConfigField(fieldKey: const Key('earned_leave_field'), ctrl: _earnedCtrl, label: 'Earned Leave (days/year)', keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Salary Calculation'),
          const SizedBox(height: 12),
          _ConfigField(fieldKey: const Key('working_days_field'), ctrl: _workingDaysCtrl, label: 'Working Days per Month', keyboardType: TextInputType.number),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Probation'),
          const SizedBox(height: 12),
          _ConfigField(fieldKey: const Key('probation_months_field'), ctrl: _probationCtrl, label: 'Probation Period (months)', keyboardType: TextInputType.number),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              key: const Key('save_leave_config_button'),
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Per-Teacher Overrides ─────────────────────────────────────────────

class _PerTeacherTab extends StatefulWidget {
  const _PerTeacherTab();

  @override
  State<_PerTeacherTab> createState() => _PerTeacherTabState();
}

class _PerTeacherTabState extends State<_PerTeacherTab> {
  List<Map<String, dynamic>> _teachers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminListTeacherLeaveOverrides();
      if (mounted) setState(() { _teachers = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) { showSnack(context, e.message, error: true); setState(() => _loading = false); }
    } catch (_) {
      if (mounted) { showSnack(context, 'Failed to load. Try again.', error: true); setState(() => _loading = false); }
    }
  }

  void _showEditSheet(Map<String, dynamic> teacher) {
    final existing = teacher['override'] as Map<String, dynamic>?;
    final casualCtrl = TextEditingController(text: existing?['casual_per_year']?.toString() ?? '');
    final sickCtrl = TextEditingController(text: existing?['sick_per_year']?.toString() ?? '');
    final earnedCtrl = TextEditingController(text: existing?['earned_per_year']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: existing?['notes'] as String? ?? '');
    bool? inProbation = existing?['in_probation'] as bool?;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                teacher['teacher_name'] as String? ?? 'Teacher',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 4),
              Text(
                'Leave per year — leave blank to use school default',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _ConfigField(ctrl: casualCtrl, label: 'Casual', keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _ConfigField(ctrl: sickCtrl, label: 'Sick', keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  Expanded(child: _ConfigField(ctrl: earnedCtrl, label: 'Earned', keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Probation Status', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _ProbationChip(
                          label: 'Auto (by date)',
                          selected: inProbation == null,
                          onTap: () => setSheet(() => inProbation = null),
                        ),
                        const SizedBox(width: 8),
                        _ProbationChip(
                          label: 'In Probation',
                          selected: inProbation == true,
                          color: AppColors.amber,
                          onTap: () => setSheet(() => inProbation = true),
                        ),
                        const SizedBox(width: 8),
                        _ProbationChip(
                          label: 'Confirmed',
                          selected: inProbation == false,
                          color: AppColors.teal,
                          onTap: () => setSheet(() => inProbation = false),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _ConfigField(ctrl: notesCtrl, label: 'Notes (optional)'),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (existing != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: saving ? null : () async {
                          setSheet(() => saving = true);
                          try {
                            await ApiClient.adminClearTeacherLeaveOverride(teacher['teacher_id'] as String);
                            if (mounted) Navigator.pop(ctx);
                            _load();
                            if (mounted) showSnack(context, 'Override removed — using school defaults');
                          } on ApiError catch (e) {
                            setSheet(() => saving = false);
                            if (mounted) showSnack(context, e.message, error: true);
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.coral,
                          side: const BorderSide(color: AppColors.coral),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Clear Override'),
                      ),
                    ),
                  if (existing != null) const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: saving ? null : () async {
                        setSheet(() => saving = true);
                        try {
                          final payload = <String, dynamic>{};
                          if (casualCtrl.text.isNotEmpty) payload['casual_per_year'] = int.tryParse(casualCtrl.text);
                          if (sickCtrl.text.isNotEmpty) payload['sick_per_year'] = int.tryParse(sickCtrl.text);
                          if (earnedCtrl.text.isNotEmpty) payload['earned_per_year'] = int.tryParse(earnedCtrl.text);
                          if (inProbation != null) payload['in_probation'] = inProbation;
                          if (notesCtrl.text.isNotEmpty) payload['notes'] = notesCtrl.text.trim();
                          await ApiClient.adminSetTeacherLeaveOverride(teacher['teacher_id'] as String, payload);
                          if (mounted) Navigator.pop(ctx);
                          _load();
                          if (mounted) showSnack(context, 'Override saved');
                        } on ApiError catch (e) {
                          setSheet(() => saving = false);
                          if (mounted) showSnack(context, e.message, error: true);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: null,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Override', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_teachers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('👩‍🏫', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text('No teachers found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.muted)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: context.primary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _teachers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final t = _teachers[i];
          final override = t['override'] as Map<String, dynamic>?;
          final name = t['teacher_name'] as String? ?? '';
          final role = t['role'] as String? ?? '';
          final joinedDate = t['joined_date'] as String?;

          return GestureDetector(
            onTap: () => _showEditSheet(t),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: override != null ? context.primary.withOpacity(0.5) : AppColors.border,
                  width: override != null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
                              child: Text(role, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.muted)),
                            ),
                          ],
                        ),
                        if (joinedDate != null)
                          Text('Joined: ${fmtDate(joinedDate)}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        if (override != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (override['casual_per_year'] != null)
                                _OverrideChip('Casual: ${override['casual_per_year']}d'),
                              if (override['sick_per_year'] != null)
                                _OverrideChip('Sick: ${override['sick_per_year']}d'),
                              if (override['earned_per_year'] != null)
                                _OverrideChip('Earned: ${override['earned_per_year']}d'),
                              if (override['in_probation'] == true)
                                _OverrideChip('On Probation', color: AppColors.amber),
                              if (override['in_probation'] == false)
                                _OverrideChip('Confirmed', color: AppColors.teal),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    override != null ? Icons.tune_rounded : Icons.add_rounded,
                    color: override != null ? context.primary : AppColors.muted,
                    size: 20,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverrideChip extends StatelessWidget {
  const _OverrideChip(this.label, {this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.primary;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: c.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
      );
  }
}

class _ProbationChip extends StatelessWidget {
  const _ProbationChip({required this.label, required this.selected, required this.onTap, this.color = AppColors.sky});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : AppColors.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? color : AppColors.muted),
          ),
        ),
      );
}

// ── Tab 0: Pending leave requests (approve / reject) ─────────────────────────
//
// The backend has supported GET /admin/leaves and PATCH /admin/leaves/{id}/
// review since before this file existed, with full test coverage
// (tests/test_leaves.py, test_e2e_flows.py, test_race_conditions.py) -- but no
// screen in this app ever called either endpoint. A teacher could apply for
// leave (leave.dart) with no in-app way for a director/principal/admin to
// approve or reject it. This tab is that missing piece.

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String _statusFilter = 'pending';
  final Set<String> _reviewing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminListLeaveRequests(status: _statusFilter);
      final leaves = (data['leaves'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList();
      if (mounted) setState(() { _requests = leaves; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) { showSnack(context, e.message, error: true); setState(() => _loading = false); }
    } catch (_) {
      if (mounted) { showSnack(context, 'Failed to load. Try again.', error: true); setState(() => _loading = false); }
    }
  }

  Future<void> _review(String leaveId, String action) async {
    setState(() => _reviewing.add(leaveId));
    try {
      await ApiClient.adminReviewLeaveRequest(leaveId, action);
      if (!mounted) return;
      showSnack(context, action == 'approved' ? 'Leave approved ✓' : 'Leave rejected');
      // Re-fetch from the server rather than just removing the row locally --
      // this is the real create/update -> DB -> reload proof, not an
      // optimistic UI update that could drift from what actually persisted.
      await _load();
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _reviewing.remove(leaveId));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              for (final s in const ['pending', 'approved', 'rejected'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ProbationChip(
                    label: s[0].toUpperCase() + s.substring(1),
                    selected: _statusFilter == s,
                    color: s == 'pending' ? AppColors.amber : (s == 'approved' ? AppColors.teal : AppColors.coral),
                    onTap: () {
                      setState(() => _statusFilter = s);
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _requests.isEmpty
              ? Center(
                  child: Text('No $_statusFilter leave requests',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                )
              : RefreshIndicator(
                  color: context.primary,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = _requests[i];
                      final id = r['id'] as String;
                      final isReviewing = _reviewing.contains(id);
                      return Container(
                        key: Key('leave_request_$id'),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(r['teacher_name'] as String? ?? 'Teacher',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                                ),
                                _OverrideChip((r['leave_type'] as String? ?? '').toUpperCase()),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${r['start_date']} → ${r['end_date']}  (${r['days_count']} day${r['days_count'] == 1 ? '' : 's'})',
                              style: const TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                            if ((r['reason'] as String?)?.isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(r['reason'] as String, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
                            ],
                            if (_statusFilter == 'pending') ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      key: Key('reject_leave_$id'),
                                      onPressed: isReviewing ? null : () => _review(id, 'rejected'),
                                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.coral),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      key: Key('approve_leave_$id'),
                                      onPressed: isReviewing ? null : () => _review(id, 'approved'),
                                      child: isReviewing
                                          ? const SizedBox(
                                              width: 16, height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Text('Approve'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ConfigField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final TextInputType? keyboardType;
  final Key? fieldKey;
  const _ConfigField({required this.ctrl, required this.label, this.keyboardType, this.fieldKey});

  @override
  Widget build(BuildContext context) => TextField(
        key: fieldKey,
        controller: ctrl,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      );
}
