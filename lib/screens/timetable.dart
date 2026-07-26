import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  List<TimetableSlot>? _slots;
  bool _loading = true;
  String? _error;
  int _selectedDay = DateTime.now().weekday.clamp(1, 6); // Mon=1..Sat=6
  DateTime _selectedDate = DateTime.now();
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const _dayFull = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _monthLabel(DateTime month) => '${_monthNames[month.month - 1]} ${month.year}';

  // Color palette for subjects (deterministic by index)
  static const _palette = [
    _SlotColor(AppColors.violetLight, Color(0xFFC4B5FD), Color(0xFF5B21B6)),
    _SlotColor(AppColors.skyLight, Color(0xFF93C5FD), Color(0xFF1E40AF)),
    _SlotColor(AppColors.tealLight, Color(0xFF6EE7B7), Color(0xFF065F46)),
    _SlotColor(AppColors.coralLight, Color(0xFFFCA5A5), Color(0xFF991B1B)),
    _SlotColor(AppColors.amberLight, Color(0xFFFCD34D), Color(0xFF92400E)),
    _SlotColor(AppColors.sunLight, Color(0xFFFDBA74), Color(0xFFC2410C)),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedDay = date.weekday.clamp(1, 6);
    });
  }

  List<DateTime> get _monthDays {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Leading blanks so day 1 lines up under its weekday column (Mon-start week).
    final leading = first.weekday - 1;
    return [
      for (int i = 0; i < leading; i++) DateTime(0),
      for (int d = 1; d <= daysInMonth; d++) DateTime(_visibleMonth.year, _visibleMonth.month, d),
    ];
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final slots = await ApiClient.getMyTimetable();
      setState(() {
        _slots = slots;
        _loading = false;
      });
    } on ApiError catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load timetable'; _loading = false; });
    }
  }

  List<TimetableSlot> get _daySlots {
    if (_slots == null) return [];
    return _slots!
        .where((s) => s.dayOfWeek == _selectedDay)
        .toList()
      ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));
  }

  // Deterministic color per subject name
  _SlotColor _colorForSubject(String? name) {
    if (name == null) return _palette[0];
    return _palette[name.hashCode.abs() % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.text),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Timetable',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.text,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _load,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.refresh, size: 18, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your recurring weekly schedule, shown across the month',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  // Month navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _changeMonth(-1),
                        child: const Icon(Icons.chevron_left, color: AppColors.muted),
                      ),
                      Text(
                        _monthLabel(_visibleMonth),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                      ),
                      GestureDetector(
                        onTap: () => _changeMonth(1),
                        child: const Icon(Icons.chevron_right, color: AppColors.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Weekday header row
                  Row(
                    children: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map((d) => Expanded(
                              child: Center(
                                child: Text(d,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                  // Month grid — 7 columns, Mon-start weeks
                  GridView.count(
                    crossAxisCount: 7,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.85,
                    children: _monthDays.map((date) {
                      if (date.year == 0) return const SizedBox.shrink();
                      final today = DateTime.now();
                      final isSun = date.weekday == DateTime.sunday;
                      final active = !isSun &&
                          date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;
                      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                      return GestureDetector(
                        onTap: isSun ? null : () => _selectDate(date),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: active
                                ? context.primary
                                : isSun
                                    ? const Color(0xFFF3F4F6)
                                    : AppColors.bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active
                                  ? context.primary
                                  : isToday
                                      ? context.primary.withOpacity(0.5)
                                      : AppColors.border,
                              width: 1.2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: active
                                    ? Colors.white
                                    : isSun
                                        ? AppColors.muted
                                        : isToday
                                            ? context.primary
                                            : AppColors.text,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1, color: AppColors.border),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('😕', style: TextStyle(fontSize: 40)),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: const TextStyle(color: AppColors.muted),
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(onPressed: _load, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : _daySlots.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('☕', style: TextStyle(fontSize: 40)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No classes on ${_dayFull[(_selectedDay - 1).clamp(0, 5)]}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Enjoy your free time!',
                                    style: TextStyle(color: AppColors.muted),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: context.primary,
                              onRefresh: _load,
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                                children: [
                                  Text(
                                    '${_dayFull[(_selectedDay - 1).clamp(0, 5)]} — ${_daySlots.length} period${_daySlots.length > 1 ? "s" : ""}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ..._daySlots.asMap().entries.map((e) {
                                    final slot = e.value;
                                    final isLast = e.key == _daySlots.length - 1;
                                    final color = _colorForSubject(slot.subjectName);
                                    return _SlotCard(
                                      slot: slot,
                                      color: color,
                                      isLast: isLast,
                                    );
                                  }),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotColor {
  final Color bg;
  final Color border;
  final Color text;
  const _SlotColor(this.bg, this.border, this.text);
}

class _SlotCard extends StatelessWidget {
  final TimetableSlot slot;
  final _SlotColor color;
  final bool isLast;

  const _SlotCard({required this.slot, required this.color, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      decoration: BoxDecoration(
        color: color.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.border, width: 1.5),
      ),
      child: Row(
        children: [
          // Period number pill
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: color.border.withOpacity(0.4),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
            child: Center(
              child: Text(
                'P${slot.periodNumber}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.subjectName ?? 'Subject',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: color.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    slot.sectionLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color.text.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (slot.startTime != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    slot.startTime!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: color.text,
                    ),
                  ),
                  if (slot.endTime != null)
                    Text(
                      slot.endTime!,
                      style: TextStyle(
                        fontSize: 10,
                        color: color.text.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
