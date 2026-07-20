import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'test_scores.dart';

class TestsScreen extends StatefulWidget {
  const TestsScreen({super.key});

  @override
  State<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends State<TestsScreen> {
  List<TestSummary>? _tests;
  bool _loading = true;
  String? _error;
  String? _filterWorkType;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getTests();
      // Sort: most recent first
      data.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() { _tests = data; _loading = false; });
    } on ApiError catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      setState(() { _error = 'Failed to load tests'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('My Tests'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.muted),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Work type filter chips
          if (_tests != null && _tests!.any((t) => t.workType != null))
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip('All', _filterWorkType == null, () => setState(() => _filterWorkType = null)),
                    const SizedBox(width: 6),
                    ...const [
                      ('classwork', 'Classwork'), ('homework', 'Homework'), ('quiz', 'Quiz'),
                      ('assignment', 'Assignment'), ('unit_test', 'Unit Test'),
                      ('half_yearly', 'Half Yearly'), ('annual', 'Annual'),
                    ].where((e) => _tests!.any((t) => t.workType == e.$1)).map((e) =>
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _FilterChip(e.$2, _filterWorkType == e.$1, () => setState(() => _filterWorkType = e.$1)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('😕', style: TextStyle(fontSize: 40)),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : _tests == null || _tests!.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('📝', style: TextStyle(fontSize: 40)),
                          SizedBox(height: 12),
                          Text(
                            'No tests yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Create tests in Assessment Studio on the web',
                            style: TextStyle(color: AppColors.muted, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : Builder(builder: (ctx) {
                      final filtered = _filterWorkType == null
                          ? _tests!
                          : _tests!.where((t) => t.workType == _filterWorkType).toList();
                      return RefreshIndicator(
                        color: AppColors.sun,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _TestCard(
                            test: filtered[i],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TestScoresScreen(test: filtered[i]),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
          ),
        ],
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final TestSummary test;
  final VoidCallback onTap;

  const _TestCard({required this.test, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.violet, Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                        child: Text('📝', style: TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                test.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                ),
                              ),
                            ),
                            statusBadgeForTest(test.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (test.subject.isNotEmpty) test.subject,
                            if (test.className.isNotEmpty) test.className,
                          ].join(' · '),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  if (test.workType != null) ...[
                    _FooterChip(_workTypeLabel(test.workType!), AppColors.amberLight, AppColors.amber),
                    const SizedBox(width: 8),
                  ],
                  _FooterChip('${test.totalMarks.toInt()} marks', AppColors.violetLight, AppColors.violet),
                  const SizedBox(width: 8),
                  _FooterChip('${test.questionCount} questions', AppColors.skyLight, AppColors.sky),
                  if (test.scoreCount > 0) ...[
                    const SizedBox(width: 8),
                    _FooterChip('${test.scoreCount} scored', AppColors.greenLight, AppColors.green),
                  ],
                  if (test.durationMinutes != null && test.durationMinutes! > 0) ...[
                    const SizedBox(width: 8),
                    _FooterChip('${test.durationMinutes} min', AppColors.bg, AppColors.muted),
                  ],
                  if (test.variantLevel != null) ...[
                    const SizedBox(width: 8),
                    _FooterChip(
                      test.variantLevel![0].toUpperCase() + test.variantLevel!.substring(1),
                      test.variantLevel == 'remedial'
                          ? const Color(0xFFFFF3CD)
                          : test.variantLevel == 'advanced'
                              ? const Color(0xFFD1ECF1)
                              : AppColors.bg,
                      test.variantLevel == 'remedial'
                          ? const Color(0xFF856404)
                          : test.variantLevel == 'advanced'
                              ? const Color(0xFF0C5460)
                              : AppColors.muted,
                    ),
                  ],
                  const Spacer(),
                  if (test.scheduledDate != null)
                    Text(
                      fmtDate(test.scheduledDate!.toLocal().toString().substring(0, 10)),
                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _workTypeLabel(String wt) {
  const labels = {
    'classwork': 'Classwork', 'homework': 'Homework', 'quiz': 'Quiz',
    'assignment': 'Assignment', 'unit_test': 'Unit Test',
    'half_yearly': 'Half Yearly', 'annual': 'Annual',
  };
  return labels[wt] ?? wt;
}

class _FooterChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _FooterChip(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
      );
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _FilterChip(this.label, this.isActive, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? AppColors.violet : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.violet : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      );
}
