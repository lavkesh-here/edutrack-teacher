import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminWorkLogsScreen extends StatefulWidget {
  const AdminWorkLogsScreen({super.key});

  @override
  State<AdminWorkLogsScreen> createState() => _AdminWorkLogsScreenState();
}

class _AdminWorkLogsScreenState extends State<AdminWorkLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String _range = '7d';

  static const _ranges = [
    ('7d', 'Last 7 days'),
    ('30d', 'Last 30 days'),
    ('month', 'This month'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  (String, String) _getDateRange() {
    final now = DateTime.now();
    final today = _fmt(now);
    if (_range == '7d') {
      return (_fmt(now.subtract(const Duration(days: 7))), today);
    } else if (_range == '30d') {
      return (_fmt(now.subtract(const Duration(days: 30))), today);
    } else {
      // This month
      final start = DateTime(now.year, now.month, 1);
      return (_fmt(start), today);
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final (from, to) = _getDateRange();
      final data = await ApiClient.adminListWorkLogs(dateFrom: from, dateTo: to);
      data.sort((a, b) {
        final da = a['log_date'] as String? ?? a['date'] as String? ?? '';
        final db = b['log_date'] as String? ?? b['date'] as String? ?? '';
        return db.compareTo(da); // newest first
      });
      setState(() {
        _logs = data;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      setState(() => _loading = false);
    }
  }

  // Group logs by date
  Map<String, List<Map<String, dynamic>>> _grouped() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final log in _logs) {
      final date = log['log_date'] as String? ?? log['date'] as String? ?? '';
      map.putIfAbsent(date, () => []).add(log);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _grouped();
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Work Log Overview'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: DropdownButton<String>(
              value: _range,
              underline: const SizedBox(),
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.sun,
              ),
              items: _ranges.map((r) {
                return DropdownMenuItem(value: r.$1, child: Text(r.$2));
              }).toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _range = v);
                  _load();
                }
              },
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('📋', style: TextStyle(fontSize: 44)),
                      SizedBox(height: 12),
                      Text(
                        'No work logs in this period',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.sun,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: dates.length,
                    itemBuilder: (_, i) {
                      final date = dates[i];
                      final items = grouped[date]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                            child: Text(
                              fmtDate(date),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          ...items.map((log) => _WorkLogItem(log: log)),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

class _WorkLogItem extends StatelessWidget {
  final Map<String, dynamic> log;

  const _WorkLogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final logType = log['log_type'] as String? ?? 'classwork';
    final subject = log['subject_name'] as String? ?? log['subject'] as String? ?? 'No Subject';
    final description = log['description'] as String? ?? '';
    final teacher = log['teacher_name'] as String? ?? '';
    final section = log['section_label'] as String? ?? '';
    final ackCount = log['acknowledgment_count'] as int? ?? 0;

    final isHomework = logType.toLowerCase() == 'homework';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Log type chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isHomework ? AppColors.amberLight : AppColors.tealLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isHomework ? 'HOMEWORK' : 'CLASSWORK',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isHomework ? const Color(0xFF92400E) : AppColors.teal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Ack count
              if (ackCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '✓ $ackCount seen',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: AppColors.text2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                section,
                style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
              if (teacher.isNotEmpty) ...[
                const Text(' · ', style: TextStyle(color: AppColors.muted)),
                Expanded(
                  child: Text(
                    teacher,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
