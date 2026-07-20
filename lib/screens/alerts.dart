import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _loading = true;
  bool _unackOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.getMyAlerts(unacknowledgedOnly: _unackOnly);
      if (mounted) setState(() { _alerts = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _metricLabel(String metric) {
    switch (metric) {
      case 'attendance_pct': return 'Attendance';
      case 'test_score_pct': return 'Test Scores';
      case 'syllabus_behind_pct': return 'Syllabus Behind';
      default: return metric;
    }
  }

  String _metricIcon(String metric) {
    switch (metric) {
      case 'attendance_pct': return '📅';
      case 'test_score_pct': return '📊';
      case 'syllabus_behind_pct': return '📖';
      default: return '⚠️';
    }
  }

  Color _severityColor(String metric, num value) {
    if (metric == 'attendance_pct' || metric == 'test_score_pct') {
      if (value < 50) return AppColors.rose;
      if (value < 70) return AppColors.amber;
      return AppColors.green;
    }
    // syllabus_behind_pct: higher = worse
    if (value > 50) return AppColors.rose;
    if (value > 25) return AppColors.amber;
    return AppColors.amber;
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
        title: const Text('Predictive Alerts',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
        actions: [
          IconButton(
            icon: Icon(
              _unackOnly
                  ? Icons.filter_alt_rounded
                  : Icons.filter_alt_outlined,
              color: _unackOnly ? AppColors.sun : AppColors.muted,
            ),
            tooltip: 'New only',
            onPressed: () {
              setState(() => _unackOnly = !_unackOnly);
              _load();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.sun,
              child: _alerts.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(32),
                      children: [
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 56, color: AppColors.green),
                              const SizedBox(height: 12),
                              const Text('No alerts',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text)),
                              const SizedBox(height: 4),
                              Text(
                                _unackOnly
                                    ? 'All alerts have been acknowledged.'
                                    : 'No predictive alerts have been triggered for your students.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 13, color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        if (_unackOnly)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color: AppColors.amberLight,
                            child: Row(
                              children: [
                                const Icon(Icons.filter_alt_rounded,
                                    size: 14, color: AppColors.amber),
                                const SizedBox(width: 6),
                                Text(
                                  'Showing ${_alerts.length} unacknowledged alert${_alerts.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.amber),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: _alerts.length,
                            itemBuilder: (_, i) => _AlertCard(
                              alert: _alerts[i],
                              metricLabel: _metricLabel,
                              metricIcon: _metricIcon,
                              severityColor: _severityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Map<String, dynamic> alert;
  final String Function(String) metricLabel;
  final String Function(String) metricIcon;
  final Color Function(String, num) severityColor;

  const _AlertCard({
    required this.alert,
    required this.metricLabel,
    required this.metricIcon,
    required this.severityColor,
  });

  @override
  Widget build(BuildContext context) {
    final studentName = alert['student_name'] as String? ?? 'Unknown Student';
    final classLabel = alert['class_section_label'] as String? ?? '';
    final metric = alert['metric'] as String? ?? '';
    final metricValue = (alert['metric_value'] as num?) ?? 0;
    final ruleName = alert['rule_name'] as String? ?? '';
    final firedAt = alert['fired_at'] as String? ?? '';
    final acknowledged = alert['acknowledged_at'] != null;
    final lookbackDays = alert['lookback_days'] as int?;

    final color = severityColor(metric, metricValue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(metricIcon(metric),
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text)),
                      if (classLabel.isNotEmpty)
                        Text(classLabel,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${metricValue.toStringAsFixed(1)}%',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ruleName.isNotEmpty
                            ? ruleName
                            : metricLabel(metric),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text),
                      ),
                      if (lookbackDays != null)
                        Text('Last $lookbackDays days',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
                if (acknowledged)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.greenLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Acknowledged',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.green)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.coralLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('New',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.coral)),
                  ),
              ],
            ),
            if (firedAt.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Triggered: ${_fmtDateTime(firedAt)}',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.muted)),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDateTime(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} $h:$m';
    } catch (_) {
      return iso;
    }
  }
}
