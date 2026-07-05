// TDD red phase — Session 44 v2 plan structure.
// Replicated inline (no platform deps) to keep tests runnable without device.
// When features.dart is updated, these serve as the contract.

import 'package:flutter_test/flutter_test.dart';

// ── Inline _FeatureFlags replicating expected features.dart post-v2 ───────────

class _FeatureFlags {
  final Map<String, bool> _flags;
  const _FeatureFlags(this._flags);

  factory _FeatureFlags.defaults() => const _FeatureFlags({});
  factory _FeatureFlags.fromMap(Map<String, bool> m) => _FeatureFlags(m);

  // ── Basic tier (all plans) ────────────────────────────────────────────────
  bool get transport     => (_flags['feature.transport']       ?? true) && (_flags['sa.transport_module']       ?? true);
  bool get syllabus      =>  _flags['feature.syllabus']        ?? true;
  bool get announcements =>  _flags['feature.announcements']   ?? true;
  bool get circulars     =>  _flags['feature.circulars']       ?? true;
  bool get workLogs      =>  _flags['feature.work_logs']       ?? true;
  bool get visitorLog    =>  _flags['feature.visitor_log']     ?? true;
  bool get todo          =>  _flags['feature.todo']            ?? true;

  // ── Standard tier ─────────────────────────────────────────────────────────
  bool get tests               =>  _flags['feature.tests']               ?? true;
  bool get payroll             =>  _flags['feature.payroll']             ?? true;
  bool get fees                => (_flags['feature.parent_fees']         ?? true) && (_flags['sa.fees_module'] ?? true);
  bool get aiGenerate          => (_flags['feature.ai_generate']         ?? true) && (_flags['sa.ai_question_generation'] ?? true);
  bool get attendanceAnalytics =>  _flags['feature.attendance_analytics'] ?? true;
  bool get operationalDashboard =>  _flags['feature.operational_dashboard'] ?? true;
  bool get pdfExport           =>  _flags['feature.pdf_export']          ?? true;

  // ── Premium tier ──────────────────────────────────────────────────────────
  bool get aiAnalysis        => (_flags['feature.ai_analysis']        ?? true) && (_flags['sa.ai_analysis']   ?? true);
  bool get analyticsDashboard =>  _flags['feature.analytics_dashboard'] ?? true;
  bool get onlineFees        =>  _flags['feature.online_fees']        ?? true;
  bool get spacedRepetition  =>  _flags['feature.spaced_repetition']  ?? true;
  bool get diksha            => (_flags['feature.diksha']             ?? true) && (_flags['sa.diksha_resources'] ?? true);

  // ── SA-only flags ─────────────────────────────────────────────────────────
  bool get aiSupportChat => _flags['sa.ai_support_chat'] ?? true;
  bool get parentApp     => _flags['sa.parent_app']      ?? true;

  bool operator [](String key) => _flags[key] ?? true;
}

// ── Plan flag maps (mirrors what /teacher/feature-config returns) ─────────────

Map<String, bool> _basicFlags() => {
  // basic tier — core infra only
  'feature.transport': true,
  'feature.syllabus': true,
  'feature.announcements': true,
  'feature.circulars': true,
  'feature.work_logs': true,
  'feature.visitor_log': true,
  'feature.todo': true,
  // locked out on basic
  'feature.tests': false,
  'feature.payroll': false,
  'feature.parent_fees': false,
  'feature.ai_generate': false,
  'feature.attendance_analytics': false,
  'feature.operational_dashboard': false,
  'feature.pdf_export': false,
  'feature.ai_analysis': false,
  'feature.analytics_dashboard': false,
  'feature.online_fees': false,
  'feature.spaced_repetition': false,
  'feature.diksha': false,
  // SA passthrough defaults
  'sa.transport_module': true,
  'sa.fees_module': false,
  'sa.ai_question_generation': false,
  'sa.ai_analysis': false,
  'sa.diksha_resources': false,
  'sa.ai_support_chat': true,
  'sa.parent_app': true,
};

