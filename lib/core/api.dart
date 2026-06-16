import 'dart:convert';
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'cache.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class SchoolInfo {
  final int id;
  final String name;
  final String code;
  final String? logoUrl;

  const SchoolInfo({required this.id, required this.name, required this.code, this.logoUrl});

  factory SchoolInfo.fromJson(Map<String, dynamic> j) => SchoolInfo(
        id: j['id'] as int,
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
  final int teacherId;
  final bool mustChangePassword;

  const AuthResponse({
    required this.token,
    required this.teacherName,
    required this.schoolName,
    required this.role,
    required this.teacherId,
    this.mustChangePassword = false,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j['access_token'] as String,
        teacherName: j['teacher_name'] as String,
        schoolName: j['school_name'] as String,
        role: j['role'] as String,
        teacherId: j['teacher_id'] as int,
        mustChangePassword: j['must_change_password'] as bool? ?? false,
      );
}

class StudentSearchResult {
  final int id;
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
        id: j['id'] as int,
        name: j['name'] as String,
        admissionNumber: j['admission_number'] as String? ?? '',
        guardianName: j['guardian_name'] as String?,
        guardianPhone: j['guardian_phone'] as String?,
        rollNo: j['roll_no']?.toString(),
        classLabel: j['class_label'] as String?,
      );
}

class TodoItem {
  final int id;
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
        id: j['id'] as int,
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
  final int id;
  final String title;
  final String subject;
  final String className;
  final String status;
  final double totalMarks;
  final DateTime? scheduledDate;
  final DateTime createdAt;
  final int questionCount;
  final int scoreCount;

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
  });

  factory TestSummary.fromJson(Map<String, dynamic> j) => TestSummary(
        id: j['id'] as int,
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
      );
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
        marks: (j['marks'] as num?)?.toDouble(),
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
      belowAverageCount: (report?['below_40_percent'] as num?)?.toInt(),
    );
  }
}

class TimetableSlot {
  final int id;
  final int dayOfWeek;
  final int periodNumber;
  final String? startTime;
  final String? endTime;
  final String? subjectName;
  final String sectionLabel;
  final int classSectionId;

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
        id: j['id'] as int,
        dayOfWeek: j['day_of_week'] as int,
        periodNumber: j['period_number'] as int,
        startTime: j['start_time'] as String?,
        endTime: j['end_time'] as String?,
        subjectName: j['subject_name'] as String?,
        sectionLabel: j['section_label'] as String? ?? '',
        classSectionId: j['class_section_id'] as int? ?? 0,
      );
}

class SectionInfo {
  final int id;
  final String label;

  const SectionInfo({required this.id, required this.label});

  factory SectionInfo.fromJson(Map<String, dynamic> j) => SectionInfo(
        id: j['id'] as int,
        label: j['label'] as String,
      );
}

class AttendanceStudent {
  final int id;
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
        id: j['id'] as int,
        name: j['name'] as String,
        rollNo: j['roll_no']?.toString() ?? '',
        gender: j['gender'] as String?,
        photoUrl: j['photo_url'] as String?,
      );
}

class LeaveRequest {
  final int id;
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
        id: j['id'] as int,
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

// ── New Models ────────────────────────────────────────────────────────────────

class AnnouncementImage {
  final int id;
  final String gcsUrl;
  final int position;
  const AnnouncementImage({required this.id, required this.gcsUrl, required this.position});
  factory AnnouncementImage.fromJson(Map<String, dynamic> j) => AnnouncementImage(
        id: j['id'] as int,
        gcsUrl: j['gcs_url'] as String,
        position: j['position'] as int? ?? 0,
      );
}

class AnnouncementComment {
  final int id;
  final String body;
  final String? authorName;
  final String createdAt;
  const AnnouncementComment({required this.id, required this.body, this.authorName, required this.createdAt});
  factory AnnouncementComment.fromJson(Map<String, dynamic> j) => AnnouncementComment(
        id: j['id'] as int,
        body: j['body'] as String? ?? '',
        authorName: j['author_name'] as String?,
        createdAt: j['created_at'] as String? ?? '',
      );
}

class Announcement {
  final int id;
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
  });

  factory Announcement.fromJson(Map<String, dynamic> j) => Announcement(
        id: j['id'] as int,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        audience: j['audience'] as String? ?? 'all',
        isPinned: j['is_pinned'] as bool? ?? false,
        allowComments: j['allow_comments'] as bool? ?? false,
        createdAt: j['created_at'] as String? ?? '',
        authorName: j['author_name'] as String?,
        images: (j['images'] as List<dynamic>? ?? [])
            .map((e) => AnnouncementImage.fromJson(e as Map<String, dynamic>))
            .toList(),
        commentCount: j['comment_count'] as int? ?? 0,
        likeCount: j['like_count'] as int? ?? 0,
        likedByMe: j['liked_by_me'] as bool? ?? false,
      );
}

