import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/api.dart';
import '../core/features.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminSchoolSettingsScreen extends StatefulWidget {
  const AdminSchoolSettingsScreen({super.key});

  @override
  State<AdminSchoolSettingsScreen> createState() => _AdminSchoolSettingsScreenState();
}

class _AdminSchoolSettingsScreenState extends State<AdminSchoolSettingsScreen> {
  final _nameCtrl = TextEditingController();
  final _boardCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isDirty = false;
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;
  AdminFeatureConfig? _featureConfig;
  bool _togglingFeature = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _onTextChanged() {
    if (!_isDirty) setState(() => _isDirty = true);
  }

  void _initListeners() {
    for (final c in [_nameCtrl, _boardCtrl, _phoneCtrl, _emailCtrl, _addressCtrl, _websiteCtrl]) {
      c.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _boardCtrl, _phoneCtrl, _emailCtrl, _addressCtrl, _websiteCtrl]) {
      c.removeListener(_onTextChanged);
    }
    _nameCtrl.dispose();
    _boardCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminGetSchool();
      _nameCtrl.text = data['name'] as String? ?? '';
      _boardCtrl.text = data['board_affiliation'] as String? ?? '';
      _phoneCtrl.text = data['phone'] as String? ?? '';
      _emailCtrl.text = data['email'] as String? ?? '';
      _addressCtrl.text = data['address'] as String? ?? '';
      _websiteCtrl.text = data['website'] as String? ?? '';
      _latitude = (data['latitude'] as num?)?.toDouble();
      _longitude = (data['longitude'] as num?)?.toDouble();
      setState(() => _loading = false);
      _initListeners();
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      setState(() => _loading = false);
    }
    try {
      final cfg = await ApiClient.getAdminFeatureConfig();
      if (mounted) setState(() => _featureConfig = AdminFeatureConfig.fromJson(cfg));
    } catch (_) {}
  }

  Future<void> _useMyLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      if (mounted) {
        showSnack(
          context,
          permission == LocationPermission.deniedForever
              ? 'Location permission permanently denied. Enable in device Settings.'
              : 'Location permission is required.',
          error: true,
        );
      }
      return;
    }
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) showSnack(context, 'Please enable location services.', error: true);
      return;
    }
    setState(() => _gettingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isDirty = true;
      });
      if (mounted) showSnack(context, 'Location captured. Tap Save Changes to apply.');
    } catch (_) {
      if (mounted) showSnack(context, 'Could not get location. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _toggleFeature(String role, String key, bool newValue) async {
    if (_togglingFeature) return;

    if (!newValue) {
      final warning = _featureConfig?.criticalWarning(role, key);
      if (warning != null) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dctx) => AlertDialog(
            title: const Text('⚠️ This impacts core functionality'),
            content: Text(warning),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('Disable anyway', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    setState(() => _togglingFeature = true);
    try {
      await ApiClient.adminSetFeatureConfig(role, key, newValue);
      final cfg = await ApiClient.getAdminFeatureConfig();
      if (mounted) {
        setState(() => _featureConfig = AdminFeatureConfig.fromJson(cfg));
        showSnack(context, 'Feature updated');
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _togglingFeature = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'board_affiliation': _boardCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
      };
      if (_latitude != null) body['latitude'] = _latitude;
      if (_longitude != null) body['longitude'] = _longitude;
      await ApiClient.adminUpdateSchool(body);
      if (mounted) {
        showSnack(context, 'Settings saved successfully');
        setState(() => _isDirty = false);
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('School Settings'),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.violetLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.violet.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Text('🏫', style: TextStyle(fontSize: 20)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Update your school\'s contact info and basic details.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.violet,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'SCHOOL INFO',
                    children: [
                      _LabeledField(
                        fieldKey: const Key('school_name_field'),
                        label: 'School Name',
                        controller: _nameCtrl,
                        hint: 'e.g. St. Mary\'s School',
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 14),
                      _LabeledField(
                        fieldKey: const Key('school_board_field'),
                        label: 'Board Affiliation',
                        controller: _boardCtrl,
                        hint: 'e.g. CBSE, ICSE, State Board',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'CONTACT',
                    children: [
                      _LabeledField(
                        fieldKey: const Key('school_phone_field'),
                        label: 'Phone',
                        controller: _phoneCtrl,
                        hint: 'e.g. +91 98765 43210',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 14),
                      _LabeledField(
                        fieldKey: const Key('school_email_field'),
                        label: 'Email',
                        controller: _emailCtrl,
                        hint: 'e.g. office@school.edu.in',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      _LabeledField(
                        fieldKey: const Key('school_website_field'),
                        label: 'Website',
                        controller: _websiteCtrl,
                        hint: 'e.g. https://school.edu.in',
                        keyboardType: TextInputType.url,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _SettingsSection(
                    title: 'ADDRESS',
                    children: [
                      _LabeledField(
                        fieldKey: const Key('school_address_field'),
                        label: 'Full Address',
                        controller: _addressCtrl,
                        hint: 'Street, City, State, PIN',
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // School Location section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SCHOOL LOCATION',
                        style: TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w800,
                          color: AppColors.muted, letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Location status
                            Row(
                              children: [
                                Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    color: _latitude != null ? AppColors.tealLight : AppColors.bg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _latitude != null ? '📍' : '🗺️',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _latitude != null ? 'Location Set' : 'Location Not Set',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _latitude != null ? AppColors.teal : AppColors.muted,
                                        ),
                                      ),
                                      if (_latitude != null && _longitude != null)
                                        Text(
                                          '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                                          style: const TextStyle(fontSize: 10, color: AppColors.muted),
                                        )
                                      else
                                        const Text(
                                          'Required for teacher GPS attendance',
                                          style: TextStyle(fontSize: 11, color: AppColors.muted),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: AppColors.border),
                            const SizedBox(height: 12),
                            const Text(
                              'Teachers must be within 50 meters of this location to mark self-attendance.',
                              style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _gettingLocation ? null : _useMyLocation,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.sky,
                                  side: const BorderSide(color: AppColors.sky),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                icon: _gettingLocation
                                    ? const SizedBox(width: 16, height: 16,
                                        child: CircularProgressIndicator(color: AppColors.sky, strokeWidth: 2))
                                    : const Icon(Icons.my_location, size: 16),
                                label: Text(
                                  _gettingLocation ? 'Getting location...' : 'Use My Current Location',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Features & Plan section
                  if (_featureConfig != null) ...[
                    _FeaturesPlanSection(
                      config: _featureConfig!,
                      toggling: _togglingFeature,
                      onToggle: _toggleFeature,
                    ),
                    const SizedBox(height: 28),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      key: const Key('save_school_settings_button'),
                      onPressed: _saving ? null : (_isDirty ? _save : null),
                      child: _saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Features & Plan Section ───────────────────────────────────────────────────
//
// Key lists mirror backend `_ALL_FEATURES` (app/api/v1/endpoints/admin/school.py).
// Kept as top-level constants (rather than nested in the private section widget)
// so admin_school_settings_test.dart can assert parity and catch future drift.

const teacherFeatureDefs = [
  ('feature.work_logs',   '📋', 'Work Logs',      'Homework & daily work tracking'),
  ('feature.announcements','📢', 'Announcements',  'Forum & school-wide posts'),
  ('feature.circulars',   '📄', 'Circulars',      'Circular distribution to parents'),
  ('feature.ai_analysis', '🤖', 'AI Analysis',    'AI-powered student performance insights'),
  ('feature.transport',   '🚌', 'Transport',      'Bus routes & stop management'),
  ('feature.parent_fees', '💰', 'Fee Management', 'Fee components & payment tracking'),
  ('feature.payroll',     '💳', 'Payroll',        'Teacher salary & auto-calculation'),
  ('feature.diksha',      '📚', 'DIKSHA',         'NCERT digital content library'),
  ('feature.syllabus',    '📘', 'Syllabus',       'Chapter-wise syllabus tracking'),
  ('feature.todo',        '✅', 'To-Do List',     'Personal task list for teachers'),
  ('feature.tests',       '📝', 'Tests',          'Test creation & score entry'),
  ('feature.ai_generate', '🧠', 'AI Question Generation', 'AI-generated test questions'),
  ('feature.attendance_analytics', '📊', 'Attendance Analytics', 'Attendance trends & insights'),
  ('feature.operational_dashboard', '📈', 'Operational Dashboard', 'School-wide operations overview'),
  ('feature.pdf_export',  '🖨️', 'PDF Export',     'Export reports & question papers as PDF'),
  ('feature.visitor_log', '🧾', 'Visitor Log',    'Track school visitor check-ins'),
  ('feature.analytics_dashboard', '📉', 'Analytics Dashboard', 'School performance analytics'),
  ('feature.online_fees', '💳', 'Online Fees',    'Online fee payment collection'),
  ('feature.spaced_repetition', '🔁', 'Spaced Repetition', 'Spaced-repetition revision tool'),
  ('feature.color_theme', '🎨', 'Custom Branding', 'Custom app color theme'),
  ('feature.library',     '📗', 'Library',        'Book catalog & issue tracking'),
  ('feature.brain_booster','🧩', 'Brain Booster',  'Daily puzzle game for students'),
];

const parentFeatureDefs = [
  ('feature.work_logs',   '📚', 'Work Log (Parent)',  'Parents see homework in parent app'),
  ('feature.circulars',   '📄', 'Circulars (Parent)', 'Circulars visible in parent app'),
  ('feature.parent_fees', '💰', 'Fees (Parent)',      'Fee status visible in parent app'),
  ('feature.transport',   '🚌', 'Transport (Parent)', 'Bus tracking in parent app'),
  ('feature.announcements','💬', 'Forum (Parent)',    'School forum access for parents'),
  ('feature.brain_booster','🧩', 'Brain Booster (Parent)', 'Daily puzzle game in parent app'),
];

class _FeaturesPlanSection extends StatelessWidget {
  final AdminFeatureConfig config;
  final bool toggling;
  final Future<void> Function(String role, String key, bool enabled) onToggle;

  const _FeaturesPlanSection({
    required this.config,
    required this.toggling,
    required this.onToggle,
  });

  static const _teacherFeatures = teacherFeatureDefs;
  static const _parentFeatures = parentFeatureDefs;

  Color _planColor(String plan) {
    return switch (plan) {
      'premium'  => AppColors.violet,
      'standard' => AppColors.teal,
      _          => AppColors.muted,
    };
  }

  Color _planBg(String plan) {
    return switch (plan) {
      'premium'  => AppColors.violetLight,
      'standard' => AppColors.tealLight,
      _          => AppColors.bg,
    };
  }

  @override
  Widget build(BuildContext context) {
    final planLabel = config.plan[0].toUpperCase() + config.plan.substring(1);
    final planColor = _planColor(config.plan);
    final planBg = _planBg(config.plan);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FEATURES & PLAN',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.8),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plan badge
              Row(
                children: [
                  const Text('Your plan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text2)),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: planBg, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      planLabel.toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: planColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              // Teacher features
              const Text('TEACHER APP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              ..._teacherFeatures.map((f) {
                final (key, icon, title, sub) = f;
                final locked = config.isLocked('teacher', key);
                final enabled = config.isEnabled('teacher', key);
                final planReq = config.planRequired('teacher', key);
                return _FeatureToggleRow(
                  icon: icon,
                  title: title,
                  sub: sub,
                  enabled: enabled,
                  locked: locked,
                  planRequired: planReq,
                  toggling: toggling,
                  onToggle: locked ? null : (v) => onToggle('teacher', key, v),
                );
              }),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 12),
              // Parent features
              const Text('PARENT APP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.6)),
              const SizedBox(height: 8),
              ..._parentFeatures.map((f) {
                final (key, icon, title, sub) = f;
                final locked = config.isLocked('parent', key);
                final enabled = config.isEnabled('parent', key);
                final planReq = config.planRequired('parent', key);
                return _FeatureToggleRow(
                  icon: icon,
                  title: title,
                  sub: sub,
                  enabled: enabled,
                  locked: locked,
                  planRequired: planReq,
                  toggling: toggling,
                  onToggle: locked ? null : (v) => onToggle('parent', key, v),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureToggleRow extends StatelessWidget {
  final String icon;
  final String title;
  final String sub;
  final bool enabled;
  final bool locked;
  final String? planRequired;
  final bool toggling;
  final void Function(bool)? onToggle;

  const _FeatureToggleRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.enabled,
    required this.locked,
    required this.toggling,
    this.planRequired,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: locked ? 0.55 : 1.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                      if (planRequired != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.violetLight, borderRadius: BorderRadius.circular(5)),
                          child: Text(
                            planRequired!.toUpperCase(),
                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.violet),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
            locked
                ? const Icon(Icons.lock_outline, size: 18, color: AppColors.muted)
                : Switch(
                    value: enabled,
                    onChanged: toggling ? null : onToggle,
                    activeColor: AppColors.teal,
                  ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.muted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final Key? fieldKey;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.fieldKey,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.text2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
