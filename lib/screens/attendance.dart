import 'dart:math' as math;
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
  bool _swipeMode = false;
  int _swipeIndex = 0;

  // onboarding: remaining views allowed for swipe tutorial
  int _tutorialViewsLeft = 0;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _loadSections();
    _fetchOnboarding();
  }

  Future<void> _fetchOnboarding() async {
    try {
      final data = await ApiClient.getOnboardingState();
      final actions = data['actions'] as Map<String, dynamic>? ?? {};
      final swipe = actions['attendance_swipe'] as Map<String, dynamic>?;
      if (swipe != null) {
        final limit = swipe['limit'] as int? ?? 10;
        final count = swipe['view_count'] as int? ?? 0;
        setState(() => _tutorialViewsLeft = math.max(0, limit - count));
      }
    } catch (_) {}
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

  void _enterSwipeMode() {
    if (_students == null || _students!.isEmpty) return;
    setState(() {
      _swipeMode = true;
      _swipeIndex = 0;
      if (_tutorialViewsLeft > 0) {
        _showTutorial = true;
      }
    });
    if (_tutorialViewsLeft > 0) {
      ApiClient.markOnboardingSeen('attendance_swipe').catchError((_) {});
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) setState(() => _showTutorial = false);
      });
      setState(() => _tutorialViewsLeft--);
    }
  }

  void _exitSwipeMode() {
    setState(() {
      _swipeMode = false;
      _swipeIndex = 0;
    });
  }

  void _onSwipeDecision(String status) {
    if (_students == null || _swipeIndex >= _students!.length) return;
    setState(() {
      _students![_swipeIndex].status = status;
      _swipeIndex++;
    });
    if (_swipeIndex >= _students!.length) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() { _swipeMode = false; _swipeIndex = 0; });
      });
    }
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
                      if (_swipeMode)
                        GestureDetector(
                          onTap: _exitSwipeMode,
                          child: const Icon(Icons.close, color: AppColors.muted, size: 22),
                        )
                      else
                        const Text(
                          'Attendance',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text),
                        ),
                      const Spacer(),
                      if (!_swipeMode) ...[
                        // Swipe mode toggle
                        GestureDetector(
                          onTap: _enterSwipeMode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.sunLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.sun.withOpacity(0.4)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.swipe, size: 14, color: AppColors.sun),
                                SizedBox(width: 5),
                                Text('Swipe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.sun)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.text2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else
                        Text(
                          '${_swipeIndex}/${_students?.length ?? 0}',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted),
                        ),
                    ],
                  ),
                  if (!_swipeMode) ...[
                    const SizedBox(height: 10),
                    // 7-day week strip
                    _buildWeekStrip(),
                    const SizedBox(height: 6),
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
                      const Text('No sections assigned', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ],
              ),
            ),

            // Stats bar
            if (_students != null && !_swipeMode)
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
                    Row(
                      children: [
                        _MarkAllBtn(label: 'All Present', bg: AppColors.tealLight, fg: AppColors.teal, onTap: () => _markAll('present')),
                        const SizedBox(width: 6),
                        _MarkAllBtn(label: 'All Absent', bg: AppColors.coralLight, fg: AppColors.coral, onTap: () => _markAll('absent')),
                        const SizedBox(width: 6),
                        _MarkAllBtn(label: 'All Late', bg: AppColors.amberLight, fg: AppColors.amber, onTap: () => _markAll('late')),
                        const SizedBox(width: 6),
                        _MarkAllBtn(label: 'Reset', bg: const Color(0xFFF3F4F6), fg: AppColors.muted, onTap: () => _markAll('')),
                      ],
                    ),
                  ],
                ),
              ),

            // Main content area
            Expanded(
              child: _swipeMode
                  ? _buildSwipeView()
                  : _loadingStudents
                      ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
                      : _students == null || _students!.isEmpty
                          ? const Center(child: Text('No students enrolled', style: TextStyle(color: AppColors.muted)))
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
                                onLongPress: () => _showStudentModal(context, _students![i]),
                              ),
                            ),
            ),

            // Submit bar
            if (!_swipeMode)
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Save Attendance'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeView() {
    if (_students == null || _students!.isEmpty) {
      return const Center(child: Text('No students', style: TextStyle(color: AppColors.muted)));
    }
    if (_swipeIndex >= _students!.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 64, color: AppColors.teal),
            const SizedBox(height: 16),
            const Text('All marked!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 8),
            const Text('Tap Save Attendance below', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () { _exitSwipeMode(); _submit(); },
              child: const Text('Save & Exit'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Card stack (show current + peek of next)
        Positioned.fill(
          child: _TinderSwipeCard(
            key: ValueKey(_swipeIndex),
            student: _students![_swipeIndex],
            onSwipe: _onSwipeDecision,
          ),
        ),

        // Hint labels: right = Present, left = Absent, up = Late
        Positioned(
          bottom: 32,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HintPill(label: '← Absent', color: AppColors.coral),
              const SizedBox(width: 8),
              _HintPill(label: '↑ Late', color: AppColors.amber),
              const SizedBox(width: 8),
              _HintPill(label: 'Present →', color: AppColors.teal),
            ],
          ),
        ),

        // Tutorial overlay
        if (_showTutorial)
          Positioned.fill(
            child: _TutorialOverlay(onDismiss: () => setState(() => _showTutorial = false)),
          ),
      ],
    );
  }

  void _cycleStatus(int i) {
    final s = _students![i];
    setState(() {
      switch (s.status) {
        case '': s.status = 'present'; break;
        case 'present': s.status = 'absent'; break;
        case 'absent': s.status = 'late'; break;
        default: s.status = '';
      }
    });
  }

  void _showStudentModal(BuildContext context, AttendanceStudent student) {
    Color statusColor;
    String statusLabel;
    switch (student.status) {
      case 'present': statusColor = AppColors.teal; statusLabel = 'Present'; break;
      case 'absent': statusColor = AppColors.coral; statusLabel = 'Absent'; break;
      case 'late': statusColor = AppColors.amber; statusLabel = 'Late'; break;
      default: statusColor = AppColors.muted; statusLabel = 'Not marked';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            _StudentAvatar(student: student, size: 56),
            const SizedBox(height: 12),
            Text(student.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
            if (student.rollNo.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text('Roll No: ${student.rollNo}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.4)),
              ),
              child: Text(statusLabel, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekStrip() {
    final today = DateTime.now();
    // Start from Monday of the current week
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 52,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (_, i) {
          final day = monday.add(Duration(days: i));
          final isSunday = day.weekday == DateTime.sunday;
          final isSelected = day.year == _date.year && day.month == _date.month && day.day == _date.day;
          final isFuture = day.isAfter(today);
          return GestureDetector(
            onTap: isSunday || isFuture ? null : () {
              setState(() => _date = day);
              _loadStudents();
            },
            child: Container(
              width: 40,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.sun : isSunday ? const Color(0xFFF3F4F6) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.sun : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayLabels[i],
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : isSunday ? AppColors.muted : AppColors.text2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isSunday ? 'Off' : '${day.day}',
                    style: TextStyle(
                      fontSize: isSunday ? 9 : 13,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : isSunday ? AppColors.muted : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 6)),
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

// ── Tinder swipe card ──────────────────────────────────────────────────────────

class _TinderSwipeCard extends StatefulWidget {
  final AttendanceStudent student;
  final void Function(String status) onSwipe;

  const _TinderSwipeCard({super.key, required this.student, required this.onSwipe});

  @override
  State<_TinderSwipeCard> createState() => _TinderSwipeCardState();
}

class _TinderSwipeCardState extends State<_TinderSwipeCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Offset _drag = Offset.zero;
  bool _decided = false;

  static const double _threshold = 100;
  static const double _upThreshold = -80;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_decided) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails _) {
    if (_decided) return;
    if (_drag.dy < _upThreshold) {
      _decide('late');
    } else if (_drag.dx > _threshold) {
      _decide('present');
    } else if (_drag.dx < -_threshold) {
      _decide('absent');
    } else {
      // Snap back
      setState(() => _drag = Offset.zero);
    }
  }

  void _decide(String status) {
    _decided = true;
    final end = _drag.dx.abs() > _drag.dy.abs()
        ? Offset(_drag.dx.sign * 400, _drag.dy)
        : Offset(_drag.dx, -400.0);
    // Animate out
    final start = _drag;
    _ctrl.addListener(() {
      if (mounted) setState(() => _drag = Offset.lerp(start, end, _ctrl.value)!);
    });
    _ctrl.forward().then((_) {
      widget.onSwipe(status);
    });
  }

  Color get _overlayColor {
    if (_drag.dy < _upThreshold) return AppColors.amber.withOpacity(0.3);
    if (_drag.dx > 40) return AppColors.teal.withOpacity(0.3);
    if (_drag.dx < -40) return AppColors.coral.withOpacity(0.3);
    return Colors.transparent;
  }

  String get _overlayLabel {
    if (_drag.dy < _upThreshold) return 'LATE';
    if (_drag.dx > 40) return 'PRESENT';
    if (_drag.dx < -40) return 'ABSENT';
    return '';
  }

  Color get _overlayLabelColor {
    if (_drag.dy < _upThreshold) return AppColors.amber;
    if (_drag.dx > 40) return AppColors.teal;
    if (_drag.dx < -40) return AppColors.coral;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final angle = _drag.dx / 400;
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Center(
        child: Transform.translate(
          offset: _drag,
          child: Transform.rotate(
            angle: angle * 0.3,
            child: Container(
              width: 300,
              height: 380,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Card content
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StudentAvatar(student: widget.student, size: 100),
                        const SizedBox(height: 20),
                        Text(
                          widget.student.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.text),
                        ),
                        if (widget.student.rollNo.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Roll No: ${widget.student.rollNo}',
                            style: const TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Overlay tint + label
                  if (_overlayLabel.isNotEmpty)
                    Positioned.fill(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        decoration: BoxDecoration(
                          color: _overlayColor,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _overlayLabelColor, width: 2.5),
                            ),
                            child: Text(
                              _overlayLabel,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: _overlayLabelColor,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Student avatar (gender-based initials or photo) ────────────────────────────

class _StudentAvatar extends StatelessWidget {
  final AttendanceStudent student;
  final double size;

  const _StudentAvatar({required this.student, required this.size});

  String get _initials {
    final parts = student.name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  Widget _initialsAvatar() {
    final isFemale = student.gender?.toLowerCase() == 'female';
    final bg = isFemale ? const Color(0xFFF3E8FF) : const Color(0xFFDBEAFE);
    final fg = isFemale ? const Color(0xFF7C3AED) : const Color(0xFF1D4ED8);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(fontSize: size * 0.35, fontWeight: FontWeight.w900, color: fg),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (student.photoUrl != null && student.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          student.photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsAvatar(),
        ),
      );
    }
    return _initialsAvatar();
  }
}

// ── Tutorial overlay ───────────────────────────────────────────────────────────

class _TutorialOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const _TutorialOverlay({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.72),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'How to mark attendance',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Arrow(icon: Icons.arrow_back, label: 'Absent', color: AppColors.coral),
                  const SizedBox(width: 32),
                  _Arrow(icon: Icons.arrow_upward, label: 'Late', color: AppColors.amber),
                  const SizedBox(width: 32),
                  _Arrow(icon: Icons.arrow_forward, label: 'Present', color: AppColors.teal),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                'Tap to dismiss',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Arrow({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      );
}

class _HintPill extends StatelessWidget {
  final String label;
  final Color color;
  const _HintPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

// ── Helpers ────────────────────────────────────────────────────────────────────

class _MarkAllBtn extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _MarkAllBtn({required this.label, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Center(
              child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
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
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
      );
}

class _StudentCard extends StatelessWidget {
  final AttendanceStudent student;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _StudentCard({required this.student, required this.onTap, this.onLongPress});

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

  Color get _avatarFg {
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
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor, width: 1.5),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Show photo if available, else initials
                  if (student.photoUrl != null && student.photoUrl!.isNotEmpty)
                    ClipOval(
                      child: Image.network(
                        student.photoUrl!,
                        width: 40, height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: _avatarFg.withOpacity(0.15), shape: BoxShape.circle),
                          child: Center(child: Text(_initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _avatarFg))),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: _avatarFg.withOpacity(0.15), shape: BoxShape.circle),
                      child: Center(child: Text(_initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _avatarFg))),
                    ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      student.name.split(' ').first,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _statusLabel,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: _avatarFg),
                  ),
                ],
              ),
              // Info button — tapping shows modal, main card tap cycles status
              if (onLongPress != null)
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: onLongPress,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline, size: 12, color: AppColors.muted),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
