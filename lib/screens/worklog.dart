import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

String _workLogShareText(WorkLogEntry entry, String schoolName) {
  final typeLabel = switch (entry.logType) {
    'homework' => 'Homework',
    'note' => 'Note',
    _ => 'Classwork',
  };
  final buf = StringBuffer('*$typeLabel* — ${entry.sectionLabel}\n');
  if (entry.subjectName != null) buf.writeln(entry.subjectName);
  buf.writeln();
  buf.writeln(entry.description);
  if (entry.chapterName != null) {
    buf.writeln(entry.topicName != null
        ? '\nChapter: ${entry.chapterName} (${entry.topicName})'
        : '\nChapter: ${entry.chapterName}');
  }
  if (entry.dueDate != null) buf.writeln('\n📅 Due: ${fmtDate(entry.dueDate!)}');
  buf.write('\n— via $schoolName');
  return buf.toString();
}

enum _Tab { today, week, month, custom }

class WorkLogScreen extends StatefulWidget {
  const WorkLogScreen({super.key});

  @override
  State<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends State<WorkLogScreen> {
  _Tab _tab = _Tab.week;
  DateTime _date = DateTime.now();
  DateTime? _customFrom;
  DateTime? _customTo;

  List<SectionInfo>? _sections;
  final Set<String> _selectedSectionIds = {};
  String? _typeFilter; // null = all, 'homework'|'classwork'|'note'
  String? _reviewFilter; // null = all, 'reviewed'|'partial'|'not_reviewed'

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
                      color: context.primaryLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 13, color: context.primary),
                        const SizedBox(width: 5),
                        Text(
                          _dateLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: context.primary,
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
        backgroundColor: null,
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
          if (_typeFilter == null || _typeFilter == 'homework') _buildReviewFilter(),
          // Scrollable list
          Expanded(
            child: RefreshIndicator(
              color: context.primary,
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
        height: 72,
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
                  color: isSelected ? context.primary : isSunday ? const Color(0xFFF3F4F6) : AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? context.primary : AppColors.border,
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
                      color: _tab == t ? context.primary : Colors.transparent,
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
          ? LinearProgressIndicator()
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
                  color: active ? context.primary : AppColors.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? context.primary : AppColors.border, width: 1.5),
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

  bool _passesFilters(WorkLogEntry e) {
    if (_typeFilter != null && e.logType != _typeFilter) return false;
    if (_reviewFilter != null && e.reviewStatus != _reviewFilter) return false;
    return true;
  }

  Widget _buildReviewFilter() {
    const statuses = [
      (null, 'All'),
      ('reviewed', '✅ Reviewed'),
      ('partial', '🟡 Partially Reviewed'),
      ('not_reviewed', '⏳ Not Reviewed'),
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: statuses.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final (val, label) = statuses[i];
            final active = _reviewFilter == val;
            return GestureDetector(
              onTap: () => setState(() => _reviewFilter = val),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? context.primary : AppColors.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: active ? context.primary : AppColors.border, width: 1.5),
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

  List<WorkLogEntry> get _filteredEntries => _entries.where(_passesFilters).toList();

  Map<String, List<WorkLogEntry>> get _filteredGrouped {
    if (_typeFilter == null && _reviewFilter == null) return _grouped;
    final Map<String, List<WorkLogEntry>> result = {};
    for (final entry in _grouped.entries) {
      final filtered = entry.value.where(_passesFilters).toList();
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
            child: Center(child: CircularProgressIndicator()),
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
              (_, i) => _WorkLogCard(entry: _filteredEntries[i], onChanged: _loadForTab),
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
              return _WorkLogCard(entry: item.entry!, onChanged: _loadForTab);
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
                colorScheme: null),
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
    List<XFile> pickedImages = [];
    List<Map<String, String>> subjects = [];
    String? selectedSubjectId;
    String? selectedSubjectName;
    List<Map<String, dynamic>> chapterOptions = [];
    String? selectedChapterId;
    String? selectedChapterName;
    bool markChapterCompleted = false;
    bool loadingChapters = false;
    List<Map<String, dynamic>> topicOptions = [];
    final Set<String> selectedTopicIds = {};
    bool loadingTopics = false;
    String? _subjectsLoadedForSectionId;
    bool subjectsLoading = true;
    bool subjectsError = false;

    Future<void> loadSubjects(String? sectionId, void Function(void Function()) setSheetFn) async {
      setSheetFn(() {
        subjectsLoading = true;
        subjectsError = false;
        selectedSubjectId = null;
        selectedSubjectName = null;
        chapterOptions = [];
        selectedChapterId = null;
        selectedChapterName = null;
        markChapterCompleted = false;
      });
      try {
        final s = await ApiClient.getMySubjects(classSectionId: sectionId);
        setSheetFn(() { subjects = s; subjectsLoading = false; });
      } catch (_) {
        setSheetFn(() { subjectsLoading = false; subjectsError = true; });
      }
    }

    Future<void> loadChapters(String sectionId, String subjectId, void Function(void Function()) setSheetFn) async {
      setSheetFn(() {
        loadingChapters = true; chapterOptions = []; selectedChapterId = null; selectedChapterName = null;
        markChapterCompleted = false; topicOptions = []; selectedTopicIds.clear();
      });
      try {
        final syllabus = await ApiClient.getSyllabus(sectionId);
        final match = syllabus.firstWhere(
          (s) => s['subject_id']?.toString() == subjectId,
          orElse: () => <String, dynamic>{},
        );
        final chapters = (match['chapters'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        setSheetFn(() { chapterOptions = chapters; loadingChapters = false; });
      } catch (_) {
        setSheetFn(() { loadingChapters = false; });
      }
    }

    // Topics are chapter-scoped — always re-fetched fresh for the specific
    // chapterId just selected, never carried over from a previous chapter.
    // sectionId (only when a single section is selected) brings back each
    // topic's `covered` flag so the teacher can spot what's left to teach.
    Future<void> loadTopics(String chapterId, String? sectionId, void Function(void Function()) setSheetFn) async {
      setSheetFn(() { loadingTopics = true; topicOptions = []; selectedTopicIds.clear(); });
      try {
        final topics = await ApiClient.getTopics(chapterId, classSectionId: sectionId);
        setSheetFn(() { topicOptions = topics; loadingTopics = false; });
      } catch (_) {
        setSheetFn(() { loadingTopics = false; });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) {
          final currentSectionId = selectedSectionIds.length == 1 ? selectedSectionIds.first : null;
          if (_subjectsLoadedForSectionId != currentSectionId) {
            _subjectsLoadedForSectionId = currentSectionId;
            loadSubjects(currentSectionId, setSheet);
          }
          return Padding(
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
                  'Section',
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
                          selectedSectionIds
                            ..clear()
                            ..add(sec.id);
                        }),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Subject selector
                const Text('Subject (optional)',
                    style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                if (subjectsLoading)
                  const SizedBox(
                    height: 34,
                    child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                else if (subjectsError)
                  const Text('Could not load subjects — pull down to retry',
                      style: TextStyle(color: AppColors.muted, fontSize: 12))
                else if (subjects.isEmpty)
                  const Text('No subjects assigned for these sections',
                      style: TextStyle(color: AppColors.muted, fontSize: 12))
                else
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: subjects.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          final active = selectedSubjectId == null;
                          return _SectionChip(
                            label: 'All',
                            active: active,
                            onTap: () => setSheet(() {
                              selectedSubjectId = null;
                              selectedSubjectName = null;
                              chapterOptions = [];
                              selectedChapterId = null;
                              selectedChapterName = null;
                              markChapterCompleted = false;
                            }),
                          );
                        }
                        final sub = subjects[i - 1];
                        final active = selectedSubjectId == sub['id'];
                        return _SectionChip(
                          label: sub['name']!,
                          active: active,
                          onTap: () {
                            setSheet(() {
                              selectedSubjectId = sub['id'];
                              selectedSubjectName = sub['name'];
                            });
                            if (selectedSectionIds.isNotEmpty) {
                              loadChapters(selectedSectionIds.first, sub['id']!, setSheet);
                            }
                          },
                        );
                      },
                    ),
                  ),
                // Chapter picker — shown when a subject is selected
                if (selectedSubjectId != null) ...[
                  const SizedBox(height: 10),
                  const Text('Chapter (optional)',
                      style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (loadingChapters)
                    const SizedBox(
                      height: 34,
                      child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                    )
                  else if (chapterOptions.isEmpty)
                    const SizedBox(
                      height: 28,
                      child: Center(
                        child: Text('No chapters configured for this subject',
                            style: TextStyle(fontSize: 11, color: AppColors.muted)),
                      ),
                    )
                  else
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: chapterOptions.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return _SectionChip(
                              label: 'None',
                              active: selectedChapterId == null,
                              onTap: () => setSheet(() {
                                selectedChapterId = null;
                                selectedChapterName = null;
                                markChapterCompleted = false;
                                topicOptions = [];
                                selectedTopicIds.clear();
                              }),
                            );
                          }
                          final ch = chapterOptions[i - 1];
                          final chId = ch['id'] as String? ?? '';
                          final chName = ch['name'] as String? ?? '';
                          final chNum = ch['number'] as int? ?? i;
                          final status = ch['status'] as String? ?? 'not_started';
                          final active = selectedChapterId == chId;
                          final statusColor = status == 'completed'
                              ? AppColors.green
                              : status == 'in_progress'
                                  ? AppColors.amber
                                  : AppColors.muted;
                          return _ChapterChip(
                            number: chNum,
                            name: chName,
                            active: active,
                            statusColor: statusColor,
                            completed: status == 'completed',
                            onTap: () {
                              setSheet(() {
                                selectedChapterId = chId;
                                selectedChapterName = chName;
                                markChapterCompleted = false;
                              });
                              loadTopics(chId, currentSectionId, setSheet);
                            },
                          );
                        },
                      ),
                    ),
                  if (selectedChapterId != null) ...[
                    // Topic picker — chapter-scoped, only shown when this chapter
                    // actually has topics (most don't yet; that's fine, this whole
                    // block just doesn't render and work logs behave as before).
                    // Multi-select: a teacher can cover several topics from the
                    // same chapter in one session. Topics already logged against
                    // this section (covered == true) get a check-mark so the
                    // teacher can spot what's left at a glance.
                    if (loadingTopics) ...[
                      const SizedBox(height: 8),
                      const SizedBox(
                        height: 28,
                        child: Center(child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
                      ),
                    ] else if (topicOptions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Topics (optional, pick any that apply)',
                          style: TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: topicOptions.length + 1,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) {
                            if (i == 0) {
                              return _SectionChip(
                                label: 'Clear',
                                active: selectedTopicIds.isEmpty,
                                onTap: () => setSheet(() => selectedTopicIds.clear()),
                              );
                            }
                            final tp = topicOptions[i - 1];
                            final tpId = tp['id'] as String? ?? '';
                            final tpName = tp['name'] as String? ?? '';
                            final tpCovered = tp['covered'] as bool? ?? false;
                            return _SectionChip(
                              label: tpName,
                              active: selectedTopicIds.contains(tpId),
                              covered: tpCovered,
                              onTap: () => setSheet(() {
                                if (!selectedTopicIds.remove(tpId)) selectedTopicIds.add(tpId);
                              }),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () => setSheet(() => markChapterCompleted = !markChapterCompleted),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Checkbox(
                            value: markChapterCompleted,
                            onChanged: (v) => setSheet(() => markChapterCompleted = v ?? false),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const SizedBox(width: 4),
                          const Expanded(
                            child: Text('Mark this chapter as completed',
                                style: TextStyle(fontSize: 12, color: AppColors.text, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
                                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)))
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
                                      Text('#${s.rollNo}', style: TextStyle(fontSize: 11, color: context.primary, fontWeight: FontWeight.w700)),
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
                  key: const Key('worklog_description_field'),
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
                        builder: (c, w) => Theme(data: Theme.of(c), child: w!),
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
                const SizedBox(height: 10),
                // Image attachments (up to 2)
                if (pickedImages.isNotEmpty) ...[
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pickedImages.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: FutureBuilder<Uint8List>(
                              future: pickedImages[i].readAsBytes(),
                              builder: (_, snap) => snap.hasData
                                  ? Image.memory(snap.data!, width: 72, height: 72, fit: BoxFit.cover)
                                  : Container(width: 72, height: 72, color: AppColors.border),
                            ),
                          ),
                          Positioned(
                            top: 2,
                            right: 2,
                            child: GestureDetector(
                              onTap: () => setSheet(() => pickedImages.removeAt(i)),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (pickedImages.length < 2)
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                      if (img != null) setSheet(() => pickedImages.add(img));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.bg,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_photo_alternate_outlined, size: 16, color: AppColors.muted),
                          const SizedBox(width: 6),
                          Text(
                            pickedImages.isEmpty ? 'Add photo (optional, up to 2)' : 'Add another photo',
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('save_worklog_button'),
                    onPressed: () async {
                      if (descCtrl.text.trim().isEmpty) {
                        showSnack(context, 'Please enter a description', error: true);
                        return;
                      }
                      try {
                        // Upload images first, collect GCS URLs
                        final gcsUrls = <String>[];
                        for (final img in pickedImages) {
                          final bytes = await img.readAsBytes();
                          final ext = img.name.split('.').last.toLowerCase();
                          final ct = ext == 'png' ? 'image/png' : 'image/jpeg';
                          final urlData = await ApiClient.getWorkLogUploadUrl(img.name, ct, bytes.length);
                          await http.put(Uri.parse(urlData['upload_url'] as String),
                              headers: {'Content-Type': ct}, body: bytes);
                          gcsUrls.add(urlData['gcs_url'] as String);
                        }

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
                            imageUrls: gcsUrls.isNotEmpty ? gcsUrls : null,
                            subjectId: selectedSubjectId,
                            chapterId: selectedChapterId,
                            markChapterCompleted: markChapterCompleted,
                            topicIds: selectedTopicIds.isNotEmpty ? selectedTopicIds.toList() : null,
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
        );
        },
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
          color: hasValue ? context.primaryLight : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: hasValue ? context.primary : AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 13, color: hasValue ? context.primary : AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: hasValue ? context.primary : AppColors.muted,
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
  // Small check-mark shown before the label — used by the topic picker to
  // flag topics already covered in a past work log for this section.
  final bool covered;
  const _SectionChip({required this.label, required this.active, required this.onTap, this.covered = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: active ? context.primary : AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? context.primary : AppColors.border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (covered) ...[
                Icon(Icons.check_circle, size: 12, color: active ? Colors.white : AppColors.green),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      );
}

class _ChapterChip extends StatelessWidget {
  final int number;
  final String name;
  final bool active;
  final Color statusColor;
  // A completed chapter gets an actual check-mark, not just a colored dot —
  // matches _SectionChip's `covered` treatment in the topic picker below,
  // so "done" reads the same way in both pickers.
  final bool completed;
  final VoidCallback onTap;

  const _ChapterChip({
    required this.number,
    required this.name,
    required this.active,
    required this.statusColor,
    required this.onTap,
    this.completed = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.sky : AppColors.bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: active ? AppColors.sky : AppColors.border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (completed)
                Icon(Icons.check_circle,
                    size: 12, color: active ? Colors.white : AppColors.green)
              else
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: active ? Colors.white.withOpacity(0.8) : statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 5),
              Text(
                'Ch $number · $name',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.text2,
                ),
              ),
            ],
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
  final VoidCallback? onChanged;
  const _WorkLogCard({required this.entry, this.onChanged});

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
                  '${fmtDate(entry.date)} · ${fmtTime(entry.createdAt)}',
                  style: const TextStyle(fontSize: 10, color: AppColors.muted),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => shareAsText(_workLogShareText(
                    entry, context.read<AuthProvider>().user?.schoolName ?? 'EduTrack')),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.share_outlined, size: 15, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              entry.description,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.text, height: 1.4),
            ),
            if (entry.chapterName != null) ...[
              const SizedBox(height: 6),
              _ChapterStatusChip(
                name: entry.topicName != null ? '${entry.chapterName!} · ${entry.topicName}' : entry.chapterName!,
                status: entry.chapterStatus,
              ),
            ],
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
            if (entry.imageUrls.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: entry.imageUrls.map((url) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _openImageViewer(context, entry.imageUrls, entry.imageUrls.indexOf(url)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(imageUrl: url, width: 64, height: 64, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                              width: 64, height: 64, color: AppColors.border,
                              child: const Icon(Icons.broken_image_outlined, size: 20, color: AppColors.muted))),
                    ),
                  ),
                )).toList(),
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
            if (entry.logType == 'homework') ...[
              const SizedBox(height: 8),
              if (entry.reviewStatus == 'reviewed')
                GestureDetector(
                  onTap: () async {
                    await showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => _HomeworkReviewSheet(workLogId: entry.id),
                    );
                    onChanged?.call();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 15, color: AppColors.green),
                        SizedBox(width: 6),
                        Text('Reviewed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.green)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _HomeworkReviewSheet(workLogId: entry.id),
                      );
                      onChanged?.call();
                    },
                    icon: const Icon(Icons.fact_check_outlined, size: 16),
                    label: Text(
                      entry.reviewStatus == 'partial' ? 'Continue Review' : 'Review Homework',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.primary,
                      side: BorderSide(color: context.primary.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
}

class _ChapterStatusChip extends StatelessWidget {
  final String name;
  final String? status;
  const _ChapterStatusChip({required this.name, this.status});

  @override
  Widget build(BuildContext context) {
    final (dotColor, bgColor, label) = switch (status) {
      'completed' => (AppColors.green, const Color(0xFFE8F5E9), 'Done'),
      'in_progress' => (AppColors.amber, const Color(0xFFFFF8E1), 'In Progress'),
      _ => (AppColors.border, Colors.transparent, 'Not Started'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: dotColor.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.menu_book_rounded, size: 12, color: AppColors.muted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 5, height: 5, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dotColor)),
        ],
      ),
    );
  }
}

class _HomeworkReviewSheet extends StatefulWidget {
  final String workLogId;
  const _HomeworkReviewSheet({required this.workLogId});

  @override
  State<_HomeworkReviewSheet> createState() => _HomeworkReviewSheetState();
}

class _HomeworkReviewSheetState extends State<_HomeworkReviewSheet> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  bool _markingAll = false;
  final Set<String> _savingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await ApiClient.getWorkLogSubmissions(widget.workLogId);
      if (mounted) setState(() { _students = s; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showSnack(context, 'Could not load students: $e', error: true);
      }
    }
  }

  Future<void> _markOne(String studentId, String? status, {String? remarks}) async {
    setState(() => _savingIds.add(studentId));
    try {
      await ApiClient.reviewWorkLogStudent(
        workLogId: widget.workLogId, studentId: studentId, teacherStatus: status, teacherRemarks: remarks,
      );
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _savingIds.remove(studentId));
    }
  }

  /// Tapping "Checked" again un-marks that student back to unreviewed.
  Future<void> _toggleChecked(String studentId, String? currentStatus) =>
      _markOne(studentId, currentStatus == 'checked' ? null : 'checked');

  Future<void> _markAll({required bool clear}) async {
    setState(() => _markingAll = true);
    try {
      final count = await ApiClient.reviewWorkLogAllStudents(widget.workLogId, clear: clear);
      await _load();
      if (mounted) {
        showSnack(context, clear
            ? 'Reset $count student${count == 1 ? '' : 's'} back to unreviewed'
            : 'Marked $count student${count == 1 ? '' : 's'} checked ✓');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _addRemarks(String studentId, String? existing) async {
    final ctrl = TextEditingController(text: existing);
    final result = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Remarks'),
        content: TextField(controller: ctrl, maxLines: 3, autofocus: true,
            decoration: const InputDecoration(hintText: 'What needs to be redone or fixed?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _markOne(studentId, 'has_remarks', remarks: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allChecked = _students.isNotEmpty && _students.every((s) => s['teacher_status'] == 'checked');
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Expanded(child: Text('Review Homework', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                if (!_loading && _students.isNotEmpty)
                  TextButton.icon(
                    onPressed: _markingAll ? null : () => _markAll(clear: allChecked),
                    icon: _markingAll
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(allChecked ? Icons.replay : Icons.done_all, size: 16),
                    label: Text(allChecked ? 'Unmark all' : 'Mark whole class checked', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
            const Divider(height: 20),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _students.isEmpty
                      ? const Center(child: Text('No students on this work log', style: TextStyle(color: AppColors.muted)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _students.length,
                          separatorBuilder: (_, __) => const Divider(height: 20),
                          itemBuilder: (_, i) {
                            final s = _students[i];
                            final studentId = s['student_id'] as String;
                            final name = s['student_name'] as String? ?? '—';
                            final rollNo = s['roll_no'];
                            final status = s['teacher_status'] as String?;
                            final remarks = s['teacher_remarks'] as String?;
                            final saving = _savingIds.contains(studentId);
                            return Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(rollNo != null ? '$name · Roll $rollNo' : name,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  // Shown whenever a remark exists, independent of teacher_status —
                                  // marking "Checked" afterward must not hide (or, per the backend
                                  // fix, no longer wipe) a remark already left for this student.
                                  if (remarks != null && remarks.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 3),
                                      child: Text('💬 $remarks', style: const TextStyle(fontSize: 11, color: AppColors.amber)),
                                    ),
                                ]),
                              ),
                              if (saving)
                                const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              else ...[
                                IconButton(
                                  tooltip: 'Has remarks',
                                  onPressed: () => _addRemarks(studentId, remarks),
                                  icon: Icon(Icons.edit_note,
                                      color: remarks != null && remarks.isNotEmpty ? AppColors.amber : AppColors.muted),
                                ),
                                IconButton(
                                  tooltip: status == 'checked' ? 'Unmark' : 'Checked',
                                  onPressed: () => _toggleChecked(studentId, status),
                                  icon: Icon(Icons.check_circle,
                                      color: status == 'checked' ? AppColors.green : AppColors.muted),
                                ),
                              ],
                            ]);
                          },
                        ),
            ),
            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }
}

void _openImageViewer(BuildContext context, List<String> urls, int initialIndex) {
  showDialog(
    context: context,
    builder: (_) => Dialog.fullscreen(
      child: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: urls.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: Center(
                child: CachedNetworkImage(imageUrl: urls[i], fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, size: 48, color: AppColors.muted)),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
