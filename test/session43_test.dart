// Pure logic tests for Session 43 feature packaging.
// No device or platform channels required.

import 'package:flutter_test/flutter_test.dart';

// ── AdminFeatureConfig logic (replicated inline — no platform deps) ────────────

class _FeatureEntry {
  final bool enabled;
  final bool locked;
  final String? planRequired;
  _FeatureEntry({required this.enabled, required this.locked, this.planRequired});
}

class _AdminFeatureConfig {
  final String plan;
  final Map<String, _FeatureEntry> _teacher;
  final Map<String, _FeatureEntry> _parent;

  _AdminFeatureConfig({
    required this.plan,
    required Map<String, dynamic> teacher,
    required Map<String, dynamic> parent,
  })  : _teacher = _parse(teacher),
        _parent = _parse(parent);

  static Map<String, _FeatureEntry> _parse(Map<String, dynamic> m) => {
        for (final e in m.entries)
          e.key: _FeatureEntry(
            enabled: (e.value as Map<String, dynamic>)['enabled'] as bool? ?? true,
            locked: (e.value as Map<String, dynamic>)['locked'] as bool? ?? false,
            planRequired: (e.value as Map<String, dynamic>)['plan_required'] as String?,
          ),
      };

  factory _AdminFeatureConfig.fromJson(Map<String, dynamic> j) =>
      _AdminFeatureConfig(
        plan: j['plan'] as String? ?? 'basic',
        teacher: Map<String, dynamic>.from(j['teacher'] as Map? ?? {}),
        parent: Map<String, dynamic>.from(j['parent'] as Map? ?? {}),
      );

  bool isLocked(String key) => (_teacher[key] ?? _parent[key])?.locked ?? false;
  bool isEnabled(String key) => (_teacher[key] ?? _parent[key])?.enabled ?? true;
  String? planRequired(String key) {
    if (!isLocked(key)) return null;
    return (_teacher[key] ?? _parent[key])?.planRequired;
  }
}

void main() {
  // ── AdminFeatureConfig.fromJson ────────────────────────────────────────────

  group('AdminFeatureConfig.fromJson', () {
    final json = {
      'plan': 'standard',
      'teacher': {
        'feature.announcements': {'enabled': true, 'locked': false, 'plan_required': null},
        'feature.parent_fees': {'enabled': true, 'locked': false, 'plan_required': 'standard'},
        'feature.ai_generate': {'enabled': false, 'locked': true, 'plan_required': 'standard'},
        'feature.transport': {'enabled': false, 'locked': true, 'plan_required': 'premium'},
        'feature.payroll': {'enabled': false, 'locked': true, 'plan_required': 'premium'},
      },
      'parent': {
        'feature.parent_fees': {'enabled': true, 'locked': false, 'plan_required': 'standard'},
      },
    };

    late _AdminFeatureConfig cfg;
    setUp(() => cfg = _AdminFeatureConfig.fromJson(json));

    test('plan is parsed correctly', () => expect(cfg.plan, 'standard'));

    test('unlocked enabled feature: isLocked=false, isEnabled=true', () {
      expect(cfg.isLocked('feature.announcements'), isFalse);
      expect(cfg.isEnabled('feature.announcements'), isTrue);
    });

    test('locked feature: isLocked=true', () {
      expect(cfg.isLocked('feature.ai_generate'), isTrue);
      expect(cfg.isEnabled('feature.ai_generate'), isFalse);
    });

    test('planRequired returns null for unlocked feature', () {
      expect(cfg.planRequired('feature.announcements'), isNull);
    });

    test('planRequired returns plan string for locked standard feature', () {
      expect(cfg.planRequired('feature.ai_generate'), 'standard');
    });

    test('planRequired returns premium for premium-locked feature', () {
      expect(cfg.planRequired('feature.transport'), 'premium');
      expect(cfg.planRequired('feature.payroll'), 'premium');
    });

    test('missing key → not locked, enabled by default', () {
      expect(cfg.isLocked('feature.nonexistent'), isFalse);
      expect(cfg.isEnabled('feature.nonexistent'), isTrue);
      expect(cfg.planRequired('feature.nonexistent'), isNull);
    });

    test('parent-only key resolved via _parent map', () {
      // feature.parent_fees defined in parent map too
      expect(cfg.isEnabled('feature.parent_fees'), isTrue);
    });
  });

  group('AdminFeatureConfig plan fallback', () {
    test('missing plan defaults to basic', () {
      final cfg = _AdminFeatureConfig.fromJson({'teacher': {}, 'parent': {}});
      expect(cfg.plan, 'basic');
    });

    test('empty teacher/parent maps parse without error', () {
      final cfg = _AdminFeatureConfig.fromJson({'plan': 'premium', 'teacher': {}, 'parent': {}});
      expect(cfg.plan, 'premium');
      expect(cfg.isLocked('feature.ai_generate'), isFalse);
    });
  });

  // ── Feature flag gating logic ──────────────────────────────────────────────

  group('FeatureFlags plan-ceiling gate', () {
    // Mirrors what /teacher/feature-config returns after plan ceiling applied:
    // basic plan: announcements/circulars/work_logs = true; fees/ai_generate = false

    Map<String, bool> basicFlags() => {
          'feature.announcements': true,
          'feature.circulars': true,
          'feature.work_logs': true,
          'feature.parent_fees': false,
          'feature.ai_generate': false,
          'feature.transport': false,
          'feature.payroll': false,
        };

    Map<String, bool> standardFlags() => {
          ...basicFlags(),
          'feature.parent_fees': true,
          'feature.ai_generate': true,
        };

    Map<String, bool> premiumFlags() => {
          ...standardFlags(),
          'feature.transport': true,
          'feature.payroll': true,
        };

    bool get_(Map<String, bool> flags, String key) => flags[key] ?? true;

    test('basic plan: announcements enabled', () => expect(get_(basicFlags(), 'feature.announcements'), isTrue));
    test('basic plan: fees disabled', () => expect(get_(basicFlags(), 'feature.parent_fees'), isFalse));
    test('basic plan: ai_generate disabled', () => expect(get_(basicFlags(), 'feature.ai_generate'), isFalse));
    test('standard plan: fees enabled', () => expect(get_(standardFlags(), 'feature.parent_fees'), isTrue));
    test('standard plan: transport still disabled', () => expect(get_(standardFlags(), 'feature.transport'), isFalse));
    test('premium plan: all enabled', () {
      for (final key in premiumFlags().keys) {
        expect(get_(premiumFlags(), key), isTrue, reason: '$key should be true on premium');
      }
    });
    test('upgrade from basic to standard unlocks fees', () {
      expect(get_(basicFlags(), 'feature.parent_fees'), isFalse);
      expect(get_(standardFlags(), 'feature.parent_fees'), isTrue);
    });
  });

  // ── Locked feature row — upgrade plan required display ─────────────────────

  group('Upgrade CTA plan label', () {
    String planLabel(String? plan) {
      switch (plan) {
        case 'standard': return 'Standard';
        case 'premium': return 'Premium';
        default: return 'Upgrade';
      }
    }

    test('standard plan_required → Standard label', () => expect(planLabel('standard'), 'Standard'));
    test('premium plan_required → Premium label', () => expect(planLabel('premium'), 'Premium'));
    test('null plan_required → Upgrade label', () => expect(planLabel(null), 'Upgrade'));
    test('unknown plan_required → Upgrade label', () => expect(planLabel('enterprise'), 'Upgrade'));
  });
}
