import 'cache.dart';

/// Typed accessor for school feature flags.
/// Each accessor ANDs the school-admin flag (feature.*) with the SA platform flag (sa.*).
/// Defaults to `true` (enabled) for any unknown key — new features are on by default.
class FeatureFlags {
  final Map<String, bool> _flags;

  const FeatureFlags(this._flags);

  factory FeatureFlags.defaults() => const FeatureFlags({});

  factory FeatureFlags.fromJson(Map<String, dynamic> j) => FeatureFlags(
        Map<String, bool>.fromEntries(
          j.entries.map((e) => MapEntry(e.key, (e.value as bool?) ?? true)),
        ),
      );

  // ── Basic tier ────────────────────────────────────────────────────────────
  bool get transport     => (_flags['feature.transport']       ?? true) && (_flags['sa.transport_module']       ?? true);
  bool get syllabus      =>  _flags['feature.syllabus']        ?? true;
  bool get announcements =>  _flags['feature.announcements']   ?? true;
  bool get circulars     =>  _flags['feature.circulars']       ?? true;
  bool get workLogs      =>  _flags['feature.work_logs']       ?? true;
  bool get visitorLog    =>  _flags['feature.visitor_log']     ?? true;
  bool get todo          =>  _flags['feature.todo']            ?? true;
  bool get library       =>  _flags['feature.library']         ?? true;
  bool get brainBooster  =>  _flags['feature.brain_booster']   ?? true;

  // ── Standard tier ─────────────────────────────────────────────────────────
  bool get tests               =>  _flags['feature.tests']               ?? true;
  bool get payroll             =>  _flags['feature.payroll']             ?? true;
  bool get fees                => (_flags['feature.parent_fees']         ?? true) && (_flags['sa.fees_module'] ?? true);
  bool get aiGenerate          => (_flags['feature.ai_generate']         ?? true) && (_flags['sa.ai_question_generation'] ?? true);
  bool get attendanceAnalytics =>  _flags['feature.attendance_analytics'] ?? true;
  bool get operationalDashboard =>  _flags['feature.operational_dashboard'] ?? true;
  bool get pdfExport           =>  _flags['feature.pdf_export']          ?? true;

  // ── Premium tier ──────────────────────────────────────────────────────────
  bool get aiAnalysis         => (_flags['feature.ai_analysis']        ?? true) && (_flags['sa.ai_analysis']   ?? true);
  bool get analyticsDashboard =>  _flags['feature.analytics_dashboard'] ?? true;
  bool get onlineFees         =>  _flags['feature.online_fees']        ?? true;
  bool get spacedRepetition   =>  _flags['feature.spaced_repetition']  ?? true;
  bool get diksha             => (_flags['feature.diksha']             ?? true) && (_flags['sa.diksha_resources'] ?? true);

  // ── SA-only flags ─────────────────────────────────────────────────────────
  bool get aiSupportChat => _flags['sa.ai_support_chat'] ?? true;
  bool get parentApp     => _flags['sa.parent_app']      ?? true;

  bool operator [](String key) => _flags[key] ?? true;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(_flags);

  // ── Cache helpers ─────────────────────────────────────────────────────────

  static const _cacheKey = 'feature_flags';
  static const _cacheTtl = Duration(minutes: 30);

  static Future<FeatureFlags?> fromCache() async {
    final cached = await CacheService.getMap(_cacheKey, maxAge: _cacheTtl);
    if (cached == null) return null;
    return FeatureFlags.fromJson(cached);
  }

  Future<void> saveToCache() async {
    await CacheService.set(_cacheKey, toJson());
  }

  static Future<void> clearCache() async {
    await CacheService.remove(_cacheKey);
  }
}

/// Rich feature config for admin/director role — includes lock state and plan info.
/// Loaded separately from FeatureFlags (calls GET /admin/feature-config).
class AdminFeatureConfig {
  final String plan;
  final Map<String, Map<String, dynamic>> _teacher;
  final Map<String, Map<String, dynamic>> _parent;

  AdminFeatureConfig({
    required this.plan,
    required Map<String, dynamic> teacher,
    required Map<String, dynamic> parent,
  })  : _teacher = Map<String, Map<String, dynamic>>.from(
              teacher.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)))),
        _parent = Map<String, Map<String, dynamic>>.from(
              parent.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map))));

  factory AdminFeatureConfig.fromJson(Map<String, dynamic> j) {
    return AdminFeatureConfig(
      plan: j['plan'] as String? ?? 'basic',
      teacher: (j['teacher'] as Map<String, dynamic>? ?? {}),
      parent: (j['parent'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic>? _entry(String role, String key) =>
      role == 'parent' ? _parent[key] : _teacher[key];

  bool isLocked(String role, String key) {
    return (_entry(role, key)?['locked'] as bool?) ?? false;
  }

  bool isEnabled(String role, String key) {
    return (_entry(role, key)?['enabled'] as bool?) ?? true;
  }

  /// Non-null when disabling this feature has real operational impact —
  /// the admin UI should confirm before turning it off. `role` matters:
  /// the same feature key can carry a different warning per role
  /// (e.g. feature.work_logs means something different for teacher vs parent).
  String? criticalWarning(String role, String key) {
    return _entry(role, key)?['critical_warning'] as String?;
  }

  String? planRequired(String role, String key) {
    if (!isLocked(role, key)) return null;
    return _entry(role, key)?['plan_required'] as String?;
  }
}
