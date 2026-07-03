import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  List<LeaveRequest>? _leaves;
  Map<String, dynamic>? _balance;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.getMyLeaves(),
        ApiClient.getMyLeaveBalance().then<dynamic>((v) => v).catchError((_) => null),
      ]);
      setState(() {
        _leaves = results[0] as List<LeaveRequest>;
        _balance = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Leave balance counts
    final approved = _leaves?.where((l) => l.status == 'approved').length ?? 0;
    final pending = _leaves?.where((l) => l.status == 'pending').length ?? 0;

    // Split into upcoming/active and history
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final upcomingLeaves = _leaves?.where((l) {
      final end = DateTime.tryParse(l.endDate);
      return end == null || !end.isBefore(todayMidnight);
    }).toList() ?? [];
    final historyLeaves = _leaves?.where((l) {
      final end = DateTime.tryParse(l.endDate);
      return end != null && end.isBefore(todayMidnight);
    }).toList() ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'My Leaves',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      Text(
                        'Leave requests & history',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    key: const Key('apply_leave_button'),
                    onPressed: () => _showApplySheet(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Apply'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Leave balance tiles
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _BalTile(
                      value: approved.toString(),
                      label: 'Approved',
                      sub: 'this year',
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BalTile(
                      value: pending.toString(),
                      label: 'Pending',
                      sub: 'awaiting review',
                      color: AppColors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BalTile(
                      value: (_leaves?.length ?? 0).toString(),
                      label: 'Total',
                      sub: 'all requests',
                      color: AppColors.violet,
                    ),
                  ),
                ],
              ),
            ),

            // Available quota section
            if (_balance != null) ...[
              Container(height: 1, color: AppColors.border),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'LEAVE BALANCE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.6),
                        ),
                        if (_balance!['in_probation'] == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.amberLight, borderRadius: BorderRadius.circular(6)),
                            child: const Text('On Probation', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.amber)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _QuotaTile('Casual', _balance!['casual'] as Map<String, dynamic>?, AppColors.sky)),
                        const SizedBox(width: 8),
                        Expanded(child: _QuotaTile('Sick', _balance!['sick'] as Map<String, dynamic>?, AppColors.coral)),
                        const SizedBox(width: 8),
                        Expanded(child: _QuotaTile('Earned', _balance!['earned'] as Map<String, dynamic>?, AppColors.teal)),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            Container(height: 1, color: AppColors.border),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
                  : _leaves == null || _leaves!.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🌴', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 12),
                              const Text(
                                'No leave requests yet',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () => _showApplySheet(context),
                                child: const Text('Apply for Leave'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: AppColors.sun,
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 32),
                            children: [
                              if (upcomingLeaves.isEmpty && historyLeaves.isEmpty)
                                const Center(child: Text('No leave requests', style: TextStyle(color: AppColors.muted))),
                              if (upcomingLeaves.isNotEmpty) ...[
                                const _SectionLabel('UPCOMING & ACTIVE'),
                                ...upcomingLeaves.map((l) => _LeaveItem(leave: l, onCancelled: _load)),
                              ],
                              if (historyLeaves.isNotEmpty)
                                _HistorySection(leaves: historyLeaves, onCancelled: _load),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _showApplySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ApplyLeaveSheet(
        onSubmitted: () {
          Navigator.pop(context);
          _load();
        },
      ),
    );
  }
}

class _BalTile extends StatelessWidget {
  final String value;
  final String label;
  final String sub;
  final Color color;

  const _BalTile({
    required this.value,
    required this.label,
    required this.sub,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(fontSize: 9, color: AppColors.muted),
            ),
          ],
        ),
      );
}

