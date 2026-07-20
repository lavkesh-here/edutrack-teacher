import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class SyllabusChapter {
  final String id;
  final int number;
  final String name;
  String status;
  String? targetDate;
  String? milestoneNote;
  String? onTrack;

  SyllabusChapter({
    required this.id,
    required this.number,
    required this.name,
    required this.status,
    this.targetDate,
    this.milestoneNote,
    this.onTrack,
  });

  factory SyllabusChapter.fromJson(Map<String, dynamic> j) => SyllabusChapter(
        id: j['id'] as String,
        number: j['number'] as int,
        name: j['name'] as String,
        status: (j['status'] as String?) ?? 'not_started',
      );
}

class SyllabusSubject {
  final String id;
  final String name;
  final List<SyllabusChapter> chapters;

  SyllabusSubject({required this.id, required this.name, required this.chapters});

  factory SyllabusSubject.fromJson(Map<String, dynamic> j) => SyllabusSubject(
        id: j['subject_id'] as String,
        name: j['subject_name'] as String,
        chapters: (j['chapters'] as List)
            .map((c) => SyllabusChapter.fromJson(c as Map<String, dynamic>))
            .toList(),
      );

  int get total => chapters.length;
  int get completed => chapters.where((c) => c.status == 'completed').length;
  int get inProgress => chapters.where((c) => c.status == 'in_progress').length;
  double get pct => total == 0 ? 0.0 : completed / total;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class SyllabusScreen extends StatefulWidget {
  const SyllabusScreen({super.key});

  @override
  State<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends State<SyllabusScreen> {
  List<SectionInfo> _sections = [];
  String? _selectedSectionId;
  String? _selectedSectionLabel;
  List<SyllabusSubject> _subjects = [];
  bool _loadingSections = true;
  bool _loadingSubjects = false;
  String? _error;
  // plan data keyed by chapter_id
  Map<String, Map<String, dynamic>> _planByChapter = {};

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    try {
      final sections = await ApiClient.getMySections();
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _loadingSections = false;
      });
      if (sections.isNotEmpty) {
        _selectSection(sections.first.id, sections.first.label);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSections = false;
        _error = 'Failed to load sections';
      });
    }
  }

  Future<void> _selectSection(String id, String label) async {
    setState(() {
      _selectedSectionId = id;
      _selectedSectionLabel = label;
      _loadingSubjects = true;
      _error = null;
      _planByChapter = {};
    });
    try {
      final rawSubjects = await ApiClient.getSyllabus(id);
      Map<String, dynamic> planResp;
      try {
        planResp = await ApiClient.getSyllabusPlan(id);
      } catch (_) {
        planResp = {};
      }
      if (!mounted) return;
      final planChapters = (planResp['chapters'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      final planMap = <String, Map<String, dynamic>>{};
      for (final ch in planChapters) {
        final cid = ch['chapter_id'] as String?;
        if (cid != null) planMap[cid] = ch;
      }
      setState(() {
        _subjects = rawSubjects.map((e) => SyllabusSubject.fromJson(e)).toList();
        _planByChapter = planMap;
        _loadingSubjects = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSubjects = false;
        _error = 'Failed to load syllabus';
      });
    }
  }

  Future<void> _setChapterTarget(SyllabusChapter chapter, String subjectId) async {
    if (_selectedSectionId == null) return;
    DateTime initial = DateTime.now().add(const Duration(days: 7));
    if (chapter.targetDate != null) {
      try { initial = DateTime.parse(chapter.targetDate!); } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.sun)),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    final dateStr =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    try {
      await ApiClient.upsertSyllabusPlan(
        classSectionId: _selectedSectionId!,
        chapterId: chapter.id,
        subjectId: subjectId,
        targetDate: dateStr,
      );
      if (!mounted) return;
      setState(() {
        chapter.targetDate = dateStr;
        _planByChapter[chapter.id] = {
          ..._planByChapter[chapter.id] ?? {},
          'target_date': dateStr,
        };
      });
      showSnack(context, 'Target date set');
    } catch (e) {
      if (mounted) {
        final msg = e is ApiError ? e.message : 'Failed to set target date';
        showSnack(context, msg, error: true);
      }
    }
  }

  Future<void> _updateStatus(SyllabusChapter chapter, String newStatus) async {
    if (_selectedSectionId == null) return;
    final oldStatus = chapter.status;
    setState(() => chapter.status = newStatus);
    try {
      await ApiClient.updateChapterStatus(
        classSectionId: _selectedSectionId!,
        chapterId: chapter.id,
        status: newStatus,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => chapter.status = oldStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update. Please try again.')),
      );
    }
  }

  String _nextStatus(String current) {
    switch (current) {
      case 'not_started': return 'in_progress';
      case 'in_progress': return 'completed';
      default: return 'not_started';
    }
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
        title: const Text('Syllabus Progress',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _loadingSections
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? const Center(child: Text('No class sections assigned', style: TextStyle(color: AppColors.muted)))
              : Column(
                  children: [
                    _SectionPicker(
                      sections: _sections,
                      selectedId: _selectedSectionId,
                      onSelect: (id, label) => _selectSection(id, label),
                    ),
                    Expanded(
                      child: _loadingSubjects
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.muted)))
                              : _subjects.isEmpty
                                  ? const Center(
                                      child: Text('No subjects found for this section',
                                          style: TextStyle(color: AppColors.muted)))
                                  : ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                      itemCount: _subjects.length,
                                      itemBuilder: (ctx, i) => _SubjectCard(
                                        subject: _subjects[i],
                                        planByChapter: _planByChapter,
                                        onStatusChange: _updateStatus,
                                        onSetTarget: (ch) => _setChapterTarget(ch, _subjects[i].id),
                                      ),
                                    ),
                    ),
                  ],
                ),
    );
  }
}

