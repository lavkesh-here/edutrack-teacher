import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class TestScoresScreen extends StatefulWidget {
  final TestSummary test;
  const TestScoresScreen({super.key, required this.test});

  @override
  State<TestScoresScreen> createState() => _TestScoresScreenState();
}

class _TestScoresScreenState extends State<TestScoresScreen> {
  TestScoresResponse? _scores;
  AnalysisInsight? _analysis;
  List<TestQuestion> _questions = [];
  bool _loadingScores = true;
  bool _loadingAnalysis = false;

  @override
  void initState() {
    super.initState();
    _loadScores();
    _loadQuestions();
  }

  Future<void> _loadScores() async {
    setState(() => _loadingScores = true);
    try {
      final scores = await ApiClient.getTestScores(widget.test.id);
      setState(() { _scores = scores; _loadingScores = false; });
      _loadAnalysis();
    } catch (_) {
      setState(() => _loadingScores = false);
    }
  }

  Future<void> _loadQuestions() async {
    try {
      final qs = await ApiClient.getTestQuestions(widget.test.id);
      if (mounted) setState(() => _questions = qs);
    } catch (_) {}
  }

  Future<void> _loadAnalysis() async {
    setState(() => _loadingAnalysis = true);
    try {
      final a = await ApiClient.getAnalysis(widget.test.id);
      setState(() { _analysis = a; _loadingAnalysis = false; });
    } catch (_) {
      setState(() => _loadingAnalysis = false);
    }
  }

  Future<void> _openPreview() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.sun)),
    );
    try {
      final html = await ApiClient.getPreviewHtml(widget.test.id);
      if (!mounted) return;
      Navigator.pop(context); // dismiss loader
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => _PreviewScreen(title: widget.test.title, html: html),
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openMarkEntry() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => _MarkEntryScreen(test: widget.test)),
    );
    if (saved == true) _loadScores();
  }

  @override
  Widget build(BuildContext context) {
    final isDraft = widget.test.status == 'draft';
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: isDraft
          ? FloatingActionButton.extended(
              key: const Key('enter_marks_fab'),
              onPressed: _openMarkEntry,
              backgroundColor: AppColors.violet,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              label: const Text('Enter Marks',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.violet,
            foregroundColor: Colors.white,
            expandedHeight: 120,
            pinned: true,
            actions: [
              IconButton(
                key: const Key('preview_test_button'),
                icon: const Icon(Icons.preview_outlined, color: Colors.white),
                tooltip: 'Preview Test Paper',
                onPressed: _openPreview,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.test.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.violet, Color(0xFF7C3AED)],
                  ),
                ),
              ),
            ),
          ),

          // Test info
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  _InfoChip('${widget.test.subject} · ${widget.test.className}',
                      AppColors.violetLight, AppColors.violet),
                  const SizedBox(width: 8),
                  _InfoChip('${widget.test.totalMarks.toInt()} marks',
                      AppColors.skyLight, AppColors.sky),
                  const SizedBox(width: 8),
                  statusBadgeForTest(widget.test.status),
                ],
              ),
            ),
          ),

          // Stats
          if (!_loadingScores && _scores != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _ScoreTile(
                        label: 'Class Avg',
                        value: _scores!.classAverage != null
                            ? '${_scores!.classAverage!.toStringAsFixed(1)}%'
                            : '—',
                        color: AppColors.sun,
                        lightColor: AppColors.sunLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ScoreTile(
                        label: 'Students',
                        value: '${_scores!.scores.length}',
                        color: AppColors.teal,
                        lightColor: AppColors.tealLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ScoreTile(
                        label: 'Highest',
                        value: _scores!.highestMark != null
                            ? _scores!.highestMark!.toStringAsFixed(1)
                            : '—',
                        color: AppColors.violet,
                        lightColor: AppColors.violetLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Questions section
          if (_questions.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader(title: 'Questions')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: _questions.asMap().entries.map((e) {
                      final q = e.value;
                      final isLast = e.key == _questions.length - 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : const Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.violetLight,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${q.order}',
                                    style: const TextStyle(
                                        fontSize: 12, fontWeight: FontWeight.w900,
                                        color: AppColors.violet)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                q.questionText.isNotEmpty ? q.questionText : '(No question text)',
                                style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${q.marks.toInt()}m',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: AppColors.muted)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],

          // AI Analysis section — hidden if SA has disabled ai_analysis for this school/teacher
          if (context.read<AuthProvider>().features.aiAnalysis)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _AnalysisCard(
                  analysis: _analysis,
                  loading: _loadingAnalysis,
                  onLoad: _loadAnalysis,
                ),
              ),
            ),

          // Scores list
          const SliverToBoxAdapter(
            child: SectionHeader(title: 'Student Scores'),
          ),

          if (_loadingScores)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: AppColors.sun)),
              ),
            )
          else if (_scores == null || _scores!.scores.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, isDraft ? 88 : 20),
                child: const Center(
                  child: Text(
                    'No scores entered yet',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, isDraft ? 88 : 24),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Builder(builder: (_) {
                    // Peer comparison: rank students by score (absents unranked)
                    final ranked = _scores!.scores
                        .where((s) => !s.isAbsent && s.marks != null)
                        .toList()
                      ..sort((a, b) => b.marks!.compareTo(a.marks!));
                    final rankMap = <String, int>{};
                    for (int i = 0; i < ranked.length; i++) {
                      rankMap[ranked[i].name] = i + 1;
                    }
                    final totalRanked = ranked.length;
                    return Column(
                      children: _scores!.scores.asMap().entries.map((e) {
                        final s = e.value;
                        final isLast = e.key == _scores!.scores.length - 1;
                        final pct = s.marks != null && widget.test.totalMarks > 0
                            ? (s.marks! / widget.test.totalMarks * 100)
                            : null;
                        return _ScoreRow(
                          score: s,
                          totalMarks: widget.test.totalMarks,
                          percentage: pct,
                          isLast: isLast,
                          rank: rankMap[s.name],
                          totalRanked: totalRanked,
                        );
                      }).toList(),
                    );
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _InfoChip(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );
}

class _ScoreTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color lightColor;
  const _ScoreTile(
      {required this.label, required this.value, required this.color, required this.lightColor});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted)),
          ],
        ),
      );
}

