import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class PTMScreen extends StatefulWidget {
  const PTMScreen({super.key});
  @override
  State<PTMScreen> createState() => _PTMScreenState();
}

class _PTMScreenState extends State<PTMScreen> {
  List<Map<String, dynamic>>? _events;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final events = await ApiClient.getPTMEvents();
      if (mounted) setState(() { _events = events; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _events = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Parent-Teacher Meetings', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 16)),
        iconTheme: const IconThemeData(color: AppColors.text),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_events == null || _events!.isEmpty)
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('📅', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('No PTM events scheduled', style: TextStyle(color: AppColors.muted, fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Admin will create PTM events from the web portal', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _EventCard(event: _events![i]),
                  ),
                ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final date = _fmtDate(event['event_date'] as String?);
    final myMeetings = event['my_meetings'] as int? ?? 0;
    final done = event['done'] as int? ?? 0;
    final noShow = event['no_show'] as int? ?? 0;
    final pending = myMeetings - done - noShow;

    return AppCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PTMEventDetail(
          eventId: event['id'] as String,
          eventName: event['name'] as String? ?? 'PTM',
          eventDate: event['event_date'] as String? ?? '',
        ),
      )),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(event['name'] as String? ?? 'PTM',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.sunLight, borderRadius: BorderRadius.circular(20)),
            child: Text(date, style: const TextStyle(fontSize: 11, color: AppColors.sun, fontWeight: FontWeight.w600)),
          ),
        ]),
        if ((event['description'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(event['description'] as String, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
        if (myMeetings > 0) ...[
          const SizedBox(height: 10),
          Row(children: [
            _StatChip(label: '$myMeetings Total', color: AppColors.sky),
            const SizedBox(width: 6),
            _StatChip(label: '$done Done', color: AppColors.green),
            const SizedBox(width: 6),
            if (noShow > 0) _StatChip(label: '$noShow No-show', color: AppColors.muted),
            if (pending > 0) ...[
              const SizedBox(width: 6),
              _StatChip(label: '$pending Pending', color: AppColors.amber),
            ],
          ]),
        ],
        const SizedBox(height: 6),
        Row(children: [
          const Spacer(),
          Text('Tap to view & log meetings →', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ]),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

// ── PTM Event Detail — log meetings per student ───────────────────────────────

class PTMEventDetail extends StatefulWidget {
  final String eventId;
  final String eventName;
  final String eventDate;
  const PTMEventDetail({super.key, required this.eventId, required this.eventName, required this.eventDate});
  @override
  State<PTMEventDetail> createState() => _PTMEventDetailState();
}

class _PTMEventDetailState extends State<PTMEventDetail> {
  List<Map<String, dynamic>>? _meetings;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final meetings = await ApiClient.getPTMMeetings(widget.eventId);
      if (mounted) setState(() { _meetings = meetings; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _meetings = []; _loading = false; });
    }
  }

  void _addMeeting() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMeetingSheet(
        eventId: widget.eventId,
        onCreated: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.eventName, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 15)),
          Text(_fmtDate(widget.eventDate), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
        ]),
        iconTheme: const IconThemeData(color: AppColors.text),
        actions: [
          TextButton.icon(
            onPressed: _addMeeting,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Log Meeting', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _meetings == null || _meetings!.isEmpty
                  ? ListView(children: const [
                      Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('📝', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('No meetings logged yet', style: TextStyle(color: AppColors.muted, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('Tap "+ Log Meeting" to add one', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        ]),
                      ),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _meetings!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _MeetingCard(
                        meeting: _meetings![i],
                        onUpdated: _load,
                      ),
                    ),
            ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final Map<String, dynamic> meeting;
  final VoidCallback onUpdated;
  const _MeetingCard({required this.meeting, required this.onUpdated});

  Color get _statusColor {
    switch (meeting['status'] as String? ?? '') {
      case 'done': return AppColors.green;
      case 'no_show': return AppColors.muted;
      default: return AppColors.amber;
    }
  }

  String get _statusLabel {
    switch (meeting['status'] as String? ?? '') {
      case 'done': return 'Done';
      case 'no_show': return 'No-show';
      default: return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionItems = (meeting['action_items'] as List?)?.cast<String>() ?? [];
    return AppCard(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _UpdateMeetingSheet(meeting: meeting, onUpdated: onUpdated),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meeting['student_name'] as String? ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            if ((meeting['subject_name'] as String?)?.isNotEmpty == true)
              Text(meeting['subject_name'] as String, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _statusColor.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(_statusLabel, style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w700)),
          ),
        ]),
        if ((meeting['remarks'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(meeting['remarks'] as String, style: const TextStyle(fontSize: 13, color: AppColors.text2, height: 1.4)),
        ],
        if (actionItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...actionItems.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 14, color: AppColors.teal),
              const SizedBox(width: 6),
              Expanded(child: Text(a, style: const TextStyle(fontSize: 12, color: AppColors.text2))),
            ]),
          )),
        ],
        const SizedBox(height: 4),
        Text('Tap to edit', style: const TextStyle(fontSize: 10, color: AppColors.muted)),
      ]),
    );
  }
}

class _AddMeetingSheet extends StatefulWidget {
  final String eventId;
  final VoidCallback onCreated;
  const _AddMeetingSheet({required this.eventId, required this.onCreated});
  @override
  State<_AddMeetingSheet> createState() => _AddMeetingSheetState();
}

class _AddMeetingSheetState extends State<_AddMeetingSheet> {
  final _studentCtrl = TextEditingController();
  final _studentIdCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _actionCtrl = TextEditingController();
  String _status = 'done';
  final List<String> _actions = [];
  bool _saving = false;
  List<StudentSearchResult> _searchResults = [];
  bool _searching = false;

