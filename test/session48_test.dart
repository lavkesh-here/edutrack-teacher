// Pure logic tests for Session 48 — comprehensive model + business logic coverage.
// No device or platform channels required.

import 'package:flutter_test/flutter_test.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MODEL REPLICAS (from core/api.dart and screens/)
// ══════════════════════════════════════════════════════════════════════════════

// ── SchoolInfo ────────────────────────────────────────────────────────────────
class _SchoolInfo {
  final String id;
  final String name;
  final String code;
  final String? logoUrl;
  const _SchoolInfo({required this.id, required this.name, required this.code, this.logoUrl});
  factory _SchoolInfo.fromJson(Map<String, dynamic> j) => _SchoolInfo(
        id: j['id'].toString(),
        name: j['name'] as String,
        code: j['code'] as String,
        logoUrl: j['logo_url'] as String?,
      );
}

// ── AuthResponse ──────────────────────────────────────────────────────────────
class _AuthResponse {
  final String token;
  final String teacherName;
  final String schoolName;
  final String role;
  final String teacherId;
  final bool mustChangePassword;
  const _AuthResponse({
    required this.token,
    required this.teacherName,
    required this.schoolName,
    required this.role,
    required this.teacherId,
    this.mustChangePassword = false,
  });
  factory _AuthResponse.fromJson(Map<String, dynamic> j) => _AuthResponse(
        token: j['access_token'] as String,
        teacherName: j['teacher_name'] as String,
        schoolName: j['school_name'] as String,
        role: j['role'] as String,
        teacherId: j['teacher_id'].toString(),
        mustChangePassword: j['must_change_password'] as bool? ?? false,
      );
}

// ── StudentSearchResult ───────────────────────────────────────────────────────
class _StudentSearchResult {
  final String id;
  final String name;
  final String admissionNumber;
  final String? guardianName;
  final String? guardianPhone;
  final String? rollNo;
  final String? classLabel;
  const _StudentSearchResult({
    required this.id,
    required this.name,
    required this.admissionNumber,
    this.guardianName,
    this.guardianPhone,
    this.rollNo,
    this.classLabel,
  });
  factory _StudentSearchResult.fromJson(Map<String, dynamic> j) => _StudentSearchResult(
        id: j['id'].toString(),
        name: j['name'] as String,
        admissionNumber: j['admission_number'] as String? ?? '',
        guardianName: j['guardian_name'] as String?,
        guardianPhone: j['guardian_phone'] as String?,
        rollNo: j['roll_no']?.toString(),
        classLabel: j['class_label'] as String?,
      );
}

// ── TodoItem ──────────────────────────────────────────────────────────────────
class _TodoItem {
  final String id;
  final String title;
  final String? notes;
  final String? dueDate;
  final bool isPersonal;
  final bool isCompleted;
  final String status;
  final String? completedAt;
  const _TodoItem({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    required this.isPersonal,
    required this.isCompleted,
    this.status = 'todo',
    this.completedAt,
  });
  factory _TodoItem.fromJson(Map<String, dynamic> j) => _TodoItem(
        id: j['id'].toString(),
        title: j['title'] as String,
        notes: j['notes'] as String?,
        dueDate: j['due_date'] as String?,
        isPersonal: j['is_personal'] as bool? ?? false,
        isCompleted: j['is_completed'] as bool? ?? false,
        status: j['status'] as String? ?? (j['is_completed'] == true ? 'done' : 'todo'),
        completedAt: j['completed_at'] as String?,
      );
}

bool _isTodoOverdue(_TodoItem t) {
  if (t.status == 'done' || t.dueDate == null) return false;
  final due = DateTime.tryParse(t.dueDate!);
  if (due == null) return false;
  return due.isBefore(DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0));
}

String _formatTodoDueDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day}/${d.month}/${d.year}';
}