class _AnalysisCard extends StatelessWidget {
  final AnalysisInsight? analysis;
  final bool loading;
  final VoidCallback onLoad;
  const _AnalysisCard({this.analysis, required this.loading, required this.onLoad});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A0A00), Color(0xFF3D1A08)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(14),
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          : analysis == null
              ? Column(
                  children: [
                    const Row(
                      children: [
                        Text('🧠', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          'AI Analysis',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No analysis available. Generate one in Assessment Studio on the web.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Text('🧠', style: TextStyle(fontSize: 22)),
                        SizedBox(width: 8),
                        Text(
                          'AI Analysis',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      analysis!.summary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    if (analysis!.concernAreas.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        '⚠ Concern Areas',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFFBBF24)),
                      ),
                      const SizedBox(height: 4),
                      ...analysis!.concernAreas.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '• $a',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70, height: 1.4),
                          ),
                        ),
                      ),
                    ],
                    if (analysis!.recommendedAction.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppColors.teal.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                analysis!.recommendedAction,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final StudentScore score;
  final double totalMarks;
  final double? percentage;
  final bool isLast;
  final int? rank;
  final int? totalRanked;

  const _ScoreRow({
    required this.score,
    required this.totalMarks,
    this.percentage,
    required this.isLast,
    this.rank,
    this.totalRanked,
  });

  Color get _pctColor {
    final p = percentage ?? 0;
    if (p >= 75) return AppColors.green;
    if (p >= 50) return AppColors.amber;
    return AppColors.coral;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: score.isAbsent ? AppColors.coralLight : AppColors.sunLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                score.isAbsent
                    ? 'A'
                    : (score.name.isNotEmpty ? score.name[0].toUpperCase() : '?'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: score.isAbsent ? AppColors.coral : AppColors.sun,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                if (score.rollNo.isNotEmpty || rank != null)
                  Row(children: [
                    if (score.rollNo.isNotEmpty)
                      Text('Roll ${score.rollNo}', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                    if (score.rollNo.isNotEmpty && rank != null)
                      const Text(' · ', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                    if (rank != null && totalRanked != null)
                      Text(
                        '#$rank / $totalRanked',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: rank == 1 ? AppColors.amber : AppColors.muted,
                        ),
                      ),
                  ]),
              ],
            ),
          ),
          if (score.isAbsent)
            const StatusBadge(
                label: 'Absent',
                bg: AppColors.coralLight,
                fg: Color(0xFFBE123C))
          else if (score.marks != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${score.marks!.toStringAsFixed(0)} / ${totalMarks.toInt()}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                if (percentage != null)
                  Text(
                    '${percentage!.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _pctColor,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PreviewScreen extends StatefulWidget {
  final String title;
  final String html;
  const _PreviewScreen({required this.title, required this.html});

  @override
  State<_PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<_PreviewScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(widget.html);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
        ),
        body: WebViewWidget(controller: _controller),
      );
}

