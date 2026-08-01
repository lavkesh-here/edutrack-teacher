import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class EnquiriesScreen extends StatefulWidget {
  const EnquiriesScreen({super.key});

  @override
  State<EnquiriesScreen> createState() => _EnquiriesScreenState();
}

class _EnquiriesScreenState extends State<EnquiriesScreen> {
  List<Map<String, dynamic>>? _enquiries;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final enquiries = await ApiClient.getEnquiries();
      if (mounted) setState(() { _enquiries = enquiries; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        showSnack(context, 'Failed to load enquiries', error: true);
      }
    }
  }

  Future<void> _close(Map<String, dynamic> enquiry) async {
    try {
      await ApiClient.updateEnquiry(enquiry['id'].toString(), status: 'closed');
      await _load();
      if (mounted) showSnack(context, 'Marked closed ✓');
    } catch (_) {
      if (mounted) showSnack(context, 'Update failed', error: true);
    }
  }

  void _showFollowupSheet(Map<String, dynamic> enquiry) {
    DateTime? followup = enquiry['followup_at'] != null ? DateTime.tryParse(enquiry['followup_at']) : null;
    bool needsFollowup = enquiry['needs_followup'] == true;
    final notesCtrl = TextEditingController(text: enquiry['notes'] as String? ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(enquiry['visitor_name'] as String? ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 14),
              TextField(
                controller: notesCtrl,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Comments',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setSheet(() => needsFollowup = !needsFollowup),
                borderRadius: BorderRadius.circular(8),
                child: Row(children: [
                  Checkbox(value: needsFollowup, onChanged: (v) => setSheet(() => needsFollowup = v ?? false)),
                  const Text('Needs follow-up', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.text)),
                ]),
              ),
              if (needsFollowup) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 15),
                      label: Text(followup == null
                          ? 'Date'
                          : '${followup!.day}/${followup!.month}/${followup!.year}'),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: followup ?? DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setSheet(() => followup = DateTime(picked.year, picked.month, picked.day,
                              followup?.hour ?? 10, followup?.minute ?? 0));
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.access_time, size: 15),
                      label: Text(followup == null
                          ? 'Time'
                          : TimeOfDay.fromDateTime(followup!).format(ctx)),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () async {
                        final base = followup ?? DateTime.now().add(const Duration(days: 1));
                        final picked = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.fromDateTime(base),
                        );
                        if (picked != null) {
                          setSheet(() => followup = DateTime(base.year, base.month, base.day, picked.hour, picked.minute));
                        }
                      },
                    ),
                  ),
                ]),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (needsFollowup && followup == null) {
                      showSnack(ctx, 'Pick a follow-up date and time', error: true);
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await ApiClient.updateEnquiry(
                        enquiry['id'].toString(),
                        notes: notesCtrl.text.trim(),
                        needsFollowup: needsFollowup,
                        followupAt: needsFollowup ? followup : null,
                        clearFollowup: !needsFollowup,
                        status: needsFollowup ? 'followup_scheduled' : 'open',
                      );
                      await _load();
                      if (mounted) showSnack(context, 'Saved ✓');
                    } catch (_) {
                      if (mounted) showSnack(context, 'Save failed', error: true);
                    }
                  },
                  child: const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();
    String? nameError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              const Text('New Enquiry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 4),
              const Text('Someone visiting to meet you', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) { if (nameError != null) setSheet(() => nameError = null); },
                decoration: InputDecoration(
                  labelText: 'Visitor name *',
                  errorText: nameError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: purposeCtrl,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Purpose (optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      setSheet(() => nameError = 'Please enter a name');
                      return;
                    }
                    Navigator.pop(ctx);
                    try {
                      await ApiClient.createEnquiry(
                        visitorName: name,
                        visitorPhone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        purpose: purposeCtrl.text.trim().isEmpty ? null : purposeCtrl.text.trim(),
                      );
                      await _load();
                      if (mounted) showSnack(context, 'Enquiry added ✓');
                    } catch (_) {
                      if (mounted) showSnack(context, 'Create failed', error: true);
                    }
                  },
                  child: const Text('Add Enquiry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = _enquiries ?? [];
    final followup = all.where((e) => e['needs_followup'] == true && e['status'] != 'closed').toList();
    final open = all.where((e) => e['status'] == 'open').toList();
    final closed = all.where((e) => e['status'] == 'closed').toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Enquiries'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.text,
        elevation: 0,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: AppColors.border)),
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showAddSheet, child: const Icon(Icons.add, color: Colors.white)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : all.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                    children: const [
                      Center(child: Text('🤝', style: TextStyle(fontSize: 48))),
                      SizedBox(height: 12),
                      Center(child: Text('No enquiries yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text))),
                      SizedBox(height: 4),
                      Center(child: Text('Tap + when someone visits to meet you', style: TextStyle(fontSize: 13, color: AppColors.muted))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    children: [
                      if (followup.isNotEmpty) ...[
                        _SectionLabel('NEEDS FOLLOW-UP  (${followup.length})'),
                        ...followup.map((e) => _EnquiryCard(enquiry: e, onTap: () => _showFollowupSheet(e), onClose: () => _close(e))),
                      ],
                      if (open.isNotEmpty) ...[
                        _SectionLabel('OPEN  (${open.length})'),
                        ...open.map((e) => _EnquiryCard(enquiry: e, onTap: () => _showFollowupSheet(e), onClose: () => _close(e))),
                      ],
                      if (closed.isNotEmpty)
                        _ClosedSection(enquiries: closed, onTap: _showFollowupSheet),
                    ],
                  ),
                ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 0, 6),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
      );
}