// ── Section picker ─────────────────────────────────────────────────────────────

class _SectionPicker extends StatelessWidget {
  final List<SectionInfo> sections;
  final String? selectedId;
  final void Function(String id, String label) onSelect;

  const _SectionPicker({required this.sections, required this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: sections.map((s) {
            final id = s.id;
            final label = s.label;
            final selected = id == selectedId;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onSelect(id, label),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.sun : AppColors.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? AppColors.sun : AppColors.border),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.text,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Subject card ───────────────────────────────────────────────────────────────

class _SubjectCard extends StatefulWidget {
  final SyllabusSubject subject;
  final Map<String, Map<String, dynamic>> planByChapter;
  final Future<void> Function(SyllabusChapter chapter, String status) onStatusChange;
  final Future<void> Function(SyllabusChapter chapter) onSetTarget;

  const _SubjectCard({
    required this.subject,
    required this.planByChapter,
    required this.onStatusChange,
    required this.onSetTarget,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final sub = widget.subject;
    final pct = sub.pct;
    final pctInt = (pct * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(sub.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                      ),
                      Text('$pctInt%',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: pct >= 0.8
                                  ? AppColors.green
                                  : pct >= 0.5
                                      ? AppColors.amber
                                      : AppColors.rose)),
                      const SizedBox(width: 6),
                      Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: AppColors.muted, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      color: pct >= 0.8
                          ? AppColors.green
                          : pct >= 0.5
                              ? AppColors.amber
                              : AppColors.rose,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Stats row
                  Row(
                    children: [
                      _StatChip(label: '${sub.completed} done', color: AppColors.green),
                      const SizedBox(width: 6),
                      if (sub.inProgress > 0) ...[
                        _StatChip(label: '${sub.inProgress} in progress', color: AppColors.amber),
                        const SizedBox(width: 6),
                      ],
                      _StatChip(
                          label: '${sub.total - sub.completed - sub.inProgress} remaining',
                          color: AppColors.muted),
                      const Spacer(),
                      Text('${sub.total} chapters',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Chapter list (expanded)
          if (_expanded) ...[
            Divider(height: 1, color: AppColors.border),
            ...sub.chapters.map((ch) {
              final plan = widget.planByChapter[ch.id];
              return _ChapterRow(
                chapter: ch,
                targetDate: plan?['target_date'] as String?,
                onTrack: plan?['on_track'] as String?,
                onTap: () async {
                  final newStatus = _nextStatus(ch.status);
                  await widget.onStatusChange(ch, newStatus);
                  if (mounted) setState(() {});
                },
                onSetTarget: () async {
                  await widget.onSetTarget(ch);
                  if (mounted) setState(() {});
                },
              );
            }),
          ],
        ],
      ),
      ),
    );
  }

  String _nextStatus(String current) {
    switch (current) {
      case 'not_started': return 'in_progress';
      case 'in_progress': return 'completed';
      default: return 'not_started';
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color));
  }
}

// ── Chapter row ────────────────────────────────────────────────────────────────

class _ChapterRow extends StatelessWidget {
  final SyllabusChapter chapter;
  final String? targetDate;
  final String? onTrack;
  final VoidCallback onTap;
  final VoidCallback onSetTarget;

  const _ChapterRow({
    required this.chapter,
    required this.onTap,
    required this.onSetTarget,
    this.targetDate,
    this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final status = chapter.status;
    Color dotColor;
    Color bgColor;
    String statusLabel;
    IconData? icon;

    switch (status) {
      case 'completed':
        dotColor = AppColors.green;
        bgColor = const Color(0xFFE8F5E9);
        statusLabel = 'Done';
        icon = Icons.check_circle_rounded;
        break;
      case 'in_progress':
        dotColor = AppColors.amber;
        bgColor = const Color(0xFFFFF8E1);
        statusLabel = 'In Progress';
        icon = Icons.timelapse_rounded;
        break;
      default:
        dotColor = AppColors.border;
        bgColor = Colors.transparent;
        statusLabel = 'Not Started';
        icon = Icons.radio_button_unchecked;
    }

    final (onTrackColor, onTrackLabel) = switch (onTrack) {
      'behind'   => (AppColors.rose, 'Behind'),
      'due_soon' => (AppColors.amber, 'Due Soon'),
      'on_track' => (AppColors.green, 'On Track'),
      'completed'=> (AppColors.green, 'Done'),
      _ => (null, null),
    };

    return InkWell(
      onTap: onTap,
      onLongPress: onSetTarget,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: dotColor, size: 20),
                const SizedBox(width: 10),
                Text('${chapter.number}.',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(chapter.name,
                      style: TextStyle(
                          fontSize: 13,
                          color: status == 'completed' ? AppColors.muted : AppColors.text,
                          decoration:
                              status == 'completed' ? TextDecoration.lineThrough : null)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: dotColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: dotColor)),
                ),
              ],
            ),
            if (targetDate != null || onTrackColor != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Row(
                  children: [
                    if (targetDate != null)
                      GestureDetector(
                        onTap: onSetTarget,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 11, color: AppColors.muted),
                            const SizedBox(width: 3),
                            Text(_fmtDate(targetDate!),
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.muted)),
                          ],
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: onSetTarget,
                        child: const Text('+ Set target date',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.sun,
                                fontWeight: FontWeight.w600)),
                      ),
                    if (onTrackColor != null && onTrackLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: onTrackColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(onTrackLabel,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: onTrackColor)),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: GestureDetector(
                  onTap: onSetTarget,
                  child: const Text('+ Set target date',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.sun,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) {
      return iso;
    }
  }
}