  Future<void> _search(String q) async {
    if (q.length < 2) { setState(() => _searchResults = []); return; }
    setState(() => _searching = true);
    try {
      final res = await ApiClient.searchStudents(q);
      if (mounted) setState(() { _searchResults = res.take(5).toList(); _searching = false; });
    } catch (_) {
      if (mounted) setState(() { _searching = false; });
    }
  }

  Future<void> _save() async {
    if (_studentIdCtrl.text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ApiClient.createPTMMeeting(
        ptmEventId: widget.eventId,
        studentId: _studentIdCtrl.text,
        status: _status,
        remarks: _remarksCtrl.text.isEmpty ? null : _remarksCtrl.text,
        actionItems: _actions,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text('Log PTM Meeting', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Student search
                const Text('Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _studentCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name or admission number',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    suffixIcon: _searching ? const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))) : null,
                  ),
                  onChanged: _search,
                ),
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
                    child: Column(children: _searchResults.map((s) => ListTile(
                      dense: true,
                      title: Text(s.name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(s.admissionNumber, style: const TextStyle(fontSize: 11)),
                      onTap: () {
                        setState(() {
                          _studentCtrl.text = s.name;
                          _studentIdCtrl.text = s.id;
                          _searchResults = [];
                        });
                      },
                    )).toList()),
                  ),
                ],
                const SizedBox(height: 14),
                // Status
                const Text('Meeting Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final s in ['done', 'no_show', 'scheduled'])
                    ChoiceChip(
                      label: Text(s == 'done' ? 'Done ✅' : s == 'no_show' ? 'No-show 🚫' : 'Pending ⏳',
                        style: TextStyle(fontSize: 12, color: _status == s ? Colors.white : AppColors.text2)),
                      selected: _status == s,
                      selectedColor: s == 'done' ? AppColors.green : s == 'no_show' ? AppColors.muted : AppColors.amber,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                ]),
                const SizedBox(height: 14),
                // Remarks
                const Text('Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 6),
                TextField(
                  controller: _remarksCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Meeting notes, observations…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 14),
                // Action items
                const Text('Action Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: TextField(
                    controller: _actionCtrl,
                    decoration: InputDecoration(
                      hintText: 'e.g. Practice fractions daily',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  )),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.sun),
                    onPressed: () {
                      final text = _actionCtrl.text.trim();
                      if (text.isNotEmpty) {
                        setState(() { _actions.add(text); _actionCtrl.clear(); });
                      }
                    },
                  ),
                ]),
                if (_actions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._actions.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, size: 14, color: AppColors.teal),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13))),
                      GestureDetector(
                        onTap: () => setState(() => _actions.removeAt(e.key)),
                        child: const Icon(Icons.close, size: 16, color: AppColors.muted),
                      ),
                    ]),
                  )),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_saving || _studentIdCtrl.text.isEmpty) ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.sun, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Meeting', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _UpdateMeetingSheet extends StatefulWidget {
  final Map<String, dynamic> meeting;
  final VoidCallback onUpdated;
  const _UpdateMeetingSheet({required this.meeting, required this.onUpdated});
  @override
  State<_UpdateMeetingSheet> createState() => _UpdateMeetingSheetState();
}

class _UpdateMeetingSheetState extends State<_UpdateMeetingSheet> {
  late String _status;
  late TextEditingController _remarksCtrl;
  late List<String> _actions;
  final _actionCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.meeting['status'] as String? ?? 'scheduled';
    _remarksCtrl = TextEditingController(text: widget.meeting['remarks'] as String? ?? '');
    _actions = (widget.meeting['action_items'] as List?)?.cast<String>().toList() ?? [];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiClient.updatePTMMeeting(
        widget.meeting['id'] as String,
        status: _status,
        remarks: _remarksCtrl.text.isEmpty ? null : _remarksCtrl.text,
        actionItems: _actions,
      );
      if (mounted) { Navigator.pop(context); widget.onUpdated(); }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(widget.meeting['student_name'] as String? ?? 'Meeting',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Text('Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final s in ['done', 'no_show', 'scheduled'])
              ChoiceChip(
                label: Text(s == 'done' ? 'Done ✅' : s == 'no_show' ? 'No-show 🚫' : 'Pending ⏳',
                  style: TextStyle(fontSize: 12, color: _status == s ? Colors.white : AppColors.text2)),
                selected: _status == s,
                selectedColor: s == 'done' ? AppColors.green : s == 'no_show' ? AppColors.muted : AppColors.amber,
                onSelected: (_) => setState(() => _status = s),
              ),
          ]),
          const SizedBox(height: 14),
          const Text('Remarks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          TextField(
            controller: _remarksCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Action Items', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: TextField(
              controller: _actionCtrl,
              decoration: InputDecoration(
                hintText: 'Add action item…',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            )),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.add_circle, color: AppColors.sun), onPressed: () {
              final t = _actionCtrl.text.trim();
              if (t.isNotEmpty) setState(() { _actions.add(t); _actionCtrl.clear(); });
            }),
          ]),
          ..._actions.asMap().entries.map((e) => ListTile(
            dense: true,
            leading: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.teal),
            title: Text(e.value, style: const TextStyle(fontSize: 13)),
            trailing: IconButton(icon: const Icon(Icons.close, size: 16, color: AppColors.muted),
              onPressed: () => setState(() => _actions.removeAt(e.key))),
          )),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sun, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Update', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

String _fmtDate(String? iso) {
  if (iso == null) return '';
  try {
    final d = DateTime.parse(iso);
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month-1]} ${d.year}';
  } catch (_) { return iso; }
}
