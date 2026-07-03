import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'whatsapp_report.dart';

class StudentProfileDetail extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String sectionLabel;

  const StudentProfileDetail({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.sectionLabel,
  });

  @override
  State<StudentProfileDetail> createState() => _StudentProfileDetailState();
}

class _StudentProfileDetailState extends State<StudentProfileDetail>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final p = await ApiClient.getStudentProfile(
        widget.studentId,
        month: _selectedMonth,
        year: _selectedYear,
      );
      setState(() { _profile = p; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  Future<void> _onAvatarTap() async {
    final photoUploadedBy = _profile?['photo_uploaded_by'] as String?;
    if (photoUploadedBy == 'teacher') {
      showSnack(context, 'Photo already uploaded — only a parent can change it', error: true);
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'Image must be under 5MB', error: true);
      return;
    }
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => _uploading = true);
    try {
      final resp = await ApiClient.getStudentPhotoUploadUrl(
          widget.studentId, file.name, contentType, bytes.lengthInBytes);
      final uploadUrl = resp['upload_url'] as String;
      final photoUrl = resp['photo_url'] as String;
      final putResp = await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': contentType}, body: bytes);
      if (putResp.statusCode < 200 || putResp.statusCode >= 300) {
        throw Exception('Storage upload failed (${putResp.statusCode})');
      }
      await ApiClient.saveStudentPhoto(widget.studentId, photoUrl);
      setState(() {
        _profile = Map<String, dynamic>.from(_profile ?? {})
          ..['photo_url'] = photoUrl
          ..['photo_uploaded_by'] = 'teacher';
      });
      if (mounted) showSnack(context, 'Photo uploaded ✓');
    } on ApiError catch (e) {
      if (e.statusCode == 409) {
        if (mounted) showSnack(context, 'Photo already uploaded — only a parent can change it', error: true);
      } else {
        if (mounted) showSnack(context, 'Upload failed', error: true);
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Upload failed', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
          : _error != null
              ? _ErrorView(onRetry: _load)
              : _body(),
    );
  }

  Widget _body() {
    final name = _profile!['name'] as String? ?? widget.studentName;
    final admNo = _profile!['admission_number'] as String? ?? '';
    final classLabel = _profile!['class_label'] as String? ?? widget.sectionLabel;
    final photoUrl = _profile!['photo_url'] as String?;
    final gender = _profile!['gender'] as String?;
    final photoUploadedBy = _profile!['photo_uploaded_by'] as String?;
    final canUpload = photoUploadedBy != 'teacher';

    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        // ── Gradient hero (collapsed: orange bar + name) ──────────────────
        SliverAppBar(
          expandedHeight: 210,
          pinned: true,
          backgroundColor: AppColors.sun,
          foregroundColor: Colors.white,
          title: Text(
            '$name · $classLabel',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          actions: [
            IconButton(
              tooltip: 'WhatsApp Report',
              icon: const Text('💬', style: TextStyle(fontSize: 20)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WhatsAppReportScreen(
                    studentId: widget.studentId,
                    studentName: widget.studentName,
                  ),
                ),
              ),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.sun, Color(0xFFEA580C), AppColors.coral],
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    // Tappable avatar with camera badge
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        _HeroAvatar(
                          initials: _initials(name),
                          photoUrl: photoUrl,
                          gender: gender,
                          size: 72,
                          uploading: _uploading,
                        ),
                        if (canUpload)
                          GestureDetector(
                            onTap: _uploading ? null : _onAvatarTap,
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                              ),
                              child: const Icon(Icons.camera_alt, size: 14, color: AppColors.sun),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(
                      '$classLabel · $admNo',
                      style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Sticky white tab bar (separate from gradient) ─────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _StickyTabBar(_tabs),
        ),
      ],
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProfileTab(profile: _profile!),
          _AttendanceTab(
            profile: _profile!,
            month: _selectedMonth,
            year: _selectedYear,
            onMonthChanged: (m, y) {
              setState(() { _selectedMonth = m; _selectedYear = y; });
              _load();
            },
          ),
          _TestsTab(tests: (_profile!['tests'] as List?)?.cast<Map<String, dynamic>>() ?? []),
          _StudentWorkLogsTab(studentId: widget.studentId),
          _ReportTab(studentId: widget.studentId),
          _FullReportCardTab(studentId: widget.studentId),
        ],
      ),
    );
  }
}

