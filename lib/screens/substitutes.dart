import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class SubstitutesScreen extends StatefulWidget {
  const SubstitutesScreen({super.key});

  @override
  State<SubstitutesScreen> createState() => _SubstitutesScreenState();
}

class _SubstitutesScreenState extends State<SubstitutesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _today = [];
  Map<String, dynamic>? _history;
  bool _loadingToday = true;
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadToday();
    _loadHistory();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadToday() async {
    try {
      final data = await ApiClient.getSubstituteToday();
      if (mounted) setState(() { _today = data; _loadingToday = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingToday = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final data = await ApiClient.getSubstituteHistory();
      if (mounted) setState(() { _history = data; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _refresh() async {
    setState(() { _loadingToday = true; _loadingHistory = true; });
    await Future.wait([_loadToday(), _loadHistory()]);
  }

  void _showSelfAssignSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SelfAssignSheet(onDone: _refresh),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Substitutions',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
        actions: [
          TextButton.icon(
            onPressed: _showSelfAssignSheet,
            icon: const Icon(Icons.add, size: 18, color: AppColors.sun),
            label: const Text('Self-Assign',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.sun)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(color: AppColors.border, height: 1),
              TabBar(
                controller: _tabCtrl,
                labelColor: AppColors.sun,
                unselectedLabelColor: AppColors.muted,
                indicatorColor: AppColors.sun,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: const [
                  Tab(text: "Today's Coverage"),
                  Tab(text: 'History'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _TodayTab(today: _today, loading: _loadingToday, onRefresh: _refresh),
          _HistoryTab(history: _history, loading: _loadingHistory, onRefresh: _refresh),
        ],
      ),
    );
  }
}

// ── Today Tab ─────────────────────────────────────────────────────────────────

class _TodayTab extends StatelessWidget {
  final List<Map<String, dynamic>> today;
  final bool loading;
  final VoidCallback onRefresh;

  const _TodayTab(
      {required this.today, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (today.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: const [
            Center(
              child: Column(
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 48, color: AppColors.muted),
                  SizedBox(height: 12),
                  Text('No substitutions today',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  SizedBox(height: 4),
                  Text('Your scheduled substitute classes will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: today.length,
        itemBuilder: (_, i) => _TodayCard(item: today[i]),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _TodayCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final subject = item['subject_name'] as String? ?? 'Unknown';
    final className = item['class_section_label'] as String? ??
        item['class_section_name'] as String? ?? '';
    final period = item['period_number'] as int?;
    final startTime = item['start_time'] as String? ?? '';
    final endTime = item['end_time'] as String? ?? '';
    final originalTeacher = item['original_teacher_name'] as String? ?? '';
    final note = item['notes'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  period != null ? 'P$period' : '--',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.teal),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(className,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (startTime.isNotEmpty || endTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('$startTime${endTime.isNotEmpty ? ' – $endTime' : ''}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.sky)),
                  ],
                  if (originalTeacher.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Covering: $originalTeacher',
                        style:
                            const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                          color: AppColors.amberLight,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(note,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.amber)),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Covering',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── History Tab ───────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  final Map<String, dynamic>? history;
  final bool loading;
  final VoidCallback onRefresh;

  const _HistoryTab(
      {required this.history, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final assignments =
        (history?['assignments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (assignments.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: const [
            Center(
              child: Column(
                children: [
                  Icon(Icons.history_rounded, size: 48, color: AppColors.muted),
                  SizedBox(height: 12),
                  Text('No history yet',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  SizedBox(height: 4),
                  Text('Past substitution assignments will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: assignments.length,
        itemBuilder: (_, i) => _HistoryCard(item: assignments[i]),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = item['date'] as String? ?? '';
    final subject = item['subject_name'] as String? ?? '';
    final className = item['class_section_label'] as String? ??
        item['class_section_name'] as String? ?? '';
    final period = item['period_number'] as int?;
    final originalTeacher = item['original_teacher_name'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  _fmtDate(date),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Container(
                width: 1, height: 36, color: AppColors.border),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$subject  ·  $className',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text)),
                  if (period != null || originalTeacher.isNotEmpty)
                    Text(
                      [
                        if (period != null) 'Period $period',
                        if (originalTeacher.isNotEmpty)
                          'for $originalTeacher',
                      ].join(' '),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${d.day}\n${months[d.month - 1]}';
    } catch (_) {
      return iso.substring(0, 10);
    }
  }
}

// ── Self-Assign Sheet ─────────────────────────────────────────────────────────

class _SelfAssignSheet extends StatefulWidget {
  final VoidCallback onDone;
  const _SelfAssignSheet({required this.onDone});

  @override
  State<_SelfAssignSheet> createState() => _SelfAssignSheetState();
}

class _SelfAssignSheetState extends State<_SelfAssignSheet> {
  final _notesCtrl = TextEditingController();
  String? _selectedSectionId;
  String? _selectedSectionLabel;
  List<SectionInfo> _sections = [];
  bool _loadingSections = true;
  int? _selectedPeriod;
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    try {
      final sections = await ApiClient.getMySections();
      if (mounted) {
        setState(() {
          _sections = sections;
          _loadingSections = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSections = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.sun),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submit() async {
    if (_selectedSectionId == null) {
      showSnack(context, 'Please select a class section', error: true);
      return;
    }
    if (_selectedPeriod == null) {
      showSnack(context, 'Please select a period', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      await ApiClient.selfSubstitute(
        classSectionId: _selectedSectionId!,
        date: dateStr,
        periodNumber: _selectedPeriod!,
        reason: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        showSnack(context, 'Substitution recorded');
        widget.onDone();
      }
    } catch (e) {
      if (mounted) {
        final msg = e is ApiError ? e.message : 'Failed to save';
        showSnack(context, msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Record Substitution',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Log a class you covered as a substitute teacher.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 20),

            // Date picker
            const Text('Date',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Text(_fmt(_selectedDate),
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Class Section
            const Text('Class Section',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
            const SizedBox(height: 6),
            _loadingSections
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.sun))
                : _sections.isEmpty
                    ? const Text('No sections available',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.muted))
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _sections.map((s) {
                          final selected = s.id == _selectedSectionId;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedSectionId = s.id;
                              _selectedSectionLabel = s.label;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.sun
                                    : AppColors.bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.sun
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                s.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.text,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
            const SizedBox(height: 14),

            // Period
            const Text('Period Number',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(9, (i) {
                final p = i + 1;
                final selected = p == _selectedPeriod;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPeriod = p),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.sun : AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppColors.sun : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$p',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color:
                              selected ? Colors.white : AppColors.text,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),

            // Notes
            const Text('Notes (optional)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Any relevant notes…',
                hintStyle:
                    const TextStyle(color: AppColors.muted, fontSize: 13),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.border, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.sun, width: 2),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sun,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save Substitution',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
