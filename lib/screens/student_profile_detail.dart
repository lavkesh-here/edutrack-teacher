import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class StudentProfileDetail extends StatefulWidget {
  final int studentId;
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
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

  void _onPhotoUploaded(String url) {
    setState(() {
      _profile = Map<String, dynamic>.from(_profile ?? {})
        ..['photo_url'] = url
        ..['photo_uploaded_by'] = 'teacher';
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
          : _error != null
              ? _ErrorView(onRetry: _load)
              : _ProfileBody(
                  profile: _profile!,
                  tabs: _tabs,
                  initials: _initials(widget.studentName),
                  sectionLabel: widget.sectionLabel,
                  studentId: widget.studentId,
                  onPhotoUploaded: _onPhotoUploaded,
                ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final Map<String, dynamic> profile;
  final TabController tabs;
  final String initials;
  final String sectionLabel;
  final int studentId;
  final void Function(String url) onPhotoUploaded;

  const _ProfileBody({
    required this.profile,
    required this.tabs,
    required this.initials,
    required this.sectionLabel,
    required this.studentId,
    required this.onPhotoUploaded,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile['name'] as String? ?? '';
    final admNo = profile['admission_number'] as String? ?? '';
    final classLabel = profile['class_label'] as String? ?? sectionLabel;
    final photoUrl = profile['photo_url'] as String?;
    final gender = profile['gender'] as String?;

    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverAppBar(
          expandedHeight: 210,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
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
                    _HeroAvatar(initials: initials, photoUrl: photoUrl, gender: gender, size: 70),
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
          bottom: TabBar(
            controller: tabs,
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
              Tab(text: 'Photo'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: tabs,
        children: [
          _ProfileTab(profile: profile),
          _AttendanceTab(profile: profile),
          _TestsTab(tests: (profile['tests'] as List?)?.cast<Map<String, dynamic>>() ?? []),
          _WorkLogsTab(submissions: (profile['work_log_submissions'] as List?)?.cast<Map<String, dynamic>>() ?? []),
          _PhotoTab(
            studentId: studentId,
            photoUrl: profile['photo_url'] as String?,
            photoUploadedBy: profile['photo_uploaded_by'] as String?,
            onUploaded: onPhotoUploaded,
          ),
        ],
      ),
    );
  }
}

// ── Hero avatar ───────────────────────────────────────────────────────────────

class _HeroAvatar extends StatelessWidget {
  final String initials;
  final String? photoUrl;
  final String? gender;
  final double size;
  const _HeroAvatar({required this.initials, this.photoUrl, this.gender, required this.size});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl!,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initialsWidget,
        ),
      );
    }
    return _initialsWidget;
  }

  Widget get _initialsWidget => Container(
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
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
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
            _InfoRow(label: 'Phone', value: profile['guardian_phone']?.toString() ?? '—'),
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
    } catch (_) {
      return raw;
    }
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
    if (tests.isEmpty) {
      return const _EmptyState(icon: '📊', label: 'No test records yet');
    }
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
          Row(
            children: [
              if (isAbsent)
                const Text('Absent from test', style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w600))
              else if (score != null) ...[
                Text(
                  '${score % 1 == 0 ? score.toInt() : score}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.text),
                ),
                Text(' / ${total % 1 == 0 ? total.toInt() : total}', style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                const Spacer(),
                if (pct != null)
                  Text('$pct%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: statusColor)),
              ],
            ],
          ),
          if (pct != null && !isAbsent) ...[
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
      ),
    );
  }

  String _fmtDate(String raw) {
    try {
      final d = DateTime.parse(raw);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return raw;
    }
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
    if (submissions.isEmpty) {
      return const _EmptyState(icon: '📝', label: 'No work log records');
    }
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
    } catch (_) {
      return raw;
    }
  }
}

// ── Tab 5: Photo (one-time teacher upload) ────────────────────────────────────

class _PhotoTab extends StatefulWidget {
  final int studentId;
  final String? photoUrl;
  final String? photoUploadedBy;
  final void Function(String url) onUploaded;

  const _PhotoTab({
    required this.studentId,
    this.photoUrl,
    this.photoUploadedBy,
    required this.onUploaded,
  });

  @override
  State<_PhotoTab> createState() => _PhotoTabState();
}

class _PhotoTabState extends State<_PhotoTab> {
  bool _uploading = false;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _currentPhotoUrl = widget.photoUrl;
  }

  bool get _teacherAlreadyUploaded => widget.photoUploadedBy == 'teacher' || (_currentPhotoUrl != null && widget.photoUploadedBy == 'teacher');

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'Image must be under 5MB', error: true);
      return;
    }
    final ext = file.path.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() => _uploading = true);
    try {
      final resp = await ApiClient.getStudentPhotoUploadUrl(widget.studentId);
      final uploadUrl = resp['upload_url'] as String;
      final photoUrl = resp['photo_url'] as String;
      await http.put(Uri.parse(uploadUrl), headers: {'Content-Type': contentType}, body: bytes);
      await ApiClient.saveStudentPhoto(widget.studentId, photoUrl);
      setState(() => _currentPhotoUrl = photoUrl);
      widget.onUploaded(photoUrl);
      if (mounted) showSnack(context, 'Photo uploaded ✓');
    } on ApiError catch (e) {
      if (e.statusCode == 409) {
        if (mounted) showSnack(context, 'Photo already uploaded by teacher — cannot change', error: true);
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
    final alreadyUploaded = _teacherAlreadyUploaded;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Photo preview
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                color: AppColors.bg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: _currentPhotoUrl != null
                  ? ClipOval(
                      child: Image.network(
                        _currentPhotoUrl!,
                        width: 120, height: 120, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: AppColors.muted),
                      ),
                    )
                  : const Icon(Icons.person_outline, size: 50, color: AppColors.muted),
            ),
            const SizedBox(height: 20),

            if (alreadyUploaded) ...[
              const Icon(Icons.lock_outline, size: 20, color: AppColors.muted),
              const SizedBox(height: 8),
              const Text(
                'Photo uploaded by teacher',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Once uploaded by a teacher, this photo cannot be changed from the teacher app. Parents may update it.',
                style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Text(
                _currentPhotoUrl != null ? 'Update Student Photo' : 'Add Student Photo',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 6),
              const Text(
                'You can upload once. After upload, the photo cannot be changed from the teacher app.',
                style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _pickAndUpload,
                  icon: _uploading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Icon(Icons.upload_rounded, size: 20),
                  label: Text(_uploading ? 'Uploading…' : 'Choose from Gallery'),
                ),
              ),
            ],
          ],
        ),
      ),
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
              width: 110,
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
