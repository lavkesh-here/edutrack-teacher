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

  SyllabusChapter({
    required this.id,
    required this.number,
    required this.name,
    required this.status,
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
    });
    try {
      final raw = await ApiClient.getSyllabus(id);
      if (!mounted) return;
      setState(() {
        _subjects = raw.map((e) => SyllabusSubject.fromJson(e)).toList();
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
                                        onStatusChange: _updateStatus,
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
  final Future<void> Function(SyllabusChapter chapter, String status) onStatusChange;

  const _SubjectCard({required this.subject, required this.onStatusChange});

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
            ...sub.chapters.map((ch) => _ChapterRow(
                  chapter: ch,
                  onTap: () async {
                    final newStatus = _nextStatus(ch.status);
                    await widget.onStatusChange(ch, newStatus);
                    if (mounted) setState(() {});
                  },
                )),
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
  final VoidCallback onTap;

  const _ChapterRow({required this.chapter, required this.onTap});

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

    return InkWell(
      onTap: onTap,
      child: Container(
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: dotColor, size: 20),
            const SizedBox(width: 10),
            Text('${chapter.number}.',
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.muted)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(chapter.name,
                  style: TextStyle(
                      fontSize: 13,
                      color: status == 'completed' ? AppColors.muted : AppColors.text,
                      decoration: status == 'completed' ? TextDecoration.lineThrough : null)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: dotColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(statusLabel,
                  style:
                      TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: dotColor)),
            ),
          ],
        ),
      ),
    );
  }
}
