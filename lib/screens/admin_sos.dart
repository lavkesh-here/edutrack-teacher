import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

enum _SOSTab { unresolved, resolved, all }

class AdminSOSScreen extends StatefulWidget {
  const AdminSOSScreen({super.key});

  @override
  State<AdminSOSScreen> createState() => _AdminSOSScreenState();
}

class _AdminSOSScreenState extends State<AdminSOSScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = [];
  _SOSTab _tab = _SOSTab.unresolved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resolved = switch (_tab) {
        _SOSTab.unresolved => false,
        _SOSTab.resolved => true,
        _SOSTab.all => null,
      };
      final data = await ApiClient.getSOSEvents(resolved: resolved);
      if (mounted) {
        setState(() {
          _events = (data['events'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _setTab(_SOSTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    _load();
  }

  Future<void> _resolve(String eventId) async {
    final notes = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ResolveSheet(),
    );
    if (notes == _cancelledSentinel) return;
    try {
      await ApiClient.resolveSOSEvent(eventId, notes: notes);
      if (mounted) {
        showSnack(context, 'Marked as resolved');
        _load();
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('SOS Alerts'),
        centerTitle: false,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _TabChip(label: 'Unresolved', selected: _tab == _SOSTab.unresolved, onTap: () => _setTab(_SOSTab.unresolved)),
                const SizedBox(width: 8),
                _TabChip(label: 'Resolved', selected: _tab == _SOSTab.resolved, onTap: () => _setTab(_SOSTab.resolved)),
                const SizedBox(width: 8),
                _TabChip(label: 'All', selected: _tab == _SOSTab.all, onTap: () => _setTab(_SOSTab.all)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : _events.isEmpty
                        ? _EmptyState(unresolved: _tab == _SOSTab.unresolved)
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                              itemCount: _events.length,
                              itemBuilder: (_, i) => _SOSCard(
                                event: _events[i],
                                onResolve: () => _resolve(_events[i]['id']?.toString() ?? ''),
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

const _cancelledSentinel = '__cancelled__';

class _TabChip extends StatelessWidget {
  const _TabChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.coral : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.coral : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }
}

class _SOSCard extends StatelessWidget {
  const _SOSCard({required this.event, required this.onResolve});
  final Map<String, dynamic> event;
  final VoidCallback onResolve;

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]}, $h:$m';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final triggeredByName = event['triggered_by_name'] as String? ?? 'Unknown';
    final triggeredByType = event['triggered_by_type'] as String? ?? 'teacher';
    final studentName = event['student_name'] as String?;
    final sectionLabel = event['section_label'] as String?;
    final locationNote = event['location_note'] as String?;
    final createdAt = event['created_at'] as String?;
    final resolved = event['resolved'] as bool? ?? false;
    final resolvedByName = event['resolved_by_name'] as String?;
    final notes = event['notes'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: resolved ? AppColors.border : AppColors.coral.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: resolved ? AppColors.tealLight : AppColors.coralLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  resolved ? 'Resolved' : 'Unresolved',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: resolved ? AppColors.teal : AppColors.coral),
                ),
              ),
              const Spacer(),
              Text(_formatDateTime(createdAt), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text('$triggeredByName ($triggeredByType)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          if (studentName != null || sectionLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              [studentName, sectionLabel].where((s) => s != null && s.isNotEmpty).join(' · '),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
          if (locationNote != null && locationNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(locationNote, style: const TextStyle(fontSize: 13, color: AppColors.text)),
          ],
          if (resolved) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 8),
            if (resolvedByName != null)
              Text('Resolved by $resolvedByName', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(notes, style: const TextStyle(fontSize: 12, color: AppColors.text)),
            ],
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onResolve,
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Mark Resolved'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.coral,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResolveSheet extends StatefulWidget {
  const _ResolveSheet();

  @override
  State<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends State<_ResolveSheet> {
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Resolve SOS Alert', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'What action was taken? (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, _cancelledSentinel),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim()),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.coral),
                  child: const Text('Mark Resolved'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.unresolved});
  final bool unresolved;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(unresolved ? '✅' : '🚨', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            unresolved ? 'No unresolved SOS alerts' : 'No SOS alerts found',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
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
            const Text('⚠️', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