String _dueDatePayload(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ── TestSummary ───────────────────────────────────────────────────────────────
class _TestSummary {
  final String id;
  final String title;
  final String subject;
  final String className;
  final String status;
  final double totalMarks;
  final DateTime? scheduledDate;
  final int questionCount;
  final int scoreCount;
  final String? workType;
  final int? durationMinutes;
  const _TestSummary({
    required this.id,
    required this.title,
    required this.subject,
    required this.className,
    required this.status,
    required this.totalMarks,
    this.scheduledDate,
    required this.questionCount,
    required this.scoreCount,
    this.workType,
    this.durationMinutes,
  });
  factory _TestSummary.fromJson(Map<String, dynamic> j) => _TestSummary(
        id: j['id'].toString(),
        title: j['title'] as String,
        subject: j['subject'] as String? ?? '',
        className: j['class_name'] as String? ?? '',
        status: j['status'] as String? ?? 'draft',
        totalMarks: (j['total_marks'] as num?)?.toDouble() ?? 0,
        scheduledDate: j['scheduled_date'] != null
            ? DateTime.tryParse(j['scheduled_date'] as String)
            : null,
        questionCount: j['question_count'] as int? ?? 0,
        scoreCount: j['score_count'] as int? ?? 0,
        workType: j['work_type'] as String?,
        durationMinutes: j['exam_duration_minutes'] as int?,
      );
}

// ── TestQuestion ──────────────────────────────────────────────────────────────
class _TestQuestion {
  final int order;
  final double marks;
  final String questionText;
  const _TestQuestion({required this.order, required this.marks, required this.questionText});
  factory _TestQuestion.fromJson(Map<String, dynamic> j) {
    final custom = j['custom_question_text'] as String?;
    final diksha = (j['question'] as Map<String, dynamic>?)?['question_text'] as String?;
    return _TestQuestion(
      order: j['order'] as int? ?? 0,
      marks: (j['marks'] as num?)?.toDouble() ?? 0,
      questionText: (custom?.isNotEmpty == true ? custom : diksha) ?? '',
    );
  }
}

// ── StudentScore ──────────────────────────────────────────────────────────────
class _StudentScore {
  final String rollNo;
  final String name;
  final double? marks;
  final bool isAbsent;
  final String? remarks;
  const _StudentScore({
    required this.rollNo,
    required this.name,
    this.marks,
    required this.isAbsent,
    this.remarks,
  });
  factory _StudentScore.fromJson(Map<String, dynamic> j) => _StudentScore(
        rollNo: j['roll_no']?.toString() ?? '',
        name: j['student_name'] as String? ?? j['name'] as String? ?? '',
        marks: (j['score'] as num?)?.toDouble(),
        isAbsent: j['is_absent'] as bool? ?? false,
        remarks: j['remarks'] as String?,
      );
}

// ── TestScoresResponse ────────────────────────────────────────────────────────
class _TestScoresResponse {
  final List<_StudentScore> scores;
  final double? classAverage;
  final double? highestMark;
  final int? belowAverageCount;
  const _TestScoresResponse({
    required this.scores,
    this.classAverage,
    this.highestMark,
    this.belowAverageCount,
  });
  factory _TestScoresResponse.fromJson(Map<String, dynamic> j) {
    final raw = j['scores'] as List<dynamic>? ?? [];
    final report = j['report'] as Map<String, dynamic>?;
    return _TestScoresResponse(
      scores: raw.map((e) => _StudentScore.fromJson(e as Map<String, dynamic>)).toList(),
      classAverage: (report?['average_percentage'] as num?)?.toDouble(),
      highestMark: (report?['highest'] as num?)?.toDouble(),
      belowAverageCount: (report?['below_40_percent'] as List?)?.length,
    );
  }
}

// ── SpacedRepChapter ──────────────────────────────────────────────────────────
class _SpacedRepChapter {
  final String chapterId;
  final String chapterName;
  final String subjectName;
  final double? avgPct;
  final String? lastTested;
  final String urgency;
  const _SpacedRepChapter({
    required this.chapterId,
    required this.chapterName,
    required this.subjectName,
    this.avgPct,
    this.lastTested,
    required this.urgency,
  });
  factory _SpacedRepChapter.fromJson(Map<String, dynamic> j) => _SpacedRepChapter(
        chapterId: j['chapter_id']?.toString() ?? '',
        chapterName: j['chapter_name'] as String? ?? '',
        subjectName: j['subject_name'] as String? ?? '',
        avgPct: (j['avg_pct'] as num?)?.toDouble(),
        lastTested: j['last_tested'] as String?,
        urgency: j['urgency'] as String? ?? 'low_score',
      );
}

// ── TimetableSlot ─────────────────────────────────────────────────────────────
class _TimetableSlot {
  final String id;
  final int dayOfWeek;
  final int periodNumber;
  final String? startTime;
  final String? endTime;
  final String? subjectName;
  final String sectionLabel;
  final String classSectionId;
  const _TimetableSlot({
    required this.id,
    required this.dayOfWeek,
    required this.periodNumber,
    this.startTime,
    this.endTime,
    this.subjectName,
    required this.sectionLabel,
    required this.classSectionId,
  });
  factory _TimetableSlot.fromJson(Map<String, dynamic> j) => _TimetableSlot(
        id: j['id'].toString(),
        dayOfWeek: j['day_of_week'] as int,
        periodNumber: j['period_number'] as int,
        startTime: j['start_time'] as String?,
        endTime: j['end_time'] as String?,
        subjectName: j['subject_name'] as String?,
        sectionLabel: j['section_label'] as String? ?? '',
        classSectionId: j['class_section_id']?.toString() ?? '',
      );
}

// ── SectionInfo ───────────────────────────────────────────────────────────────
class _SectionInfo {
  final String id;
  final String label;
  const _SectionInfo({required this.id, required this.label});
  factory _SectionInfo.fromJson(Map<String, dynamic> j) => _SectionInfo(
        id: j['id'].toString(),
        label: j['label'] as String,
      );
}

// ── AttendanceStudent ─────────────────────────────────────────────────────────
class _AttendanceStudent {
  final String id;
  final String name;
  final String rollNo;
  final String? gender;
  final String? photoUrl;
  String status;
  _AttendanceStudent({
    required this.id,
    required this.name,
    required this.rollNo,
    this.gender,
    this.photoUrl,
    this.status = '',
  });
  factory _AttendanceStudent.fromJson(Map<String, dynamic> j) => _AttendanceStudent(
        id: j['id'].toString(),
        name: j['name'] as String,
        rollNo: j['roll_no']?.toString() ?? '',
        gender: j['gender'] as String?,
        photoUrl: j['photo_url'] as String?,
      );
}

// ── LeaveRequest ──────────────────────────────────────────────────────────────
class _LeaveRequest {
  final String id;
  final String leaveType;
  final String startDate;
  final String endDate;
  final int daysCount;
  final String? reason;
  final String status;
  const _LeaveRequest({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    this.reason,
    required this.status,
  });
  factory _LeaveRequest.fromJson(Map<String, dynamic> j) => _LeaveRequest(
        id: j['id'].toString(),
        leaveType: j['leave_type'] as String? ?? 'casual',
        startDate: j['start_date'] as String? ?? '',
        endDate: j['end_date'] as String? ?? '',
        daysCount: j['days_count'] as int? ?? 1,
        reason: j['reason'] as String?,
        status: j['status'] as String? ?? 'pending',
      );
}

// ── AnalysisInsight ───────────────────────────────────────────────────────────
class _AnalysisInsight {
  final String summary;
  final List<String> concernAreas;
  final String recommendedAction;
  const _AnalysisInsight({required this.summary, required this.concernAreas, required this.recommendedAction});
  factory _AnalysisInsight.fromJson(Map<String, dynamic> j) => _AnalysisInsight(
        summary: j['summary'] as String? ?? '',
        concernAreas: (j['concern_areas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        recommendedAction: j['recommended_action'] as String? ?? '',
      );
}

// ── TestAnalysisResult ────────────────────────────────────────────────────────
class _TestAnalysisResult {
  final String generatedAt;
  final int studentCount;
  final String summary;
  final List<String> concernAreas;
  final String recommendedAction;
  final List<Map<String, dynamic>> studentPlans;
  final String? suggestedFollowup;
  final bool isUpToDate;
  const _TestAnalysisResult({
    required this.generatedAt,
    required this.studentCount,
    required this.summary,
    required this.concernAreas,
    required this.recommendedAction,
    required this.studentPlans,
    this.suggestedFollowup,
    this.isUpToDate = false,
  });
  factory _TestAnalysisResult.fromJson(Map<String, dynamic> j) {
    final ci = (j['analysis'] as Map<String, dynamic>?)?['class_insight'] as Map<String, dynamic>? ?? {};
    final plans = (j['analysis'] as Map<String, dynamic>?)?['student_plans'] as List<dynamic>? ?? [];
    return _TestAnalysisResult(
      generatedAt: j['generated_at'] as String? ?? '',
      studentCount: j['student_count'] as int? ?? 0,
      summary: ci['summary'] as String? ?? '',
      concernAreas: (ci['concern_areas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      recommendedAction: ci['recommended_action'] as String? ?? '',
      studentPlans: plans.map((e) => e as Map<String, dynamic>).toList(),
      suggestedFollowup: (j['analysis'] as Map<String, dynamic>?)?['suggested_followup_test'] as String?,
      isUpToDate: j['up_to_date'] as bool? ?? false,
    );
  }
}

// ── TeacherSearchResult ───────────────────────────────────────────────────────
class _TeacherSearchResult {
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> tests;
  final List<Map<String, dynamic>> announcements;
  const _TeacherSearchResult({required this.students, required this.tests, required this.announcements});
  bool get isEmpty => students.isEmpty && tests.isEmpty && announcements.isEmpty;
  factory _TeacherSearchResult.fromJson(Map<String, dynamic> j) => _TeacherSearchResult(
        students: (j['students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
        tests: (j['tests'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
        announcements: (j['announcements'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      );
}

// ── SyllabusChapter / SyllabusSubject (from screens/syllabus.dart) ────────────
class _SyllabusChapter {
  final String id;
  final int number;
  final String name;
  String status;
  _SyllabusChapter({required this.id, required this.number, required this.name, required this.status});
  factory _SyllabusChapter.fromJson(Map<String, dynamic> j) => _SyllabusChapter(
        id: j['id'] as String,
        number: j['number'] as int,
        name: j['name'] as String,
        status: (j['status'] as String?) ?? 'not_started',
      );
}

class _SyllabusSubject {
  final String id;
  final String name;
  final List<_SyllabusChapter> chapters;
  _SyllabusSubject({required this.id, required this.name, required this.chapters});
  factory _SyllabusSubject.fromJson(Map<String, dynamic> j) => _SyllabusSubject(
        id: j['subject_id'] as String,
        name: j['subject_name'] as String,
        chapters: (j['chapters'] as List)
            .map((c) => _SyllabusChapter.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
  int get total => chapters.length;
  int get completed => chapters.where((c) => c.status == 'completed').length;
  int get inProgress => chapters.where((c) => c.status == 'in_progress').length;
  double get pct => total == 0 ? 0.0 : completed / total;
}

String _nextStatus(String current) {
  switch (current) {
    case 'not_started': return 'in_progress';
    case 'in_progress': return 'completed';
    default: return 'not_started';
  }
}

// ── Announcement + Comment (from core/api.dart) ───────────────────────────────
class _AnnouncementComment {
  final String id;
  final String body;
  final String? authorName;
  final String createdAt;
  final String? parentId;
  final int likeCount;
  final bool likedByMe;
  const _AnnouncementComment({
    required this.id, required this.body, this.authorName,
    required this.createdAt, this.parentId, this.likeCount = 0, this.likedByMe = false,
  });
  factory _AnnouncementComment.fromJson(Map<String, dynamic> j) => _AnnouncementComment(
        id: j['id'].toString(), body: j['body'] as String? ?? '',
        authorName: j['author_name'] as String?, createdAt: j['created_at'] as String? ?? '',
        parentId: j['parent_id']?.toString(),
        likeCount: j['like_count'] as int? ?? 0, likedByMe: j['liked_by_me'] as bool? ?? false,
      );
}

class _Announcement {
  final String id;
  final String title;
  final String body;
  final String audience;
  final bool isPinned;
  final bool allowComments;
  final String createdAt;
  final String? authorName;
  final int commentCount;
  final int likeCount;
  final bool likedByMe;
  final int imageCount;
  const _Announcement({
    required this.id, required this.title, required this.body,
    required this.audience, required this.isPinned, required this.allowComments,
    required this.createdAt, this.authorName, this.commentCount = 0,
    this.likeCount = 0, this.likedByMe = false, this.imageCount = 0,
  });
  factory _Announcement.fromJson(Map<String, dynamic> j) => _Announcement(
        id: j['id'].toString(), title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '', audience: j['audience'] as String? ?? 'all',
        isPinned: j['is_pinned'] as bool? ?? false,
        allowComments: j['allow_comments'] as bool? ?? false,
        createdAt: j['created_at'] as String? ?? '',
        authorName: j['author_name'] as String?,
        commentCount: j['comment_count'] as int? ?? 0,
        likeCount: j['like_count'] as int? ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
        imageCount: (j['images'] as List<dynamic>?)?.length ?? 0,
      );
}

// ── WorkLogEntry (from core/api.dart) ────────────────────────────────────────
class _WorkLogEntry {
  final String id;
  final String classSectionId;
  final String sectionLabel;
  final String? subjectId;
  final String? subjectName;
  final String date;
  final String logType;
  final String description;
  final String? dueDate;
  final int acknowledgmentCount;
  const _WorkLogEntry({
    required this.id, required this.classSectionId, required this.sectionLabel,
    this.subjectId, this.subjectName, required this.date, required this.logType,
    required this.description, this.dueDate, this.acknowledgmentCount = 0,
  });
  factory _WorkLogEntry.fromJson(Map<String, dynamic> j) => _WorkLogEntry(
        id: j['id'].toString(), classSectionId: j['class_section_id']?.toString() ?? '',
        sectionLabel: j['section_label'] as String? ?? '',
        subjectId: j['subject_id']?.toString(), subjectName: j['subject_name'] as String?,
        date: j['date'] as String? ?? '', logType: j['log_type'] as String? ?? 'classwork',
        description: j['description'] as String? ?? '', dueDate: j['due_date'] as String?,
        acknowledgmentCount: j['acknowledgment_count'] as int? ?? 0,
      );
}

// ── Attendance stat helpers ───────────────────────────────────────────────────
int _countByStatus(List<_AttendanceStudent> ss, String status) =>
    ss.where((s) => s.status == status).length;

Map<String, String> _buildSubmitPayload(List<_AttendanceStudent> ss) {
  final m = <String, String>{};
  for (final s in ss) {
    if (s.status.isNotEmpty) m[s.id] = s.status;
  }
  return m;
}

// ══════════════════════════════════════════════════════════════════════════════
// TESTS
// ══════════════════════════════════════════════════════════════════════════════

void main() {
  // ── SchoolInfo ────────────────────────────────────────────────────────────
  group('SchoolInfo.fromJson', () {
    test('parses all fields', () {
      final s = _SchoolInfo.fromJson({'id': '1', 'name': 'Sunrise', 'code': 'SRS', 'logo_url': 'https://logo.png'});
      expect(s.id, '1');
      expect(s.name, 'Sunrise');
      expect(s.code, 'SRS');
      expect(s.logoUrl, 'https://logo.png');
    });
    test('logoUrl optional null', () {
      final s = _SchoolInfo.fromJson({'id': '2', 'name': 'X', 'code': 'X'});
      expect(s.logoUrl, isNull);
    });
    test('id coerced from int', () {
      final s = _SchoolInfo.fromJson({'id': 99, 'name': 'Y', 'code': 'Y'});
      expect(s.id, '99');
    });
  });

  // ── AuthResponse ──────────────────────────────────────────────────────────
  group('AuthResponse.fromJson', () {
    test('parses all fields', () {
      final a = _AuthResponse.fromJson({
        'access_token': 'tok123',
        'teacher_name': 'Ravi Kumar',
        'school_name': 'Sunrise',
        'role': 'teacher',
        'teacher_id': 42,
        'must_change_password': true,
      });
      expect(a.token, 'tok123');
      expect(a.teacherName, 'Ravi Kumar');
      expect(a.role, 'teacher');
      expect(a.teacherId, '42');
      expect(a.mustChangePassword, isTrue);
    });
    test('mustChangePassword defaults false', () {
      final a = _AuthResponse.fromJson({
        'access_token': 't', 'teacher_name': 'T', 'school_name': 'S', 'role': 'teacher', 'teacher_id': '1',
      });
      expect(a.mustChangePassword, isFalse);
    });
  });

  // ── StudentSearchResult ───────────────────────────────────────────────────
  group('StudentSearchResult.fromJson', () {
    test('parses full record', () {
      final r = _StudentSearchResult.fromJson({
        'id': 'stu-1', 'name': 'Aarav Singh', 'admission_number': 'ADM001',
        'guardian_name': 'Rajiv Singh', 'guardian_phone': '9876543210',
        'roll_no': '15', 'class_label': '8A',
      });
      expect(r.id, 'stu-1');
      expect(r.name, 'Aarav Singh');
      expect(r.admissionNumber, 'ADM001');
      expect(r.guardianName, 'Rajiv Singh');
      expect(r.rollNo, '15');
      expect(r.classLabel, '8A');
    });
    test('optional fields null when absent', () {
      final r = _StudentSearchResult.fromJson({'id': '1', 'name': 'Priya'});
      expect(r.admissionNumber, '');
      expect(r.guardianName, isNull);
      expect(r.rollNo, isNull);
    });
    test('roll_no coerced from int', () {
      final r = _StudentSearchResult.fromJson({'id': '1', 'name': 'X', 'roll_no': 5});
      expect(r.rollNo, '5');
    });
  });

  // ── TodoItem.fromJson ─────────────────────────────────────────────────────
  group('TodoItem.fromJson', () {
    test('parses complete todo', () {
      final t = _TodoItem.fromJson({
        'id': 'td-1', 'title': 'Grade papers', 'notes': 'Check chapter 3',
        'due_date': '2026-08-01', 'is_personal': true, 'is_completed': false,
        'status': 'in_progress', 'completed_at': null,
      });
      expect(t.id, 'td-1');
      expect(t.title, 'Grade papers');
      expect(t.isPersonal, isTrue);
      expect(t.status, 'in_progress');
      expect(t.dueDate, '2026-08-01');
    });
    test('status defaults to done when is_completed=true and status absent', () {
      final t = _TodoItem.fromJson({'id': '1', 'title': 'X', 'is_personal': false, 'is_completed': true});
      expect(t.status, 'done');
    });
    test('status defaults to todo when is_completed=false and status absent', () {
      final t = _TodoItem.fromJson({'id': '1', 'title': 'X', 'is_personal': false, 'is_completed': false});
      expect(t.status, 'todo');
    });
    test('notes optional null', () {
      final t = _TodoItem.fromJson({'id': '1', 'title': 'X', 'is_personal': false, 'is_completed': false});
      expect(t.notes, isNull);
    });
  });

  // ── Todo active/done split ────────────────────────────────────────────────
  group('Todo active/done split', () {
    final todos = [
      _TodoItem(id: '1', title: 'A', isPersonal: false, isCompleted: false, status: 'todo'),
      _TodoItem(id: '2', title: 'B', isPersonal: false, isCompleted: false, status: 'in_progress'),
      _TodoItem(id: '3', title: 'C', isPersonal: false, isCompleted: true, status: 'done'),
      _TodoItem(id: '4', title: 'D', isPersonal: false, isCompleted: true, status: 'done'),
    ];
    test('active excludes done', () {
      final active = todos.where((t) => t.status != 'done').toList();
      expect(active.length, 2);
    });
    test('done only includes completed', () {
      final done = todos.where((t) => t.status == 'done').toList();
      expect(done.length, 2);
    });
  });

  // ── Todo overdue logic ────────────────────────────────────────────────────
  group('_isTodoOverdue', () {
    test('done todo never overdue', () {
      final t = _TodoItem(id: '1', title: 'X', isPersonal: false, isCompleted: true,
          status: 'done', dueDate: '2020-01-01');
      expect(_isTodoOverdue(t), isFalse);
    });
    test('no dueDate never overdue', () {
      final t = _TodoItem(id: '1', title: 'X', isPersonal: false, isCompleted: false, status: 'todo');
      expect(_isTodoOverdue(t), isFalse);
    });
    test('past dueDate is overdue', () {
      final t = _TodoItem(id: '1', title: 'X', isPersonal: false, isCompleted: false,
          status: 'todo', dueDate: '2020-01-01');
      expect(_isTodoOverdue(t), isTrue);
    });
    test('far-future dueDate not overdue', () {
      final t = _TodoItem(id: '1', title: 'X', isPersonal: false, isCompleted: false,
          status: 'todo', dueDate: '2099-12-31');
      expect(_isTodoOverdue(t), isFalse);
    });
  });

  // ── Todo date formatting ──────────────────────────────────────────────────
  group('Todo date formatting', () {
    test('ISO → d/m/yyyy', () => expect(_formatTodoDueDate('2026-07-15'), '15/7/2026'));
    test('invalid string returned as-is', () => expect(_formatTodoDueDate('not-a-date'), 'not-a-date'));
    test('due-date payload format', () {
      final d = DateTime(2026, 8, 5);
      expect(_dueDatePayload(d), '2026-08-05');
    });
    test('single-digit month padded', () {
      final d = DateTime(2026, 3, 9);
      expect(_dueDatePayload(d), '2026-03-09');
    });
  });

  // ── TestSummary.fromJson ──────────────────────────────────────────────────
  group('TestSummary.fromJson', () {
    test('parses scheduled test', () {
      final t = _TestSummary.fromJson({
        'id': 'ts-1', 'title': 'Chapter 3 Test', 'subject': 'Maths', 'class_name': '8A',
        'status': 'finalized', 'total_marks': 50.0, 'scheduled_date': '2026-08-10',
        'question_count': 25, 'score_count': 30, 'work_type': 'exam',
        'exam_duration_minutes': 90,
      });
      expect(t.id, 'ts-1');
      expect(t.status, 'finalized');
      expect(t.totalMarks, 50.0);
      expect(t.scheduledDate, DateTime(2026, 8, 10));
      expect(t.questionCount, 25);
      expect(t.durationMinutes, 90);
    });
    test('status defaults to draft', () {
      final t = _TestSummary.fromJson({'id': '1', 'title': 'T', 'created_at': ''});
      expect(t.status, 'draft');
    });
    test('null scheduledDate stays null', () {
      final t = _TestSummary.fromJson({'id': '1', 'title': 'T', 'created_at': ''});
      expect(t.scheduledDate, isNull);
    });
    test('totalMarks from int JSON', () {
      final t = _TestSummary.fromJson({'id': '1', 'title': 'T', 'total_marks': 100, 'created_at': ''});
      expect(t.totalMarks, 100.0);
    });
  });

  // ── TestQuestion.fromJson ─────────────────────────────────────────────────
  group('TestQuestion.fromJson', () {
    test('prefers custom_question_text over diksha', () {
      final q = _TestQuestion.fromJson({
        'order': 1, 'marks': 2.0,
        'custom_question_text': 'What is 2+2?',
        'question': {'question_text': 'DIKSHA question'},
      });
      expect(q.questionText, 'What is 2+2?');
    });
    test('falls back to diksha when custom is null', () {
      final q = _TestQuestion.fromJson({
        'order': 2, 'marks': 1.0,
        'custom_question_text': null,
        'question': {'question_text': 'DIKSHA question'},
      });
      expect(q.questionText, 'DIKSHA question');
    });
    test('falls back to diksha when custom is empty string', () {
      final q = _TestQuestion.fromJson({
        'order': 3, 'marks': 1.0,
        'custom_question_text': '',
        'question': {'question_text': 'DIKSHA only'},
      });
      expect(q.questionText, 'DIKSHA only');
    });
    test('empty string when both absent', () {
      final q = _TestQuestion.fromJson({'order': 0, 'marks': 0});
      expect(q.questionText, '');
    });
    test('marks from int', () {
      final q = _TestQuestion.fromJson({'order': 1, 'marks': 5});
      expect(q.marks, 5.0);
    });
  });

  // ── StudentScore.fromJson ─────────────────────────────────────────────────
  group('StudentScore.fromJson', () {
    test('parses scored student', () {
      final s = _StudentScore.fromJson({
        'roll_no': '12', 'student_name': 'Priya Mehta', 'score': 42.5, 'is_absent': false,
      });
      expect(s.rollNo, '12');
      expect(s.name, 'Priya Mehta');
      expect(s.marks, 42.5);
      expect(s.isAbsent, isFalse);
    });
    test('absent student has null marks', () {
      final s = _StudentScore.fromJson({'roll_no': '5', 'student_name': 'Ravi', 'is_absent': true});
      expect(s.marks, isNull);
      expect(s.isAbsent, isTrue);
    });
    test('falls back to name field when student_name absent', () {
      final s = _StudentScore.fromJson({'roll_no': '1', 'name': 'Kiran', 'is_absent': false});
      expect(s.name, 'Kiran');
    });
    test('roll_no coerced from int', () {
      final s = _StudentScore.fromJson({'roll_no': 7, 'student_name': 'X', 'is_absent': false});
      expect(s.rollNo, '7');
    });
  });

  // ── TestScoresResponse.fromJson ───────────────────────────────────────────
  group('TestScoresResponse.fromJson', () {
    final json = {
      'scores': [
        {'roll_no': '1', 'student_name': 'A', 'score': 80, 'is_absent': false},
        {'roll_no': '2', 'student_name': 'B', 'score': 45, 'is_absent': false},
        {'roll_no': '3', 'student_name': 'C', 'is_absent': true},
      ],
      'report': {
        'average_percentage': 62.5,
        'highest': 80.0,
        'below_40_percent': ['stu-3'],
      },
    };
    test('parses scores list', () {
      final r = _TestScoresResponse.fromJson(json);
      expect(r.scores.length, 3);
    });
    test('parses report stats', () {
      final r = _TestScoresResponse.fromJson(json);
      expect(r.classAverage, 62.5);
      expect(r.highestMark, 80.0);
      expect(r.belowAverageCount, 1);
    });
    test('empty response returns empty scores and null stats', () {
      final r = _TestScoresResponse.fromJson({});
      expect(r.scores, isEmpty);
      expect(r.classAverage, isNull);
      expect(r.belowAverageCount, isNull);
    });
  });

  // ── SpacedRepChapter.fromJson ─────────────────────────────────────────────
  group('SpacedRepChapter.fromJson', () {
    test('parses full entry', () {
      final c = _SpacedRepChapter.fromJson({
        'chapter_id': 'ch-1', 'chapter_name': 'Fractions', 'subject_name': 'Maths',
        'avg_pct': 38.5, 'last_tested': '2026-06-10', 'urgency': 'high_score',
      });
      expect(c.chapterId, 'ch-1');
      expect(c.avgPct, 38.5);
      expect(c.urgency, 'high_score');
    });
    test('defaults urgency to low_score', () {
      final c = _SpacedRepChapter.fromJson({'chapter_id': '1', 'chapter_name': '', 'subject_name': ''});
      expect(c.urgency, 'low_score');
    });
    test('avgPct null when absent', () {
      final c = _SpacedRepChapter.fromJson({'chapter_id': '1', 'chapter_name': '', 'subject_name': ''});
      expect(c.avgPct, isNull);
    });
    test('chapter_id coerced from int', () {
      final c = _SpacedRepChapter.fromJson({'chapter_id': 42, 'chapter_name': '', 'subject_name': ''});
      expect(c.chapterId, '42');
    });
  });

  // ── TimetableSlot.fromJson ────────────────────────────────────────────────
  group('TimetableSlot.fromJson', () {
    test('parses slot', () {
      final s = _TimetableSlot.fromJson({
        'id': 'slot-1', 'day_of_week': 2, 'period_number': 3,
        'start_time': '09:00', 'end_time': '09:45',
        'subject_name': 'Maths', 'section_label': '8A', 'class_section_id': 'cs-1',
      });
      expect(s.dayOfWeek, 2);
      expect(s.periodNumber, 3);
      expect(s.startTime, '09:00');
      expect(s.subjectName, 'Maths');
      expect(s.sectionLabel, '8A');
    });
    test('optional time fields null when absent', () {
      final s = _TimetableSlot.fromJson({
        'id': '1', 'day_of_week': 1, 'period_number': 1,
        'section_label': 'A', 'class_section_id': 'cs',
      });
      expect(s.startTime, isNull);
      expect(s.endTime, isNull);
      expect(s.subjectName, isNull);
    });
  });

  // ── SectionInfo.fromJson ──────────────────────────────────────────────────
  group('SectionInfo.fromJson', () {
    test('parses correctly', () {
      final s = _SectionInfo.fromJson({'id': 'sec-1', 'label': '8A'});
      expect(s.id, 'sec-1');
      expect(s.label, '8A');
    });
    test('id coerced from int', () {
      final s = _SectionInfo.fromJson({'id': 7, 'label': '7B'});
      expect(s.id, '7');
    });
  });

  // ── AttendanceStudent.fromJson ────────────────────────────────────────────
  group('AttendanceStudent.fromJson', () {
    test('parses student', () {
      final s = _AttendanceStudent.fromJson({
        'id': '42', 'name': 'Rohan Gupta', 'roll_no': '10',
        'gender': 'male', 'photo_url': 'https://example.com/photo.jpg',
      });
      expect(s.id, '42');
      expect(s.name, 'Rohan Gupta');
      expect(s.rollNo, '10');
      expect(s.gender, 'male');
      expect(s.status, ''); // default
    });
    test('status mutable after parsing', () {
      final s = _AttendanceStudent.fromJson({'id': '1', 'name': 'X', 'roll_no': '1'});
      s.status = 'present';
      expect(s.status, 'present');
    });
    test('roll_no coerced from int', () {
      final s = _AttendanceStudent.fromJson({'id': '1', 'name': 'X', 'roll_no': 5});
      expect(s.rollNo, '5');
    });
  });

  // ── Attendance stat counting ──────────────────────────────────────────────
  group('Attendance stat counting', () {
    final ss = [
      _AttendanceStudent(id: '1', name: 'A', rollNo: '1', status: 'present'),
      _AttendanceStudent(id: '2', name: 'B', rollNo: '2', status: 'present'),
      _AttendanceStudent(id: '3', name: 'C', rollNo: '3', status: 'absent'),
      _AttendanceStudent(id: '4', name: 'D', rollNo: '4', status: 'late'),
      _AttendanceStudent(id: '5', name: 'E', rollNo: '5', status: ''),
    ];
    test('present count', () => expect(_countByStatus(ss, 'present'), 2));
    test('absent count', () => expect(_countByStatus(ss, 'absent'), 1));
    test('late count', () => expect(_countByStatus(ss, 'late'), 1));
    test('unmarked count', () => expect(_countByStatus(ss, ''), 1));
    test('mark-all present', () {
      final students = [
        _AttendanceStudent(id: '1', name: 'A', rollNo: '1'),
        _AttendanceStudent(id: '2', name: 'B', rollNo: '2'),
      ];
      for (final s in students) s.status = 'present';
      expect(_countByStatus(students, 'present'), 2);
    });
    test('clear resets to empty', () {
      final students = [_AttendanceStudent(id: '1', name: 'A', rollNo: '1', status: 'present')];
      for (final s in students) s.status = '';
      expect(_countByStatus(students, ''), 1);
    });
  });

  // ── Submit payload only includes marked students ──────────────────────────
  group('Attendance submit payload', () {
    test('excludes unmarked students', () {
      final ss = [
        _AttendanceStudent(id: 'a', name: 'A', rollNo: '1', status: 'present'),
        _AttendanceStudent(id: 'b', name: 'B', rollNo: '2', status: ''),
        _AttendanceStudent(id: 'c', name: 'C', rollNo: '3', status: 'absent'),
      ];
      final payload = _buildSubmitPayload(ss);
      expect(payload.length, 2);
      expect(payload['a'], 'present');
      expect(payload['c'], 'absent');
      expect(payload.containsKey('b'), isFalse);
    });
    test('empty payload when all unmarked', () {
      final ss = [_AttendanceStudent(id: '1', name: 'A', rollNo: '1')];
      expect(_buildSubmitPayload(ss), isEmpty);
    });
  });

  // ── LeaveRequest.fromJson ─────────────────────────────────────────────────
  group('LeaveRequest.fromJson', () {
    test('parses full request', () {
      final l = _LeaveRequest.fromJson({
        'id': 'lv-1', 'leave_type': 'sick', 'start_date': '2026-08-01',
        'end_date': '2026-08-03', 'days_count': 3, 'reason': 'Fever', 'status': 'pending',
      });
      expect(l.id, 'lv-1');
      expect(l.leaveType, 'sick');
      expect(l.daysCount, 3);
      expect(l.reason, 'Fever');
      expect(l.status, 'pending');
    });
    test('leaveType defaults to casual', () {
      final l = _LeaveRequest.fromJson({'id': '1', 'start_date': '', 'end_date': '', 'created_at': ''});
      expect(l.leaveType, 'casual');
    });
    test('daysCount defaults to 1', () {
      final l = _LeaveRequest.fromJson({'id': '1', 'start_date': '', 'end_date': '', 'created_at': ''});
      expect(l.daysCount, 1);
    });
    test('status defaults to pending', () {
      final l = _LeaveRequest.fromJson({'id': '1', 'start_date': '', 'end_date': '', 'created_at': ''});
      expect(l.status, 'pending');
    });
  });

  // ── AnalysisInsight.fromJson ──────────────────────────────────────────────
  group('AnalysisInsight.fromJson', () {
    test('parses summary and concern areas', () {
      final a = _AnalysisInsight.fromJson({
        'summary': 'Class is struggling with algebra.',
        'concern_areas': ['Algebra', 'Fractions'],
        'recommended_action': 'Assign practice sets',
      });
      expect(a.summary, 'Class is struggling with algebra.');
      expect(a.concernAreas, ['Algebra', 'Fractions']);
      expect(a.recommendedAction, 'Assign practice sets');
    });
    test('empty concern_areas list', () {
      final a = _AnalysisInsight.fromJson({'concern_areas': []});
      expect(a.concernAreas, isEmpty);
    });
    test('missing fields default to empty', () {
      final a = _AnalysisInsight.fromJson({});
      expect(a.summary, '');
      expect(a.concernAreas, isEmpty);
    });
  });

  // ── TestAnalysisResult.fromJson ───────────────────────────────────────────
  group('TestAnalysisResult.fromJson', () {
    final json = {
      'generated_at': '2026-07-10T12:00:00Z',
      'student_count': 30,
      'up_to_date': true,
      'analysis': {
        'class_insight': {
          'summary': 'Good overall.',
          'concern_areas': ['Geometry'],
          'recommended_action': 'More practice.',
        },
        'student_plans': [
          {'student_id': 's1', 'plan': 'remedial'},
          {'student_id': 's2', 'plan': 'advanced'},
        ],
        'suggested_followup_test': 'Mid-term revision',
      },
    };
    test('parses all nested fields', () {
      final r = _TestAnalysisResult.fromJson(json);
      expect(r.studentCount, 30);
      expect(r.isUpToDate, isTrue);
      expect(r.summary, 'Good overall.');
      expect(r.concernAreas, ['Geometry']);
      expect(r.studentPlans.length, 2);
      expect(r.suggestedFollowup, 'Mid-term revision');
    });
    test('empty analysis returns safe defaults', () {
      final r = _TestAnalysisResult.fromJson({'student_count': 0, 'generated_at': ''});
      expect(r.summary, '');
      expect(r.concernAreas, isEmpty);
      expect(r.studentPlans, isEmpty);
      expect(r.suggestedFollowup, isNull);
      expect(r.isUpToDate, isFalse);
    });
  });

  // ── TeacherSearchResult ───────────────────────────────────────────────────
  group('TeacherSearchResult', () {
    test('isEmpty true when all empty', () {
      final r = _TeacherSearchResult.fromJson({});
      expect(r.isEmpty, isTrue);
    });
    test('isEmpty false when students present', () {
      final r = _TeacherSearchResult.fromJson({
        'students': [{'id': '1', 'name': 'Aarav'}],
      });
      expect(r.isEmpty, isFalse);
      expect(r.students.length, 1);
    });
    test('parses all three buckets', () {
      final r = _TeacherSearchResult.fromJson({
        'students': [{'id': '1'}],
        'tests': [{'id': 't1'}, {'id': 't2'}],
        'announcements': [{'id': 'a1'}],
      });
      expect(r.students.length, 1);
      expect(r.tests.length, 2);
      expect(r.announcements.length, 1);
    });
  });

  // ── SyllabusChapter / SyllabusSubject ─────────────────────────────────────
  group('SyllabusChapter.fromJson', () {
    test('parses all fields', () {
      final ch = _SyllabusChapter.fromJson({'id': 'c1', 'number': 2, 'name': 'Fractions', 'status': 'in_progress'});
      expect(ch.status, 'in_progress');
    });
    test('defaults status to not_started', () {
      final ch = _SyllabusChapter.fromJson({'id': 'c2', 'number': 1, 'name': 'Intro'});
      expect(ch.status, 'not_started');
    });
  });

  group('SyllabusSubject computed properties', () {
    _SyllabusSubject make(List<String> statuses) => _SyllabusSubject(
          id: 's', name: 'Maths',
          chapters: statuses.asMap().entries.map((e) => _SyllabusChapter(
                id: 'c${e.key}', number: e.key + 1, name: 'Ch${e.key}', status: e.value,
              )).toList(),
        );
    test('pct = 0.0 when no chapters', () {
      final sub = _SyllabusSubject(id: 's', name: 'X', chapters: []);
      expect(sub.pct, 0.0);
    });
    test('pct = 1.0 when all completed', () => expect(make(['completed', 'completed']).pct, 1.0));
    test('pct = 0.5 for half completed', () => expect(make(['completed', 'not_started']).pct, 0.5));
    test('in_progress not counted in pct', () {
      final sub = make(['in_progress', 'not_started']);
      expect(sub.pct, 0.0);
      expect(sub.inProgress, 1);
    });
    test('fromJson maps chapters', () {
      final sub = _SyllabusSubject.fromJson({
        'subject_id': 'sub-1', 'subject_name': 'Science',
        'chapters': [
          {'id': 'c1', 'number': 1, 'name': 'Matter', 'status': 'completed'},
          {'id': 'c2', 'number': 2, 'name': 'Energy'},
        ],
      });
      expect(sub.total, 2);
      expect(sub.completed, 1);
    });
  });

  group('_nextStatus cycle', () {
    test('not_started → in_progress', () => expect(_nextStatus('not_started'), 'in_progress'));
    test('in_progress → completed', () => expect(_nextStatus('in_progress'), 'completed'));
    test('completed → not_started', () => expect(_nextStatus('completed'), 'not_started'));
    test('unknown → not_started', () => expect(_nextStatus('???'), 'not_started'));
  });

  // ── Announcement.fromJson ─────────────────────────────────────────────────
  group('Announcement.fromJson', () {
    test('parses full announcement', () {
      final a = _Announcement.fromJson({
        'id': '1', 'title': 'Sports Day', 'body': 'Friday!', 'audience': 'all',
        'is_pinned': true, 'allow_comments': true, 'created_at': '2026-07-01',
        'author_name': 'Principal', 'comment_count': 5, 'like_count': 12,
        'liked_by_me': false, 'images': [{'id': 'i1', 'gcs_url': 'u', 'position': 0}],
      });
      expect(a.isPinned, isTrue);
      expect(a.likeCount, 12);
      expect(a.imageCount, 1);
    });
    test('defaults when fields absent', () {
      final a = _Announcement.fromJson({'id': '2', 'title': '', 'body': '', 'created_at': ''});
      expect(a.audience, 'all');
      expect(a.likeCount, 0);
      expect(a.imageCount, 0);
    });
    test('id coerced from int', () {
      final a = _Announcement.fromJson({'id': 99, 'title': '', 'body': '', 'created_at': ''});
      expect(a.id, '99');
    });
  });

  // ── AnnouncementComment.fromJson ──────────────────────────────────────────
  group('AnnouncementComment.fromJson', () {
    test('top-level comment', () {
      final c = _AnnouncementComment.fromJson({
        'id': 'c1', 'body': 'Great!', 'author_name': 'Ravi',
        'created_at': '2026-07-02', 'parent_id': null, 'like_count': 3, 'liked_by_me': true,
      });
      expect(c.parentId, isNull);
      expect(c.likedByMe, isTrue);
    });
    test('reply has parentId', () {
      final c = _AnnouncementComment.fromJson({'id': 'c2', 'body': '', 'created_at': '', 'parent_id': 'c1'});
      expect(c.parentId, 'c1');
    });
    test('defaults likeCount=0', () {
      final c = _AnnouncementComment.fromJson({'id': 'c', 'body': '', 'created_at': ''});
      expect(c.likeCount, 0);
    });
  });

  // ── Optimistic like toggle ────────────────────────────────────────────────
  group('Optimistic like toggle', () {
    test('like: count +1, flag true', () {
      bool liked = false; int count = 5;
      liked = !liked; count += liked ? 1 : -1;
      expect(liked, isTrue); expect(count, 6);
    });
    test('unlike: count -1, flag false', () {
      bool liked = true; int count = 6;
      liked = !liked; count += liked ? 1 : -1;
      expect(liked, isFalse); expect(count, 5);
    });
    test('rollback restores original', () {
      bool liked = false; int count = 5;
      final was = liked;
      liked = !liked; count += liked ? 1 : -1;
      liked = was; count += was ? 1 : -1;
      expect(liked, isFalse); expect(count, 5);
    });
  });

  // ── WorkLogEntry.fromJson ─────────────────────────────────────────────────
  group('WorkLogEntry.fromJson', () {
    test('parses homework entry', () {
      final wl = _WorkLogEntry.fromJson({
        'id': 'wl-1', 'class_section_id': 's1', 'section_label': '8A',
        'subject_name': 'Maths', 'date': '2026-07-10', 'log_type': 'homework',
        'description': 'Ex 3.1', 'due_date': '2026-07-11', 'acknowledgment_count': 3,
      });
      expect(wl.logType, 'homework');
      expect(wl.dueDate, '2026-07-11');
      expect(wl.acknowledgmentCount, 3);
    });
    test('logType defaults to classwork', () {
      final wl = _WorkLogEntry.fromJson({'id': '1', 'class_section_id': '', 'section_label': '', 'date': '', 'description': '', 'created_at': ''});
      expect(wl.logType, 'classwork');
    });
    test('acknowledgmentCount defaults to 0', () {
      final wl = _WorkLogEntry.fromJson({'id': '1', 'class_section_id': '', 'section_label': '', 'date': '', 'description': '', 'created_at': ''});
      expect(wl.acknowledgmentCount, 0);
    });
  });
}
