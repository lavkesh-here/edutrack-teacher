import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class WorkLogScreen extends StatefulWidget {
  const WorkLogScreen({super.key});

  @override
  State<WorkLogScreen> createState() => _WorkLogScreenState();
}

class _WorkLogScreenState extends State<WorkLogScreen> {
  DateTime _date = DateTime.now();
  List<SectionInfo>? _sections;
  final Set<int> _selectedSectionIds = {}; // empty = all sections
  List<WorkLogEntry> _entries = [];
  bool _loadingSections = true;
  bool _loadingEntries = false;

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
        _loadingSections = false;
      });
      _loadEntries();
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

  @override
  Widget build(BuildContext context) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateLabel =
        '${days[_date.weekday - 1]}, ${_date.day} ${months[_date.month]}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Work Log'),
        actions: [
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
                    dateLabel,
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
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: AppColors.sun,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Log', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        color: AppColors.sun,
        onRefresh: _loadEntries,
        child: CustomScrollView(
          slivers: [
            // Section chips
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _loadingSections
                    ? const LinearProgressIndicator(color: AppColors.sun)
                    : _sections == null || _sections!.isEmpty
                        ? const Text('No sections assigned',
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 13))
                        : SizedBox(
                            height: 34,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _sections!.length + 1, // +1 for "All"
                              separatorBuilder: (_, __) => const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                if (i == 0) {
                                  final allActive = _selectedSectionIds.isEmpty;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() { _selectedSectionIds.clear(); });
                                      _loadEntries();
                                    },
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: allActive ? AppColors.sun : AppColors.bg,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: allActive ? AppColors.sun : AppColors.border,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Text(
                                        'All',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: allActive ? Colors.white : AppColors.muted,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                final sec = _sections![i - 1];
                                final active = _selectedSectionIds.contains(sec.id);
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (active) {
                                        _selectedSectionIds.remove(sec.id);
                                      } else {
                                        _selectedSectionIds.add(sec.id);
                                      }
                                    });
                                    _loadEntries();
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
                          ),
              ),
            ),

            // Entries
            if (_loadingEntries)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                      child:
                          CircularProgressIndicator(color: AppColors.sun)),
                ),
              )
            else if (_entries.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
                  child: Center(
                    child: Column(
                      children: [
                        const Text('📝', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 10),
                        const Text(
                          'No work logs for today',
                          style: TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to add homework or classwork',
                          style: TextStyle(
                              color: AppColors.muted.withOpacity(0.7),
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _WorkLogCard(entry: _entries[i]),
                    childCount: _entries.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: ThemeData(
            colorScheme: const ColorScheme.light(primary: AppColors.sun)),
        child: child!,
      ),
    );
    if (picked != null && picked != _date) {
      setState(() => _date = picked);
      _loadEntries();
    }
  }

  void _showAddSheet() {
    if (_sections == null || _sections!.isEmpty) {
      showSnack(context, 'No sections assigned', error: true);
      return;
    }

    final descCtrl = TextEditingController();
    String logType = 'classwork';
    SectionInfo section = _sections!.first;
    DateTime? dueDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
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
                // Section picker
                DropdownButtonFormField<SectionInfo>(
                  value: section,
                  decoration: const InputDecoration(labelText: 'Section'),
                  items: _sections!
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(s.label),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setSheet(() => section = v);
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
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
                      if (descCtrl.text.trim().isEmpty) return;
                      try {
                        await ApiClient.createWorkLog(
                          classSectionId: section.id,
                          date: DateFormat('yyyy-MM-dd').format(_date),
                          logType: logType,
                          description: descCtrl.text.trim(),
                          dueDate: dueDate != null
                              ? DateFormat('yyyy-MM-dd').format(dueDate!)
                              : null,
                        );
                        if (mounted) Navigator.pop(ctx2);
                        _loadEntries();
                        if (mounted) showSnack(context, 'Work log added ✓');
                      } on ApiError catch (e) {
                        if (mounted)
                          showSnack(context, e.message, error: true);
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
    switch (entry.logType) {
      case 'homework': return AppColors.coral;
      case 'note': return AppColors.amber;
      default: return AppColors.sky;
    }
  }

  Color get _bg {
    switch (entry.logType) {
      case 'homework': return AppColors.coralLight;
      case 'note': return AppColors.amberLight;
      default: return AppColors.skyLight;
    }
  }

  String get _typeLabel {
    switch (entry.logType) {
      case 'homework': return '📚 Homework';
      case 'note': return '📌 Note';
      default: return '📖 Classwork';
    }
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
                if (entry.sectionLabel.isNotEmpty)
                  Text(
                    entry.sectionLabel,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.muted),
                  ),
                const Spacer(),
                Text(
                  fmtDate(entry.date),
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.muted),
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
          ],
        ),
      );
}