// ── Mark Entry Screen ─────────────────────────────────────────────────────────

class _MarkEntryScreen extends StatefulWidget {
  final TestSummary test;
  const _MarkEntryScreen({required this.test});

  @override
  State<_MarkEntryScreen> createState() => _MarkEntryScreenState();
}

class _MarkEntryScreenState extends State<_MarkEntryScreen> {
  List<Map<String, dynamic>> _roster = [];
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, bool> _absent = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final roster = await ApiClient.getTestRoster(widget.test.id);
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _loading = false;
        for (int i = 0; i < roster.length; i++) {
          _controllers[i] = TextEditingController();
          _absent[i] = false;
        }
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _save() async {
    // Validate: each non-absent student needs a score
    for (int i = 0; i < _roster.length; i++) {
      if (!(_absent[i] ?? false)) {
        final text = _controllers[i]?.text.trim() ?? '';
        if (text.isEmpty) {
          showSnack(context, 'Enter score or mark absent for every student', error: true);
          return;
        }
        final v = double.tryParse(text);
        if (v == null || v < 0 || v > widget.test.totalMarks) {
          showSnack(context,
              'Score must be 0–${widget.test.totalMarks.toInt()}', error: true);
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final scores = <Map<String, dynamic>>[];
      for (int i = 0; i < _roster.length; i++) {
        final s = _roster[i];
        final isAbsent = _absent[i] ?? false;
        scores.add({
          'student_id': s['student_id'],
          'student_name': s['student_name'] as String,
          'roll_no': s['roll_no'] as String?,
          'score': isAbsent ? 0.0 : double.parse(_controllers[i]!.text.trim()),
          'is_absent': isAbsent,
        });
      }
      await ApiClient.submitTestScores(widget.test.id, scores);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to save: $e', error: true);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.test.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.violet,
        foregroundColor: Colors.white,
        actions: [
          if (!_loading && _roster.isNotEmpty)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.violet))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: AppColors.muted)))
              : _roster.isEmpty
                  ? const Center(child: Text('No students found', style: TextStyle(color: AppColors.muted)))
                  : Column(
                      children: [
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(20)),
                              child: Text('Max ${widget.test.totalMarks.toInt()} marks',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.violet)),
                            ),
                            const SizedBox(width: 8),
                            Text('${_roster.length} students',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                          ]),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _roster.length,
                            itemBuilder: (_, i) {
                              final s = _roster[i];
                              final isAbsent = _absent[i] ?? false;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: isAbsent ? AppColors.coralLight : AppColors.sunLight,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          (s['student_name'] as String? ?? '?')[0].toUpperCase(),
                                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16,
                                              color: isAbsent ? AppColors.coral : AppColors.sun),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(s['student_name'] as String? ?? '',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                        if ((s['roll_no'] as String?)?.isNotEmpty == true)
                                          Text('Roll ${s['roll_no']}',
                                              style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                      ]),
                                    ),
                                    const SizedBox(width: 8),
                                    if (isAbsent)
                                      GestureDetector(
                                        onTap: () => setState(() => _absent[i] = false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(color: AppColors.coralLight, borderRadius: BorderRadius.circular(8)),
                                          child: const Text('ABSENT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.coral)),
                                        ),
                                      )
                                    else ...[
                                      SizedBox(
                                        width: 64,
                                        child: TextField(
                                          controller: _controllers[i],
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                          decoration: InputDecoration(
                                            hintText: '—',
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          _controllers[i]?.clear();
                                          setState(() => _absent[i] = true);
                                        },
                                        child: const Icon(Icons.person_off_outlined, color: AppColors.muted, size: 20),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