Map<String, bool> _standardFlags() => {
  ..._basicFlags(),
  // cumulative unlocks for standard
  'feature.tests': true,
  'feature.payroll': true,
  'feature.parent_fees': true,
  'feature.ai_generate': true,
  'feature.attendance_analytics': true,
  'feature.operational_dashboard': true,
  'feature.pdf_export': true,
  // SA flags enabled for standard
  'sa.fees_module': true,
  'sa.ai_question_generation': true,
};

Map<String, bool> _premiumFlags() => {
  ..._standardFlags(),
  // cumulative unlocks for premium
  'feature.ai_analysis': true,
  'feature.analytics_dashboard': true,
  'feature.online_fees': true,
  'feature.spaced_repetition': true,
  'feature.diksha': true,
  // SA flags enabled for premium
  'sa.ai_analysis': true,
  'sa.diksha_resources': true,
};

void main() {
  // ── 1. FeatureFlags defaults ───────────────────────────────────────────────

  group('FeatureFlags.defaults', () {
    final f = _FeatureFlags.defaults();

    test('all accessors return true by default (fail-open for new installs)', () {
      expect(f.transport, isTrue);
      expect(f.syllabus, isTrue);
      expect(f.announcements, isTrue);
      expect(f.circulars, isTrue);
      expect(f.workLogs, isTrue);
      expect(f.visitorLog, isTrue);
      expect(f.todo, isTrue);
      expect(f.tests, isTrue);
      expect(f.payroll, isTrue);
      expect(f.fees, isTrue);
      expect(f.aiGenerate, isTrue);
      expect(f.attendanceAnalytics, isTrue);
      expect(f.operationalDashboard, isTrue);
      expect(f.pdfExport, isTrue);
      expect(f.aiAnalysis, isTrue);
      expect(f.analyticsDashboard, isTrue);
      expect(f.onlineFees, isTrue);
      expect(f.spacedRepetition, isTrue);
      expect(f.diksha, isTrue);
      expect(f.aiSupportChat, isTrue);
      expect(f.parentApp, isTrue);
    });

    test('subscript operator returns true for unknown key', () {
      expect(f['feature.nonexistent_key'], isTrue);
    });
  });

  // ── 2. Basic plan ──────────────────────────────────────────────────────────

  group('Basic plan', () {
    late _FeatureFlags f;
    setUp(() => f = _FeatureFlags.fromMap(_basicFlags()));

    // Always-on for basic
    test('transport is enabled on basic', () => expect(f.transport, isTrue));
    test('syllabus is enabled on basic', () => expect(f.syllabus, isTrue));
    test('announcements is enabled on basic', () => expect(f.announcements, isTrue));
    test('circulars is enabled on basic', () => expect(f.circulars, isTrue));
    test('workLogs is enabled on basic', () => expect(f.workLogs, isTrue));
    test('visitorLog is enabled on basic', () => expect(f.visitorLog, isTrue));
    test('todo is enabled on basic', () => expect(f.todo, isTrue));
    test('aiSupportChat is enabled on basic', () => expect(f.aiSupportChat, isTrue));
    test('parentApp is enabled on basic', () => expect(f.parentApp, isTrue));

    // Locked out on basic
    test('tests is disabled on basic', () => expect(f.tests, isFalse));
    test('payroll is disabled on basic', () => expect(f.payroll, isFalse));
    test('fees is disabled on basic', () => expect(f.fees, isFalse));
    test('aiGenerate is disabled on basic', () => expect(f.aiGenerate, isFalse));
    test('attendanceAnalytics is disabled on basic', () => expect(f.attendanceAnalytics, isFalse));
    test('operationalDashboard is disabled on basic', () => expect(f.operationalDashboard, isFalse));
    test('pdfExport is disabled on basic', () => expect(f.pdfExport, isFalse));
    test('aiAnalysis is disabled on basic', () => expect(f.aiAnalysis, isFalse));
    test('analyticsDashboard is disabled on basic', () => expect(f.analyticsDashboard, isFalse));
    test('onlineFees is disabled on basic', () => expect(f.onlineFees, isFalse));
    test('spacedRepetition is disabled on basic', () => expect(f.spacedRepetition, isFalse));
    test('diksha is disabled on basic', () => expect(f.diksha, isFalse));
  });

  // ── 3. Standard plan ──────────────────────────────────────────────────────

  group('Standard plan', () {
    late _FeatureFlags f;
    setUp(() => f = _FeatureFlags.fromMap(_standardFlags()));

    // Inherited from basic
    test('transport is enabled on standard (inherited from basic)', () => expect(f.transport, isTrue));
    test('syllabus is enabled on standard (inherited from basic)', () => expect(f.syllabus, isTrue));
    test('announcements is enabled on standard', () => expect(f.announcements, isTrue));

    // New unlocks at standard
    test('tests is enabled on standard', () => expect(f.tests, isTrue));
    test('payroll is enabled on standard', () => expect(f.payroll, isTrue));
    test('fees is enabled on standard (manual entry)', () => expect(f.fees, isTrue));
    test('aiGenerate is enabled on standard (with daily limit)', () => expect(f.aiGenerate, isTrue));
    test('attendanceAnalytics is enabled on standard', () => expect(f.attendanceAnalytics, isTrue));
    test('operationalDashboard is enabled on standard', () => expect(f.operationalDashboard, isTrue));
    test('pdfExport is enabled on standard', () => expect(f.pdfExport, isTrue));

    // Still locked on standard
    test('aiAnalysis is disabled on standard (premium only)', () => expect(f.aiAnalysis, isFalse));
    test('analyticsDashboard is disabled on standard (premium only)', () => expect(f.analyticsDashboard, isFalse));
    test('onlineFees is disabled on standard (premium only)', () => expect(f.onlineFees, isFalse));
    test('spacedRepetition is disabled on standard (premium only)', () => expect(f.spacedRepetition, isFalse));
    test('diksha is disabled on standard (premium only)', () => expect(f.diksha, isFalse));
  });

  // ── 4. Premium plan ────────────────────────────────────────────────────────

  group('Premium plan', () {
    late _FeatureFlags f;
    setUp(() => f = _FeatureFlags.fromMap(_premiumFlags()));

    test('all basic features remain enabled on premium', () {
      expect(f.transport, isTrue);
      expect(f.syllabus, isTrue);
      expect(f.announcements, isTrue);
      expect(f.circulars, isTrue);
      expect(f.workLogs, isTrue);
      expect(f.visitorLog, isTrue);
      expect(f.todo, isTrue);
    });

    test('all standard features remain enabled on premium', () {
      expect(f.tests, isTrue);
      expect(f.payroll, isTrue);
      expect(f.fees, isTrue);
      expect(f.aiGenerate, isTrue);
      expect(f.attendanceAnalytics, isTrue);
      expect(f.operationalDashboard, isTrue);
      expect(f.pdfExport, isTrue);
    });

    // Premium-exclusive unlocks
    test('aiAnalysis is enabled on premium', () => expect(f.aiAnalysis, isTrue));
    test('analyticsDashboard is enabled on premium', () => expect(f.analyticsDashboard, isTrue));
    test('onlineFees is enabled on premium', () => expect(f.onlineFees, isTrue));
    test('spacedRepetition is enabled on premium', () => expect(f.spacedRepetition, isTrue));
    test('diksha is enabled on premium', () => expect(f.diksha, isTrue));
  });

  // ── 5. SA layer AND-gate ───────────────────────────────────────────────────

  group('SA AND-gate', () {
    test('transport disabled when SA disables transport_module', () {
      final f = _FeatureFlags.fromMap({
        'feature.transport': true,
        'sa.transport_module': false,
      });
      expect(f.transport, isFalse);
    });

    test('aiGenerate disabled when SA disables ai_question_generation', () {
      final f = _FeatureFlags.fromMap({
        'feature.ai_generate': true,
        'sa.ai_question_generation': false,
      });
      expect(f.aiGenerate, isFalse);
    });

    test('aiAnalysis disabled when SA disables ai_analysis', () {
      final f = _FeatureFlags.fromMap({
        'feature.ai_analysis': true,
        'sa.ai_analysis': false,
      });
      expect(f.aiAnalysis, isFalse);
    });

    test('fees disabled when SA disables fees_module', () {
      final f = _FeatureFlags.fromMap({
        'feature.parent_fees': true,
        'sa.fees_module': false,
      });
      expect(f.fees, isFalse);
    });

    test('diksha disabled when SA disables diksha_resources', () {
      final f = _FeatureFlags.fromMap({
        'feature.diksha': true,
        'sa.diksha_resources': false,
      });
      expect(f.diksha, isFalse);
    });

    test('both layers must be true for AND-gated feature to be enabled', () {
      final bothTrue = _FeatureFlags.fromMap({
        'feature.transport': true,
        'sa.transport_module': true,
      });
      expect(bothTrue.transport, isTrue);
    });

    test('features without SA counterpart: only feature flag matters', () {
      final f = _FeatureFlags.fromMap({'feature.payroll': false});
      expect(f.payroll, isFalse);

      final g = _FeatureFlags.fromMap({'feature.payroll': true});
      expect(g.payroll, isTrue);
    });
  });

  // ── 6. Plan upgrade/downgrade transitions ─────────────────────────────────

  group('Plan transitions', () {
    test('upgrading basic→standard unlocks tests', () {
      final basic = _FeatureFlags.fromMap(_basicFlags());
      final standard = _FeatureFlags.fromMap(_standardFlags());
      expect(basic.tests, isFalse);
      expect(standard.tests, isTrue);
    });

    test('upgrading basic→standard unlocks payroll', () {
      final basic = _FeatureFlags.fromMap(_basicFlags());
      final standard = _FeatureFlags.fromMap(_standardFlags());
      expect(basic.payroll, isFalse);
      expect(standard.payroll, isTrue);
    });

    test('upgrading basic→standard unlocks fees', () {
      final basic = _FeatureFlags.fromMap(_basicFlags());
      final standard = _FeatureFlags.fromMap(_standardFlags());
      expect(basic.fees, isFalse);
      expect(standard.fees, isTrue);
    });

    test('upgrading standard→premium unlocks aiAnalysis', () {
      final standard = _FeatureFlags.fromMap(_standardFlags());
      final premium = _FeatureFlags.fromMap(_premiumFlags());
      expect(standard.aiAnalysis, isFalse);
      expect(premium.aiAnalysis, isTrue);
    });

    test('upgrading standard→premium unlocks onlineFees', () {
      final standard = _FeatureFlags.fromMap(_standardFlags());
      final premium = _FeatureFlags.fromMap(_premiumFlags());
      expect(standard.onlineFees, isFalse);
      expect(premium.onlineFees, isTrue);
    });

    test('upgrading standard→premium unlocks analyticsDashboard', () {
      final standard = _FeatureFlags.fromMap(_standardFlags());
      final premium = _FeatureFlags.fromMap(_premiumFlags());
      expect(standard.analyticsDashboard, isFalse);
      expect(premium.analyticsDashboard, isTrue);
    });

    test('downgrading premium→standard hides aiAnalysis', () {
      final premium = _FeatureFlags.fromMap(_premiumFlags());
      final downgraded = _FeatureFlags.fromMap(_standardFlags());
      expect(premium.aiAnalysis, isTrue);
      expect(downgraded.aiAnalysis, isFalse);
    });

    test('downgrading standard→basic hides tests', () {
      final standard = _FeatureFlags.fromMap(_standardFlags());
      final downgraded = _FeatureFlags.fromMap(_basicFlags());
      expect(standard.tests, isTrue);
      expect(downgraded.tests, isFalse);
    });

    test('transport and syllabus survive downgrade to basic', () {
      final premium = _FeatureFlags.fromMap(_premiumFlags());
      final downgraded = _FeatureFlags.fromMap(_basicFlags());
      // these should still be true on basic
      expect(premium.transport, isTrue);
      expect(downgraded.transport, isTrue);
      expect(premium.syllabus, isTrue);
      expect(downgraded.syllabus, isTrue);
    });
  });

  // ── 7. v2 vs v1 regression — verify old wrong plan assignments are fixed ──

  group('v2 plan assignment regressions', () {
    test('transport was wrongly premium in v1 — must be basic in v2', () {
      final basic = _FeatureFlags.fromMap(_basicFlags());
      expect(basic.transport, isTrue,
          reason: 'transport was moved to basic in v2; regression if false');
    });

    test('payroll was wrongly premium in v1 — must be standard in v2', () {
      final standard = _FeatureFlags.fromMap(_standardFlags());
      final basic = _FeatureFlags.fromMap(_basicFlags());
      expect(standard.payroll, isTrue,
          reason: 'payroll was moved to standard in v2; regression if false on standard');
      expect(basic.payroll, isFalse,
          reason: 'payroll still locked on basic');
    });

    test('syllabus is basic in v2 (previously was premium in proposal)', () {
      final basic = _FeatureFlags.fromMap(_basicFlags());
      expect(basic.syllabus, isTrue,
          reason: 'syllabus kept in basic — all schools get it');
    });
  });

  // ── 8. Question gen limit display logic ───────────────────────────────────

  group('Question generation limit display', () {
    test('standard: aiGenerate enabled (daily-limited by SA key value)', () {
      final f = _FeatureFlags.fromMap(_standardFlags());
      expect(f.aiGenerate, isTrue,
          reason: 'standard unlocks generation; daily quota enforced server-side');
    });

    test('premium: aiGenerate enabled (effectively unlimited, limit=999)', () {
      final f = _FeatureFlags.fromMap(_premiumFlags());
      expect(f.aiGenerate, isTrue);
    });

    test('basic: aiGenerate disabled (no access to question generation)', () {
      final f = _FeatureFlags.fromMap(_basicFlags());
      expect(f.aiGenerate, isFalse);
    });
  });

  // ── 9. AdminFeatureConfig v2 plan display ────────────────────────────────

  group('AdminFeatureConfig v2 plan tiers', () {
    // Mirrors expected /admin/feature-config response for each plan
    Map<String, dynamic> _lockedEntry(String planRequired) =>
        {'enabled': false, 'locked': true, 'plan_required': planRequired};
    Map<String, dynamic> _enabledEntry() =>
        {'enabled': true, 'locked': false, 'plan_required': null};

    test('basic plan config: transport unlocked, tests locked at standard', () {
      final teacher = {
        'feature.transport': _enabledEntry(),
        'feature.syllabus': _enabledEntry(),
        'feature.tests': _lockedEntry('standard'),
        'feature.payroll': _lockedEntry('standard'),
        'feature.ai_analysis': _lockedEntry('premium'),
        'feature.analytics_dashboard': _lockedEntry('premium'),
      };

      bool isLocked(String key) => (teacher[key]?['locked'] as bool?) ?? false;
      String? planReq(String key) {
        if (!isLocked(key)) return null;
        return teacher[key]?['plan_required'] as String?;
      }

      expect(isLocked('feature.transport'), isFalse);
      expect(isLocked('feature.syllabus'), isFalse);
      expect(isLocked('feature.tests'), isTrue);
      expect(planReq('feature.tests'), 'standard');
      expect(planReq('feature.payroll'), 'standard');
      expect(planReq('feature.ai_analysis'), 'premium');
      expect(planReq('feature.analytics_dashboard'), 'premium');
    });

    test('standard plan config: payroll unlocked, aiAnalysis locked at premium', () {
      final teacher = {
        'feature.payroll': _enabledEntry(),
        'feature.tests': _enabledEntry(),
        'feature.ai_generate': _enabledEntry(),
        'feature.ai_analysis': _lockedEntry('premium'),
        'feature.online_fees': _lockedEntry('premium'),
      };

      bool isLocked(String key) => (teacher[key]?['locked'] as bool?) ?? false;
      expect(isLocked('feature.payroll'), isFalse);
      expect(isLocked('feature.tests'), isFalse);
      expect(isLocked('feature.ai_analysis'), isTrue);
      expect(isLocked('feature.online_fees'), isTrue);
    });
  });
}
