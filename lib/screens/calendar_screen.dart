import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _viewMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();
  List<CalendarEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final list = await ApiClient.getCalendarEvents(
        month: _viewMonth.month,
        year: _viewMonth.year,
      );
      setState(() { _events = list; _loading = false; });
    } catch (_) {
      setState(() { _events = []; _loading = false; });
    }
  }

  List<CalendarEvent> _eventsForDay(DateTime day) {
    return _events.where((e) {
      try {
        final start = DateTime.parse(e.startDate);
        final end = DateTime.parse(e.endDate);
        final d = DateTime(day.year, day.month, day.day);
        return !d.isBefore(DateTime(start.year, start.month, start.day)) &&
            !d.isAfter(DateTime(end.year, end.month, end.day));
      } catch (_) {
        return false;
      }
    }).toList();
  }

  Color _eventColor(String type) {
    switch (type) {
      case 'holiday': return AppColors.coral;
      case 'exam': return AppColors.violet;
      case 'meeting': return AppColors.amber;
      default: return AppColors.sky;
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const monthNames = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text('${monthNames[_viewMonth.month]} ${_viewMonth.year}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadEvents,
            color: AppColors.muted,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddEventSheet,
        backgroundColor: AppColors.sun,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Event', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppColors.sun,
        onRefresh: _loadEvents,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Month nav
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () {
                        setState(() {
                          _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1);
                        });
                        _loadEvents();
                      },
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${monthNames[_viewMonth.month]} ${_viewMonth.year}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () {
                        setState(() {
                          _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1);
                        });
                        _loadEvents();
                      },
                    ),
                  ],
                ),
              ),

              // Day headers
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      .map(
                        (d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.muted),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),

              // Calendar grid
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: _loading
                    ? const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator(color: AppColors.sun)),
                      )
                    : _buildGrid(now),
              ),

              const SizedBox(height: 8),

              // Events for selected day
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Events on ${_selectedDay.day} ${monthNames[_selectedDay.month]}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
                      ),
                    ),
                    ..._buildEventList(),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(DateTime now) {
    final firstDay = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    // weekday: Mon=1, Sun=7. We want Mon in col 0.
    final startCol = (firstDay.weekday - 1) % 7; // 0 for Mon

    final cells = <Widget>[];
    // Leading blanks
    for (int i = 0; i < startCol; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_viewMonth.year, _viewMonth.month, day);
      final isToday =
          date.year == now.year && date.month == now.month && date.day == now.day;
      final isSelected = date.year == _selectedDay.year &&
          date.month == _selectedDay.month &&
          date.day == _selectedDay.day;
      final dayEvents = _eventsForDay(date);

      cells.add(
        GestureDetector(
          onTap: () => setState(() => _selectedDay = date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.sun
                  : isToday
                      ? AppColors.sunLight
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday || isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : isToday
                            ? AppColors.sun
                            : AppColors.text,
                  ),
                ),
                if (dayEvents.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: dayEvents
                        .take(3)
                        .map(
                          (e) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.8)
                                  : _eventColor(e.eventType),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.95,
      children: cells,
    );
  }

  List<Widget> _buildEventList() {
    final dayEvents = _eventsForDay(_selectedDay);
    if (dayEvents.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: Text(
              'No events on this day',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ),
      ];
    }
    return dayEvents.map((e) => _EventRow(event: e)).toList();
  }

  void _showAddEventSheet() {
    final titleCtrl = TextEditingController();
    String eventType = 'event';
    DateTime? startDate = _selectedDay;
    DateTime? endDate = _selectedDay;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Add Calendar Event',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Event Title'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: eventType,
                  decoration: const InputDecoration(labelText: 'Event Type'),
                  items: const [
                    DropdownMenuItem(value: 'event', child: Text('Event')),
                    DropdownMenuItem(value: 'holiday', child: Text('Holiday')),
                    DropdownMenuItem(value: 'exam', child: Text('Exam')),
                    DropdownMenuItem(value: 'meeting', child: Text('Meeting')),
                  ],
                  onChanged: (v) => setSheet(() => eventType = v ?? 'event'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx2,
                            initialDate: startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (c, w) => Theme(
                              data: ThemeData(
                                  colorScheme: const ColorScheme.light(
                                      primary: AppColors.sun)),
                              child: w!,
                            ),
                          );
                          if (d != null) setSheet(() => startDate = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.bg,
                          ),
                          child: Text(
                            startDate != null
                                ? fmtDate(startDate!.toIso8601String())
                                : 'Start Date',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx2,
                            initialDate: endDate ?? startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (c, w) => Theme(
                              data: ThemeData(
                                  colorScheme: const ColorScheme.light(
                                      primary: AppColors.sun)),
                              child: w!,
                            ),
                          );
                          if (d != null) setSheet(() => endDate = d);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.bg,
                          ),
                          child: Text(
                            endDate != null
                                ? fmtDate(endDate!.toIso8601String())
                                : 'End Date',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty || startDate == null) return;
                      try {
                        await ApiClient.createCalendarEvent(
                          title: titleCtrl.text.trim(),
                          eventType: eventType,
                          startDate: startDate!.toIso8601String().split('T')[0],
                          endDate:
                              (endDate ?? startDate!).toIso8601String().split('T')[0],
                        );
                        if (mounted) Navigator.pop(ctx2);
                        _loadEvents();
                        if (mounted) showSnack(context, 'Event added ✓');
                      } on ApiError catch (e) {
                        if (mounted) showSnack(context, e.message, error: true);
                      }
                    },
                    child: const Text('Add Event'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final CalendarEvent event;
  const _EventRow({required this.event});

  Color get _color {
    switch (event.eventType) {
      case 'holiday': return AppColors.coral;
      case 'exam': return AppColors.violet;
      case 'meeting': return AppColors.amber;
      default: return AppColors.sky;
    }
  }

  Color get _bg {
    switch (event.eventType) {
      case 'holiday': return AppColors.coralLight;
      case 'exam': return AppColors.violetLight;
      case 'meeting': return AppColors.amberLight;
      default: return AppColors.skyLight;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${fmtDate(event.startDate)}${event.startDate != event.endDate ? ' → ${fmtDate(event.endDate)}' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                event.eventType[0].toUpperCase() + event.eventType.substring(1),
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _color),
              ),
            ),
          ],
        ),
      );
}
