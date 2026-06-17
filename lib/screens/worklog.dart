import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

enum _Tab { today, week, month, custom }

class WorkLogScreen extends StatefulWidget {
  const WorkLogScreen({super.key});

  @override
  State<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends State<WorkLogScreen> {
  _Tab _tab = _Tab.today;
  DateTime _date = DateTime.now();
  DateTime? _customFrom;
  DateTime? _customTo;

  List<SectionInfo>? _sections;
  final Set<String> _selectedSectionIds = {};
  String? _typeFilter; // null = all, 'homework'|'classwork'|'note'

  List<WorkLogEntry> _entries = [];
  Map<String, List<WorkLogEntry>> _grouped = {};
  bool _loadingSections = true;
  bool _loadingEntries = false;

  static const _fmt = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String get _dateLabel =>
      '${_days[_date.weekday - 1]}, ${_date.day} ${_fmt[_date.month]}';

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    setState(() => _loadingSections = true);
    try {
      final sections = await ApiClient.getMySections();
      setState(() { _sections = sections; _loadingSections = false; });
      await _loadForTab();
    } catch (_) {
      setState(() => _loadingSections = false);
    }
  }

  Future<void> _loadEntries() async {
    setState(() => _loadingEntries = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      final ids = _selectedSectionIds.isEmpty ? null : _selectedSectionIds.toList();
      final list = await ApiClient.getWorkLogs(date: dateStr, sectionIds: ids);
      setState(() { _entries = list; _loadingEntries = false; });
    } catch (_) {
      setState(() { _entries = []; _loadingEntries = false; });
    }
  }

  Future<void> _loadRange() async {
    final range = _getDateRange();
    if (range == null) {
      setState(() { _grouped = {}; _loadingEntries = false; });
      return;
    }
    setState(() => _loadingEntries = true);
    try {
      final ids = _selectedSectionIds.isEmpty ? null : _selectedSectionIds.toList();
      final list = await ApiClient.getWorkLogs(
        dateFrom: range.$1, dateTo: range.$2, sectionIds: ids,
      );
      final Map<String, List<WorkLogEntry>> g = {};
      for (final e in list) {
        (g[e.date] ??= []).add(e);
      }
      setState(() {
        _grouped = Map.fromEntries(
          g.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
        );
        _loadingEntries = false;
      });
    } catch (_) {
      setState(() { _grouped = {}; _loadingEntries = false; });
    }
  }

  (String, String)? _getDateRange() {
    final now = DateTime.now();
    final f = DateFormat('yyyy-MM-dd');
    return switch (_tab) {
      _Tab.week => (f.format(now.subtract(Duration(days: now.weekday - 1))), f.format(now)),
      _Tab.month => (f.format(DateTime(now.year, now.month, 1)), f.format(now)),
      _Tab.custom when _customFrom != null && _customTo != null =>
        (f.format(_customFrom!), f.format(_customTo!)),
      _ => null,
    };
  }