class _QuotaTile extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? quota;
  final Color color;

  const _QuotaTile(this.label, this.quota, this.color);

  @override
  Widget build(BuildContext context) {
    final remaining = quota?['remaining'] as int? ?? 0;
    final total = quota?['quota'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$remaining',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color),
          ),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.text)),
          Text('of $total', style: const TextStyle(fontSize: 9, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _LeaveItem extends StatefulWidget {
  final LeaveRequest leave;
  final VoidCallback onCancelled;
  const _LeaveItem({required this.leave, required this.onCancelled});

  @override
  State<_LeaveItem> createState() => _LeaveItemState();
}

class _LeaveItemState extends State<_LeaveItem> {
  bool _cancelling = false;

  String get _icon {
    switch (widget.leave.leaveType) {
      case 'sick': return '🤒';
      case 'casual': return '🌴';
      case 'earned': return '⭐';
      default: return '📋';
    }
  }

  Color get _iconBg {
    switch (widget.leave.leaveType) {
      case 'sick': return AppColors.coralLight;
      case 'casual': return AppColors.tealLight;
      case 'earned': return AppColors.amberLight;
      default: return AppColors.violetLight;
    }
  }

  Future<void> _cancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Leave?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This will withdraw your pending leave request.', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Cancel Leave'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await ApiClient.cancelLeave(widget.leave.id);
      if (mounted) {
        showSnack(context, 'Leave request cancelled');
        widget.onCancelled();
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: Text(_icon, style: const TextStyle(fontSize: 17))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_leaveLabel(widget.leave.leaveType)} — ${widget.leave.daysCount} day${widget.leave.daysCount > 1 ? "s" : ""}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtDate(widget.leave.startDate)} → ${fmtDate(widget.leave.endDate)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  if (widget.leave.reason != null && widget.leave.reason!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.leave.reason!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.leave.status == 'pending')
              _cancelling
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.coral))
                  : GestureDetector(
                      onTap: _cancel,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.coralLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.coral.withOpacity(0.3)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.coral)),
                      ),
                    )
            else
              statusBadgeForLeave(widget.leave.status),
          ],
        ),
      );

  String _leaveLabel(String t) {
    switch (t) {
      case 'sick': return 'Sick Leave';
      case 'casual': return 'Casual Leave';
      case 'earned': return 'Earned Leave';
      default: return '${t[0].toUpperCase()}${t.substring(1)} Leave';
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
    child: Text(text,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
  );
}

class _HistorySection extends StatefulWidget {
  final List<LeaveRequest> leaves;
  final VoidCallback onCancelled;
  const _HistorySection({required this.leaves, required this.onCancelled});

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(
              children: [
                const Text('HISTORY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(6)),
                  child: Text('${widget.leaves.length}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.muted)),
                ),
                const Spacer(),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.leaves.map((l) => _LeaveItem(leave: l, onCancelled: widget.onCancelled)),
      ],
    );
  }
}

// ── Apply Leave Bottom Sheet ──────────────────────────────────────────────────

class _ApplyLeaveSheet extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _ApplyLeaveSheet({required this.onSubmitted});

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  String _leaveType = 'casual';
  DateTime? _start;
  DateTime? _end;
  final _reason = TextEditingController();
  bool _saving = false;

  bool get _canSubmit => _start != null && _end != null && !_saving;

  static const _types = [
    ('casual', '🌴', 'Casual'),
    ('sick', '🤒', 'Sick'),
    ('earned', '⭐', 'Earned'),
  ];

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_start == null || _end == null) return;
    if (_end!.isBefore(_start!)) {
      showSnack(context, 'End date must be after start date', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.createLeave(
        leaveType: _leaveType,
        startDate: DateFormat('yyyy-MM-dd').format(_start!),
        endDate: DateFormat('yyyy-MM-dd').format(_end!),
        reason: _reason.text.trim(),
      );
      if (mounted) {
        showSnack(context, 'Leave request submitted ✓');
        widget.onSubmitted();
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = (_start != null && _end != null) ? _end!.difference(_start!).inDays + 1 : 0;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text(
                      'Apply for Leave',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.text,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('✕',
                          style: TextStyle(fontSize: 22, color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Leave type
                    const Text(
                      'LEAVE TYPE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: _types.map((t) {
                        final active = _leaveType == t.$1;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _leaveType = t.$1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              margin: EdgeInsets.only(right: t.$1 == 'earned' ? 0 : 8),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: active ? AppColors.sunLight : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: active ? AppColors.sun : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(t.$2, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.$3,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: active ? AppColors.sun : AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Date pickers
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'START DATE',
                            value: _start,
                            onPick: (d) => setState(() {
                              _start = d;
                              if (_end != null && _end!.isBefore(_start!)) _end = _start;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateField(
                            label: 'END DATE',
                            value: _end,
                            onPick: (d) => setState(() => _end = d),
                            firstDate: _start ?? DateTime.now(),
                          ),
                        ),
                      ],
                    ),
                    if (_start != null && _end != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.sunLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$days day${days > 1 ? "s" : ""} selected',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sun,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    // Reason
                    const Text(
                      'REASON (OPTIONAL)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.muted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('leave_reason_field'),
                      controller: _reason,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: 'Add a note for the principal…',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        key: const Key('submit_leave_button'),
                        onPressed: _canSubmit ? _submit : null,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Text('Submit Request'),
                      ),
                    ),
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

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final void Function(DateTime) onPick;
  final DateTime? firstDate;

  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    this.firstDate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? (firstDate ?? now),
              firstDate: firstDate ?? now,
              lastDate: now.add(const Duration(days: 365)),
              selectableDayPredicate: (date) => date.weekday != DateTime.sunday,
              builder: (ctx, child) => Theme(
                data: ThemeData(
                    colorScheme: const ColorScheme.light(primary: AppColors.sun)),
                child: child!,
              ),
            );
            if (picked != null) onPick(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: value == null ? AppColors.sun.withOpacity(0.5) : AppColors.border,
                width: value == null ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined,
                    size: 14, color: value == null ? AppColors.sun : AppColors.muted),
                const SizedBox(width: 8),
                Text(
                  value != null ? DateFormat('d MMM yy').format(value!) : 'Select date',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: value != null ? AppColors.text : AppColors.sun,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}
