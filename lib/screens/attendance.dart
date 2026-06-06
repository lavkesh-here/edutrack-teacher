import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<SectionInfo>? _sections;
  SectionInfo? _selectedSection;
  DateTime _date = DateTime.now();
  List<AttendanceStudent>? _students;
  bool _loadingSections = true;
  bool _loadingStudents = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    setState(() => _loadingSections = true);
    try {
      final sections = await ApiClient.getMySections();
      setState(() {
        _sections = sections;
        if (sections.isNotEmpty) {
          _selectedSection = sections.first;
          _loadStudents();
        }
        _loadingSections = false;
      });
    } catch (_) {
      setState(() => _loadingSections = false);
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedSection == null) return;
    setState(() { _loadingStudents = true; _students = null; });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final students = await ApiClient.getAttendance(_selectedSection!.id, dateStr);
      setState(() {
        _students = students;
        _loadingStudents = false;
      });
    } catch (_) {
      setState(() => _loadingStudents = false);
    }
  }

  Future<void> _submit() async {
    if (_students == null || _selectedSection == null) return;
    setState(() => _saving = true);
    try {
      final statuses = <String, String>{};
      for (final s in _students!) {
        if (s.status.isNotEmpty) statuses[s.id.toString()] = s.status;
      }
      await ApiClient.submitAttendance(
        sectionId: _selectedSection!.id,
        date: DateFormat('yyyy-MM-dd').format(_date),
        statuses: statuses,
      );
      if (mounted) showSnack(context, 'Attendance saved ✓');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _markAll(String status) {
    if (_students == null) return;
    setState(() {
      for (final s in _students!) {
        s.status = status;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final present = _students?.where((s) => s.status == 'present').length ?? 0;
    final absent = _students?.where((s) => s.status == 'absent').length ?? 0;
    final unmarked = _students?.where((s) => s.status.isEmpty).length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Attendance',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      const Spacer(),
                      // Date picker
                      GestureDetector(
                        onTap: _pickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.muted),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('d MMM').format(_date),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Section selector
                  if (_loadingSections)
                    const LinearProgressIndicator(color: AppColors.sun)
                  else if (_sections != null && _sections!.isNotEmpty)
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _sections!.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final sec = _sections![i];
                          final active = sec.id == _selectedSection?.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedSection = sec);
                              _loadStudents();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: active ? AppColors.sun : AppColors.bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: active ? AppColors.sun : AppColors.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                sec.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active ? Colors.white : AppColors.muted,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    const Text(
                      'No sections assigned',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                ],
              ),
            ),

            // Stats bar
            if (_students != null)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _StatChip('✓ $present Present', AppColors.tealLight, AppColors.teal),
                        const SizedBox(width: 8),
                        _StatChip('✗ $absent Absent', AppColors.coralLight, AppColors.coral),
                        if (unmarked > 0) ...[
                          const SizedBox(width: 8),
                          _StatChip('? $unmarked Unmarked', AppColors.amberLight, AppColors.amber),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Mark-all buttons row
                    Row(
                      children: [
                        _MarkAllBtn(
                          label: 'All Present',
                          bg: AppColors.tealLight,
                          fg: AppColors.teal,
                          onTap: () => _markAll('present'),
                        ),
                        const SizedBox(width: 6),
                        _MarkAllBtn(
                          label: 'All Absent',
                          bg: AppColors.coralLight,
                          fg: AppColors.coral,
                          onTap: () => _markAll('absent'),
                        ),
                        const SizedBox(width: 6),
                        _MarkAllBtn(
                          label: 'All Late',
                          bg: AppColors.amberLight,
                          fg: AppColors.amber,
                          onTap: () => _markAll('late'),
                        ),
                        const SizedBox(width: 6),
                        _MarkAllBtn(
                          label: 'Reset',
                          bg: const Color(0xFFF3F4F6),
                          fg: AppColors.muted,
                          onTap: () => _markAll(''),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // Student grid
            Expanded(
              child: _loadingStudents
                  ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
                  : _students == null || _students!.isEmpty
                      ? const Center(
                          child: Text(
                            'No students enrolled',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 0.9,
                          ),
                          itemCount: _students!.length,
                          itemBuilder: (_, i) => _StudentCard(
                            student: _students![i],
                            onTap: () => _cycleStatus(i),
                          ),
                        ),
            ),

            // Submit bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Save Attendance'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _cycleStatus(int i) {
    final s = _students![i];
    setState(() {
      switch (s.status) {
        case '':
          s.status = 'present';
          break;
        case 'present':
          s.status = 'absent';
          break;
        case 'absent':
          s.status = 'late';
          break;
        default:
          s.status = '';
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData(colorScheme: const ColorScheme.light(primary: AppColors.sun)),
        child: child!,
      ),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      _loadStudents();
    }
  }
}

class _MarkAllBtn extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _MarkAllBtn({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      );
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _StatChip(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
      );
}

class _StudentCard extends StatelessWidget {
  final AttendanceStudent student;
  final VoidCallback onTap;

  const _StudentCard({required this.student, required this.onTap});

  Color get _bg {
    switch (student.status) {
      case 'present': return AppColors.tealLight;
      case 'absent': return AppColors.coralLight;
      case 'late': return AppColors.amberLight;
      default: return AppColors.bg;
    }
  }

  Color get _borderColor {
    switch (student.status) {
      case 'present': return AppColors.teal;
      case 'absent': return AppColors.coral;
      case 'late': return AppColors.amber;
      default: return AppColors.border;
    }
  }

  Color get _avatarColor {
    switch (student.status) {
      case 'present': return AppColors.teal;
      case 'absent': return AppColors.coral;
      case 'late': return AppColors.amber;
      default: return AppColors.muted;
    }
  }

  String get _statusLabel {
    switch (student.status) {
      case 'present': return 'Present';
      case 'absent': return 'Absent';
      case 'late': return 'Late';
      default: return 'Tap to mark';
    }
  }

  String get _initials {
    final parts = student.name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderColor, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _avatarColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                student.name.split(' ').first,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              if (student.rollNo.isNotEmpty)
                Text(
                  student.rollNo,
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _borderColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: _borderColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
