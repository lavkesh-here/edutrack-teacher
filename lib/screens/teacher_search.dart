import 'dart:async';
import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'student_profile_detail.dart';
import 'test_scores.dart';

class TeacherSearchScreen extends StatefulWidget {
  const TeacherSearchScreen({super.key});

  @override
  State<TeacherSearchScreen> createState() => _TeacherSearchScreenState();
}

class _TeacherSearchScreenState extends State<TeacherSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  TeacherSearchResult? _results;
  bool _loading = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    final q = _controller.text.trim();
    if (q == _lastQuery) return;
    _lastQuery = q;
    _debounce?.cancel();
    if (q.length < 2) {
      setState(() { _results = null; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q, {int limit = 5}) async {
    try {
      final r = await ApiClient.teacherSearch(q, limit: limit);
      if (mounted && _controller.text.trim() == q) {
        setState(() { _results = r; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  void _openStudent(Map<String, dynamic> s) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => StudentProfileDetail(
        studentId: s['id'] as String,
        studentName: s['name'] as String,
        sectionLabel: s['class_label'] as String? ?? '',
      ),
    ));
  }

  void _openTest(Map<String, dynamic> t) {
    final test = TestSummary(
      id: t['id'] as String,
      title: t['title'] as String,
      subject: t['subject'] as String? ?? '',
      className: t['class_name'] as String? ?? '',
      status: t['status'] as String? ?? '',
      totalMarks: (t['total_marks'] as num?)?.toDouble() ?? 0,
      scheduledDate: t['scheduled_date'] != null
          ? DateTime.tryParse(t['scheduled_date'] as String)
          : null,
      createdAt: DateTime.now(),
      questionCount: 0,
      scoreCount: 0,
    );
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => TestScoresScreen(test: test),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(fontSize: 15, color: AppColors.text),
          decoration: const InputDecoration(
            hintText: 'Search students, tests, announcements…',
            hintStyle: TextStyle(fontSize: 14, color: AppColors.muted),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.muted, size: 20),
              onPressed: () {
                _controller.clear();
                setState(() { _results = null; });
              },
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final q = _controller.text.trim();

    if (q.length < 2) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍', style: TextStyle(fontSize: 40)),
            SizedBox(height: 12),
            Text('Search students, tests, announcements',
                style: TextStyle(fontSize: 13, color: AppColors.muted)),
            SizedBox(height: 4),
            Text('Type at least 2 characters to search',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      );
    }

    if (_loading && _results == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.violet));
    }

    if (_results == null || _results!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😶', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('No results for "$q"', style: const TextStyle(fontSize: 14, color: AppColors.text)),
            const SizedBox(height: 4),
            const Text('Try different keywords', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_results!.students.isNotEmpty) ...[
          _SectionHeader(
            title: 'Students',
            count: _results!.students.length,
            onViewAll: _results!.students.length >= 5
                ? () => _openFullResults(q, category: 'students')
                : null,
          ),
          ..._results!.students.map((s) => _StudentTile(student: s, onTap: () => _openStudent(s))),
        ],
        if (_results!.tests.isNotEmpty) ...[
          _SectionHeader(
            title: 'Tests',
            count: _results!.tests.length,
            onViewAll: _results!.tests.length >= 5
                ? () => _openFullResults(q, category: 'tests')
                : null,
          ),
          ..._results!.tests.map((t) => _TestTile(test: t, onTap: () => _openTest(t))),
        ],
        if (_results!.announcements.isNotEmpty) ...[
          _SectionHeader(
            title: 'Announcements',
            count: _results!.announcements.length,
            onViewAll: _results!.announcements.length >= 5
                ? () => _openFullResults(q, category: 'announcements')
                : null,
          ),
          ..._results!.announcements.map((a) => _AnnouncementTile(ann: a)),
        ],
      ],
    );
  }

  void _openFullResults(String q, {required String category}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullResultsScreen(
        query: q,
        category: category,
        onOpenStudent: _openStudent,
        onOpenTest: _openTest,
      ),
    ));
  }
}

// ── Full results page ─────────────────────────────────────────────────────────