  Future<void> _loadForTab() async {
    if (_tab == _Tab.today) {
      await _loadEntries();
    } else {
      await _loadRange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Work Log'),
        actions: _tab == _Tab.today
            ? [
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.sunLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 13, color: AppColors.sun),
                        const SizedBox(width: 5),
                        Text(
                          _dateLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.sun,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]
            : null,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: AppColors.sun,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Log', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Non-scrollable header area
          _buildTabBar(),
          if (_tab == _Tab.today) _buildWeekStrip(),
          if (_tab == _Tab.custom) _buildCustomPickers(),
          _buildSectionChips(),
          _buildTypeFilter(),
          // Scrollable list
          Expanded(
            child: RefreshIndicator(
              color: AppColors.sun,
              onRefresh: _loadForTab,
              child: CustomScrollView(
                slivers: _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
    final today = DateTime.now();
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: SizedBox(
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
                _loadEntries();
              },
              child: Container(
                width: 40,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.sun : isSunday ? const Color(0xFFF3F4F6) : AppColors.bg,
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
      ),
    );
  }

  Widget _buildTabBar() {
    const labels = [
      (_Tab.today, 'Today'),
      (_Tab.week, 'Week'),
      (_Tab.month, 'Month'),
      (_Tab.custom, 'Custom'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            for (final (t, label) in labels)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_tab == t) return;
                    setState(() => _tab = t);
                    _loadForTab();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _tab == t ? AppColors.sun : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _tab == t ? Colors.white : AppColors.muted,
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

  Widget _buildCustomPickers() {
    final fmt = DateFormat('dd MMM yyyy');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _customFrom ?? DateTime.now().subtract(const Duration(days: 7)),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: _customTo ?? DateTime.now(),
                  builder: _datepickerTheme,
                );
                if (d != null) {
                  setState(() => _customFrom = d);
                  if (_customTo != null) _loadRange();
                }
              },
              child: _DatePickerBtn(
                label: _customFrom != null ? fmt.format(_customFrom!) : 'From date',
                hasValue: _customFrom != null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _customTo ?? DateTime.now(),
                  firstDate: _customFrom ?? DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                  builder: _datepickerTheme,
                );
                if (d != null) {
                  setState(() => _customTo = d);
                  if (_customFrom != null) _loadRange();
                }
              },
              child: _DatePickerBtn(
                label: _customTo != null ? fmt.format(_customTo!) : 'To date',
                hasValue: _customTo != null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: _loadingSections
          ? const LinearProgressIndicator(color: AppColors.sun)
          : _sections == null || _sections!.isEmpty
              ? const Text('No sections assigned',
                  style: TextStyle(color: AppColors.muted, fontSize: 13))
              : SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sections!.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        final allActive = _selectedSectionIds.isEmpty;
                        return _SectionChip(
                          label: 'All',
                          active: allActive,
                          onTap: () {
                            setState(() => _selectedSectionIds.clear());
                            _loadForTab();
                          },
                        );
                      }
                      final sec = _sections![i - 1];
                      final active = _selectedSectionIds.contains(sec.id);
                      return _SectionChip(
                        label: sec.label,
                        active: active,
                        onTap: () {
                          setState(() {
                            if (active) {
                              _selectedSectionIds.remove(sec.id);
                            } else {
                              _selectedSectionIds.add(sec.id);
                            }
                          });
                          _loadForTab();
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildTypeFilter() {
    const types = [
      (null, 'All'),
      ('homework', '📚 Homework'),
      ('classwork', '📖 Classwork'),
      ('note', '📌 Note'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: types.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final (val, label) = types[i];
            final active = _typeFilter == val;
            return GestureDetector(
              onTap: () => setState(() => _typeFilter = val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? AppColors.sun : AppColors.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? AppColors.sun : AppColors.border, width: 1.5),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.muted,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<WorkLogEntry> get _filteredEntries =>
      _typeFilter == null ? _entries : _entries.where((e) => e.logType == _typeFilter).toList();

  Map<String, List<WorkLogEntry>> get _filteredGrouped {
    if (_typeFilter == null) return _grouped;
    final Map<String, List<WorkLogEntry>> result = {};
    for (final entry in _grouped.entries) {
      final filtered = entry.value.where((e) => e.logType == _typeFilter).toList();
      if (filtered.isNotEmpty) result[entry.key] = filtered;
    }
    return result;
  }

  List<Widget> _buildContent() {
    if (_loadingEntries) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator(color: AppColors.sun)),
          ),
        ),
      ];
    }

    if (_tab == _Tab.today) {
      if (_filteredEntries.isEmpty) {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
              child: Center(
                child: Column(
                  children: [
                    const Text('📝', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 10),
                    const Text('No work logs for today',
                        style: TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Tap + to add homework or classwork',
                        style: TextStyle(
                            color: AppColors.muted.withOpacity(0.7),
                            fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _WorkLogCard(entry: _filteredEntries[i]),
              childCount: _filteredEntries.length,
            ),
          ),
        ),
      ];
    }

    // History tabs: grouped by date
    if (_tab == _Tab.custom && _getDateRange() == null) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('Select from and to dates above',
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
          ),
        ),
      ];
    }

    if (_filteredGrouped.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text('No entries in this period',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontSize: 14)),
            ),
          ),
        ),
      ];
    }

    // Flatten groups into items list: [DateHeader, Entry, Entry, DateHeader, Entry, ...]
    final items = <_HistoryItem>[];
    for (final entry in _filteredGrouped.entries) {
      items.add(_HistoryItem.header(entry.key));
      for (final e in entry.value) {
        items.add(_HistoryItem.entry(e));
      }
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (_, i) {
              final item = items[i];
              if (item.isHeader) {
                return _DateHeader(dateKey: item.dateKey!);
              }
              return _WorkLogCard(entry: item.entry!);
            },
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: _datepickerTheme,
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      _loadEntries();
    }
  }

  Widget Function(BuildContext, Widget?) get _datepickerTheme =>
      (ctx, child) => Theme(
            data: ThemeData(
                colorScheme: const ColorScheme.light(primary: AppColors.sun)),
            child: child!,
          );

  void _showAddSheet() {
    if (_sections == null || _sections!.isEmpty) {
      showSnack(context, 'No sections assigned', error: true);
      return;
    }

    final descCtrl = TextEditingController();
    final studentSearchCtrl = TextEditingController();
    String logType = 'classwork';
    final Set<String> selectedSectionIds = {_sections!.first.id};
    DateTime? dueDate;
    StudentSearchResult? selectedStudent;
    List<StudentSearchResult> studentResults = [];
    bool searchingStudent = false;

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
                  'Add Work Log',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.text),
                ),
                const SizedBox(height: 14),
                // Log type selector
                Row(
                  children: [
                    _LogTypeChip(
                      label: 'Homework',
                      icon: '📚',
                      color: AppColors.coral,
                      bg: AppColors.coralLight,
                      selected: logType == 'homework',
                      onTap: () => setSheet(() => logType = 'homework'),
                    ),
                    const SizedBox(width: 8),
                    _LogTypeChip(
                      label: 'Classwork',
                      icon: '📖',
                      color: AppColors.sky,
                      bg: AppColors.skyLight,
                      selected: logType == 'classwork',
                      onTap: () => setSheet(() => logType = 'classwork'),
                    ),
                    const SizedBox(width: 8),
                    _LogTypeChip(
                      label: 'Note',
                      icon: '📌',
                      color: AppColors.amber,
                      bg: AppColors.amberLight,
                      selected: logType == 'note',
                      onTap: () => setSheet(() => logType = 'note'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Section chip multi-selector
                const Text(
                  'Sections (tap to select multiple)',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sections!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final sec = _sections![i];
                      final active = selectedSectionIds.contains(sec.id);
                      return _SectionChip(
                        label: sec.label,
                        active: active,
                        onTap: () => setSheet(() {
                          if (active) {
                            if (selectedSectionIds.length > 1) selectedSectionIds.remove(sec.id);
                          } else {
                            selectedSectionIds.add(sec.id);
                          }
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Optional: specific student
                const Text('For Student (optional)',
                    style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (selectedStudent != null)
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                          ),
                          child: Text('👤 ${selectedStudent!.name}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.teal)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setSheet(() { selectedStudent = null; studentResults = []; studentSearchCtrl.clear(); }),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      TextField(
                        controller: studentSearchCtrl,
                        onChanged: (q) async {
                          if (q.trim().length < 2) {
                            setSheet(() { studentResults = []; searchingStudent = false; });
                            return;
                          }
                          setSheet(() => searchingStudent = true);
                          try {
                            final r = await ApiClient.searchStudents(q.trim());
                            setSheet(() { studentResults = r; searchingStudent = false; });
                          } catch (_) {
                            setSheet(() { studentResults = []; searchingStudent = false; });
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Search student (or leave blank for whole class)',
                          prefixIcon: const Icon(Icons.search, size: 16, color: AppColors.muted),
                          suffixIcon: searchingStudent
                              ? const Padding(padding: EdgeInsets.all(12),
                                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sun)))
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                      ),
                      if (studentResults.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: studentResults.take(4).map((s) => InkWell(
                              onTap: () => setSheet(() { selectedStudent = s; studentResults = []; studentSearchCtrl.clear(); }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                                    const SizedBox(width: 6),
                                    if (s.rollNo != null)
                                      Text('#${s.rollNo}', style: const TextStyle(fontSize: 11, color: AppColors.sun, fontWeight: FontWeight.w700)),
                                    if (s.rollNo != null) const SizedBox(width: 4),
                                    Text(s.classLabel ?? '', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the work assigned...',
                  ),
                ),
                if (logType == 'homework') ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx2,
                        initialDate:
                            dueDate ?? _date.add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 90)),
                        builder: (c, w) => Theme(
                          data: ThemeData(
                              colorScheme: const ColorScheme.light(
                                  primary: AppColors.sun)),
                          child: w!,
                        ),
                      );
                      if (d != null) setSheet(() => dueDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.bg,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined,
                              size: 14, color: AppColors.muted),
                          const SizedBox(width: 8),
                          Text(
                            dueDate != null
                                ? 'Due: ${fmtDate(dueDate!.toIso8601String())}'
                                : 'Set due date (optional)',
                            style: TextStyle(
                              fontSize: 13,
                              color: dueDate != null
                                  ? AppColors.text
                                  : AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (descCtrl.text.trim().isEmpty) {
                        showSnack(context, 'Please enter a description', error: true);
                        return;
                      }
                      try {
                        final dateStr = DateFormat('yyyy-MM-dd').format(_date);
                        final dueDateStr = dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : null;
                        final desc = descCtrl.text.trim();
                        for (final secId in selectedSectionIds) {
                          await ApiClient.createWorkLog(
                            classSectionId: secId,
                            date: dateStr,
                            logType: logType,
                            description: desc,
                            dueDate: dueDateStr,
                          );
                        }
                        descCtrl.clear();
                        if (mounted) Navigator.pop(ctx2);
                        _loadForTab();
                        final count = selectedSectionIds.length;
                        if (mounted) showSnack(context, count > 1 ? 'Work log added to $count sections ✓' : 'Work log added ✓');
                      } on ApiError catch (e) {
                        if (mounted) showSnack(context, e.message, error: true);
                      }
                    },
                    child: const Text('Save Work Log'),
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

// ── Small items ───────────────────────────────────────────────────────────────

class _HistoryItem {
  final bool isHeader;
  final String? dateKey;
  final WorkLogEntry? entry;

  const _HistoryItem.header(String key)
      : isHeader = true,
        dateKey = key,
        entry = null;

  const _HistoryItem.entry(WorkLogEntry e)
      : isHeader = false,
        dateKey = null,
        entry = e;
}

class _DateHeader extends StatelessWidget {
  final String dateKey; // "yyyy-MM-dd"
  const _DateHeader({required this.dateKey});

  String _format() {
    try {
      final d = DateTime.parse(dateKey);
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return '${days[d.weekday - 1]}, ${d.day} ${months[d.month]}';
    } catch (_) {
      return dateKey;
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(
          _format(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 0.4),
        ),
      );
}

class _DatePickerBtn extends StatelessWidget {
  final String label;
  final bool hasValue;
  const _DatePickerBtn({required this.label, required this.hasValue});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: hasValue ? AppColors.sunLight : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasValue ? AppColors.sun : AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 13, color: hasValue ? AppColors.sun : AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasValue ? AppColors.sun : AppColors.muted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
}

class _SectionChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _SectionChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.sun : AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? AppColors.sun : AppColors.border, width: 1.5),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      );
}

class _LogTypeChip extends StatelessWidget {
  final String label;
  final String icon;
  final Color color;
  final Color bg;
  final bool selected;
  final VoidCallback onTap;

  const _LogTypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color : AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
}

class _WorkLogCard extends StatelessWidget {
  final WorkLogEntry entry;
  const _WorkLogCard({required this.entry});

  Color get _color {
    return switch (entry.logType) {
      'homework' => AppColors.coral,
      'note' => AppColors.amber,
      _ => AppColors.sky,
    };
  }

  Color get _bg {
    return switch (entry.logType) {
      'homework' => AppColors.coralLight,
      'note' => AppColors.amberLight,
      _ => AppColors.skyLight,
    };
  }

  String get _typeLabel {
    return switch (entry.logType) {
      'homework' => '📚 Homework',
      'note' => '📌 Note',
      _ => '📖 Classwork',
    };
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _typeLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _color),
                  ),
                ),
                const SizedBox(width: 8),
                if (entry.studentName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.tealLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '👤 ${entry.studentName}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.teal),
                        ),
                        if (entry.studentRollNo != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '· #${entry.studentRollNo}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.teal),
                          ),
                        ],
                        if (entry.studentClassLabel != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            '· ${entry.studentClassLabel}',
                            style: TextStyle(fontSize: 10, color: AppColors.teal.withOpacity(0.8)),
                          ),
                        ],
                      ],
                    ),
                  )
                else if (entry.sectionLabel.isNotEmpty)
                  Text(
                    entry.sectionLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                const Spacer(),
                Text(
                  fmtDate(entry.date),
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.description,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.text, height: 1.4),
            ),
            if (entry.dueDate != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 12, color: AppColors.coral),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${fmtDate(entry.dueDate!)}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.coral,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            if (entry.acknowledgmentCount > 0) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 12, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text(
                    '${entry.acknowledgmentCount} seen',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.teal,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
}