// ── Sticky tab bar delegate ───────────────────────────────────────────────────

class _StickyTabBar extends SliverPersistentHeaderDelegate {
  final TabController controller;
  const _StickyTabBar(this.controller);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: TabBar(
        controller: controller,
        indicatorColor: AppColors.sun,
        indicatorWeight: 3,
        labelColor: AppColors.text,
        unselectedLabelColor: AppColors.muted,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: 'Profile'),
          Tab(text: 'Attendance'),
          Tab(text: 'Tests'),
          Tab(text: 'Work Logs'),
          Tab(text: 'Report'),
          Tab(text: 'Report Card'),
        ],
      ),
    );
  }

  @override
  double get maxExtent => 48;
  @override
  double get minExtent => 48;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => false;
}

// ── Hero avatar ───────────────────────────────────────────────────────────────

class _HeroAvatar extends StatelessWidget {
  final String initials;
  final String? photoUrl;
  final String? gender;
  final double size;
  final bool uploading;
  const _HeroAvatar({required this.initials, this.photoUrl, this.gender, required this.size, this.uploading = false});

  Widget _initialsWidget() => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
        ),
        child: Center(
          child: Text(initials, style: TextStyle(fontSize: size * 0.37, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (uploading) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), shape: BoxShape.circle),
        child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
      );
    }
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsWidget(),
        ),
      );
    }
    return _initialsWidget();
  }
}

// ── Tab 1: Profile ────────────────────────────────────────────────────────────

class _ProfileTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileTab({required this.profile});

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final phone2 = profile['guardian_phone_2'] as String?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'Personal Information',
          children: [
            _InfoRow(label: 'Admission No.', value: profile['admission_number']?.toString() ?? '—'),
            _InfoRow(label: 'Gender', value: _capitalize(profile['gender']?.toString() ?? '—')),
            _InfoRow(label: 'Date of Birth', value: _fmtDate(profile['dob']?.toString())),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Guardian',
          children: [
            _InfoRow(label: 'Name', value: profile['guardian_name']?.toString() ?? '—'),
            _InfoRow(label: 'Primary Phone', value: profile['guardian_phone']?.toString() ?? '—'),
            if (phone2 != null && phone2.isNotEmpty)
              _InfoRow(label: 'Secondary Phone', value: phone2),
          ],
        ),
      ],
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Tab 2: Attendance (calendar) ──────────────────────────────────────────────

