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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
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
      final p = await ApiClient.getStudentProfile(widget.studentId);
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
          _AttendanceTab(profile: _profile!),
          _TestsTab(tests: (_profile!['tests'] as List?)?.cast<Map<String, dynamic>>() ?? []),
          _WorkLogsTab(submissions: (_profile!['work_log_submissions'] as List?)?.cast<Map<String, dynamic>>() ?? []),
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

// ── Tab 2: Attendance ─────────────────────────────────────────────────────────

class _AttendanceTab extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _AttendanceTab({required this.profile});

  String _shortDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) { return raw; }
  }

  @override
  Widget build(BuildContext context) {
    final att = profile['attendance_this_month'] as Map<String, dynamic>? ?? {};
    final last5 = (profile['last_5_days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final pct = att['percentage'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: 'This Month',
          children: [
            Row(
              children: [
                _AttBadge(label: 'Present', value: '${att['present'] ?? 0}', color: AppColors.teal, bg: AppColors.tealLight),
                const SizedBox(width: 8),
                _AttBadge(label: 'Absent', value: '${att['absent'] ?? 0}', color: AppColors.coral, bg: AppColors.coralLight),
                const SizedBox(width: 8),
                _AttBadge(label: 'Late', value: '${att['late'] ?? 0}', color: AppColors.amber, bg: AppColors.amberLight),
                const SizedBox(width: 8),
                _AttBadge(label: 'Attendance', value: '${pct ?? 0}%', color: AppColors.sky, bg: AppColors.skyLight),
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
        if (last5.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Last 5 Days',
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: last5.map((d) {
                  final status = d['status'] as String? ?? '';
                  final date = d['date'] as String? ?? '';
                  final (color, label) = switch (status) {
                    'present' => (AppColors.teal, 'P'),
                    'absent' => (AppColors.coral, 'A'),
                    'late' => (AppColors.amber, 'L'),
                    _ => (AppColors.muted, '?'),
                  };
                  return Column(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color))),
                      ),
                      const SizedBox(height: 4),
                      Text(_shortDate(date), style: const TextStyle(fontSize: 9, color: AppColors.muted)),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ],
    );
  }
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
    final examType = test['exam_type'] as String? ?? '';

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

class _WorkLogsTab extends StatelessWidget {
  final List<Map<String, dynamic>> submissions;
  const _WorkLogsTab({required this.submissions});

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) return const _EmptyState(icon: '📝', label: 'No work log records');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: submissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _SubmissionCard(sub: submissions[i]),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  const _SubmissionCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final desc = sub['description'] as String? ?? '';
    final logType = sub['log_type'] as String? ?? 'classwork';
    final date = sub['log_date'] as String? ?? '';
    final status = sub['status'] as String? ?? 'pending';
    final note = sub['parent_note'] as String?;

    final (typeIcon, typeColor, typeBg) = switch (logType) {
      'homework' => ('📚', AppColors.coral, AppColors.coralLight),
      'note' => ('📌', AppColors.amber, AppColors.amberLight),
      _ => ('📖', AppColors.sky, AppColors.skyLight),
    };

    final (statusColor, statusLabel) = switch (status) {
      'acknowledged' => (AppColors.teal, '✓ Acknowledged'),
      'pending' => (AppColors.muted, 'Pending'),
      _ => (AppColors.amber, status),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: typeBg, borderRadius: BorderRadius.circular(20)),
                child: Text('$typeIcon ${_fmtType(logType)}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: typeColor)),
              ),
              const Spacer(),
              Text(_fmtDate(date), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.text, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(statusLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
              ),
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text('"$note"',
                    style: const TextStyle(fontSize: 11, color: AppColors.muted, fontStyle: FontStyle.italic),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _fmtType(String t) => switch (t) { 'homework' => 'Homework', 'note' => 'Note', _ => 'Classwork' };

  String _fmtDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]}';
    } catch (_) { return raw; }
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
