import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminTeacherRolesScreen extends StatefulWidget {
  const AdminTeacherRolesScreen({super.key});

  @override
  State<AdminTeacherRolesScreen> createState() =>
      _AdminTeacherRolesScreenState();
}

class _AdminTeacherRolesScreenState extends State<AdminTeacherRolesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _teachers = [];
  String _search = '';

  // 'medical_supervisor' used to be listed here, but it's not checked
  // anywhere on the backend -- selecting it silently did nothing. The real
  // mechanism for health-incident access is the dedicated is_nurse flag
  // (PATCH .../toggle-nurse), surfaced as its own switch below instead.
  static const _allTags = [
    ('attender', '🏠 Attender', 'Records visitors'),
    ('sports_teacher', '🏆 Sports Teacher', 'Sports activities'),
    ('hostel_warden', '🏨 Hostel Warden', 'Manages hostel'),
    ('librarian', '📚 Librarian', 'Manages library'),
  ];

  // Core-teaching sections that can be individually hidden for a plain
  // teacher whose role in the school is really front-office/support (e.g. a
  // receptionist built as role=teacher + 'attender' tag). Basic staff
  // features (Forum, My Leaves, My Attendance, Substitutions, Staff
  // Directory, Ask Vidya, Help) are intentionally never in this list — see
  // backend ALLOWED_DISABLABLE_FEATURES for the matching source of truth.
  static const _restrictableFeatures = [
    ('worklog', '📚 Homework / Classwork', 'Create & view work log entries'),
    ('notify', '🔔 Notify Parents', 'Send messages to parents'),
    ('results', '📊 Tests & Results', 'Post exam scores'),
    ('syllabus', '📖 Syllabus Progress', 'Update chapter completion status'),
    ('ptm', '🤝 PTM', 'Parent-teacher meetings & notes'),
    ('enquiries', '🙋 Enquiries', 'Visitor follow-ups'),
    ('health', '🏥 Health Incidents', 'Log student health events'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final teachers = await ApiClient.adminListTeachers(pageSize: 200);
      if (mounted) {
        setState(() {
          _teachers = teachers;
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted)
        setState(() {
          _error = e.message;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _teachers;
    final q = _search.toLowerCase();
    return _teachers
        .where((t) =>
            (t['name'] as String? ?? '').toLowerCase().contains(q) ||
            (t['email'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  void _showTagEditor(Map<String, dynamic> teacher) {
    final teacherId = teacher['id']?.toString() ?? '';
    final teacherName = teacher['name'] as String? ?? '—';
    final currentTags = List<String>.from(
      (teacher['functional_tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString()),
    );
    final currentIsNurse = teacher['is_nurse'] == true;
    final currentDisabledFeatures = List<String>.from(
      (teacher['disabled_features'] as List<dynamic>? ?? [])
          .map((e) => e.toString()),
    );
    final isRestrictable =
        (teacher['role'] as String? ?? 'teacher') == 'teacher';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TagEditorSheet(
        teacherId: teacherId,
        teacherName: teacherName,
        currentTags: currentTags,
        allTags: _allTags,
        currentIsNurse: currentIsNurse,
        currentDisabledFeatures: currentDisabledFeatures,
        restrictableFeatures: _restrictableFeatures,
        isRestrictable: isRestrictable,
        onSaved: (newTags, newDisabledFeatures) {
          setState(() {
            final idx =
                _teachers.indexWhere((t) => t['id']?.toString() == teacherId);
            if (idx >= 0) {
              _teachers[idx] = {
                ..._teachers[idx],
                'functional_tags': newTags,
                'disabled_features': newDisabledFeatures,
              };
            }
          });
        },
        onNurseToggled: (isNurse) {
          setState(() {
            final idx =
                _teachers.indexWhere((t) => t['id']?.toString() == teacherId);
            if (idx >= 0) {
              _teachers[idx] = {..._teachers[idx], 'is_nurse': isNurse};
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Staff Roles'),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search teachers…',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: AppColors.card,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('No teachers found.',
                                style: TextStyle(color: AppColors.muted)))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _TeacherRoleCard(
                                teacher: filtered[i],
                                allTags: _allTags,
                                onTap: () => _showTagEditor(filtered[i]),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _TeacherRoleCard extends StatelessWidget {
  const _TeacherRoleCard({
    required this.teacher,
    required this.allTags,
    required this.onTap,
  });
  final Map<String, dynamic> teacher;
  final List<(String, String, String)> allTags;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = teacher['name'] as String? ?? '—';
    final role = teacher['role'] as String? ?? 'teacher';
    final isNurse = teacher['is_nurse'] == true;
    final tags = List<String>.from(
      (teacher['functional_tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString()),
    );
    final disabledCount =
        (teacher['disabled_features'] as List<dynamic>? ?? []).length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.skyLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sky),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.muted),
              ],
            ),
            if (tags.isNotEmpty || isNurse || disabledCount > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (disabledCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.rose.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppColors.rose.withOpacity(0.3)),
                      ),
                      child: Text(
                        '🚫 $disabledCount restricted',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.rose),
                      ),
                    ),
                  if (isNurse)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.coralLight,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppColors.coral.withOpacity(0.3)),
                      ),
                      child: const Text(
                        '🏥 Nurse — Health Incidents',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.coral),
                      ),
                    ),
                  ...tags.map((tag) {
                    final tagInfo =
                        allTags.where((t) => t.$1 == tag).firstOrNull;
                    final label = tagInfo?.$2 ?? tag;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: AppColors.teal.withOpacity(0.3)),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal),
                      ),
                    );
                  }),
                ],
              ),
            ] else ...[
              const SizedBox(height: 4),
              const Text('No functional roles assigned',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tag Editor Sheet ──────────────────────────────────────────────────────────

class TagEditorSheet extends StatefulWidget {
  const TagEditorSheet({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.currentTags,
    required this.allTags,
    required this.currentIsNurse,
    required this.currentDisabledFeatures,
    required this.restrictableFeatures,
    required this.isRestrictable,
    required this.onSaved,
    required this.onNurseToggled,
  });
  final String teacherId;
  final String teacherName;
  final List<String> currentTags;
  final List<(String, String, String)> allTags;
  final bool currentIsNurse;
  final List<String> currentDisabledFeatures;
  final List<(String, String, String)> restrictableFeatures;
  final bool isRestrictable;
  final void Function(List<String>, List<String>) onSaved;
  final void Function(bool) onNurseToggled;

  @override
  State<TagEditorSheet> createState() => TagEditorSheetState();
}

class TagEditorSheetState extends State<TagEditorSheet> {
  late Set<String> _selected;
  late Set<String> _disabled;
  late bool _isNurse;
  bool _saving = false;
  bool _togglingNurse = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.currentTags);
    _disabled = Set<String>.from(widget.currentDisabledFeatures);
    _isNurse = widget.currentIsNurse;
  }

  Future<void> _toggleNurse() async {
    setState(() => _togglingNurse = true);
    try {
      final newValue = await ApiClient.adminToggleNurse(widget.teacherId);
      if (mounted) {
        setState(() {
          _isNurse = newValue;
          _togglingNurse = false;
        });
        widget.onNurseToggled(newValue);
        showSnack(
            context,
            newValue
                ? '${widget.teacherName} can now log & view health incidents for any student'
                : '${widget.teacherName} is no longer a nurse');
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _togglingNurse = false);
        showSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _togglingNurse = false);
        showSnack(context, 'Failed to update nurse status', error: true);
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final tags = _selected.toList();
      final disabled = widget.isRestrictable ? _disabled.toList() : <String>[];
      await ApiClient.updateTeacherFunctionalTags(widget.teacherId, tags);
      if (widget.isRestrictable) {
        await ApiClient.adminUpdateDisabledFeatures(widget.teacherId, disabled);
      }
      if (mounted) {
        widget.onSaved(tags, disabled);
        Navigator.pop(context);
        showSnack(context, 'Roles updated for ${widget.teacherName}');
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Failed to update roles', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Previously the drag handle, "Functional Roles — {name}" header, every
    // tag, the restrict-access list, AND the Save button all lived inside one
    // SingleChildScrollView -- so scrolling down to reach Save also scrolled
    // the teacher-name header off-screen, leaving the admin unable to see
    // which staff member they were editing. Fixed by pinning the header and
    // the Save button outside the scrollable region (DraggableScrollableSheet
    // gives the middle section a bounded, scrollable height instead).
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Fixed header: stays visible the whole time the sheet is open ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Functional Roles — ${widget.teacherName}',
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  const SizedBox(height: 4),
                  const Text(
                      'Select the functional responsibilities for this staff member.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            // ── Scrollable middle: nurse toggle, tags, restrict-access ──
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nurse is a dedicated backend flag (not a functional tag) — it grants
                    // school-wide health-incident access, not just the teacher's own
                    // assigned sections, so it's saved immediately on toggle rather than
                    // batched with the tags below.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isNurse ? AppColors.coralLight : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isNurse
                              ? AppColors.coral.withOpacity(0.5)
                              : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text('🏥', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Nurse',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: AppColors.text)),
                                Text(
                                    'Can log & view health incidents for any student, school-wide',
                                    style: TextStyle(
                                        color: AppColors.muted, fontSize: 11)),
                              ],
                            ),
                          ),
                          _togglingNurse
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5))
                              : Switch(
                                  key: const Key('nurse_toggle'),
                                  value: _isNurse,
                                  onChanged: (_) => _toggleNurse(),
                                  activeColor: AppColors.coral,
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...widget.allTags
                        .map(((String val, String label, String sub) t) {
                      final isSelected = _selected.contains(t.$1);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selected.remove(t.$1);
                            } else {
                              _selected.add(t.$1);
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.tealLight
                                : AppColors.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.teal.withOpacity(0.5)
                                  : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                  t.$2.substring(
                                      0,
                                      t.$2.contains(' ')
                                          ? t.$2.indexOf(' ')
                                          : t.$2.length),
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.$2.contains(' ')
                                          ? t.$2
                                              .substring(t.$2.indexOf(' ') + 1)
                                          : t.$2,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isSelected
                                            ? AppColors.teal
                                            : AppColors.text,
                                      ),
                                    ),
                                    Text(t.$3,
                                        style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: isSelected
                                    ? AppColors.teal
                                    : AppColors.border,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    if (widget.isRestrictable) ...[
                      const SizedBox(height: 16),
                      const Text('Restrict Access',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text)),
                      const SizedBox(height: 2),
                      const Text(
                          'Hide these sections for this staff member — e.g. a front-desk role that doesn\'t teach.',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 11)),
                      const SizedBox(height: 10),
                      ...widget.restrictableFeatures
                          .map(((String val, String label, String sub) t) {
                        final isDisabled = _disabled.contains(t.$1);
                        return GestureDetector(
                          key: Key('restrict_${t.$1}'),
                          onTap: () {
                            setState(() {
                              if (isDisabled) {
                                _disabled.remove(t.$1);
                              } else {
                                _disabled.add(t.$1);
                              }
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDisabled
                                  ? AppColors.rose.withOpacity(0.1)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDisabled
                                    ? AppColors.rose.withOpacity(0.5)
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(t.$2,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: isDisabled
                                                ? AppColors.rose
                                                : AppColors.text,
                                            decoration: isDisabled
                                                ? TextDecoration.lineThrough
                                                : null,
                                          )),
                                      Text(t.$3,
                                          style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Icon(
                                  isDisabled
                                      ? Icons.visibility_off
                                      : Icons.visibility_outlined,
                                  color: isDisabled
                                      ? AppColors.rose
                                      : AppColors.border,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            // ── Fixed footer: Save is always reachable and the header above
            // it never scrolls out of view while getting there. ──
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  key: const Key('save_roles_button'),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Save Roles'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
