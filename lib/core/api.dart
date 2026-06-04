import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ── Models ──────────────────────────────────────────────────────────────────

class AuthResponse {
  final String token;
  final String teacherName;
  final String schoolName;
  final String role;
  final int teacherId;

  const AuthResponse({
    required this.token,
    required this.teacherName,
    required this.schoolName,
    required this.role,
    required this.teacherId,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j['access_token'] as String,
        teacherName: j['teacher_name'] as String,
        schoolName: j['school_name'] as String,
        role: j['role'] as String,
        teacherId: j['teacher_id'] as int,
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
    return TestScoresResponse(
      scores: raw.map((e) => StudentScore.fromJson(e as Map<String, dynamic>)).toList(),
      classAverage: (j['class_average'] as num?)?.toDouble(),
      highestMark: (j['highest'] as num?)?.toDouble(),
      belowAverageCount: j['below_average_count'] as int?,
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
  String status; // present | absent | late | ''

  AttendanceStudent({
    required this.id,
    required this.name,
    required this.rollNo,
    this.status = '',
  });

  factory AttendanceStudent.fromJson(Map<String, dynamic> j) => AttendanceStudent(
        id: j['id'] as int,
        name: j['name'] as String,
        rollNo: j['roll_no']?.toString() ?? '',
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

// ── API Client ───────────────────────────────────────────────────────────────

class ApiClient {
  static const _defaultBaseUrl = 'https://edutrack-api-6382035856.asia-south1.run.app';
  static const _prefKeyUrl = 'server_url';
  static const _prefKeyToken = 'auth_token';

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

  static Future<dynamic> _get(String path) async {
    final base = await getBaseUrl();
    final res = await http.get(
      Uri.parse('$base$path'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) throw ApiError('Session expired. Please log in again.', 401);
    if (res.statusCode >= 400) {
      final body = jsonDecode(res.body);
      throw ApiError(body['detail']?.toString() ?? 'Server error', res.statusCode);
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  static Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final base = await getBaseUrl();
    final res = await http.post(
      Uri.parse('$base$path'),
      headers: await _headers(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) throw ApiError('Session expired. Please log in again.', 401);
    if (res.statusCode >= 400) {
      final b = jsonDecode(res.body);
      throw ApiError(b['detail']?.toString() ?? 'Server error', res.statusCode);
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  static Future<AuthResponse> login(String email, String password) async {
    final data = await _post('/api/v1/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(data as Map<String, dynamic>);
  }

  // ── Tests ─────────────────────────────────────────────────────────────────

  static Future<List<TestSummary>> getTests() async {
    final data = await _get('/api/v1/tests');
    final list = data as List<dynamic>;
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
}

class ApiError implements Exception {
  final String message;
  final int statusCode;
  const ApiError(this.message, this.statusCode);

  @override
  String toString() => message;
}