class _FullResultsScreen extends StatefulWidget {
  final String query;
  final String category;
  final void Function(Map<String, dynamic>) onOpenStudent;
  final void Function(Map<String, dynamic>) onOpenTest;

  const _FullResultsScreen({
    required this.query,
    required this.category,
    required this.onOpenStudent,
    required this.onOpenTest,
  });

  @override
  State<_FullResultsScreen> createState() => _FullResultsScreenState();
}

class _FullResultsScreenState extends State<_FullResultsScreen> {
  TeacherSearchResult? _results;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiClient.teacherSearch(widget.query, limit: 50);
      if (mounted) setState(() { _results = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (widget.category) {
      'students' => 'Students',
      'tests' => 'Tests',
      'announcements' => 'Announcements',
      _ => 'Results',
    };
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$title — "${widget.query}"',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
          ],
        ),
        iconTheme: const IconThemeData(color: AppColors.text),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.violet))
          : _buildList(),
    );
  }

  Widget _buildList() {
    if (_results == null) return const SizedBox();
    final items = switch (widget.category) {
      'students' => _results!.students,
      'tests' => _results!.tests,
      'announcements' => _results!.announcements,
      _ => <Map<String, dynamic>>[],
    };
    if (items.isEmpty) {
      return const Center(child: Text('No results found', style: TextStyle(color: AppColors.muted)));
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return switch (widget.category) {
          'students' => _StudentTile(student: item, onTap: () => widget.onOpenStudent(item)),
          'tests' => _TestTile(test: item, onTap: () => widget.onOpenTest(item)),
          _ => _AnnouncementTile(ann: item),
        };
      },
    );
  }
}

// ── Shared tiles ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final VoidCallback? onViewAll;
  const _SectionHeader({required this.title, required this.count, this.onViewAll});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
    child: Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
              color: AppColors.violetLight, borderRadius: BorderRadius.circular(10)),
          child: Text('$count', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.violet)),
        ),
        const Spacer(),
        if (onViewAll != null)
          TextButton(
            onPressed: onViewAll,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero),
            child: const Text('View all', style: TextStyle(fontSize: 12, color: AppColors.violet)),
          ),
      ],
    ),
  );
}

class _StudentTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onTap;
  const _StudentTile({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: CircleAvatar(
      radius: 20,
      backgroundColor: AppColors.violetLight,
      child: Text(
        (student['name'] as String? ?? '?')[0].toUpperCase(),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.violet),
      ),
    ),
    title: Text(student['name'] as String? ?? '',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
    subtitle: Text(
      [
        if ((student['class_label'] as String?)?.isNotEmpty == true) student['class_label'],
        if ((student['admission_number'] as String?)?.isNotEmpty == true) '#${student['admission_number']}',
      ].join(' · '),
      style: const TextStyle(fontSize: 11, color: AppColors.muted),
    ),
    trailing: const Icon(Icons.chevron_right, color: AppColors.border),
  );
}

class _TestTile extends StatelessWidget {
  final Map<String, dynamic> test;
  final VoidCallback onTap;
  const _TestTile({required this.test, required this.onTap});

  Color _statusColor(String status) => switch (status) {
    'exported' => AppColors.teal,
    'draft' => AppColors.amber,
    _ => AppColors.muted,
  };

  @override
  Widget build(BuildContext context) {
    final status = test['status'] as String? ?? '';
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.skyLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.assignment_outlined, color: AppColors.sky, size: 20),
      ),
      title: Text(test['title'] as String? ?? '',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
      subtitle: Text(
        [
          if ((test['subject'] as String?)?.isNotEmpty == true) test['subject'],
          if ((test['class_name'] as String?)?.isNotEmpty == true) test['class_name'],
        ].join(' · '),
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _statusColor(status).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(status,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _statusColor(status))),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  final Map<String, dynamic> ann;
  const _AnnouncementTile({required this.ann});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: AppColors.sunLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.campaign_outlined, color: AppColors.sun, size: 20),
    ),
    title: Text(ann['title'] as String? ?? '',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(ann['body'] as String? ?? '',
        style: const TextStyle(fontSize: 11, color: AppColors.muted),
        maxLines: 2, overflow: TextOverflow.ellipsis),
  );
}
