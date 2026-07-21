import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cache.dart';
import 'device_context.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class SchoolInfo {
  final String id;
  final String name;
  final String code;
  final String? logoUrl;

  const SchoolInfo({required this.id, required this.name, required this.code, this.logoUrl});

  factory SchoolInfo.fromJson(Map<String, dynamic> j) => SchoolInfo(
        id: j['id'].toString(),
        name: j['name'] as String,
        code: j['code'] as String,
        logoUrl: j['logo_url'] as String?,
      );
}

class AuthResponse {
  final String token;
  final String teacherName;
  final String schoolName;
  final String role;
  final String teacherId;
  final bool mustChangePassword;
  final List<String> functionalTags;

  const AuthResponse({
    required this.token,
    required this.teacherName,
    required this.schoolName,
    required this.role,
    required this.teacherId,
    this.mustChangePassword = false,
    this.functionalTags = const [],
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j['access_token'] as String,
        teacherName: j['teacher_name'] as String,
        schoolName: j['school_name'] as String,
        role: j['role'] as String,
        teacherId: j['teacher_id'].toString(),
        mustChangePassword: j['must_change_password'] as bool? ?? false,
        functionalTags: (j['functional_tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class StudentSearchResult {
  final String id;
  final String name;
  final String admissionNumber;
  final String? guardianName;
  final String? guardianPhone;
  final String? rollNo;
  final String? classLabel;

  const StudentSearchResult({
    required this.id,
    required this.name,
    required this.admissionNumber,
    this.guardianName,
    this.guardianPhone,
    this.rollNo,
    this.classLabel,
  });

  factory StudentSearchResult.fromJson(Map<String, dynamic> j) => StudentSearchResult(
        id: j['id'].toString(),
        name: j['name'] as String,
        admissionNumber: j['admission_number'] as String? ?? '',
        guardianName: j['guardian_name'] as String?,
        guardianPhone: j['guardian_phone'] as String?,
        rollNo: j['roll_no']?.toString(),
        classLabel: j['class_label'] as String?,
      );
}

class TodoItem {
  final String id;
  final String title;
  final String? notes;
  final String? dueDate;
  final bool isPersonal;
  final bool isCompleted;
  final String status; // "todo" | "in_progress" | "done"
  final String? createdAt;
  final String? updatedAt;
  final String? completedAt;

  const TodoItem({
    required this.id,
    required this.title,
    this.notes,
    this.dueDate,
    required this.isPersonal,
    required this.isCompleted,
    this.status = 'todo',
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory TodoItem.fromJson(Map<String, dynamic> j) => TodoItem(
        id: j['id'].toString(),
        title: j['title'] as String,
        notes: j['notes'] as String?,
        dueDate: j['due_date'] as String?,
        isPersonal: j['is_personal'] as bool? ?? false,
        isCompleted: j['is_completed'] as bool? ?? false,
        status: j['status'] as String? ?? (j['is_completed'] == true ? 'done' : 'todo'),
        createdAt: j['created_at'] as String?,
        updatedAt: j['updated_at'] as String?,
        completedAt: j['completed_at'] as String?,
      );
}

class TestSummary {
  final String id;
  final String title;
  final String subject;
  final String className;
  final String status;
  final double totalMarks;
  final DateTime? scheduledDate;
  final DateTime createdAt;
  final int questionCount;
  final int scoreCount;
  final String? workType;
  final int? durationMinutes;
  final String? variantLevel;

  const TestSummary({
    required this.id,
    required this.title,
    required this.subject,
    required this.className,
    required this.status,
    required this.totalMarks,
    this.scheduledDate,
    required this.createdAt,
    required this.questionCount,
    required this.scoreCount,
    this.workType,
    this.durationMinutes,
    this.variantLevel,
  });

  factory TestSummary.fromJson(Map<String, dynamic> j) => TestSummary(
        id: j['id'].toString(),
        title: j['title'] as String,
        subject: j['subject'] as String? ?? '',
        className: j['class_name'] as String? ?? '',
        status: j['status'] as String? ?? 'draft',
        totalMarks: (j['total_marks'] as num?)?.toDouble() ?? 0,
        scheduledDate: j['scheduled_date'] != null
            ? DateTime.tryParse(j['scheduled_date'] as String)
            : null,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
        questionCount: j['question_count'] as int? ?? 0,
        scoreCount: j['score_count'] as int? ?? 0,
        workType: j['work_type'] as String?,
        durationMinutes: j['exam_duration_minutes'] as int?,
        variantLevel: j['variant_level'] as String?,
      );
}

class TestQuestion {
  final int order;
  final double marks;
  final String questionText;

  const TestQuestion({required this.order, required this.marks, required this.questionText});

  factory TestQuestion.fromJson(Map<String, dynamic> j) {
    final custom = j['custom_question_text'] as String?;
    final diksha = (j['question'] as Map<String, dynamic>?)?['question_text'] as String?;
    return TestQuestion(
      order: j['order'] as int? ?? 0,
      marks: (j['marks'] as num?)?.toDouble() ?? 0,
      questionText: (custom?.isNotEmpty == true ? custom : diksha) ?? '',
    );
  }
}

class StudentScore {
  final String rollNo;
  final String name;
  final double? marks;
  final bool isAbsent;
  final String? remarks;

  const StudentScore({
    required this.rollNo,
    required this.name,
    this.marks,
    required this.isAbsent,
    this.remarks,
  });

  factory StudentScore.fromJson(Map<String, dynamic> j) => StudentScore(
        rollNo: j['roll_no']?.toString() ?? '',
        name: j['student_name'] as String? ?? j['name'] as String? ?? '',
        marks: (j['score'] as num?)?.toDouble(),
        isAbsent: j['is_absent'] as bool? ?? false,
        remarks: j['remarks'] as String?,
      );
}

class TestScoresResponse {
  final List<StudentScore> scores;
  final double? classAverage;
  final double? highestMark;
  final int? belowAverageCount;

  const TestScoresResponse({
    required this.scores,
    this.classAverage,
    this.highestMark,
    this.belowAverageCount,
  });

  factory TestScoresResponse.fromJson(Map<String, dynamic> j) {
    final raw = j['scores'] as List<dynamic>? ?? [];
    final report = j['report'] as Map<String, dynamic>?;
    return TestScoresResponse(
      scores: raw.map((e) => StudentScore.fromJson(e as Map<String, dynamic>)).toList(),
      classAverage: (report?['average_percentage'] as num?)?.toDouble(),
      highestMark: (report?['highest'] as num?)?.toDouble(),
      belowAverageCount: (report?['below_40_percent'] as List?)?.length,
    );
  }
}

class SpacedRepChapter {
  final String chapterId;
  final String chapterName;
  final String subjectName;
  final double? avgPct;
  final String? lastTested;
  final String urgency;

  const SpacedRepChapter({
    required this.chapterId,
    required this.chapterName,
    required this.subjectName,
    this.avgPct,
    this.lastTested,
    required this.urgency,
  });

  factory SpacedRepChapter.fromJson(Map<String, dynamic> j) => SpacedRepChapter(
    chapterId: j['chapter_id']?.toString() ?? '',
    chapterName: j['chapter_name'] as String? ?? '',
    subjectName: j['subject_name'] as String? ?? '',
    avgPct: (j['avg_pct'] as num?)?.toDouble(),
    lastTested: j['last_tested'] as String?,
    urgency: j['urgency'] as String? ?? 'low_score',
  );
}

class TimetableSlot {
  final String id;
  final int dayOfWeek;
  final int periodNumber;
  final String? startTime;
  final String? endTime;
  final String? subjectName;
  final String sectionLabel;
  final String classSectionId;

  const TimetableSlot({
    required this.id,
    required this.dayOfWeek,
    required this.periodNumber,
    this.startTime,
    this.endTime,
    this.subjectName,
    required this.sectionLabel,
    required this.classSectionId,
  });

  factory TimetableSlot.fromJson(Map<String, dynamic> j) => TimetableSlot(
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

class SectionInfo {
  final String id;
  final String label;

  const SectionInfo({required this.id, required this.label});

  factory SectionInfo.fromJson(Map<String, dynamic> j) => SectionInfo(
        id: j['id'].toString(),
        label: j['label'] as String,
      );
}

class AttendanceStudent {
  final String id;
  final String name;
  final String rollNo;
  final String? gender;
  final String? photoUrl;
  String status; // present | absent | late | ''

  AttendanceStudent({
    required this.id,
    required this.name,
    required this.rollNo,
    this.gender,
    this.photoUrl,
    this.status = '',
  });

  factory AttendanceStudent.fromJson(Map<String, dynamic> j) => AttendanceStudent(
        id: j['id'].toString(),
        name: j['name'] as String,
        rollNo: j['roll_no']?.toString() ?? '',
        gender: j['gender'] as String?,
        photoUrl: j['photo_url'] as String?,
      );
}

class LeaveRequest {
  final String id;
  final String leaveType;
  final String startDate;
  final String endDate;
  final int daysCount;
  final String? reason;
  final String status;
  final String createdAt;

  const LeaveRequest({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    this.reason,
    required this.status,
    required this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> j) => LeaveRequest(
        id: j['id'].toString(),
        leaveType: j['leave_type'] as String? ?? 'casual',
        startDate: j['start_date'] as String? ?? '',
        endDate: j['end_date'] as String? ?? '',
        daysCount: j['days_count'] as int? ?? 1,
        reason: j['reason'] as String?,
        status: j['status'] as String? ?? 'pending',
        createdAt: j['created_at'] as String? ?? '',
      );
}

class AnalysisInsight {
  final String summary;
  final List<String> concernAreas;
  final String recommendedAction;

  const AnalysisInsight({
    required this.summary,
    required this.concernAreas,
    required this.recommendedAction,
  });

  factory AnalysisInsight.fromJson(Map<String, dynamic> j) => AnalysisInsight(
        summary: j['summary'] as String? ?? '',
        concernAreas: (j['concern_areas'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        recommendedAction: j['recommended_action'] as String? ?? '',
      );
}

// ── Test analysis result (richer model for mobile Run Analysis) ──────────────

class TestAnalysisResult {
  final String generatedAt;
  final int studentCount;
  final String summary;
  final List<String> concernAreas;
  final String recommendedAction;
  final List<Map<String, dynamic>> studentPlans;
  final String? suggestedFollowup;
  final bool isUpToDate; // true when hash matched and cached result returned

  const TestAnalysisResult({
    required this.generatedAt,
    required this.studentCount,
    required this.summary,
    required this.concernAreas,
    required this.recommendedAction,
    required this.studentPlans,
    this.suggestedFollowup,
    this.isUpToDate = false,
  });

  factory TestAnalysisResult.fromJson(Map<String, dynamic> j) {
    final ci = (j['analysis'] as Map<String, dynamic>?)?['class_insight'] as Map<String, dynamic>? ?? {};
    final plans = (j['analysis'] as Map<String, dynamic>?)?['student_plans'] as List<dynamic>? ?? [];
    return TestAnalysisResult(
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

// ── Teacher global search result ──────────────────────────────────────────────

class TeacherSearchResult {
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> tests;
  final List<Map<String, dynamic>> announcements;

  const TeacherSearchResult({
    required this.students,
    required this.tests,
    required this.announcements,
  });

  bool get isEmpty => students.isEmpty && tests.isEmpty && announcements.isEmpty;

  factory TeacherSearchResult.fromJson(Map<String, dynamic> j) => TeacherSearchResult(
        students: (j['students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
        tests: (j['tests'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
        announcements: (j['announcements'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
      );
}

// ── New Models ────────────────────────────────────────────────────────────────

class AnnouncementImage {
  final String id;
  final String gcsUrl;
  final int position;
  const AnnouncementImage({required this.id, required this.gcsUrl, required this.position});
  factory AnnouncementImage.fromJson(Map<String, dynamic> j) => AnnouncementImage(
        id: j['id'].toString(),
        gcsUrl: j['gcs_url'] as String,
        position: j['position'] as int? ?? 0,
      );
}

class AnnouncementComment {
  final String id;
  final String body;
  final String? authorName;
  final String createdAt;
  final String? parentId;
  final int likeCount;
  final bool likedByMe;
  const AnnouncementComment({
    required this.id,
    required this.body,
    this.authorName,
    required this.createdAt,
    this.parentId,
    this.likeCount = 0,
    this.likedByMe = false,
  });
  factory AnnouncementComment.fromJson(Map<String, dynamic> j) => AnnouncementComment(
        id: j['id'].toString(),
        body: j['body'] as String? ?? '',
        authorName: j['author_name'] as String?,
        createdAt: j['created_at'] as String? ?? '',
        parentId: j['parent_id']?.toString(),
        likeCount: j['like_count'] as int? ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
      );
}

class Announcement {
  final String id;
  final String title;
  final String body;
  final String audience;
  final bool isPinned;
  final bool allowComments;
  final String createdAt;
  final String? authorName;
  final List<AnnouncementImage> images;
  final int commentCount;
  final int likeCount;
  final bool likedByMe;
  final Map<String, dynamic>? previewComment;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.isPinned,
    required this.allowComments,
    required this.createdAt,
    this.authorName,
    this.images = const [],
    this.commentCount = 0,
    this.likeCount = 0,
    this.likedByMe = false,
    this.previewComment,
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'].toString(),
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        audience: j['audience'] as String? ?? 'all',
        isPinned: j['is_pinned'] as bool? ?? false,
        allowComments: j['allow_comments'] as bool? ?? false,
        createdAt: j['created_at'] as String? ?? '',
        authorName: j['author_name'] as String?,
        previewComment: j['preview_comment'] as Map<String, dynamic>?,
        images: (j['images'] as List<dynamic>? ?? [])
            .map((e) => AnnouncementImage.fromJson(e as Map<String, dynamic>))
            .toList(),
        commentCount: j['comment_count'] as int? ?? 0,
        likeCount: j['like_count'] as int? ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
      );
}

class CalendarEvent {
  final String id;
  final String title;
  final String eventType;
  final String startDate;
  final String endDate;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.eventType,
    required this.startDate,
    required this.endDate,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: j['id'].toString(),
        title: j['title'] as String? ?? '',
        eventType: j['event_type'] as String? ?? 'event',
        startDate: j['start_date'] as String? ?? '',
        endDate: j['end_date'] as String? ?? '',
      );
}

class WorkLogEntry {
  final String id;
  final String classSectionId;
  final String sectionLabel;
  final String? subjectId;
  final String? subjectName;
  final String date;
  final String logType;
  final String description;
  final String? dueDate;
  final String createdAt;
  final int acknowledgmentCount;
  final String? studentName;
  final String? studentRollNo;
  final String? studentClassLabel;
  final List<String> imageUrls;

  const WorkLogEntry({
    required this.id,
    required this.classSectionId,
    required this.sectionLabel,
    this.subjectId,
    this.subjectName,
    required this.date,
    required this.logType,
    required this.description,
    this.dueDate,
    required this.createdAt,
    this.acknowledgmentCount = 0,
    this.studentName,
    this.studentRollNo,
    this.studentClassLabel,
    this.imageUrls = const [],
  });

  factory WorkLogEntry.fromJson(Map<String, dynamic> j) => WorkLogEntry(
        id: j['id'].toString(),
        classSectionId: j['class_section_id']?.toString() ?? '',
        sectionLabel: j['section_label'] as String? ?? '',
        subjectId: j['subject_id']?.toString(),
        subjectName: j['subject_name'] as String?,
        date: (j['date'] as String? ?? ''),
        logType: j['log_type'] as String? ?? 'classwork',
        description: j['description'] as String? ?? '',
        dueDate: j['due_date'] as String?,
        createdAt: j['created_at'] as String? ?? '',
        acknowledgmentCount: j['acknowledgment_count'] as int? ?? 0,
        studentName: j['student_name'] as String?,
        studentRollNo: j['student_roll_no']?.toString(),
        studentClassLabel: j['student_class_label'] as String?,
        imageUrls: (j['image_urls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class PayslipRecord {
  final int month;
  final int year;
  final double baseSalary;
  final double bonus;
  final double deductions;
  final double netPay;
  final String status;

  const PayslipRecord({
    required this.month,
    required this.year,
    required this.baseSalary,
    required this.bonus,
    required this.deductions,
    required this.netPay,
    required this.status,
  });

  factory PayslipRecord.fromJson(Map<String, dynamic> j) => PayslipRecord(
        month: j['month'] as int,
        year: j['year'] as int,
        baseSalary: (j['base_salary'] as num?)?.toDouble() ?? 0,
        bonus: (j['bonus'] as num?)?.toDouble() ?? 0,
        deductions: (j['deductions'] as num?)?.toDouble() ?? 0,
        netPay: (j['net_pay'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String? ?? 'pending',
      );
}

class ParentNotificationResult {
  final String id;
  final String message;
  final String sentAt;
  final int recipientCount;

  const ParentNotificationResult({
    required this.id,
    required this.message,
    required this.sentAt,
    required this.recipientCount,
  });

  factory ParentNotificationResult.fromJson(Map<String, dynamic> j) =>
      ParentNotificationResult(
        id: j['id'].toString(),
        message: j['message'] as String? ?? '',
        sentAt: j['sent_at'] as String? ?? '',
        recipientCount: j['recipient_count'] as int? ?? 0,
      );
}

// ── API Client ───────────────────────────────────────────────────────────────

class ApiClient {
  static const defaultBaseUrl = 'https://edutrack-api-849362142189.asia-south1.run.app';
  static const _defaultBaseUrl = defaultBaseUrl;
  static const _prefKeyUrl = 'server_url';
  static const _prefKeyToken = 'auth_token';

  // Set by AuthProvider on init — called automatically on any 401
  static Future<void> Function()? onUnauthorized;

  static Future<String> getBaseUrl() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefKeyUrl) ?? _defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKeyUrl, url.trimRight().replaceAll(RegExp(r'/$'), ''));
  }

  static Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_prefKeyToken);
  }

  static Future<void> setToken(String? token) async {
    final p = await SharedPreferences.getInstance();
    if (token == null) {
      await p.remove(_prefKeyToken);
    } else {
      await p.setString(_prefKeyToken, token);
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...DeviceContext.headers,
    };
  }

  static String _errorDetail(http.Response res) {
    try {
      final b = jsonDecode(res.body);
      return b['detail']?.toString() ?? 'Server error (${res.statusCode})';
    } catch (_) {
      return 'Server error (${res.statusCode})';
    }
  }

  static void _log(String method, String path, int status, int ms, {String? requestId, String? error}) {
    if (!kDebugMode) return;
    final rid = requestId != null ? ' [rid=$requestId]' : '';
    if (error != null) {
      dev.log('$method $path → $status (${ms}ms)$rid  ERROR: $error', name: 'API', level: 900);
    } else {
      dev.log('$method $path → $status (${ms}ms)$rid', name: 'API');
    }
  }

  static Future<dynamic> _get(String path) async {
    final base = await getBaseUrl();
    final sw = Stopwatch()..start();
    final res = await http.get(
      Uri.parse('$base$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    final ms = sw.elapsedMilliseconds;
    final rid = res.headers['x-request-id'];
    if (res.statusCode == 401) {
      _log('GET', path, 401, ms, requestId: rid, error: 'session expired');
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      _log('GET', path, res.statusCode, ms, requestId: rid, error: detail);
      throw ApiError(detail, res.statusCode);
    }
    _log('GET', path, res.statusCode, ms, requestId: rid);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body, {bool handleUnauthorized = true}) async {
    final base = await getBaseUrl();
    final sw = Stopwatch()..start();
    final res = await http.post(
      Uri.parse('$base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    final ms = sw.elapsedMilliseconds;
    final rid = res.headers['x-request-id'];
    if (res.statusCode == 401) {
      _log('POST', path, 401, ms, requestId: rid, error: 'session expired');
      if (handleUnauthorized) await onUnauthorized?.call();
      throw ApiError(handleUnauthorized ? 'Session expired. Please log in again.' : 'Invalid credentials', 401);
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      _log('POST', path, res.statusCode, ms, requestId: rid, error: detail);
      throw ApiError(detail, res.statusCode);
    }
    _log('POST', path, res.statusCode, ms, requestId: rid);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _patch(String path, Map<String, dynamic> body) async {
    final base = await getBaseUrl();
    final sw = Stopwatch()..start();
    final res = await http.patch(
      Uri.parse('$base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    final ms = sw.elapsedMilliseconds;
    final rid = res.headers['x-request-id'];
    if (res.statusCode == 401) {
      _log('PATCH', path, 401, ms, requestId: rid, error: 'session expired');
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      _log('PATCH', path, res.statusCode, ms, requestId: rid, error: detail);
      throw ApiError(detail, res.statusCode);
    }
    _log('PATCH', path, res.statusCode, ms, requestId: rid);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _delete(String path) async {
    final base = await getBaseUrl();
    final sw = Stopwatch()..start();
    final res = await http.delete(
      Uri.parse('$base$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    final ms = sw.elapsedMilliseconds;
    final rid = res.headers['x-request-id'];
    if (res.statusCode == 401) {
      _log('DELETE', path, 401, ms, requestId: rid, error: 'session expired');
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      _log('DELETE', path, res.statusCode, ms, requestId: rid, error: detail);
      throw ApiError(detail, res.statusCode);
    }
    _log('DELETE', path, res.statusCode, ms, requestId: rid);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final base = await getBaseUrl();
    final sw = Stopwatch()..start();
    final res = await http.put(
      Uri.parse('$base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    final ms = sw.elapsedMilliseconds;
    final rid = res.headers['x-request-id'];
    if (res.statusCode == 401) {
      _log('PUT', path, 401, ms, requestId: rid, error: 'session expired');
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) {
      final detail = _errorDetail(res);
      _log('PUT', path, res.statusCode, ms, requestId: rid, error: detail);
      throw ApiError(detail, res.statusCode);
    }
    _log('PUT', path, res.statusCode, ms, requestId: rid);
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<SchoolInfo> lookupSchool(String code) async {
    final data = await _get('/api/v1/auth/school/$code');
    return SchoolInfo.fromJson(data as Map<String, dynamic>);
  }

  static Future<AuthResponse> login(String email, String password, {String? schoolCode}) async {
    final data = await _post('/api/v1/auth/login', {
      'email': email,
      'password': password,
      if (schoolCode != null) 'school_code': schoolCode,
    }, handleUnauthorized: false);
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _post('/api/v1/auth/change-password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  static Future<void> lockMyAccount() async {
    await _post('/api/v1/auth/lock-account', {});
  }

  static Future<void> adminUnlockTeacher(String teacherId) async {
    await _patch('/api/v1/admin/teachers/$teacherId/unlock', {});
  }

  // ── Tests ─────────────────────────────────────────────────────────────────

  static Future<List<TestSummary>> getTests({int page = 0, int pageSize = 50}) async {
    final data = await _get('/api/v1/tests?page=$page&page_size=$pageSize');
    // BE returns {tests: [...], total, page, page_size, has_more}
    final map = data as Map<String, dynamic>;
    final list = (map['tests'] as List<dynamic>?) ?? [];
    return list.map((e) => TestSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<TestScoresResponse> getTestScores(String testId) async {
    final data = await _get('/api/v1/tests/$testId/scores');
    return TestScoresResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<Map<String, dynamic>>> getTestRoster(String testId) async {
    final data = await _get('/api/v1/tests/$testId/roster');
    final map = data as Map<String, dynamic>;
    return (map['students'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
  }

  static Future<List<TestQuestion>> getTestQuestions(String testId) async {
    final data = await _get('/api/v1/tests/$testId');
    final map = data as Map<String, dynamic>;
    final list = (map['questions'] as List<dynamic>?) ?? [];
    return list.map((e) => TestQuestion.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> submitTestScores(
      String testId, List<Map<String, dynamic>> scores) async {
    await _post('/api/v1/tests/$testId/scores', {'scores': scores});
  }

  static Future<AnalysisInsight?> getAnalysis(String testId) async {
    try {
      final data = await _get('/api/v1/tests/$testId/analysis/saved');
      if (data == null) return null;
      final insight = (data as Map<String, dynamic>)['class_insight'];
      if (insight == null) return null;
      return AnalysisInsight.fromJson(insight as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<String> getPreviewHtml(String testId, {bool answerKey = false}) async {
    final base = await getBaseUrl();
    final token = await getToken();
    final uri = Uri.parse('$base/api/v1/export/$testId/preview')
        .replace(queryParameters: {'answer_key': answerKey.toString()});
    final res = await http.get(uri, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    }).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      await onUnauthorized?.call();
      throw ApiError('Session expired. Please log in again.', 401);
    }
    if (res.statusCode >= 400) throw ApiError('Preview failed (${res.statusCode})', res.statusCode);
    return utf8.decode(res.bodyBytes);
  }

  // ── Teacher timetable ─────────────────────────────────────────────────────

  static Future<List<TimetableSlot>> getMyTimetable() async {
    final data = await _get('/api/v1/teacher/timetable');
    final slots = (data as Map<String, dynamic>)['slots'] as List<dynamic>? ?? [];
    return slots.map((e) => TimetableSlot.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Attendance ────────────────────────────────────────────────────────────

  static Future<List<SectionInfo>> getMySections() async {
    final data = await _get('/api/v1/teacher/sections');
    final list = data as List<dynamic>;
    return list.map((e) => SectionInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<Map<String, String>>> getMySubjects() async {
    final data = await _get('/api/v1/teacher/my-subjects') as List<dynamic>;
    return data.map((e) => {
      'id': (e as Map<String, dynamic>)['id'] as String,
      'name': e['name'] as String,
    }).toList();
  }

  static Future<List<AttendanceStudent>> getAttendance(
      String sectionId, String date) async {
    final data = await _get(
        '/api/v1/teacher/attendance?class_section_id=$sectionId&date=$date');
    final map = data as Map<String, dynamic>;
    final students = (map['students'] as List<dynamic>? ?? [])
        .map((e) => AttendanceStudent.fromJson(e as Map<String, dynamic>))
        .toList();
    // Merge existing statuses, sanitising to only known values
    const validStatuses = {'present', 'absent', 'late'};
    final record = map['record'] as Map<String, dynamic>?;
    if (record != null) {
      final statuses = record['statuses'] as Map<String, dynamic>? ?? {};
      for (final s in students) {
        final raw = statuses[s.id.toString()] as String? ?? '';
        s.status = validStatuses.contains(raw) ? raw : '';
      }
    }
    return students;
  }

  static Future<void> submitAttendance({
    required String sectionId,
    required String date,
    required Map<String, String> statuses,
  }) async {
    await _post('/api/v1/teacher/attendance', {
      'class_section_id': sectionId,
      'date': date,
      'statuses': statuses,
    });
  }

  // ── Leaves ────────────────────────────────────────────────────────────────

  static Future<List<LeaveRequest>> getMyLeaves() async {
    final data = await _get('/api/v1/teacher/leaves');
    final list = data as List<dynamic>;
    return list.map((e) => LeaveRequest.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> createLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    String? reason,
  }) async {
    await _post('/api/v1/teacher/leaves', {
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    });
  }

  static Future<void> cancelLeave(String leaveId) async {
    await _delete('/api/v1/teacher/leaves/$leaveId');
  }

  // ── Announcements ─────────────────────────────────────────────────────────

  static Future<List<Announcement>> getAnnouncements() async {
    final data = await _get('/api/v1/admin/announcements');
    final list = (data as Map<String, dynamic>)['announcements'] as List<dynamic>;
    return list
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<String> createAnnouncement({
    required String title,
    required String body,
    required String audience,
    bool isPinned = false,
    bool allowComments = false,
  }) async {
    final data = await _post('/api/v1/admin/announcements', {
      'title': title,
      'body': body,
      'audience': audience,
      'is_pinned': isPinned,
      'allow_comments': allowComments,
    });
    return (data as Map<String, dynamic>)['id']?.toString() ?? '';
  }

  static Future<Map<String, dynamic>> getAnnouncementUploadUrl(
      String filename, String contentType, int fileSize) async {
    final data = await _post('/api/v1/admin/announcements/upload-url', {
      'filename': filename,
      'content_type': contentType,
      'file_size': fileSize,
    });
    return data as Map<String, dynamic>;
  }

  static Future<void> attachAnnouncementImage(
      String announcementId, String gcsUrl, String? fileName, int? fileSize, int position) async {
    await _post('/api/v1/admin/announcements/$announcementId/images', {
      'gcs_url': gcsUrl,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      'position': position,
    });
  }

  static Future<void> deleteAnnouncementImage(String announcementId, String imageId) async {
    await _delete('/api/v1/admin/announcements/$announcementId/images/$imageId');
  }

  static Future<Map<String, dynamic>> toggleAnnouncementLike(String announcementId) async {
    final result = await _post('/api/v1/admin/announcements/$announcementId/like', {});
    return result as Map<String, dynamic>? ?? {};
  }

  static Future<List<AnnouncementComment>> getComments(String announcementId) async {
    final data = await _get('/api/v1/admin/announcements/$announcementId/comments');
    return (data as List<dynamic>)
        .map((e) => AnnouncementComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createComment(String announcementId, String body, {String? parentId}) async {
    await _post('/api/v1/admin/announcements/$announcementId/comments', {
      'body': body,
      if (parentId != null) 'parent_id': parentId,
    });
  }

  static Future<bool> toggleCommentLike(String commentId) async {
    final data = await _post('/api/v1/admin/announcements/comments/$commentId/like', {});
    return (data as Map<String, dynamic>)['liked'] as bool? ?? false;
  }

  // ── Calendar ──────────────────────────────────────────────────────────────

  static Future<List<CalendarEvent>> getCalendarEvents({
    required int month,
    required int year,
  }) async {
    final data = await _get('/api/v1/admin/calendar?month=$month&year=$year');
    List<dynamic> list;
    if (data is List) {
      list = data;
    } else {
      list = (data as Map<String, dynamic>)['events'] as List<dynamic>? ?? [];
    }
    return list
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createCalendarEvent({
    required String title,
    required String eventType,
    required String startDate,
    required String endDate,
  }) async {
    await _post('/api/v1/admin/calendar', {
      'title': title,
      'event_type': eventType,
      'start_date': startDate,
      'end_date': endDate,
    });
  }

  // ── Work Log ──────────────────────────────────────────────────────────────

  static Future<List<WorkLogEntry>> getWorkLogs({
    String? date,
    String? dateFrom,
    String? dateTo,
    List<String>? sectionIds,
    String? studentId,
  }) async {
    final params = <String>[];
    if (date != null) params.add('date=$date');
    if (dateFrom != null) params.add('date_from=$dateFrom');
    if (dateTo != null) params.add('date_to=$dateTo');
    if (sectionIds != null && sectionIds.isNotEmpty) {
      params.add('section_ids=${sectionIds.join(',')}');
    }
    if (studentId != null) params.add('student_id=$studentId');
    final path = '/api/v1/teacher/work-log${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    final list = data as List<dynamic>;
    return list
        .map((e) => WorkLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Map<String, dynamic>> getWorkLogUploadUrl(
    String filename,
    String contentType,
    int fileSize,
  ) async {
    final data = await _post('/api/v1/teacher/work-log/upload-url', {
      'filename': filename,
      'content_type': contentType,
      'file_size': fileSize,
    });
    return data as Map<String, dynamic>;
  }

  static Future<void> createWorkLog({
    required String classSectionId,
    String? subjectId,
    required String date,
    required String logType,
    required String description,
    String? dueDate,
    List<String>? imageUrls,
    String? chapterId,
  }) async {
    await _post('/api/v1/teacher/work-log', {
      'class_section_id': classSectionId,
      if (subjectId != null) 'subject_id': subjectId,
      'date': date,
      'log_type': logType,
      'description': description,
      if (dueDate != null) 'due_date': dueDate,
      if (imageUrls != null && imageUrls.isNotEmpty) 'image_urls': imageUrls,
      if (chapterId != null) 'chapter_id': chapterId,
    });
  }

  // ── Payslip ───────────────────────────────────────────────────────────────

  static Future<PayslipRecord?> getPayslip({
    required int month,
    required int year,
  }) async {
    final data = await _get('/api/v1/teacher/payslip?month=$month&year=$year');
    if (data == null) return null;
    return PayslipRecord.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<PayslipRecord>> getPayslipHistory() async {
    final data = await _get('/api/v1/teacher/payslip/history');
    final list = data as List<dynamic>;
    return list
        .map((e) => PayslipRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Notify Parents ────────────────────────────────────────────────────────

  static Future<ParentNotificationResult> notifyParents({
    required String message,
    required String notificationType,
    required String targetType,
    String? classSectionId,
    String? studentId,
  }) async {
    final data = await _post('/api/v1/teacher/notify-parents', {
      'message': message,
      'notification_type': notificationType,
      'target_type': targetType,
      if (classSectionId != null) 'class_section_id': classSectionId,
      if (studentId != null) 'student_id': studentId,
    });
    return ParentNotificationResult.fromJson(data as Map<String, dynamic>);
  }

  // ── Student search ────────────────────────────────────────────────────────

  static Future<List<StudentSearchResult>> searchStudents(String query, {bool classScoped = false}) async {
    final params = 'q=${Uri.encodeComponent(query)}${classScoped ? '&class_scoped=true' : ''}';
    final data = await _get('/api/v1/teacher/students/search?$params');
    final list = data as List<dynamic>;
    return list.map((e) => StudentSearchResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getStudentProfile(String studentId, {int? month, int? year}) async {
    final params = <String>[];
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    final path = '/api/v1/teacher/students/$studentId/profile${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    return data as Map<String, dynamic>;
  }

  // ── Todos ─────────────────────────────────────────────────────────────────

  static Future<List<TodoItem>> getTodos() async {
    final data = await _get('/api/v1/teacher/todos');
    final list = data as List<dynamic>;
    return list.map((e) => TodoItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<String> createTodo({
    required String title,
    String? notes,
    String? dueDate,
    bool isPersonal = false,
  }) async {
    final data = await _post('/api/v1/teacher/todos', {
      'title': title,
      if (notes != null) 'notes': notes,
      if (dueDate != null) 'due_date': dueDate,
      'is_personal': isPersonal,
    });
    return (data as Map<String, dynamic>)['id'].toString();
  }

  static Future<void> updateTodo(String id, {bool? isCompleted, String? status, String? title, String? notes, String? dueDate}) async {
    await _patch('/api/v1/teacher/todos/$id', {
      if (status != null) 'status': status,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (dueDate != null) 'due_date': dueDate,
    });
  }

  static Future<List<TodoItem>> getTodosFiltered({String? status, String? dueDate}) async {
    final params = <String>[];
    if (status != null) params.add('status=${Uri.encodeComponent(status)}');
    if (dueDate != null) params.add('due_date=${Uri.encodeComponent(dueDate)}');
    final path = '/api/v1/teacher/todos${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    final list = data as List<dynamic>;
    return list.map((e) => TodoItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<int> getNotifyParentsCount(String classSectionId) async {
    final data = await _get('/api/v1/teacher/notify-parents/count?class_section_id=$classSectionId');
    return (data as Map<String, dynamic>)['parent_count'] as int? ?? 0;
  }

  static Future<void> deleteTodo(String id) async {
    await _delete('/api/v1/teacher/todos/$id');
  }

  // ── Notify parents history ────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getNotifyParentsHistory({String? classSectionId, String? studentId}) async {
    final params = <String>[];
    if (classSectionId != null) params.add('class_section_id=$classSectionId');
    if (studentId != null) params.add('student_id=$studentId');
    final path = '/api/v1/teacher/notify-parents/history${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Admin: Parents ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminListParents({String? search, String? sectionId}) async {
    final params = <String>[];
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
    if (sectionId != null) params.add('section_id=$sectionId');
    final path = '/api/v1/admin/parents${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>> adminCreateParent({required String name, required String phone, String? email}) async {
    final body = <String, dynamic>{'name': name, 'phone': phone};
    if (email != null && email.isNotEmpty) body['email'] = email;
    final data = await _post('/api/v1/admin/parents', body);
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> adminGetParent(String parentId) async {
    final data = await _get('/api/v1/admin/parents/$parentId');
    return data as Map<String, dynamic>;
  }

  static Future<void> adminLinkParent(String parentId, {required String studentId, String relationType = 'parent'}) async {
    await _post('/api/v1/admin/parents/$parentId/link', {'student_id': studentId, 'relation_type': relationType});
  }

  static Future<String> adminResetParentPassword(String parentId) async {
    final data = await _post('/api/v1/admin/parents/$parentId/reset-password', {});
    return (data as Map<String, dynamic>)['temp_password'] as String;
  }

  // ── Admin: Transport ───────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminListRoutes() async {
    final data = await _get('/api/v1/admin/transport/routes');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<Map<String, dynamic>> adminCreateRoute({required String name, String? vehicleNumber, String? driverName, String? driverPhone, int capacity = 0}) async {
    final body = <String, dynamic>{'name': name, 'capacity': capacity};
    if (vehicleNumber != null && vehicleNumber.isNotEmpty) body['vehicle_number'] = vehicleNumber;
    if (driverName != null && driverName.isNotEmpty) body['driver_name'] = driverName;
    if (driverPhone != null && driverPhone.isNotEmpty) body['driver_phone'] = driverPhone;
    final data = await _post('/api/v1/admin/transport/routes', body);
    return data as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> adminListTransportAssignments() async {
    final data = await _get('/api/v1/admin/transport/assignments');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminAssignTransport({required String studentId, required String routeId, String? stopId}) async {
    final body = <String, dynamic>{'student_id': studentId, 'route_id': routeId};
    if (stopId != null) body['stop_id'] = stopId;
    await _post('/api/v1/admin/transport/assignments', body);
  }

  static Future<void> adminRemoveTransportAssignment(String studentId) async {
    await _delete('/api/v1/admin/transport/assignments/$studentId');
  }

  // ── Admin: School Settings ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> adminGetSchool() async {
    final data = await _get('/api/v1/admin/school');
    return data as Map<String, dynamic>;
  }

  static Future<void> adminUpdateSchool(Map<String, dynamic> updates) async {
    await _patch('/api/v1/admin/school', updates);
  }

  // ── Admin: Work Logs ───────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminListWorkLogs({String? sectionId, String? dateFrom, String? dateTo}) async {
    final params = <String>[];
    if (sectionId != null) params.add('section_id=$sectionId');
    if (dateFrom != null) params.add('date_from=$dateFrom');
    if (dateTo != null) params.add('date_to=$dateTo');
    final path = '/api/v1/admin/work-logs${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Admin: Attenders ───────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminListAttenders({String? studentId}) async {
    final path = studentId != null
        ? '/api/v1/admin/attenders/student/$studentId'
        : '/api/v1/admin/attenders';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminFlagAttender(String attenderId, {required bool isFlagged}) async {
    await _patch('/api/v1/admin/attenders/$attenderId/flag', {'is_flagged': isFlagged});
  }

  // ── Admin: Fee Management ─────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminListFeeComponents() async {
    final data = await _get('/api/v1/admin/fees/components');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminCreateFeeComponent({required String name, String? description, bool isOptional = false}) async {
    await _post('/api/v1/admin/fees/components', {'name': name, 'description': description, 'is_optional': isOptional});
  }

  static Future<void> adminDeleteFeeComponent(String id) async {
    await _delete('/api/v1/admin/fees/components/$id');
  }

  static Future<List<Map<String, dynamic>>> adminListFeeStructures({String? sectionId, String? status}) async {
    final params = <String>[];
    if (sectionId != null) params.add('section_id=$sectionId');
    if (status != null) params.add('status=$status');
    final path = '/api/v1/admin/fees/structures${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    final map = data as Map<String, dynamic>;
    return (map['items'] as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminUpdateFeeStatus(String structureId, String status) async {
    await _put('/api/v1/admin/fees/structures/$structureId/status', {'status': status});
  }

  static Future<List<Map<String, dynamic>>> adminListFeePayments({String? structureId}) async {
    final path = structureId != null
        ? '/api/v1/admin/fees/payments?fee_structure_id=$structureId'
        : '/api/v1/admin/fees/payments';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminRecordPayment({
    required String structureId,
    required String studentId,
    required double amount,
    String method = 'cash',
    String? reference,
  }) async {
    final receipt = 'RCP-${DateTime.now().millisecondsSinceEpoch}';
    final today = DateTime.now().toIso8601String().split('T')[0];
    await _post('/api/v1/admin/fees/payments', {
      'fee_structure_id': structureId,
      'student_id': studentId,
      'receipt_number': reference?.isNotEmpty == true ? reference! : receipt,
      'amount': amount,
      'payment_date': today,
      'payment_method': method,
      if (reference?.isNotEmpty == true) 'notes': 'Ref: $reference',
    });
  }

  // ── Admin: Leave Config ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> adminGetLeaveConfig() async {
    final data = await _get('/api/v1/admin/leave-config');
    return data as Map<String, dynamic>;
  }

  static Future<void> adminUpdateLeaveConfig(Map<String, dynamic> updates) async {
    await _patch('/api/v1/admin/leave-config', updates);
  }

  static Future<List<Map<String, dynamic>>> adminListTeacherLeaveOverrides() async {
    final data = await _get('/api/v1/admin/leave-config/teachers');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminSetTeacherLeaveOverride(String teacherId, Map<String, dynamic> payload) async {
    await _put('/api/v1/admin/leave-config/teacher/$teacherId', payload);
  }

  static Future<void> adminClearTeacherLeaveOverride(String teacherId) async {
    await _delete('/api/v1/admin/leave-config/teacher/$teacherId');
  }

  static Future<Map<String, dynamic>> getMyLeaveBalance() async {
    final data = await _get('/api/v1/teacher/leave-balance');
    return data as Map<String, dynamic>;
  }

  // ── Teacher profile ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMyProfile() async {
    final data = await _get('/api/v1/teacher/me');
    return data as Map<String, dynamic>;
  }

  static Future<void> updateMyProfile({String? name, String? phone, String? email}) async {
    await _patch('/api/v1/teacher/me', {
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
    });
  }

  static Future<Map<String, dynamic>> getPhotoUploadUrl(
      String filename, String contentType, int fileSize) async {
    final data = await _post('/api/v1/teacher/me/photo-url', {
      'filename': filename,
      'content_type': contentType,
      'file_size': fileSize,
    });
    return data as Map<String, dynamic>;
  }

  static Future<void> savePhotoUrl(String photoUrl) async {
    await _patch('/api/v1/teacher/me/photo', {'photo_url': photoUrl});
  }

  // ── Onboarding ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getOnboardingState() async {
    return (await _get('/api/v1/teacher/onboarding')) as Map<String, dynamic>;
  }

  static Future<void> markOnboardingSeen(String actionKey) async {
    await _post('/api/v1/teacher/onboarding/$actionKey/seen', {});
  }

  // ── Student photo (teacher: one-time upload) ───────────────────────────────

  static Future<Map<String, dynamic>> getStudentPhotoUploadUrl(
      String studentId, String filename, String contentType, int fileSize) async {
    return (await _post('/api/v1/teacher/students/$studentId/photo/upload-url', {
      'filename': filename,
      'content_type': contentType,
      'file_size': fileSize,
    })) as Map<String, dynamic>;
  }

  static Future<void> saveStudentPhoto(String studentId, String photoUrl) async {
    await _patch('/api/v1/teacher/students/$studentId/photo', {'photo_url': photoUrl});
  }

  // ── Push tokens ────────────────────────────────────────────────────────────

  static Future<void> registerPushToken(String fcmToken, String deviceId) async {
    await _post('/api/v1/teacher/push-token', {'fcm_token': fcmToken, 'device_id': deviceId});
  }

  static Future<void> deregisterPushToken(String deviceId) async {
    try {
      final base = await getBaseUrl();
      final req = http.Request('DELETE', Uri.parse('$base/api/v1/teacher/push-token'));
      req.headers.addAll(await _headers());
      req.body = jsonEncode({'device_id': deviceId});
      await req.send();
    } catch (_) {}
  }

  // ── Teacher notifications ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getTeacherNotifications() async {
    final data = await _get('/api/v1/teacher/notifications');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> markNotificationRead(String notifId) async {
    await _post('/api/v1/teacher/notifications/$notifId/read', {});
  }

  // ── Support chat ───────────────────────────────────────────────────────────

  static Future<String> supportChat({
    required String message,
    required List<Map<String, String>> history,
  }) async {
    final data = await _post('/api/v1/teacher/support/chat', {
      'message': message,
      'history': history,
    });
    return data['reply'] as String;
  }

  // ── Vidya copilot ──────────────────────────────────────────────────────────

  static Future<String> askVidya({
    required String question,
    required List<Map<String, String>> history,
  }) async {
    final data = await _post('/api/v1/teacher/copilot/ask', {
      'question': question,
      'history': history,
    });
    return data['reply'] as String;
  }

  // ── WhatsApp parent report ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> generateWhatsAppReport(String studentId) async {
    return (await _post('/api/v1/teacher/students/$studentId/whatsapp-report', {}))
        as Map<String, dynamic>;
  }

  // ── Longitudinal report ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getLongitudinalReport(String studentId) async {
    return (await _get('/api/v1/teacher/students/$studentId/longitudinal-report'))
        as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> generateLongitudinalAnalysis(
    String studentId, {
    String? teacherNotes,
  }) async {
    return (await _post('/api/v1/teacher/students/$studentId/longitudinal-analysis',
        {'teacher_notes': teacherNotes})) as Map<String, dynamic>;
  }

  // ── Test-level smart analysis ─────────────────────────────────────────────

  static Future<TestAnalysisResult> runTestAnalysis(String testId, {bool isRefresh = false}) async {
    final data = await _post(
      '/api/v1/tests/$testId/analysis?triggered_by=${isRefresh ? 'refresh' : 'initial'}',
      {},
    );
    return TestAnalysisResult.fromJson(data as Map<String, dynamic>);
  }

  // ── Global search ─────────────────────────────────────────────────────────

  static Future<TeacherSearchResult> teacherSearch(String q, {int limit = 5}) async {
    final base = await getBaseUrl();
    final token = await getToken();
    final uri = Uri.parse('$base/api/v1/teacher/search')
        .replace(queryParameters: {'q': q, 'limit': '$limit'});
    final res = await http.get(uri, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    }).timeout(const Duration(seconds: 10));
    if (res.statusCode == 401) {
      await onUnauthorized?.call();
      throw ApiError('Session expired', 401);
    }
    if (res.statusCode >= 400) throw ApiError(_errorDetail(res), res.statusCode);
    return TeacherSearchResult.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  static Future<Map<String, dynamic>> getStudentFullReport(String studentId) async {
    return (await _get('/api/v1/teacher/students/$studentId/full-report'))
        as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> generateStudentFullReport(String studentId) async {
    return (await _post('/api/v1/teacher/students/$studentId/full-report', {}))
        as Map<String, dynamic>;
  }

  // ── Group D: Spaced repetition ─────────────────────────────────────────────

  static Future<List<SpacedRepChapter>> getSpacedRepetition({String? sectionId}) async {
    final path = '/api/v1/teacher/spaced-repetition${sectionId != null ? '?class_section_id=$sectionId' : ''}';
    final data = await _get(path) as List<dynamic>;
    return data.map((e) => SpacedRepChapter.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Feature flags ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFeatureConfig() async {
    final data = await _get('/api/v1/teacher/feature-config');
    return (data as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> getAdminFeatureConfig() async {
    final data = await _get('/api/v1/admin/feature-config');
    return (data as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> getBranding() async {
    final data = await _get('/api/v1/teacher/branding');
    return (data as Map<String, dynamic>?) ?? {};
  }

  // ── Health incidents ──────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getPickupPersons(String studentId) async {
    final data = await _get('/api/v1/teacher/students/$studentId/pickup-persons');
    return (data as Map<String, dynamic>?) ?? {};
  }

  static Future<Map<String, dynamic>> logHealthIncident(Map<String, dynamic> payload) async {
    final data = await _post('/api/v1/teacher/health-incidents', payload);
    return (data as Map<String, dynamic>?) ?? {};
  }

  static Future<List<Map<String, dynamic>>> listHealthIncidents({
    String? studentId,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String>[];
    if (studentId != null) params.add('student_id=$studentId');
    if (dateFrom != null) params.add('date_from=$dateFrom');
    if (dateTo != null) params.add('date_to=$dateTo');
    final path = '/api/v1/teacher/health-incidents${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path) as List<dynamic>;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminSetFeatureConfig(String role, String key, bool enabled) async {
    await _put('/api/v1/admin/feature-config/$role/$key', {'is_enabled': enabled});
  }

  // ── Teacher self-attendance ────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSelfAttendance({int? month, int? year}) async {
    final params = <String>[];
    if (month != null) params.add('month=$month');
    if (year != null) params.add('year=$year');
    final path = '/api/v1/teacher/attendance/self${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> markSelfAttendance({
    required double latitude,
    required double longitude,
  }) async {
    final data = await _post('/api/v1/teacher/attendance/self', {
      'latitude': latitude,
      'longitude': longitude,
    });
    return data as Map<String, dynamic>;
  }

  // ── Teacher qualifications ─────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getQualifications() async {
    final data = await _get('/api/v1/teacher/qualifications');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<String> addQualification({
    required String degreeType,
    required String institution,
    String? fieldOfStudy,
    int? yearPassed,
  }) async {
    final data = await _post('/api/v1/teacher/qualifications', {
      'degree_type': degreeType,
      'institution': institution,
      if (fieldOfStudy != null && fieldOfStudy.isNotEmpty) 'field_of_study': fieldOfStudy,
      if (yearPassed != null) 'year_passed': yearPassed,
    });
    return (data as Map<String, dynamic>)['id'].toString();
  }

  static Future<void> deleteQualification(String id) async {
    await _delete('/api/v1/teacher/qualifications/$id');
  }

  // ── Teacher experience ─────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getExperience() async {
    final data = await _get('/api/v1/teacher/experience');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<String> addExperience({
    required String institution,
    required String role,
    required int fromYear,
    int? toYear,
    bool isCurrent = false,
  }) async {
    final data = await _post('/api/v1/teacher/experience', {
      'institution': institution,
      'role': role,
      'from_year': fromYear,
      if (toYear != null) 'to_year': toYear,
      'is_current': isCurrent,
    });
    return (data as Map<String, dynamic>)['id'].toString();
  }

  static Future<void> deleteExperience(String id) async {
    await _delete('/api/v1/teacher/experience/$id');
  }

  // ── Notification preferences ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getNotificationPrefs() async {
    final data = await _get('/api/v1/teacher/notification-prefs');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateNotificationPrefs(Map<String, bool> prefs) async {
    final data = await _put('/api/v1/teacher/notification-prefs', prefs.cast<String, dynamic>());
    return data as Map<String, dynamic>;
  }

  // ── Caching wrappers ───────────────────────────────────────────────────────

  static Future<List<TimetableSlot>> getMyTimetableCached() async {
    // Return cache immediately, refresh in background
    return _cachedOrFetch(
      cacheKey: 'timetable',
      maxAge: const Duration(minutes: 30),
      fetch: getMyTimetable,
      fromCache: (cached) => (cached['slots'] as List<dynamic>? ?? [])
          .map((e) => TimetableSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      toCache: (slots) => {'slots': slots.map((s) => {'id': s.id, 'day_of_week': s.dayOfWeek,
          'period_number': s.periodNumber, 'start_time': s.startTime, 'end_time': s.endTime,
          'subject_name': s.subjectName, 'class_section_id': s.classSectionId}).toList()},
    );
  }

  // ── Syllabus progress ─────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getSyllabus(String classSectionId) async {
    final data = await _get('/api/v1/teacher/syllabus?class_section_id=$classSectionId');
    return (data as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static Future<void> updateChapterStatus({
    required String classSectionId,
    required String chapterId,
    required String status,
  }) async {
    await _put('/api/v1/teacher/syllabus/chapter', {
      'class_section_id': classSectionId,
      'chapter_id': chapterId,
      'status': status,
    });
  }

  // ── Director ──────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> directorDashboard() async {
    final data = await _get('/api/v1/admin/director-dashboard');
    return data as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> directorClassAnalytics() async {
    final data = await _get('/api/v1/admin/director/class-analytics');
    return data as Map<String, dynamic>;
  }

  static Future<T> _cachedOrFetch<T>({
    required String cacheKey,
    required Duration maxAge,
    required Future<T> Function() fetch,
    required T Function(Map<String, dynamic>) fromCache,
    required Map<String, dynamic> Function(T) toCache,
  }) async {
    try {
      final cached = await CacheService.getMap(cacheKey, maxAge: maxAge);
      if (cached != null) {
        // Kick off background refresh without blocking
        fetch().then((fresh) => CacheService.set(cacheKey, toCache(fresh))).ignore();
        return fromCache(cached);
      }
    } catch (_) {}
    final fresh = await fetch();
    CacheService.set(cacheKey, toCache(fresh)).ignore();
    return fresh;
  }

  static Future<List<Map<String, dynamic>>> getStudentCertificates(String studentId) async {
    final data = await _get('/api/v1/teacher/students/$studentId/certificates');
    return (data as List).cast<Map<String, dynamic>>();
  }

  static Future<String> getCertificatePdfUrl(String certId) async {
    final data = await _post('/api/v1/teacher/certificates/$certId/export-token', {});
    final token = data['token'] as String;
    final base = await getBaseUrl();
    return '$base/api/v1/teacher/certificates/$certId/pdf?token=$token';
  }

  // ── Emergency Contacts ──────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getStudentEmergencyContacts(String studentId) async {
    final data = await _get('/api/v1/teacher/students/$studentId/emergency-contacts');
    return (data['contacts'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> addEmergencyContact({
    required String studentId,
    required String name,
    required String relation,
    required String phone,
    int priority = 1,
  }) async {
    await _post('/api/v1/admin/emergency-contacts', {
      'student_id': studentId,
      'name': name,
      'relation': relation,
      'phone': phone,
      'priority': priority,
    });
  }

  static Future<void> deleteEmergencyContact(String contactId) async {
    await _delete('/api/v1/admin/emergency-contacts/$contactId');
  }

  // ── Medical Profile ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> getStudentMedicalProfile(String studentId) async {
    final data = await _get('/api/v1/teacher/students/$studentId/medical');
    return data['profile'] as Map<String, dynamic>?;
  }

  static Future<void> upsertStudentMedicalProfile(
    String studentId, {
    String? bloodGroup,
    List<String> allergies = const [],
    List<String> ongoingMedicines = const [],
    String? medicalHistory,
    String? emergencyNotes,
  }) async {
    await _put('/api/v1/admin/students/$studentId/medical', {
      if (bloodGroup != null) 'blood_group': bloodGroup,
      'allergies': allergies,
      'ongoing_medicines': ongoingMedicines,
      if (medicalHistory != null) 'medical_history': medicalHistory,
      if (emergencyNotes != null) 'emergency_notes': emergencyNotes,
    });
  }

  // ── Emergency SOS ───────────────────────────────────────────────────────────

  static Future<void> triggerSOS({String? locationNote, String? studentId, String? classSectionId}) async {
    await _post('/api/v1/teacher/sos', {
      if (locationNote != null) 'location_note': locationNote,
      if (studentId != null) 'student_id': studentId,
      if (classSectionId != null) 'class_section_id': classSectionId,
    });
  }

  // ── PTM ─────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPTMEvents() async {
    final data = await _get('/api/v1/teacher/ptm/events');
    return (data['events'] as List).cast<Map<String, dynamic>>();
  }

  static Future<void> createPTMEvent({
    required String name,
    required String eventDate,
    String? description,
  }) async {
    await _post('/api/v1/admin/ptm/events', {
      'name': name,
      'event_date': eventDate,
      if (description != null && description.isNotEmpty) 'description': description,
    });
  }

  static Future<List<Map<String, dynamic>>> getPTMMeetings(String eventId) async {
    final data = await _get('/api/v1/teacher/ptm/events/$eventId/meetings');
    return (data['meetings'] as List).cast<Map<String, dynamic>>();
  }

  static Future<String> createPTMMeeting({
    required String ptmEventId,
    required String studentId,
    String? classSectionId,
    String? subjectId,
    required String status,
    String? remarks,
    List<String> actionItems = const [],
  }) async {
    final data = await _post('/api/v1/teacher/ptm/meetings', {
      'ptm_event_id': ptmEventId,
      'student_id': studentId,
      if (classSectionId != null) 'class_section_id': classSectionId,
      if (subjectId != null) 'subject_id': subjectId,
      'status': status,
      if (remarks != null) 'remarks': remarks,
      'action_items': actionItems,
    });
    return data['id'] as String;
  }

  static Future<void> updatePTMMeeting(String meetingId, {String? status, String? remarks, List<String>? actionItems}) async {
    await _put('/api/v1/teacher/ptm/meetings/$meetingId', {
      if (status != null) 'status': status,
      if (remarks != null) 'remarks': remarks,
      if (actionItems != null) 'action_items': actionItems,
    });
  }

  static Future<List<Map<String, dynamic>>> getPTMRegistrations(String eventId) async {
    final data = await _get('/api/v1/teacher/ptm/events/$eventId/registrations');
    return (data['registrations'] as List).cast<Map<String, dynamic>>();
  }

  // ── Substitute Teacher ──────────────────────────────────────────────────────

  static Future<void> selfSubstitute({
    required String date,
    required String classSectionId,
    String? subjectId,
    int? periodNumber,
    String? startTime,
    String? endTime,
    String? originalTeacherId,
    String? reason,
  }) async {
    await _post('/api/v1/teacher/substitutes/self', {
      'date': date,
      'class_section_id': classSectionId,
      if (subjectId != null) 'subject_id': subjectId,
      if (periodNumber != null) 'period_number': periodNumber,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (originalTeacherId != null) 'original_teacher_id': originalTeacherId,
      if (reason != null) 'reason': reason,
    });
  }

  static Future<Map<String, dynamic>> getSubstituteHistory() async {
    return await _get('/api/v1/teacher/substitutes/history') as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> getSubstituteToday() async {
    final data = await _get('/api/v1/teacher/substitutes/today');
    return (data['substitutions'] as List).cast<Map<String, dynamic>>();
  }

  // ── Syllabus Plan ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getSyllabusPlan(String classSectionId) async {
    return await _get('/api/v1/teacher/syllabus/plan?class_section_id=$classSectionId') as Map<String, dynamic>;
  }

  static Future<void> upsertSyllabusPlan({
    required String classSectionId,
    required String chapterId,
    required String subjectId,
    required String targetDate,
    String? milestoneNote,
  }) async {
    await _put('/api/v1/teacher/syllabus/plan', {
      'class_section_id': classSectionId,
      'chapter_id': chapterId,
      'subject_id': subjectId,
      'target_date': targetDate,
      if (milestoneNote != null) 'milestone_note': milestoneNote,
    });
  }

  // ── Predictive Alerts ───────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getMyAlerts({bool unacknowledgedOnly = false}) async {
    final q = unacknowledgedOnly ? '?unacknowledged_only=true' : '';
    final data = await _get('/api/v1/teacher/alerts$q');
    return (data['alerts'] as List).cast<Map<String, dynamic>>();
  }

  // ── Admin: PTM ─────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> adminListPTMEvents() async {
    return (await _get('/api/v1/admin/ptm/events')) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> adminGetPTMSummary(String eventId) async {
    return (await _get('/api/v1/admin/ptm/events/$eventId/summary')) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> adminGetPTMParentAttendance(String eventId) async {
    return (await _get('/api/v1/admin/ptm/events/$eventId/parent-attendance')) as Map<String, dynamic>;
  }

  // ── Admin: Visitors ────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> listVisitors({String? dateFrom}) async {
    final q = dateFrom != null ? '?date_from=$dateFrom' : '';
    return (await _get('/api/v1/admin/visitors$q')) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> logVisitor(Map<String, dynamic> body) async {
    return (await _post('/api/v1/admin/visitors', body)) as Map<String, dynamic>;
  }

  static Future<void> checkoutVisitor(String visitorId) async {
    await _patch('/api/v1/admin/visitors/$visitorId/checkout', {});
  }

  // ── Admin: Teacher Functional Tags ─────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminListTeachers({String? search, int page = 0, int pageSize = 100}) async {
    final params = <String>[];
    if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
    params.add('page=$page');
    params.add('page_size=$pageSize');
    final path = '/api/v1/admin/teachers?${params.join('&')}';
    final data = await _get(path);
    return ((data as Map<String, dynamic>)['teachers'] as List<dynamic>).cast<Map<String, dynamic>>();
  }

  static Future<void> updateTeacherFunctionalTags(String teacherId, List<String> tags) async {
    await _patch('/api/v1/admin/teachers/$teacherId/functional-tags', {'tags': tags});
  }

  // ── Library Management ─────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> libraryListBooks({
    String? search, String? bookType, bool availableOnly = false, int page = 0, int pageSize = 25,
  }) async {
    final params = <String>['page=$page', 'page_size=$pageSize'];
    if (search != null) params.add('search=${Uri.encodeComponent(search)}');
    if (bookType != null) params.add('book_type=$bookType');
    if (availableOnly) params.add('available_only=true');
    return await _get('/api/v1/admin/library/books?${params.join(\'&\')}') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> libraryAddBook(Map<String, dynamic> payload) async {
    return await _post('/api/v1/admin/library/books', payload) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> libraryUpdateBook(String bookId, Map<String, dynamic> payload) async {
    return await _patch('/api/v1/admin/library/books/$bookId', payload) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> libraryListIssues({
    String? status, bool overdueOnly = false, String? studentId, int page = 0,
  }) async {
    final params = <String>['page=$page'];
    if (status != null) params.add('status=$status');
    if (overdueOnly) params.add('overdue_only=true');
    if (studentId != null) params.add('student_id=$studentId');
    return await _get('/api/v1/admin/library/issues?${params.join(\'&\')}') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> libraryIssueBook({
    required String bookId, required String studentId, required String dueDate,
  }) async {
    return await _post('/api/v1/admin/library/issues', {
      'book_id': bookId, 'student_id': studentId, 'due_date': dueDate,
    }) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> libraryReturnBook(String issueId) async {
    return await _patch('/api/v1/admin/library/issues/$issueId/return', {}) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> libraryStudentBooks(String studentId) async {
    return await _get('/api/v1/admin/library/students/$studentId/books') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> libraryStats() async {
    return await _get('/api/v1/admin/library/stats') as Map<String, dynamic>;
  }

  static Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    final data = await _get('/api/v1/admin/search/students?q=${Uri.encodeComponent(query)}&limit=10');
    return ((data as Map<String, dynamic>)['results'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  // ── Brain Booster ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> brainBoosterSudokuToday() async {
    return await _get('/api/v1/teacher/brain-booster/sudoku/today') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> brainBoosterHint(int hintNum) async {
    return await _get('/api/v1/teacher/brain-booster/sudoku/hint/$hintNum') as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> brainBoosterSubmit({
    required int puzzleNumber, required int hintsUsed,
    required int timeSeconds, required List<List<int>> board,
  }) async {
    return await _post('/api/v1/teacher/brain-booster/sudoku/submit', {
      'puzzle_number': puzzleNumber, 'hints_used': hintsUsed,
      'time_seconds': timeSeconds, 'board': board,
    }) as Map<String, dynamic>;
  }

  static Future<dynamic> brainBoosterLeaderboard() async {
    return await _get('/api/v1/teacher/brain-booster/sudoku/leaderboard');
  }

  static Future<Map<String, dynamic>> brainBoosterMe() async {
    return await _get('/api/v1/teacher/brain-booster/me') as Map<String, dynamic>;
  }
}

class ApiError implements Exception {
  final String message;
  final int statusCode;
  const ApiError(this.message, this.statusCode);

  @override
  String toString() => message;
}
