import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class NotifyParentsScreen extends StatefulWidget {
  const NotifyParentsScreen({super.key});

  @override
  State<NotifyParentsScreen> createState() => _NotifyParentsScreenState();
}

class _NotifyParentsScreenState extends State<NotifyParentsScreen> {
  bool _isWholeClass = true;
  String _notifType = 'homework';
  SectionInfo? _selectedSection;
  List<SectionInfo>? _sections;
  final _msgCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<StudentSearchResult> _searchResults = [];
  StudentSearchResult? _selectedStudent;
  bool _searching = false;
  bool _loading = false;
  bool _loadingSections = true;

  static const _typeIcons = {
    'homework': '📚',
    'attention': '⚠️',
    'announcement': '📢',
    'test_result': '📊',
    'custom': '✉️',
  };

  static const _typeLabels = {
    'homework': 'Homework',
    'attention': 'Attention Needed',
    'announcement': 'Announcement',
    'test_result': 'Test Results',
    'custom': 'Custom Message',
  };

  static const _templates = {
    'homework':
        'Homework has been assigned. Please ensure it is completed on time.',
    'attention':
        'Your child needs attention in class. Please meet the teacher at your earliest convenience.',
    'announcement': '',
    'test_result':
        'Test results have been posted. Please check the EduTrack app.',
    'custom': '',
  };

  @override
  void initState() {
    super.initState();
    _loadSections();
    _msgCtrl.text = _templates[_notifType]!;
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchStudents(String q) async {
    if (q.trim().length < 2) {
      setState(() { _searchResults = []; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await ApiClient.searchStudents(q.trim());
      setState(() { _searchResults = results; _searching = false; });
    } catch (_) {
      setState(() { _searchResults = []; _searching = false; });
    }
  }

  Future<void> _loadSections() async {
    try {
      final sections = await ApiClient.getMySections();
      setState(() {
        _sections = sections;
        if (sections.isNotEmpty) _selectedSection = sections.first;
        _loadingSections = false;
      });
    } catch (_) {
      setState(() => _loadingSections = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewMsg = _msgCtrl.text.trim();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Notify Parents'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target toggle
            const Text('SEND TO', style: _labelStyle),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _ToggleOption(
                    label: 'Whole Class',
                    selected: _isWholeClass,
                    onTap: () => setState(() => _isWholeClass = true),
                  ),
                  _ToggleOption(
                    label: 'Individual Student',
                    selected: !_isWholeClass,
                    onTap: () => setState(() => _isWholeClass = false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Section or student
            if (_isWholeClass) ...[
              const Text('SELECT CLASS', style: _labelStyle),
              const SizedBox(height: 8),
              if (_loadingSections)
                const LinearProgressIndicator(color: AppColors.sun)
              else if (_sections != null && _sections!.isNotEmpty)
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _sections!.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final sec = _sections![i];
                      final active = sec.id == _selectedSection?.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSection = sec),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: active ? AppColors.sun : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active ? AppColors.sun : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            sec.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active ? Colors.white : AppColors.muted,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ] else ...[
              const Text('SEARCH STUDENT', style: _labelStyle),
              const SizedBox(height: 8),
              if (_selectedStudent != null) ...[
                // Show selected student chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.tealLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.teal.withOpacity(0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedStudent!.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text),
                            ),
                            Text(
                              '${_selectedStudent!.classLabel ?? ''} · ${_selectedStudent!.guardianPhone ?? ''}',
                              style: const TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() { _selectedStudent = null; _searchCtrl.clear(); _searchResults = []; }),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _searchCtrl,
                  onChanged: _searchStudents,
                  decoration: InputDecoration(
                    hintText: 'Name, mobile, or parent mobile',
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sun)),
                          )
                        : null,
                  ),
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: _searchResults.map((s) => InkWell(
                        onTap: () => setState(() {
                          _selectedStudent = s;
                          _searchCtrl.clear();
                          _searchResults = [];
                        }),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(color: AppColors.sunLight, shape: BoxShape.circle),
                                child: Center(child: Text(s.name[0], style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.sun, fontSize: 14))),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                                    Text('${s.classLabel ?? ''} · ${s.guardianPhone ?? ''}', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                ],
              ],
            ],

            const SizedBox(height: 20),

            // Notification type
            const Text('NOTIFICATION TYPE', style: _labelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _typeIcons.entries.map((entry) {
                final selected = _notifType == entry.key;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _notifType = entry.key;
                      _msgCtrl.text = _templates[entry.key]!;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.sun : Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: selected ? AppColors.sun : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entry.value,
                            style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          _typeLabels[entry.key]!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                selected ? Colors.white : AppColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Message
            const Text('MESSAGE', style: _labelStyle),
            const SizedBox(height: 8),
            TextField(
              controller: _msgCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Type your message here...',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            // Preview
            if (previewMsg.isNotEmpty) ...[
              const Text('PREVIEW', style: _labelStyle),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sunLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.sun.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('📱', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          'Notification to ${_isWholeClass ? _selectedSection?.label ?? 'class' : 'student'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      previewMsg,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.text,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Send button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sun,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🔔', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Text(
                            'Send Notification',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) {
      showSnack(context, 'Please enter a message', error: true);
      return;
    }
    if (_isWholeClass && _selectedSection == null) {
      showSnack(context, 'Please select a section', error: true);
      return;
    }
    if (!_isWholeClass && _selectedStudent == null) {
      showSnack(context, 'Please search and select a student', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await ApiClient.notifyParents(
        message: msg,
        notificationType: _notifType,
        targetType: _isWholeClass ? 'class' : 'student',
        classSectionId: _isWholeClass ? _selectedSection?.id : null,
        studentId: _isWholeClass ? null : _selectedStudent?.id,
      );
      if (mounted) {
        showSnack(
            context,
            'Notification sent to ${result.recipientCount} parent${result.recipientCount == 1 ? '' : 's'} ✓');
        _msgCtrl.text = _templates[_notifType]!;
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

const _labelStyle = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w800,
  color: AppColors.muted,
  letterSpacing: 0.8,
);

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? AppColors.sun : Colors.transparent,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.muted,
                ),
              ),
            ),
          ),
        ),
      );
}