class _AttendanceTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  final int month;
  final int year;
  final void Function(int month, int year) onMonthChanged;

  const _AttendanceTab({
    required this.profile,
    required this.month,
    required this.year,
    required this.onMonthChanged,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final att = profile['attendance_this_month'] as Map<String, dynamic>? ?? {};
    final pct = att['percentage'];
    final attDays = (profile['attendance_days'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Build lookup map: date string => status
    final statusMap = <String, String>{};
    for (final d in attDays) {
      final date = d['date'] as String? ?? '';
      final status = d['status'] as String? ?? '';
      statusMap[date] = status;
    }

    final now = DateTime.now();
    final isCurrentMonth = month == now.month && year == now.year;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary badges
        _SectionCard(
          title: '${_monthNames[month - 1]} $year',
          children: [
            Row(
              children: [
                _AttBadge(label: 'Present', value: '${att['present'] ?? 0}', color: AppColors.teal, bg: AppColors.tealLight),
                const SizedBox(width: 8),
                _AttBadge(label: 'Absent', value: '${att['absent'] ?? 0}', color: AppColors.coral, bg: AppColors.coralLight),
                const SizedBox(width: 8),
                _AttBadge(label: 'Late', value: '${att['late'] ?? 0}', color: AppColors.amber, bg: AppColors.amberLight),
                const SizedBox(width: 8),
                _AttBadge(label: '%', value: '${pct ?? 0}%', color: AppColors.sky, bg: AppColors.skyLight),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ((pct as num).toDouble() / 100).clamp(0.0, 1.0),
                  backgroundColor: AppColors.border,
                  color: pct >= 75 ? AppColors.teal : pct >= 50 ? AppColors.amber : AppColors.coral,
                  minHeight: 7,
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // Month navigator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (month == 1) {
                    onMonthChanged(12, year - 1);
                  } else {
                    onMonthChanged(month - 1, year);
                  }
                },
                icon: const Icon(Icons.chevron_left_rounded, color: AppColors.text),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Expanded(
                child: Text(
                  '${_monthNames[month - 1]} $year',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: isCurrentMonth ? null : () {
                  if (month == 12) {
                    onMonthChanged(1, year + 1);
                  } else {
                    onMonthChanged(month + 1, year);
                  }
                },
                icon: Icon(Icons.chevron_right_rounded,
                    color: isCurrentMonth ? AppColors.border : AppColors.text),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Calendar grid
        _AttendanceCalendar(
          month: month,
          year: year,
          statusMap: statusMap,
        ),

        const SizedBox(height: 12),

        // Legend
        _SectionCard(
          title: 'LEGEND',
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _LegendItem(color: AppColors.teal, label: 'Present (P)'),
                _LegendItem(color: AppColors.coral, label: 'Absent (A)'),
                _LegendItem(color: AppColors.amber, label: 'Late (L)'),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _AttendanceCalendar extends StatelessWidget {
  final int month;
  final int year;
  final Map<String, String> statusMap;

  const _AttendanceCalendar({
    required this.month,
    required this.year,
    required this.statusMap,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;
    // Monday=1, so offset = (weekday - 1) to get 0-based Mon index
    final startOffset = (firstDay.weekday - 1) % 7;

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Day-of-week headers
          Row(
            children: dayLabels.map((d) => Expanded(
              child: Center(
                child: Text(d,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted)),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),
          // Day cells
          Builder(builder: (context) {
            final cells = <Widget>[];
            // Empty cells before first day
            for (int i = 0; i < startOffset; i++) {
              cells.add(const Expanded(child: SizedBox()));
            }
            for (int day = 1; day <= daysInMonth; day++) {
              final dateStr = '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
              final status = statusMap[dateStr];
              final isToday = DateTime.now().year == year &&
                  DateTime.now().month == month &&
                  DateTime.now().day == day;
              cells.add(Expanded(child: _CalendarCell(
                day: day,
                status: status,
                isToday: isToday,
              )));
            }
            // Pad to complete the last row
            final remainder = cells.length % 7;
            if (remainder != 0) {
              for (int i = 0; i < 7 - remainder; i++) {
                cells.add(const Expanded(child: SizedBox()));
              }
            }
            // Chunk into rows of 7
            final rows = <Widget>[];
            for (int i = 0; i < cells.length; i += 7) {
              rows.add(Row(children: cells.sublist(i, i + 7)));
              if (i + 7 < cells.length) rows.add(const SizedBox(height: 4));
            }
            return Column(children: rows);
          }),
        ],
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  final int day;
  final String? status;
  final bool isToday;

  const _CalendarCell({required this.day, this.status, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      'present' => (AppColors.teal, Colors.white, 'P'),
      'absent'  => (AppColors.coral, Colors.white, 'A'),
      'late'    => (AppColors.amber, Colors.white, 'L'),
      _         => (Colors.transparent, AppColors.muted, ''),
    };

    return Container(
      margin: const EdgeInsets.all(2),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: status != null ? bg : Colors.transparent,
            shape: BoxShape.circle,
            border: isToday && status == null
                ? Border.all(color: AppColors.sun, width: 1.5)
                : null,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: status != null ? fg : (isToday ? AppColors.sun : AppColors.text2),
                ),
              ),
              if (status != null)
                Positioned(
                  bottom: 2,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: fg.withOpacity(0.85),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14, height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.muted)),
        ],
      );
}

// ── Tab 3: Tests ──────────────────────────────────────────────────────────────

class _TestsTab extends StatelessWidget {
  final List<Map<String, dynamic>> tests;
  const _TestsTab({required this.tests});

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) return const _EmptyState(icon: '📊', label: 'No test records yet');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: tests.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _TestScoreCard(test: tests[i]),
    );
  }
}

class _TestScoreCard extends StatelessWidget {
  final Map<String, dynamic> test;
  const _TestScoreCard({required this.test});

  @override
  Widget build(BuildContext context) {
    final title = test['title'] as String? ?? '';
    final subject = test['subject'] as String? ?? '';
    final total = (test['total_marks'] as num?)?.toDouble() ?? 0;
    final score = (test['score'] as num?)?.toDouble();
    final isAbsent = test['is_absent'] as bool? ?? false;
    final pct = (test['percentage'] as num?)?.toDouble();
    final date = test['scheduled_date'] as String?;
    final examType = (test['work_type'] ?? test['exam_type']) as String? ?? '';

    final (Color statusColor, String statusLabel) = isAbsent
        ? (AppColors.coral, 'Absent')
        : pct == null
            ? (AppColors.muted, '—')
            : pct >= 75
                ? (AppColors.teal, 'Pass')
                : pct >= 40
                    ? (AppColors.amber, 'Pass')
                    : (AppColors.coral, 'Fail');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (subject.isNotEmpty) ...[
                Text(subject, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                const Text('·', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                const SizedBox(width: 8),
              ],
              if (examType.isNotEmpty) ...[
                Text(_fmtExamType(examType), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                const SizedBox(width: 8),
              ],
              if (date != null)
                Text(_fmtDate(date), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          if (isAbsent)
            const Text('Absent from test', style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w600))
          else if (score != null) ...[
            Row(
              children: [
                Text(
                  '${score % 1 == 0 ? score.toInt() : score}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text),
                ),
                Text(' / ${total % 1 == 0 ? total.toInt() : total}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const Spacer(),
                if (pct != null)
                  Text('$pct%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: statusColor)),
              ],
            ),
            if (pct != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0.0, 1.0),
                  backgroundColor: AppColors.border,
                  color: statusColor,
                  minHeight: 5,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  String _fmtDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return raw; }
  }

  String _fmtExamType(String t) => switch (t) {
        'weekly' => 'Weekly', 'monthly' => 'Monthly', 'quarterly' => 'Quarterly',
        'half_yearly' => 'Half Yearly', 'annual' => 'Annual', 'unit_test' => 'Unit Test',
        _ => t,
      };
}

// ── Tab 4: Work Logs ──────────────────────────────────────────────────────────

class _StudentWorkLogsTab extends StatefulWidget {
  final String studentId;
  const _StudentWorkLogsTab({required this.studentId});

  @override
  State<_StudentWorkLogsTab> createState() => _StudentWorkLogsTabState();
}

class _StudentWorkLogsTabState extends State<_StudentWorkLogsTab>
    with AutomaticKeepAliveClientMixin {
  List<WorkLogEntry> _logs = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getWorkLogs(studentId: widget.studentId);
      if (mounted) setState(() { _logs = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.teal));
    if (_error != null) return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚠️', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ]),
      ),
    );
    if (_logs.isEmpty) return const _EmptyState(icon: '📝', label: 'No work logs assigned to this student');
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _WorkLogCard(entry: _logs[i]),
      ),
    );
  }
}

class _WorkLogCard extends StatelessWidget {
  final WorkLogEntry entry;
  const _WorkLogCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (typeIcon, typeColor, typeBg) = switch (entry.logType) {
      'homework'  => ('📚', AppColors.coral, AppColors.coralLight),
      'note'      => ('📌', AppColors.amber, AppColors.amberLight),
      _           => ('📖', AppColors.sky,   AppColors.skyLight),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(6)),
            child: Text('$typeIcon ${entry.logType[0].toUpperCase()}${entry.logType.substring(1)}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: typeColor)),
          ),
          const Spacer(),
          Text(entry.date, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        const SizedBox(height: 8),
        Text(entry.description,
            style: const TextStyle(fontSize: 13, color: AppColors.text1, height: 1.4)),
        if (entry.dueDate != null) ...[
          const SizedBox(height: 6),
          Text('Due: ${entry.dueDate}',
              style: const TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w500)),
        ],
        if (entry.subjectName != null || entry.sectionLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            [if (entry.subjectName != null) entry.subjectName!, if (entry.sectionLabel.isNotEmpty) entry.sectionLabel].join(' · '),
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ],
      ]),
    );
  }
}


// ── Tab 5: Longitudinal Report ────────────────────────────────────────────────

class _ReportTab extends StatefulWidget {
  final String studentId;
  const _ReportTab({required this.studentId});

  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiClient.getLongitudinalReport(widget.studentId);
      if (mounted) setState(() { _report = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _generateAnalysis() async {
    setState(() => _generating = true);
    try {
      final r = await ApiClient.generateLongitudinalAnalysis(widget.studentId);
      if (mounted) {
        setState(() {
          _report = {
            ..._report ?? {},
            'ai_analysis': r['analysis'],
            'ai_analysis_generated_at': r['generated_at'],
          };
        });
        showSnack(context, 'AI report generated');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Generation failed', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.sun));
    if (_error != null) return _EmptyState(icon: '⚠️', label: 'Could not load report');
    final report = _report!;

    final history = (report['test_history'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final heatmap = (report['chapter_heatmap'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final analysis = report['ai_analysis'] as Map<String, dynamic>?;
    final generatedAt = report['ai_analysis_generated_at'] as String?;
    final trend = report['trend'] as String? ?? 'first_test';
    final avg = (report['average_percentage'] as num?)?.toDouble();
    final total = report['total_tests'] as int? ?? 0;

    return RefreshIndicator(
      color: AppColors.sun,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Summary strip ──
          Row(children: [
            _StatChip(label: 'Tests', value: '$total', color: AppColors.sky),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Average',
              value: avg != null ? '${avg.toStringAsFixed(1)}%' : '—',
              color: avg == null ? AppColors.muted : avg >= 75 ? AppColors.teal : avg >= 50 ? AppColors.amber : AppColors.coral,
            ),
            const SizedBox(width: 8),
            _StatChip(
              label: 'Trend',
              value: switch (trend) {
                'improving' => '↑ Improving',
                'declining' => '↓ Declining',
                'stable' => '→ Stable',
                _ => '— First',
              },
              color: switch (trend) {
                'improving' => AppColors.teal,
                'declining' => AppColors.coral,
                _ => AppColors.amber,
              },
            ),
          ]),
          const SizedBox(height: 16),

          // ── Score trend chart ──
          if (history.isNotEmpty) ...[
            _SectionCard(title: 'Score Trend', children: [
              _ScoreTrendChart(history: history),
            ]),
            const SizedBox(height: 12),
          ],

          // ── AI Analysis ──
          if (analysis != null) ...[
            _SectionCard(title: 'AI Analysis${generatedAt != null ? ' · ${_fmtDate(generatedAt)}' : ''}', children: [
              _AnalysisCard(analysis: analysis),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const Key('refresh_analysis_button'),
                  onPressed: _generating ? null : _generateAnalysis,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.sun,
                    side: const BorderSide(color: AppColors.sun),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _generating
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sun))
                      : const Text('Refresh AI Analysis', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(children: [
                const Text('🤖', style: TextStyle(fontSize: 36)),
                const SizedBox(height: 10),
                const Text('No AI analysis yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                const SizedBox(height: 4),
                const Text('Generate a longitudinal analysis of this student\'s performance across all tests.', style: TextStyle(fontSize: 12, color: AppColors.muted), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('generate_ai_report_button'),
                    onPressed: total == 0 || _generating ? null : _generateAnalysis,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.sun,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _generating
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Generate AI Report', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                if (total == 0) ...[
                  const SizedBox(height: 8),
                  const Text('No test records yet — enter scores first', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 12),

          // ── Chapter heatmap ──
          if (heatmap.isNotEmpty) ...[
            _SectionCard(title: 'Chapter Performance', children: [
              ...heatmap.map((c) => _ChapterHeatRow(chapter: c)),
            ]),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) { return iso; }
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color.withOpacity(0.7))),
      ]),
    ),
  );
}

class _ScoreTrendChart extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  const _ScoreTrendChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final dataPoints = history
        .where((t) => t['percentage'] != null && t['is_absent'] == false)
        .map((t) => (t['percentage'] as num).toDouble())
        .toList();

    if (dataPoints.isEmpty) {
      return const Center(child: Text('No scored tests yet', style: TextStyle(fontSize: 12, color: AppColors.muted)));
    }

    return SizedBox(
      height: 120,
      child: CustomPaint(
        painter: _LinePainter(dataPoints),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${dataPoints.length} test${dataPoints.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> points;
  _LinePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final linePaint = Paint()
      ..color = AppColors.sun
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = AppColors.sun..style = PaintingStyle.fill;
    final bgPaint = Paint()..color = AppColors.sun.withOpacity(0.08)..style = PaintingStyle.fill;

    final h = size.height - 16;
    final w = size.width;
    final min = points.reduce((a, b) => a < b ? a : b).clamp(0, 100).toDouble();
    final max = points.reduce((a, b) => a > b ? a : b).clamp(0, 100).toDouble();
    final range = (max - min).clamp(10, 100).toDouble();

    double xOf(int i) => i / (points.length - 1) * w;
    double yOf(double v) => h - ((v - min) / range * h);

    final path = Path()..moveTo(xOf(0), yOf(points[0]));
    for (int i = 1; i < points.length; i++) path.lineTo(xOf(i), yOf(points[i]));

    final fill = Path.from(path)
      ..lineTo(xOf(points.length - 1), h)
      ..lineTo(xOf(0), h)
      ..close();
    canvas.drawPath(fill, bgPaint);
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(points[i])), 4, dotPaint);
    }

    // Draw first and last % labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void drawLabel(int i, double val) {
      tp.text = TextSpan(text: '${val.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9, color: AppColors.muted, fontWeight: FontWeight.w700));
      tp.layout();
      final x = xOf(i).clamp(0.0, w - tp.width);
      tp.paint(canvas, Offset(x, yOf(val) - 13));
    }
    drawLabel(0, points.first);
    if (points.length > 1) drawLabel(points.length - 1, points.last);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.points != points;
}

class _AnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;
  const _AnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final level = analysis['performance_level'] as String? ?? '';
    final (levelColor, levelBg) = switch (level) {
      'excellent' => (const Color(0xFF166534), const Color(0xFFDCFCE7)),
      'good' => (const Color(0xFF1E40AF), const Color(0xFFDBEAFE)),
      'average' => (const Color(0xFF854D0E), const Color(0xFFFEF9C3)),
      'needs_attention' => (const Color(0xFF9A3412), const Color(0xFFFFEDD5)),
      _ => (const Color(0xFF991B1B), const Color(0xFFFEE2E2)),
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: levelBg, borderRadius: BorderRadius.circular(20)),
        child: Text(level.replaceAll('_', ' ').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: levelColor)),
      ),
      const SizedBox(height: 12),
      if ((analysis['strengths'] as String? ?? '').isNotEmpty) ...[
        _AnalysisRow(icon: '✅', label: 'Strengths', text: analysis['strengths'] as String),
        const SizedBox(height: 8),
      ],
      if ((analysis['weak_areas'] as String? ?? '').isNotEmpty) ...[
        _AnalysisRow(icon: '⚠️', label: 'Weak Areas', text: analysis['weak_areas'] as String),
        const SizedBox(height: 8),
      ],
      if ((analysis['action_plan'] as String? ?? '').isNotEmpty) ...[
        _AnalysisRow(icon: '📋', label: 'Action Plan', text: analysis['action_plan'] as String),
        const SizedBox(height: 8),
      ],
      if ((analysis['parent_note'] as String? ?? '').isNotEmpty)
        _AnalysisRow(icon: '💬', label: 'Parent Note', text: analysis['parent_note'] as String),
    ]);
  }
}

class _AnalysisRow extends StatelessWidget {
  final String icon;
  final String label;
  final String text;
  const _AnalysisRow({required this.icon, required this.label, required this.text});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$icon $label', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.text)),
      const SizedBox(height: 3),
      Text(text, style: const TextStyle(fontSize: 12, color: AppColors.text2, height: 1.45)),
    ],
  );
}

class _ChapterHeatRow extends StatelessWidget {
  final Map<String, dynamic> chapter;
  const _ChapterHeatRow({required this.chapter});

  @override
  Widget build(BuildContext context) {
    final name = chapter['chapter_name'] as String? ?? '';
    final pct = (chapter['avg_pct'] as num?)?.toDouble();
    final heat = chapter['heat_level'] as String? ?? 'none';
    final (barColor, bg) = switch (heat) {
      'green' => (AppColors.teal, AppColors.tealLight),
      'amber' => (AppColors.amber, AppColors.amberLight),
      'red'   => (AppColors.coral, AppColors.coralLight),
      _       => (AppColors.muted, AppColors.bg),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct != null ? (pct / 100).clamp(0.0, 1.0) : 0,
                backgroundColor: AppColors.border,
                color: barColor,
                minHeight: 6,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Text(
            pct != null ? '${pct.toStringAsFixed(0)}%' : '—',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: barColor),
          ),
        ),
      ]),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.3)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
            ),
          ],
        ),
      );
}

