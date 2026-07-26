import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class VisitorLogScreen extends StatefulWidget {
  const VisitorLogScreen({super.key});

  @override
  State<VisitorLogScreen> createState() => _VisitorLogScreenState();
}

class _VisitorLogScreenState extends State<VisitorLogScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _visitors = [];
  bool _activeOnly = false;
  String? _visitTypeFilter;
  late DateTime _dateFrom;
  late DateTime _dateTo;
  bool _showingToday = true;

  static const _maxRangeDays = 90;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dateFrom = DateTime(today.year, today.month, today.day);
    _dateTo = _dateFrom;
    _load();
  }

  String _iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.listVisitors(
        dateFrom: _iso(_dateFrom),
        dateTo: _iso(_dateTo),
        visitType: _visitTypeFilter,
      );
      if (mounted) {
        setState(() {
          _visitors = (data['visitors'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<_VisitorFilters>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        visitType: _visitTypeFilter,
        maxRangeDays: _maxRangeDays,
      ),
    );
    if (result != null) {
      setState(() {
        _dateFrom = result.dateFrom;
        _dateTo = result.dateTo;
        _visitTypeFilter = result.visitType;
        final today = DateTime.now();
        _showingToday = result.dateFrom.year == today.year &&
            result.dateFrom.month == today.month &&
            result.dateFrom.day == today.day &&
            result.dateTo.year == today.year &&
            result.dateTo.month == today.month &&
            result.dateTo.day == today.day;
      });
      _load();
    }
  }

  Future<void> _checkout(String visitorId) async {
    try {
      await ApiClient.checkoutVisitor(visitorId);
      if (mounted) {
        showSnack(context, 'Visitor checked out');
        _load();
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  void _showAddVisitor() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddVisitorSheet(onSuccess: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _activeOnly
        ? _visitors.where((v) => v['check_out'] == null).toList()
        : _visitors;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Visitor Log'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list, color: _visitTypeFilter != null || !_showingToday ? AppColors.sky : null),
            onPressed: _openFilters,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVisitor,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Filter bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: !_activeOnly,
                  onTap: () => setState(() => _activeOnly = false),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Active',
                  selected: _activeOnly,
                  onTap: () => setState(() => _activeOnly = true),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} visitor${filtered.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (!_showingToday || _visitTypeFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  Icon(Icons.filter_alt, size: 13, color: AppColors.sky),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      [
                        if (!_showingToday) '${_iso(_dateFrom)} → ${_iso(_dateTo)}',
                        if (_visitTypeFilter != null) _visitTypeFilter!,
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.sky, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        final today = DateTime.now();
                        _dateFrom = DateTime(today.year, today.month, today.day);
                        _dateTo = _dateFrom;
                        _visitTypeFilter = null;
                        _showingToday = true;
                      });
                      _load();
                    },
                    child: const Text('Clear', style: TextStyle(color: AppColors.sky, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: _error!, onRetry: _load)
                    : filtered.isEmpty
                        ? const _EmptyState()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) => _VisitorCard(
                                visitor: filtered[i],
                                onCheckout: () => _checkout(
                                  filtered[i]['id']?.toString() ?? '',
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
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
          color: selected ? AppColors.sky : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.sky : AppColors.border),
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

const _visitTypeFilterOptions = [
  ('parent', 'Parent'),
  ('vendor', 'Vendor'),
  ('official', 'Official'),
  ('other', 'Other'),
  ('visitor', 'Visitor'),
];

class _VisitorFilters {
  const _VisitorFilters({required this.dateFrom, required this.dateTo, this.visitType});
  final DateTime dateFrom;
  final DateTime dateTo;
  final String? visitType;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.dateFrom,
    required this.dateTo,
    required this.visitType,
    required this.maxRangeDays,
  });
  final DateTime dateFrom;
  final DateTime dateTo;
  final String? visitType;
  final int maxRangeDays;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DateTime _from;
  late DateTime _to;
  String? _type;

  @override
  void initState() {
    super.initState();
    _from = widget.dateFrom;
    _to = widget.dateTo;
    _type = widget.visitType;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final today = DateTime.now();
    final earliest = today.subtract(Duration(days: widget.maxRangeDays));
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: earliest,
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  String _label(DateTime d) => '${d.day}/${d.month}/${d.year}';

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
          const Text('Filter Visitors',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 4),
          Text('Full history is kept; showing up to ${widget.maxRangeDays} days at a time.',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          const SizedBox(height: 16),
          const Text('Date range', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: true),
                  child: Text(_label(_from)),
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('to')),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(isFrom: false),
                  child: Text(_label(_to)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Visit type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _FilterChip(label: 'All types', selected: _type == null, onTap: () => setState(() => _type = null)),
              ..._visitTypeFilterOptions.map((t) => _FilterChip(
                    label: t.$2,
                    selected: _type == t.$1,
                    onTap: () => setState(() => _type = t.$1),
                  )),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                context,
                _VisitorFilters(dateFrom: _from, dateTo: _to, visitType: _type),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorCard extends StatefulWidget {
  const _VisitorCard({required this.visitor, required this.onCheckout});
  final Map<String, dynamic> visitor;
  final VoidCallback onCheckout;

  @override
  State<_VisitorCard> createState() => _VisitorCardState();
}

class _VisitorCardState extends State<_VisitorCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final v = widget.visitor;
    final name = v['visitor_name'] as String? ?? '—';
    final purpose = v['purpose'] as String? ?? '—';
    final whomToMeet = v['whom_to_meet'] as String? ?? '—';
    final checkIn = v['check_in'] as String? ?? '';
    final checkOut = v['check_out'] as String?;
    final visitType = v['visit_type'] as String? ?? 'visitor';
    final phone = v['phone'] as String?;
    final notes = v['notes'] as String?;
    final isActive = checkOut == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? AppColors.sky.withOpacity(0.4) : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.skyLight : AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(_visitTypeEmoji(visitType),
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(purpose,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.skyLight : AppColors.bg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? AppColors.sky.withOpacity(0.4)
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Checked Out',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive ? AppColors.sky : AppColors.muted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(checkIn),
                        style: const TextStyle(fontSize: 10, color: AppColors.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow('Whom to Meet', whomToMeet),
                  _DetailRow('Visit Type', _visitTypeLabel(visitType)),
                  if (phone != null && phone.isNotEmpty)
                    _DetailRow('Phone', phone),
                  _DetailRow('Checked In', _formatDateTime(checkIn)),
                  if (checkOut != null)
                    _DetailRow('Checked Out', _formatDateTime(checkOut)),
                  if (notes != null && notes.isNotEmpty)
                    _DetailRow('Notes', notes),
                  if (isActive) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: widget.onCheckout,
                        icon: const Icon(Icons.logout, size: 16),
                        label: const Text('Mark as Checked Out'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sky,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _visitTypeEmoji(String type) {
    switch (type) {
      case 'parent': return '👨‍👩‍👦';
      case 'vendor': return '🚚';
      case 'official': return '🏛️';
      case 'other': return '👤';
      default: return '🏠';
    }
  }

  String _visitTypeLabel(String type) {
    switch (type) {
      case 'parent': return 'Parent';
      case 'vendor': return 'Vendor';
      case 'official': return 'Official';
      case 'other': return 'Other';
      default: return 'Visitor';
    }
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _formatDateTime(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${_months[dt.month - 1]}, $h:$m';
    } catch (_) {
      return iso;
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🏠', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('No visitors today',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          SizedBox(height: 6),
          Text('Tap + to log a visitor',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
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

// ── Add Visitor Sheet ─────────────────────────────────────────────────────────

class _AddVisitorSheet extends StatefulWidget {
  const _AddVisitorSheet({required this.onSuccess});
  final VoidCallback onSuccess;

  @override
  State<_AddVisitorSheet> createState() => _AddVisitorSheetState();
}

class _AddVisitorSheetState extends State<_AddVisitorSheet> {
  final _nameCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _whomCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _visitType = 'visitor';
  bool _saving = false;
  String? _nameError;

  static const _visitTypes = [
    ('visitor', 'Visitor'),
    ('parent', 'Parent'),
    ('vendor', 'Vendor'),
    ('official', 'Official'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _purposeCtrl.dispose();
    _whomCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Visitor name is required');
      return;
    }
    setState(() { _saving = true; _nameError = null; });
    try {
      final body = <String, dynamic>{
        'visitor_name': name,
        'visit_type': _visitType,
      };
      if (_purposeCtrl.text.trim().isNotEmpty) body['purpose'] = _purposeCtrl.text.trim();
      if (_whomCtrl.text.trim().isNotEmpty) body['whom_to_meet'] = _whomCtrl.text.trim();
      if (_phoneCtrl.text.trim().isNotEmpty) body['phone'] = _phoneCtrl.text.trim();
      if (_notesCtrl.text.trim().isNotEmpty) body['notes'] = _notesCtrl.text.trim();

      await ApiClient.logVisitor(body);
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } on ApiError catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, e.message, error: true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Failed to log visitor', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Log Visitor',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Visitor Name *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                errorText: _nameError,
              ),
              onChanged: (_) { if (_nameError != null) setState(() => _nameError = null); },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _purposeCtrl,
              decoration: InputDecoration(
                labelText: 'Purpose',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _whomCtrl,
              decoration: InputDecoration(
                labelText: 'Whom to Meet',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Visit Type',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _visitTypes.map(((String val, String label) t) {
                final selected = _visitType == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _visitType = t.$1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.sky : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.sky : AppColors.border,
                      ),
                    ),
                    child: Text(
                      t.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Log Visitor'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
