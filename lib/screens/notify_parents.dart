import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class NotifyParentsScreen extends StatefulWidget {
  const NotifyParentsScreen({super.key});

  @override
  State<NotifyParentsScreen> createState() => _NotifyParentsScreenState();
}

class _NotifyParentsScreenState extends State<NotifyParentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

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
  String? _msgError;

  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _loadingHistory = true;
  String _historySearch = '';
  String? _historyTypeFilter;
  bool _historyShowAll = false;

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

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadSections();
    _loadHistory();
  }

  bool get _canSend {
    final msg = _msgCtrl.text.trim();
    if (msg.length < 10) return false;
    if (_isWholeClass && _selectedSection == null) return false;
    if (!_isWholeClass && _selectedStudent == null) return false;
    return true;
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final data = await ApiClient.getNotifyParentsHistory();
      if (mounted) {
        setState(() {
          _history = data;
          _loadingHistory = false;
          _applyHistoryFilters();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  void _applyHistoryFilters() {
    if (_historySearch.isNotEmpty) {
      // Search applies across full history (ignores 7-day window and type filter)
      final q = _historySearch.toLowerCase();
      _filteredHistory = _history.where((item) {
        final title = (item['title'] as String? ?? '').toLowerCase();
        return title.contains(q);
      }).toList();
      return;
    }
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    _filteredHistory = _history.where((item) {
      if (!_historyShowAll) {
        final createdAt = item['created_at'] as String? ?? '';
        if (createdAt.isNotEmpty) {
          final dt = DateTime.tryParse(createdAt);
          if (dt != null && dt.isBefore(cutoff)) return false;
        }
      }
      if (_historyTypeFilter != null) {
        final subType = item['sub_type'] as String? ?? '';
        if (subType != _historyTypeFilter) return false;
      }
      return true;
    }).toList();
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
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: null,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: null,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Send'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          // ── Tab 0: Send ──────────────────────────────────────────────────
          SingleChildScrollView(
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
                LinearProgressIndicator()
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
                            color: active ? context.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active ? context.primary : AppColors.border,
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
                  key: const Key('student_search_field'),
                  controller: _searchCtrl,
                  onChanged: _searchStudents,
                  decoration: InputDecoration(
                    hintText: 'Name, mobile, or parent mobile',
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
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
                                decoration: BoxDecoration(color: context.primaryLight, shape: BoxShape.circle),
                                child: Center(child: Text(s.name[0], style: TextStyle(fontWeight: FontWeight.w800, color: context.primary, fontSize: 14))),
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
              spacing: 6,
              runSpacing: 6,
              children: _typeIcons.entries.map((entry) {
                final selected = _notifType == entry.key;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _notifType = entry.key;
                      _msgCtrl.clear();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? context.primary : Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: selected ? context.primary : AppColors.border,
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
              key: const Key('notification_message_field'),
              controller: _msgCtrl,
              maxLines: 4,
              maxLength: 500,
              onChanged: (_) => setState(() => _msgError = null),
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                alignLabelWithHint: true,
                errorText: _msgError,
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.coral),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.coral, width: 2),
                ),
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
                  color: context.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.primary.withOpacity(0.3)),
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
                key: const Key('send_notification_button'),
                onPressed: _loading ? null : (_canSend ? _send : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: null,
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
          ), // SingleChildScrollView (Send tab)

          // ── Tab 1: History ───────────────────────────────────────────────
          _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: TextField(
                        onChanged: (q) {
                          setState(() {
                            _historySearch = q;
                            _applyHistoryFilters();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search history...',
                          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.muted),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    // Type filter chips
                    SizedBox(
                      height: 52,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _historyTypeFilter == null,
                            onTap: () => setState(() { _historyTypeFilter = null; _applyHistoryFilters(); }),
                          ),
                          ..._typeLabels.entries.map((e) => _FilterChip(
                            label: e.value,
                            selected: _historyTypeFilter == e.key,
                            onTap: () => setState(() { _historyTypeFilter = e.key; _applyHistoryFilters(); }),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _filteredHistory.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('📭', style: TextStyle(fontSize: 40)),
                                  SizedBox(height: 12),
                                  Text('No activity yet', style: TextStyle(color: AppColors.muted, fontSize: 14)),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: context.primary,
                              onRefresh: _loadHistory,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                itemCount: _filteredHistory.length + (_history.length > _filteredHistory.length && _historySearch.isEmpty ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (i == _filteredHistory.length) {
                                    return TextButton(
                                      onPressed: () => setState(() { _historyShowAll = !_historyShowAll; _applyHistoryFilters(); }),
                                      child: Text(_historyShowAll ? 'Show recent 7 days only' : 'Load full history', style: TextStyle(color: context.primary)),
                                    );
                                  }
                                  return _HistoryItem(item: _filteredHistory[i]);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
        ], // TabBarView children
      ), // TabBarView
    );
  }

  Future<void> _send() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) {
      setState(() => _msgError = 'Message is required');
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

    // Confirmation dialog for whole-class sends
    if (_isWholeClass && _selectedSection != null) {
      setState(() => _loading = true);
      int parentCount = 0;
      try {
        parentCount = await ApiClient.getNotifyParentsCount(_selectedSection!.id);
      } catch (_) {}
      if (!mounted) return;
      setState(() => _loading = false);

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Send to whole class?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          content: Text(
            'This will send a notification to all $parentCount student${parentCount == 1 ? '' : 's'} in ${_selectedSection!.label}.',
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(_, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(_, true),
              style: ElevatedButton.styleFrom(),
              child: const Text('Send', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
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
        showSnack(context,
            'Notification sent to ${result.recipientCount} parent${result.recipientCount == 1 ? '' : 's'} ✓');
        setState(() {
          _msgCtrl.clear();
          _searchCtrl.clear();
          _searchResults = [];
          _selectedStudent = null;
        });
        _loadHistory(); // refresh history tab
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

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryItem({required this.item});

  static const _notifIcons = {
    'homework': '📚', 'attention': '⚠️', 'announcement': '📢',
    'test_result': '📊', 'custom': '✉️',
  };
  static const _logIcons = {
    'homework': '📝', 'classwork': '🏫', 'project': '🔬',
    'reading': '📖', 'other': '📌',
  };

  @override
  Widget build(BuildContext context) {
    final isNotif = item['activity_type'] == 'notification';
    final subType = item['sub_type'] as String? ?? '';
    final targetType = item['target_type'] as String? ?? '';
    final sectionLabel = item['section_label'] as String?;
    final studentName = item['student_name'] as String?;
    final icon = isNotif
        ? (_notifIcons[subType] ?? '🔔')
        : (_logIcons[subType] ?? '📝');
    final title = item['title'] as String? ?? '';
    final createdAt = item['created_at'] as String? ?? '';
    final dateLabel = createdAt.isNotEmpty
        ? DateFormat('d MMM, h:mm a').format(DateTime.parse(createdAt).toLocal())
        : '';

    String targetLabel;
    if (targetType == 'class' && sectionLabel != null) {
      targetLabel = 'Whole Class · $sectionLabel';
    } else if (studentName != null) {
      targetLabel = 'Individual · $studentName';
    } else {
      targetLabel = isNotif ? 'Notification' : 'Work Log';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: isNotif ? AppColors.sunLight : AppColors.violetLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: targetType == 'class' ? AppColors.sunLight : AppColors.tealLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        targetLabel,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                            color: targetType == 'class' ? AppColors.sun : AppColors.teal),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(dateLabel, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                  ],
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => shareAsText(
              '${isNotif ? (_notifIcons[subType] ?? '🔔') : (_logIcons[subType] ?? '📝')} $title\n\n— via EduTrack',
            ),
            child: const Padding(
              padding: EdgeInsets.only(left: 6, top: 2),
              child: Icon(Icons.share_outlined, size: 16, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? context.primary : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? context.primary : AppColors.border, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.muted),
      ),
    ),
  );
}

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
              color: selected ? context.primary : Colors.transparent,
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
