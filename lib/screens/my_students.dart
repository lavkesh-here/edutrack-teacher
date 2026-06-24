import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/theme.dart';
import 'student_profile_detail.dart';

class MyStudentsScreen extends StatefulWidget {
  const MyStudentsScreen({super.key});

  @override
  State<MyStudentsScreen> createState() => _MyStudentsScreenState();
}

class _MyStudentsScreenState extends State<MyStudentsScreen> {
  List<SectionInfo>? _sections;
  SectionInfo? _selectedSection;
  List<AttendanceStudent> _students = [];
  bool _loadingSections = true;
  bool _loadingStudents = false;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSections() async {
    setState(() => _loadingSections = true);
    try {
      final sections = await ApiClient.getMySections();
      setState(() {
        _sections = sections;
        if (sections.isNotEmpty) {
          _selectedSection = sections.first;
        }
        _loadingSections = false;
      });
      if (_sections!.isNotEmpty) _loadStudents();
    } catch (_) {
      setState(() => _loadingSections = false);
    }
  }

  Future<void> _loadStudents() async {
    if (_selectedSection == null) return;
    setState(() { _loadingStudents = true; _students = []; });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final students =
          await ApiClient.getAttendance(_selectedSection!.id, dateStr);
      setState(() { _students = students; _loadingStudents = false; });
    } catch (_) {
      setState(() { _students = []; _loadingStudents = false; });
    }
  }

  List<AttendanceStudent> get _filtered {
    if (_search.isEmpty) return _students;
    final q = _search.toLowerCase();
    return _students.where((s) =>
        s.name.toLowerCase().contains(q) ||
        s.rollNo.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('My Students'),
        leading: const BackButton(),
      ),
      body: Column(
        children: [
          // Section chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: _loadingSections
                ? const LinearProgressIndicator(color: AppColors.sun)
                : _sections == null || _sections!.isEmpty
                    ? const Text('No sections assigned',
                        style: TextStyle(color: AppColors.muted))
                    : SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _sections!.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final sec = _sections![i];
                            final active = sec.id == _selectedSection?.id;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedSection = sec);
                                _loadStudents();
                              },
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.sun
                                      : AppColors.bg,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.sun
                                        : AppColors.border,
                                    width: 1.5,
                                  ),
                                ),
                                child: Text(
                                  sec.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? Colors.white
                                        : AppColors.muted,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),

          // Search
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              key: const Key('student_search_field'),
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Search by name or roll...',
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                hintStyle:
                    const TextStyle(color: AppColors.muted, fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: const BorderSide(color: AppColors.sun),
                ),
              ),
            ),
          ),

          // Student list
          Expanded(
            child: _loadingStudents
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.sun))
                : _filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No students found',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.sun,
                        onRefresh: _loadStudents,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _StudentRow(
                            student: _filtered[i],
                            sectionLabel: _selectedSection?.label ?? '',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentProfileDetail(
                                  studentId: _filtered[i].id,
                                  studentName: _filtered[i].name,
                                  sectionLabel: _selectedSection?.label ?? '',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

}

class _StudentRow extends StatelessWidget {
  final AttendanceStudent student;
  final String sectionLabel;
  final VoidCallback onTap;

  const _StudentRow({
    required this.student,
    required this.sectionLabel,
    required this.onTap,
  });

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.sunLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _initials(student.name),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.sun,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text),
                    ),
                    Text(
                      '$sectionLabel · Roll ${student.rollNo}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.muted),
            ],
          ),
        ),
      );
}
