import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/api.dart';
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
  bool _loadingScores = true;
  bool _loadingAnalysis = false;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    setState(() => _loadingScores = true);
    try {
      final scores = await ApiClient.getTestScores(widget.test.id);
      setState(() { _scores = scores; _loadingScores = false; });
      // Try loading saved analysis
      _loadAnalysis();
    } catch (_) {
      setState(() => _loadingScores = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppColors.violet,
            foregroundColor: Colors.white,
            expandedHeight: 120,
            pinned: true,
            actions: [
              IconButton(
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

          // AI Analysis section
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
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Center(
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
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
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
                      );
                    }).toList(),
                  ),
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

  const _ScoreRow({
    required this.score,
    required this.totalMarks,
    this.percentage,
    required this.isLast,
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
                if (score.rollNo.isNotEmpty)
                  Text(
                    'Roll ${score.rollNo}',
                    style: const TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
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
