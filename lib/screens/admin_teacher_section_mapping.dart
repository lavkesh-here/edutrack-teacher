import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Admin-facing view: which teacher is mapped to which class/section (and
/// subject) this academic year, plus staff with no mapping at all -- so an
/// admin/director doesn't have to open each teacher individually to see
/// coverage, or to spot a section with no teacher assigned.
class AdminTeacherSectionMappingScreen extends StatefulWidget {
  const AdminTeacherSectionMappingScreen({super.key});

  @override
  State<AdminTeacherSectionMappingScreen> createState() =>
      _AdminTeacherSectionMappingScreenState();
}

class _AdminTeacherSectionMappingScreenState
    extends State<AdminTeacherSectionMappingScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _unmappedStaff = [];
  String? _academicYearName;
  String _search = '';

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
      final data = await ApiClient.adminGetTeacherSectionMapping();
      if (!mounted) return;
      setState(() {
        _sections = List<Map<String, dynamic>>.from(
          (data['sections'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>),
        );
        _unmappedStaff = List<Map<String, dynamic>>.from(
          (data['unmapped_staff'] as List<dynamic>? ?? [])
              .map((e) => e as Map<String, dynamic>),
        );
        _academicYearName = (data['academic_year']
            as Map<String, dynamic>?)?['name'] as String?;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted)
        setState(() {
          _error = e.message;
          _loading = false;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Failed to load mapping';
          _loading = false;
        });
    }
  }

  List<Map<String, dynamic>> get _filteredSections {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _sections;
    return _sections.where((s) {
      final label = (s['label'] as String? ?? '').toLowerCase();
      if (label.contains(q)) return true;
      final teachers = (s['teachers'] as List<dynamic>? ?? []);
      return teachers.any((t) =>
          ((t as Map<String, dynamic>)['teacher_name'] as String? ?? '')
              .toLowerCase()
              .contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Teacher ↔ Class Mapping'),
            if (_academicYearName != null)
              Text(_academicYearName!,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: AppColors.muted)),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      TextField(
                        key: const Key('mapping_search_field'),
                        onChanged: (v) => setState(() => _search = v),
                        decoration: InputDecoration(
                          hintText: 'Search class, section or teacher…',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          filled: true,
                          fillColor: AppColors.card,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_filteredSections.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No sections match your search.',
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 13)),
                          ),
                        )
                      else
                        ..._filteredSections
                            .map((s) => _SectionMappingCard(section: s)),
                      if (_search.isEmpty && _unmappedStaff.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('STAFF WITH NO CLASS/SECTION MAPPING',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.muted,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final u in _unmappedStaff)
                                _UnmappedStaffRow(staff: u),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _SectionMappingCard extends StatelessWidget {
  const _SectionMappingCard({required this.section});
  final Map<String, dynamic> section;

  @override
  Widget build(BuildContext context) {
    final label = section['label'] as String? ?? '—';
    final teachers = List<Map<String, dynamic>>.from(
      (section['teachers'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.text)),
                ),
                if (teachers.isEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.rose.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('No teacher assigned',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.rose,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (teachers.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...teachers.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.muted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${t['teacher_name']}  ·  ${t['subject_name']}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.text),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnmappedStaffRow extends StatelessWidget {
  const _UnmappedStaffRow({required this.staff});
  final Map<String, dynamic> staff;

  @override
  Widget build(BuildContext context) {
    final name = staff['name'] as String? ?? '—';
    final role = staff['role'] as String? ?? 'teacher';
    final isNurse = staff['is_nurse'] == true;
    // admin-tier roles and nurses are expected here by design -- only a
    // plain, non-nurse teacher with no mapping is a real coverage gap.
    final isExpected = role != 'teacher' || isNurse;
    final tag = isNurse ? 'Nurse' : role[0].toUpperCase() + role.substring(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isExpected ? AppColors.card : AppColors.amberLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isExpected
                      ? AppColors.border
                      : AppColors.amber.withOpacity(0.5)),
            ),
            child: Text(tag,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isExpected
                        ? AppColors.muted
                        : const Color(0xFF92400E))),
          ),
        ],
      ),
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
            const Icon(Icons.error_outline, size: 40, color: AppColors.rose),
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
