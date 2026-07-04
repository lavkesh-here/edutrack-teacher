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

  // ── School-admin flags ANDed with SA platform flags ───────────────────────
  // Disabling either layer hides the feature. Enabling both is required to show it.

  bool get aiGenerate  => (_flags['feature.ai_generate']   ?? true) && (_flags['sa.ai_question_generation'] ?? true);
  bool get aiAnalysis  => (_flags['feature.ai_analysis']   ?? true) && (_flags['sa.ai_analysis']            ?? true);
  bool get pdfExport   =>  _flags['feature.pdf_export']    ?? true;
  bool get diksha      => (_flags['feature.diksha']         ?? true) && (_flags['sa.diksha_resources']       ?? true);
  bool get payroll     =>  _flags['feature.payroll']        ?? true;
  bool get visitorLog  =>  _flags['feature.visitor_log']   ?? true;
  bool get announcements => _flags['feature.announcements'] ?? true;
  bool get circulars   =>  _flags['feature.circulars']      ?? true;
  bool get fees        => (_flags['feature.parent_fees']    ?? true) && (_flags['sa.fees_module']            ?? true);
  bool get transport   => (_flags['feature.transport']      ?? true) && (_flags['sa.transport_module']       ?? true);
  bool get workLogs    =>  _flags['feature.work_logs']      ?? true;

  // ── SA-only flags (no school-admin counterpart) ───────────────────────────

  /// Whether the in-app AI support chat is available for this school/teacher.
  bool get aiSupportChat => _flags['sa.ai_support_chat'] ?? true;

  /// Whether the parent app is enabled for this school (controls parent-related admin items).
  bool get parentApp => _flags['sa.parent_app'] ?? true;

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

  bool isLocked(String key) {
    final entry = _teacher[key] ?? _parent[key];
    return (entry?['locked'] as bool?) ?? false;
  }

  bool isEnabled(String key) {
    final entry = _teacher[key] ?? _parent[key];
    return (entry?['enabled'] as bool?) ?? true;
  }

  String? planRequired(String key) {
    if (!isLocked(key)) return null;
    final entry = _teacher[key] ?? _parent[key];
    return entry?['plan_required'] as String?;
  }
}