class CalendarEvent {
  final int id;
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
        id: j['id'] as int,
        title: j['title'] as String? ?? '',
        eventType: j['event_type'] as String? ?? 'event',
        startDate: j['start_date'] as String? ?? '',
        endDate: j['end_date'] as String? ?? '',
      );
}

class WorkLogEntry {
  final int id;
  final int classSectionId;
  final String sectionLabel;
  final int? subjectId;
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
  });

  factory WorkLogEntry.fromJson(Map<String, dynamic> j) => WorkLogEntry(
        id: j['id'] as int,
        classSectionId: j['class_section_id'] as int? ?? 0,
        sectionLabel: j['section_label'] as String? ?? '',
        subjectId: j['subject_id'] as int?,
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
  final int id;
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
        id: j['id'] as int,
        message: j['message'] as String? ?? '',
        sentAt: j['sent_at'] as String? ?? '',
        recipientCount: j['recipient_count'] as int? ?? 0,
      );
}

// ── API Client ───────────────────────────────────────────────────────────────

class ApiClient {
  static const defaultBaseUrl = 'https://edutrack-api-6382035856.asia-south1.run.app';
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

  // ── Tests ─────────────────────────────────────────────────────────────────

  static Future<List<TestSummary>> getTests({int page = 0, int pageSize = 50}) async {
    final data = await _get('/api/v1/tests?page=$page&page_size=$pageSize');
    // BE returns {tests: [...], total, page, page_size, has_more}
    final map = data as Map<String, dynamic>;
    final list = (map['tests'] as List<dynamic>?) ?? [];
    return list.map((e) => TestSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<TestScoresResponse> getTestScores(int testId) async {
    final data = await _get('/api/v1/tests/$testId/scores');
    return TestScoresResponse.fromJson(data as Map<String, dynamic>);
  }

  static Future<AnalysisInsight?> getAnalysis(int testId) async {
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

  static Future<String> getPreviewHtml(int testId, {bool answerKey = false}) async {
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

  static Future<List<AttendanceStudent>> getAttendance(
      int sectionId, String date) async {
    final data = await _get(
        '/api/v1/teacher/attendance?class_section_id=$sectionId&date=$date');
    final map = data as Map<String, dynamic>;
    final students = (map['students'] as List<dynamic>? ?? [])
        .map((e) => AttendanceStudent.fromJson(e as Map<String, dynamic>))
        .toList();
    // Merge existing statuses
    final record = map['record'] as Map<String, dynamic>?;
    if (record != null) {
      final statuses = record['statuses'] as Map<String, dynamic>? ?? {};
      for (final s in students) {
        s.status = statuses[s.id.toString()] as String? ?? '';
      }
    }
    return students;
  }

  static Future<void> submitAttendance({
    required int sectionId,
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

  // ── Announcements ─────────────────────────────────────────────────────────

  static Future<List<Announcement>> getAnnouncements() async {
    final data = await _get('/api/v1/admin/announcements');
    final list = data as List<dynamic>;
    return list
        .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<int> createAnnouncement({
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
    return (data as Map<String, dynamic>)['id'] as int? ?? 0;
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
      int announcementId, String gcsUrl, String? fileName, int? fileSize, int position) async {
    await _post('/api/v1/admin/announcements/$announcementId/images', {
      'gcs_url': gcsUrl,
      if (fileName != null) 'file_name': fileName,
      if (fileSize != null) 'file_size': fileSize,
      'position': position,
    });
  }

  static Future<void> deleteAnnouncementImage(int announcementId, int imageId) async {
    await _delete('/api/v1/admin/announcements/$announcementId/images/$imageId');
  }

  static Future<void> toggleAnnouncementLike(int announcementId) async {
    await _post('/api/v1/admin/announcements/$announcementId/like', {});
  }

  static Future<List<AnnouncementComment>> getComments(int announcementId) async {
    final data = await _get('/api/v1/admin/announcements/$announcementId/comments');
    return (data as List<dynamic>)
        .map((e) => AnnouncementComment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createComment(int announcementId, String body) async {
    await _post('/api/v1/admin/announcements/$announcementId/comments', {'body': body});
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
    List<int>? sectionIds,
  }) async {
    final params = <String>[];
    if (date != null) params.add('date=$date');
    if (dateFrom != null) params.add('date_from=$dateFrom');
    if (dateTo != null) params.add('date_to=$dateTo');
    if (sectionIds != null && sectionIds.isNotEmpty) {
      params.add('section_ids=${sectionIds.join(',')}');
    }
    final path = '/api/v1/teacher/work-log${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    final list = data as List<dynamic>;
    return list
        .map((e) => WorkLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> createWorkLog({
    required int classSectionId,
    int? subjectId,
    required String date,
    required String logType,
    required String description,
    String? dueDate,
  }) async {
    await _post('/api/v1/teacher/work-log', {
      'class_section_id': classSectionId,
      if (subjectId != null) 'subject_id': subjectId,
      'date': date,
      'log_type': logType,
      'description': description,
      if (dueDate != null) 'due_date': dueDate,
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
    int? classSectionId,
    int? studentId,
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

  static Future<List<StudentSearchResult>> searchStudents(String query) async {
    final data = await _get('/api/v1/teacher/students/search?q=${Uri.encodeComponent(query)}');
    final list = data as List<dynamic>;
    return list.map((e) => StudentSearchResult.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Map<String, dynamic>> getStudentProfile(int studentId) async {
    final data = await _get('/api/v1/teacher/students/$studentId/profile');
    return data as Map<String, dynamic>;
  }

  // ── Todos ─────────────────────────────────────────────────────────────────

  static Future<List<TodoItem>> getTodos() async {
    final data = await _get('/api/v1/teacher/todos');
    final list = data as List<dynamic>;
    return list.map((e) => TodoItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<int> createTodo({
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
    return (data as Map<String, dynamic>)['id'] as int;
  }

  static Future<void> updateTodo(int id, {bool? isCompleted, String? status, String? title, String? notes, String? dueDate}) async {
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

  static Future<int> getNotifyParentsCount(int classSectionId) async {
    final data = await _get('/api/v1/teacher/notify-parents/count?class_section_id=$classSectionId');
    return (data as Map<String, dynamic>)['parent_count'] as int? ?? 0;
  }

  static Future<void> deleteTodo(int id) async {
    await _delete('/api/v1/teacher/todos/$id');
  }

  // ── Notify parents history ────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getNotifyParentsHistory({int? classSectionId, int? studentId}) async {
    final params = <String>[];
    if (classSectionId != null) params.add('class_section_id=$classSectionId');
    if (studentId != null) params.add('student_id=$studentId');
    final path = '/api/v1/teacher/notify-parents/history${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Admin: Parents ─────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminListParents({String? search, int? sectionId}) async {
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

  static Future<Map<String, dynamic>> adminGetParent(int parentId) async {
    final data = await _get('/api/v1/admin/parents/$parentId');
    return data as Map<String, dynamic>;
  }

  static Future<void> adminLinkParent(int parentId, {required int studentId, String relationType = 'parent'}) async {
    await _post('/api/v1/admin/parents/$parentId/link', {'student_id': studentId, 'relation_type': relationType});
  }

  static Future<String> adminResetParentPassword(int parentId) async {
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

  static Future<void> adminAssignTransport({required int studentId, required int routeId, int? stopId}) async {
    final body = <String, dynamic>{'student_id': studentId, 'route_id': routeId};
    if (stopId != null) body['stop_id'] = stopId;
    await _post('/api/v1/admin/transport/assignments', body);
  }

  static Future<void> adminRemoveTransportAssignment(int studentId) async {
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

  static Future<List<Map<String, dynamic>>> adminListWorkLogs({int? sectionId, String? dateFrom, String? dateTo}) async {
    final params = <String>[];
    if (sectionId != null) params.add('section_id=$sectionId');
    if (dateFrom != null) params.add('date_from=$dateFrom');
    if (dateTo != null) params.add('date_to=$dateTo');
    final path = '/api/v1/admin/work-logs${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  // ── Admin: Attenders ───────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> adminListAttenders({int? studentId}) async {
    final path = studentId != null
        ? '/api/v1/admin/attenders/student/$studentId'
        : '/api/v1/admin/attenders';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminFlagAttender(int attenderId, {required bool isFlagged}) async {
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

  static Future<void> adminDeleteFeeComponent(int id) async {
    await _delete('/api/v1/admin/fees/components/$id');
  }

  static Future<List<Map<String, dynamic>>> adminListFeeStructures({int? sectionId, String? status}) async {
    final params = <String>[];
    if (sectionId != null) params.add('section_id=$sectionId');
    if (status != null) params.add('status=$status');
    final path = '/api/v1/admin/fees/structures${params.isEmpty ? '' : '?${params.join('&')}'}';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminUpdateFeeStatus(int structureId, String status) async {
    await _post('/api/v1/admin/fees/structures/$structureId/status', {'status': status});
  }

  static Future<List<Map<String, dynamic>>> adminListFeePayments({int? structureId}) async {
    final path = structureId != null
        ? '/api/v1/admin/fees/structures/$structureId/payments'
        : '/api/v1/admin/fees/payments';
    final data = await _get(path);
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> adminRecordPayment({required int structureId, required double amount, String method = 'cash', String? reference}) async {
    await _post('/api/v1/admin/fees/structures/$structureId/payments',
        {'amount': amount, 'payment_method': method, if (reference != null) 'reference_number': reference});
  }

  // ── Admin: Leave Config ───────────────────────────────────────────────────

  static Future<Map<String, dynamic>> adminGetLeaveConfig() async {
    final data = await _get('/api/v1/admin/leave-config');
    return data as Map<String, dynamic>;
  }

  static Future<void> adminUpdateLeaveConfig(Map<String, dynamic> updates) async {
    await _patch('/api/v1/admin/leave-config', updates);
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
      int studentId, String filename, String contentType, int fileSize) async {
    return (await _post('/api/v1/teacher/students/$studentId/photo/upload-url', {
      'filename': filename,
      'content_type': contentType,
      'file_size': fileSize,
    })) as Map<String, dynamic>;
  }

  static Future<void> saveStudentPhoto(int studentId, String photoUrl) async {
    await _patch('/api/v1/teacher/students/$studentId/photo', {'photo_url': photoUrl});
  }

  // ── Push tokens ────────────────────────────────────────────────────────────

  static Future<void> registerPushToken(String fcmToken, String deviceId) async {
    await _post('/api/v1/teacher/push-token', {'fcm_token': fcmToken, 'device_id': deviceId});
  }

  // ── Teacher notifications ──────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getTeacherNotifications() async {
    final data = await _get('/api/v1/teacher/notifications');
    return (data as List<dynamic>).map((e) => e as Map<String, dynamic>).toList();
  }

  static Future<void> markNotificationRead(int notifId) async {
    await _post('/api/v1/teacher/notifications/$notifId/read', {});
  }

  // ── WhatsApp parent report ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>> generateWhatsAppReport(int studentId) async {
    return (await _post('/api/v1/teacher/students/$studentId/whatsapp-report', {}))
        as Map<String, dynamic>;
  }

  // ── Feature flags ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getFeatureConfig() async {
    final data = await _get('/api/v1/teacher/feature-config');
    return (data as Map<String, dynamic>?) ?? {};
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
}

class ApiError implements Exception {
  final String message;
  final int statusCode;
  const ApiError(this.message, this.statusCode);

  @override
  String toString() => message;
}