class _ClosedSection extends StatefulWidget {
  final List<Map<String, dynamic>> enquiries;
  final void Function(Map<String, dynamic>) onTap;
  const _ClosedSection({required this.enquiries, required this.onTap});

  @override
  State<_ClosedSection> createState() => _ClosedSectionState();
}

class _ClosedSectionState extends State<_ClosedSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 6),
              child: Row(children: [
                Text('CLOSED  (${widget.enquiries.length})',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 1)),
                const SizedBox(width: 6),
                Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 16, color: AppColors.muted),
              ]),
            ),
          ),
          if (_expanded)
            ...widget.enquiries.map((e) => _EnquiryCard(enquiry: e, onTap: () => widget.onTap(e))),
        ],
      );
}

class _EnquiryCard extends StatelessWidget {
  final Map<String, dynamic> enquiry;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _EnquiryCard({required this.enquiry, required this.onTap, this.onClose});

  @override
  Widget build(BuildContext context) {
    final status = enquiry['status'] as String? ?? 'open';
    final closed = status == 'closed';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(enquiry['visitor_name'] as String? ?? '',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                        color: closed ? AppColors.muted : AppColors.text)),
              ),
              _StatusChip(status),
              if (!closed && onClose != null) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.teal),
                ),
              ],
            ]),
            if ((enquiry['purpose'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(enquiry['purpose'] as String, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
            const SizedBox(height: 6),
            Wrap(spacing: 10, runSpacing: 3, children: [
              _MetaChip(icon: Icons.event, label: _formatDateTime(enquiry['visited_at'] as String?)),
              if (enquiry['followup_at'] != null)
                _MetaChip(icon: Icons.notifications_active_outlined,
                    label: 'Follow-up ${_formatDateTime(enquiry['followup_at'] as String?)}',
                    color: AppColors.amber),
            ]),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(String? iso) {
    if (iso == null) return '';
    try {
      final d = DateTime.parse(iso).toLocal();
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final ampm = d.hour < 12 ? 'AM' : 'PM';
      return '${d.day} ${months[d.month]}, $h:${d.minute.toString().padLeft(2, '0')} $ampm';
    } catch (_) {
      return iso;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'closed' => ('CLOSED', const Color(0xFFD1FAE5), AppColors.teal),
      'followup_scheduled' => ('FOLLOW-UP', const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      _ => ('OPEN', const Color(0xFFF3F4F6), AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MetaChip({required this.icon, required this.label, this.color = AppColors.muted});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      );
}
