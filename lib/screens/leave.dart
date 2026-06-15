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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.getMyLeaves();
      setState(() { _leaves = data; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Leave balance counts
    final approved = _leaves?.where((l) => l.status == 'approved').length ?? 0;
    final pending = _leaves?.where((l) => l.status == 'pending').length ?? 0;

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
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _leaves!.length,
                            itemBuilder: (_, i) => _LeaveItem(leave: _leaves![i]),
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

class _LeaveItem extends StatelessWidget {
  final LeaveRequest leave;
  const _LeaveItem({required this.leave});

  String get _icon {
    switch (leave.leaveType) {
      case 'sick': return '🤒';
      case 'casual': return '🌴';
      case 'earned': return '⭐';
      default: return '📋';
    }
  }

  Color get _iconBg {
    switch (leave.leaveType) {
      case 'sick': return AppColors.coralLight;
      case 'casual': return AppColors.tealLight;
      case 'earned': return AppColors.amberLight;
      default: return AppColors.violetLight;
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
                    '${_leaveLabel(leave.leaveType)} — ${leave.daysCount} day${leave.daysCount > 1 ? "s" : ""}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtDate(leave.startDate)} → ${fmtDate(leave.endDate)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  if (leave.reason != null && leave.reason!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      leave.reason!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            statusBadgeForLeave(leave.status),
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

// ── Apply Leave Bottom Sheet ──────────────────────────────────────────────────

class _ApplyLeaveSheet extends StatefulWidget {
  final VoidCallback onSubmitted;
  const _ApplyLeaveSheet({required this.onSubmitted});

  @override
  State<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends State<_ApplyLeaveSheet> {
  String _leaveType = 'casual';
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now();
  final _reason = TextEditingController();
  bool _saving = false;

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
    if (_end.isBefore(_start)) {
      showSnack(context, 'End date must be after start date', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.createLeave(
        leaveType: _leaveType,
        startDate: DateFormat('yyyy-MM-dd').format(_start),
        endDate: DateFormat('yyyy-MM-dd').format(_end),
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
    final days = _end.difference(_start).inDays + 1;
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
                              if (_end.isBefore(_start)) _end = _start;
                            }),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DateField(
                            label: 'END DATE',
                            value: _end,
                            onPick: (d) => setState(() => _end = d),
                            firstDate: _start,
                          ),
                        ),
                      ],
                    ),
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
                        onPressed: _saving ? null : _submit,
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
  final DateTime value;
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
            final picked = await showDatePicker(
              context: context,
              initialDate: value,
              firstDate: firstDate ?? DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
              selectableDayPredicate: (_) => true, // all days allowed, including Sunday
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
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.muted),
                const SizedBox(width: 8),
                Text(
                  DateFormat('d MMM yy').format(value),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
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
