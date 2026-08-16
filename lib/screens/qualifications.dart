import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class QualificationsScreen extends StatefulWidget {
  const QualificationsScreen({super.key});

  @override
  State<QualificationsScreen> createState() => _QualificationsScreenState();
}

class _QualificationsScreenState extends State<QualificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _qualifications = [];
  List<Map<String, dynamic>> _experience = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
      final results = await Future.wait([
        ApiClient.getQualifications(),
        ApiClient.getExperience(),
      ]);
      if (mounted) {
        setState(() {
          _qualifications = results[0];
          _experience = results[1];
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _deleteQualification(String id) async {
    try {
      await ApiClient.deleteQualification(id);
      setState(() => _qualifications.removeWhere((q) => q['id'].toString() == id));
      if (mounted) showSnack(context, 'Qualification removed');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _deleteExperience(String id) async {
    try {
      await ApiClient.deleteExperience(id);
      setState(() => _experience.removeWhere((e) => e['id'].toString() == id));
      if (mounted) showSnack(context, 'Experience removed');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  void _showAddQualification() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddQualificationSheet(
        onAdded: (q) {
          setState(() => _qualifications.insert(0, q));
        },
      ),
    );
  }

  void _showAddExperience() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddExperienceSheet(
        onAdded: (e) {
          setState(() => _experience.insert(0, e));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Qualifications', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: null,
          indicatorWeight: 3,
          labelColor: AppColors.text,
          unselectedLabelColor: AppColors.muted,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Education'),
            Tab(text: 'Experience'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading ? null : () {
          if (_tabs.index == 0) {
            _showAddQualification();
          } else {
            _showAddExperience();
          }
        },
        backgroundColor: null,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorView(message: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _QualificationsList(
                      items: _qualifications,
                      onDelete: _deleteQualification,
                    ),
                    _ExperienceList(
                      items: _experience,
                      onDelete: _deleteExperience,
                    ),
                  ],
                ),
    );
  }
}

// ── Education list ────────────────────────────────────────────────────────────

class _QualificationsList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(String) onDelete;

  const _QualificationsList({required this.items, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎓', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text('No education records yet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted)),
              SizedBox(height: 4),
              Text('Tap + to add your degrees and certifications.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final q = items[i];
        final id = q['id'].toString();
        return Dismissible(
          key: Key(id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await _confirmDelete(context, 'Remove this qualification?');
          },
          onDismissed: (_) => onDelete(id),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.violetLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('🎓', style: TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        q['degree_type'] as String? ?? '',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        q['institution'] as String? ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600),
                      ),
                      if ((q['field_of_study'] as String?)?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          q['field_of_study'] as String,
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                if (q['year_passed'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.violetLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${q['year_passed']}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.violet),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Experience list ───────────────────────────────────────────────────────────

class _ExperienceList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final void Function(String) onDelete;

  const _ExperienceList({required this.items, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('💼', style: TextStyle(fontSize: 40)),
              SizedBox(height: 12),
              Text('No experience records yet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.muted)),
              SizedBox(height: 4),
              Text('Tap + to add your work history.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final exp = items[i];
        final id = exp['id'].toString();
        final isCurrent = exp['is_current'] as bool? ?? false;
        final fromYear = exp['from_year']?.toString() ?? '';
        final toYear = isCurrent ? 'Present' : (exp['to_year']?.toString() ?? '');
        final period = toYear.isNotEmpty ? '$fromYear – $toYear' : fromYear;

        return Dismissible(
          key: Key(id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: AppColors.coral,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          confirmDismiss: (_) async {
            return await _confirmDelete(context, 'Remove this experience?');
          },
          onDismissed: (_) => onDelete(id),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(isCurrent ? '⭐' : '💼', style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exp['role'] as String? ?? '',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.tealLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Current',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.teal)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exp['institution'] as String? ?? '',
                        style: const TextStyle(fontSize: 12, color: AppColors.text2, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(period, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Add Qualification bottom sheet ────────────────────────────────────────────

class _AddQualificationSheet extends StatefulWidget {
  final void Function(Map<String, dynamic>) onAdded;
  const _AddQualificationSheet({required this.onAdded});

  @override
  State<_AddQualificationSheet> createState() => _AddQualificationSheetState();
}

class _AddQualificationSheetState extends State<_AddQualificationSheet> {
  String? _degreeType;
  final _institutionCtrl = TextEditingController();
  final _fieldCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  bool _saving = false;

  static const _degreeOptions = [
    'B.Ed', 'M.Ed', 'B.A', 'M.A', 'B.Sc', 'M.Sc', 'B.Com', 'M.Com',
    'B.Tech', 'M.Tech', 'MBA', 'Ph.D', 'Diploma', 'Certificate', 'Other',
  ];

  @override
  void dispose() {
    _institutionCtrl.dispose();
    _fieldCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_degreeType == null) {
      showSnack(context, 'Please select a degree type', error: true);
      return;
    }
    if (_institutionCtrl.text.trim().isEmpty) {
      showSnack(context, 'Please enter the institution name', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final yearText = _yearCtrl.text.trim();
      final year = yearText.isNotEmpty ? int.tryParse(yearText) : null;
      final id = await ApiClient.addQualification(
        degreeType: _degreeType!,
        institution: _institutionCtrl.text.trim(),
        fieldOfStudy: _fieldCtrl.text.trim().isNotEmpty ? _fieldCtrl.text.trim() : null,
        yearPassed: year,
      );
      widget.onAdded({
        'id': id,
        'degree_type': _degreeType,
        'institution': _institutionCtrl.text.trim(),
        'field_of_study': _fieldCtrl.text.trim().isNotEmpty ? _fieldCtrl.text.trim() : null,
        'year_passed': year,
      });
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return QualificationsFormSheet(
      title: 'Add Education',
      saving: _saving,
      onSave: _save,
      children: [
        _SheetLabel('Degree / Certificate'),
        DropdownButtonFormField<String>(
          value: _degreeType,
          hint: const Text('Select degree type'),
          decoration: const InputDecoration(),
          items: _degreeOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() => _degreeType = v),
        ),
        const SizedBox(height: 14),
        _SheetLabel('Institution'),
        TextField(
          key: const Key('qualification_institution_field'),
          controller: _institutionCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Delhi University'),
        ),
        const SizedBox(height: 14),
        _SheetLabel('Field of Study (optional)'),
        TextField(
          key: const Key('qualification_field_of_study'),
          controller: _fieldCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Mathematics'),
        ),
        const SizedBox(height: 14),
        _SheetLabel('Year Passed (optional)'),
        TextField(
          key: const Key('qualification_year_field'),
          controller: _yearCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
          decoration: const InputDecoration(hintText: 'e.g. 2015'),
        ),
      ],
    );
  }
}

// ── Add Experience bottom sheet ───────────────────────────────────────────────

class _AddExperienceSheet extends StatefulWidget {
  final void Function(Map<String, dynamic>) onAdded;
  const _AddExperienceSheet({required this.onAdded});

  @override
  State<_AddExperienceSheet> createState() => _AddExperienceSheetState();
}

class _AddExperienceSheetState extends State<_AddExperienceSheet> {
  final _institutionCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  bool _isCurrent = false;
  bool _saving = false;

  @override
  void dispose() {
    _institutionCtrl.dispose();
    _roleCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_institutionCtrl.text.trim().isEmpty) {
      showSnack(context, 'Please enter the institution name', error: true);
      return;
    }
    if (_roleCtrl.text.trim().isEmpty) {
      showSnack(context, 'Please enter your role/position', error: true);
      return;
    }
    final fromYear = int.tryParse(_fromCtrl.text.trim());
    if (fromYear == null) {
      showSnack(context, 'Please enter a valid from year', error: true);
      return;
    }
    final toYear = _isCurrent ? null : int.tryParse(_toCtrl.text.trim());

    setState(() => _saving = true);
    try {
      final id = await ApiClient.addExperience(
        institution: _institutionCtrl.text.trim(),
        role: _roleCtrl.text.trim(),
        fromYear: fromYear,
        toYear: toYear,
        isCurrent: _isCurrent,
      );
      widget.onAdded({
        'id': id,
        'institution': _institutionCtrl.text.trim(),
        'role': _roleCtrl.text.trim(),
        'from_year': fromYear,
        'to_year': toYear,
        'is_current': _isCurrent,
      });
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return QualificationsFormSheet(
      title: 'Add Work Experience',
      saving: _saving,
      onSave: _save,
      children: [
        _SheetLabel('Institution / School Name'),
        TextField(
          key: const Key('experience_institution_field'),
          controller: _institutionCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. St. Mary\'s School'),
        ),
        const SizedBox(height: 14),
        _SheetLabel('Role / Position'),
        TextField(
          key: const Key('experience_role_field'),
          controller: _roleCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'e.g. Science Teacher'),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetLabel('From Year'),
                  TextField(
                    key: const Key('experience_from_year_field'),
                    controller: _fromCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    decoration: const InputDecoration(hintText: 'e.g. 2018'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SheetLabel('To Year'),
                  TextField(
                    key: const Key('experience_to_year_field'),
                    controller: _toCtrl,
                    keyboardType: TextInputType.number,
                    enabled: !_isCurrent,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                    decoration: InputDecoration(
                      hintText: _isCurrent ? 'Present' : 'e.g. 2022',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _isCurrent = !_isCurrent),
          child: Row(
            children: [
              Checkbox(
                value: _isCurrent,
                onChanged: (v) => setState(() => _isCurrent = v ?? false),
                activeColor: context.primary,
              ),
              const Text('I currently work here',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Shared sheet wrapper ──────────────────────────────────────────────────────

class QualificationsFormSheet extends StatelessWidget {
  final String title;
  final bool saving;
  final VoidCallback onSave;
  final List<Widget> children;

  const QualificationsFormSheet({
    super.key,
    required this.title,
    required this.saving,
    required this.onSave,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      // Demo-17 D5-class fix: both callers of this shared sheet (Add
      // Education, Add Work Experience) have enough fields -- including a
      // From/To-year row and a checkbox -- to plausibly push Save below the
      // visible viewport once the keyboard is open on a real phone. Same
      // defect already found and fixed in admin_teacher_roles.dart and
      // worklog.dart; same fix here.
      child: SingleChildScrollView(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.text)),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                key: const Key('qualifications_sheet_save_button'),
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text2)),
  );
}

Future<bool?> _confirmDelete(BuildContext context, String message) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text(message, style: const TextStyle(color: AppColors.muted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('😕', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.muted, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