class _AttBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  const _AttBadge({required this.label, required this.value, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  final String icon;
  final String label;
  const _EmptyState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 36)),
              const SizedBox(height: 10),
              Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      );
}

// ── Full Report Card Tab ──────────────────────────────────────────────────────

class _FullReportCardTab extends StatefulWidget {
  final String studentId;
  const _FullReportCardTab({required this.studentId});

  @override
  State<_FullReportCardTab> createState() => _FullReportCardTabState();
}

class _FullReportCardTabState extends State<_FullReportCardTab>
    with AutomaticKeepAliveClientMixin {
  Map<String, dynamic>? _report;
  bool _loading = true;
  bool _generating = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiClient.getStudentFullReport(widget.studentId);
      if (mounted) setState(() { _report = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _generateReport() async {
    setState(() => _generating = true);
    try {
      final r = await ApiClient.generateStudentFullReport(widget.studentId);
      if (mounted) {
        setState(() { _report = r; });
        showSnack(context, 'Report card generated');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Generation failed', error: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.sun));
    if (_error != null) return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            TextButton(onPressed: _loadReport, child: const Text('Retry')),
          ],
        ),
      ),
    );

    final reportJson = _report?['report'] as Map<String, dynamic>?;
    final isStale = _report?['is_stale'] as bool? ?? true;
    final hasReport = reportJson != null;

    return RefreshIndicator(
      color: AppColors.sun,
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Holistic Report Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (hasReport && isStale)
                      const Text('Data may have changed — regenerate for latest', style: TextStyle(color: AppColors.amber, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _generating ? null : _generateReport,
                icon: _generating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('✨', style: TextStyle(fontSize: 14)),
                label: Text(hasReport ? 'Regenerate' : 'Generate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sun,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),

          if (!hasReport) ...[
            const SizedBox(height: 32),
            const _EmptyState(icon: '📋', label: 'No report card yet.\nTap Generate to create one.'),
          ] else ...[
            const SizedBox(height: 16),

            // Level & trend
            Row(
              children: [
                _RcChip(reportJson['overall_level'] as String? ?? '—', AppColors.sun, AppColors.sunLight),
                const SizedBox(width: 8),
                _RcChip(_trendLabel(reportJson['overall_trend'] as String? ?? ''), AppColors.teal, AppColors.tealLight),
              ],
            ),

            // Summary
            if ((reportJson['summary'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(reportJson['summary'] as String, style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            ],

            // Strengths
            const SizedBox(height: 16),
            const Text('Strengths', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...(reportJson['strengths'] as List<dynamic>? ?? []).map((s) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✅ ', style: TextStyle(fontSize: 13)),
                    Expanded(child: Text(s.toString(), style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
            ),

            // Focus Areas
            const SizedBox(height: 16),
            const Text('Focus Areas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...(reportJson['focus_areas'] as List<dynamic>? ?? []).map((f) {
              final fa = f as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.coralLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.coral.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fa['area'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    if ((fa['observation'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(fa['observation'] as String, style: const TextStyle(color: AppColors.text2, fontSize: 12)),
                    ],
                    if ((fa['action'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text('→ ${fa['action']}', style: const TextStyle(color: AppColors.coral, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              );
            }),

            // Subject Feedback
            const SizedBox(height: 16),
            const Text('Subject Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 6),
            ...(reportJson['subject_feedback'] as List<dynamic>? ?? []).map((sf) {
              final s = sf as Map<String, dynamic>;
              final avg = (s['avg_pct'] as num?)?.toDouble() ?? 0;
              Color barColor = AppColors.green;
              if (avg < 60) barColor = AppColors.coral;
              else if (avg < 80) barColor = AppColors.amber;
              else if (avg < 90) barColor = AppColors.sky;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(s['subject'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        Text('${avg.toStringAsFixed(1)}%', style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (avg / 100).clamp(0.0, 1.0),
                        backgroundColor: AppColors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        minHeight: 5,
                      ),
                    ),
                    if ((s['feedback'] as String?)?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(s['feedback'] as String, style: const TextStyle(color: AppColors.text2, fontSize: 12, height: 1.4)),
                    ],
                  ],
                ),
              );
            }),

            // Parent Message
            if ((reportJson['parent_message'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 16),
              const Text('Parent Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.teal.withOpacity(0.3)),
                ),
                child: Text(reportJson['parent_message'] as String,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text2)),
              ),
            ],

            // Teacher Note
            if ((reportJson['teacher_note'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              const Text('Teacher Note', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                ),
                child: Text(reportJson['teacher_note'] as String,
                    style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.text2)),
              ),
            ],
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _trendLabel(String trend) {
    return switch (trend) {
      'improving' => '↑ Improving',
      'declining' => '↓ Declining',
      'stable' => '→ Stable',
      _ => '— First',
    };
  }
}

class _RcChip extends StatelessWidget {
  const _RcChip(this.label, this.fg, this.bg);
  final String label;
  final Color fg, bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: fg)),
  );
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            const Text('Failed to load profile', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      );
}
