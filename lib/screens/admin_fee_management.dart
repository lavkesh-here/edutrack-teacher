import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminFeeManagementScreen extends StatefulWidget {
  const AdminFeeManagementScreen({super.key});

  @override
  State<AdminFeeManagementScreen> createState() => _AdminFeeManagementScreenState();
}

class _AdminFeeManagementScreenState extends State<AdminFeeManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Fee Management'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabs,
          labelColor: null,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: null,
          tabs: const [
            Tab(text: 'Components'),
            Tab(text: 'Structures'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _ComponentsTab(),
          _StructuresTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: Fee Components ─────────────────────────────────────────────────────

class _ComponentsTab extends StatefulWidget {
  const _ComponentsTab();

  @override
  State<_ComponentsTab> createState() => _ComponentsTabState();
}

class _ComponentsTabState extends State<_ComponentsTab> {
  List<Map<String, dynamic>> _components = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminListFeeComponents();
      if (mounted) setState(() { _components = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) { showSnack(context, e.message, error: true); setState(() => _loading = false); }
    } catch (_) {
      if (mounted) { showSnack(context, 'Failed to load. Please try again.', error: true); setState(() => _loading = false); }
    }
  }

  Future<void> _delete(String id, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Component'),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.coral)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.adminDeleteFeeComponent(id);
      _load();
      if (mounted) showSnack(context, 'Component deleted');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  void _showAddSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    bool isOptional = false;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Fee Component',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 16),
              TextField(key: const Key('fee_component_name_field'), controller: nameCtrl, decoration: const InputDecoration(labelText: 'Component Name')),
              const SizedBox(height: 10),
              TextField(key: const Key('fee_component_desc_field'), controller: descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Switch(
                    value: isOptional,
                    activeColor: AppColors.teal,
                    onChanged: (v) => setSheet(() => isOptional = v),
                  ),
                  const Text('Optional component', style: TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  key: const Key('add_fee_component_button'),
                  onPressed: saving
                      ? null
                      : () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          setSheet(() => saving = true);
                          try {
                            await ApiClient.adminCreateFeeComponent(
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                              isOptional: isOptional,
                            );
                            if (mounted) Navigator.pop(ctx);
                            _load();
                            if (mounted) showSnack(context, 'Component added');
                          } on ApiError catch (e) {
                            setSheet(() => saving = false);
                            if (mounted) showSnack(context, e.message, error: true);
                          }
                        },
                  style: ElevatedButton.styleFrom(),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Add Component', style: TextStyle(fontWeight: FontWeight.w700)),
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        backgroundColor: null,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _components.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('💰', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('No fee components yet',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                      SizedBox(height: 6),
                      Text('Add components like Tuition, Transport, etc.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.sun,
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _components.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final c = _components[i];
                      final id = c['id'].toString();
                      final name = c['name'] as String? ?? '';
                      final desc = c['description'] as String? ?? '';
                      final isOptional = c['is_optional'] as bool? ?? false;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                  color: AppColors.amberLight,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Center(child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.amber))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(name,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                                      if (isOptional) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: AppColors.tealLight,
                                              borderRadius: BorderRadius.circular(6)),
                                          child: const Text('Optional',
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.teal)),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (desc.isNotEmpty)
                                    Text(desc,
                                        style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.coral, size: 20),
                              onPressed: () => _delete(id, name),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Tab 2: Fee Structures ─────────────────────────────────────────────────────

class _StructuresTab extends StatefulWidget {
  const _StructuresTab();

  @override
  State<_StructuresTab> createState() => _StructuresTabState();
}

class _StructuresTabState extends State<_StructuresTab> {
  List<Map<String, dynamic>> _structures = [];
  bool _loading = true;
  String? _statusFilter; // null = all

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminListFeeStructures(status: _statusFilter);
      if (mounted) setState(() { _structures = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) { showSnack(context, e.message, error: true); setState(() => _loading = false); }
    } catch (_) {
      if (mounted) { showSnack(context, 'Failed to load. Please try again.', error: true); setState(() => _loading = false); }
    }
  }

  Future<void> _updateStatus(String id, String current) async {
    final opts = ['paid', 'unpaid', 'overdue'].where((s) => s != current).toList();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Update Status',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
            const SizedBox(height: 12),
            ...opts.map((s) => ListTile(
                  leading: _statusIcon(s),
                  title: Text(_statusLabel(s), style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context, s),
                )),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    try {
      await ApiClient.adminUpdateFeeStatus(id, chosen);
      _load();
      if (mounted) showSnack(context, 'Status updated to ${_statusLabel(chosen)}');
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  void _showRecordPayment(Map<String, dynamic> structure) {
    final amountCtrl = TextEditingController(
        text: (structure['amount'] as num?)?.toStringAsFixed(0) ?? '');
    final refCtrl = TextEditingController();
    String method = 'cash';
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Record Payment — ${structure['title'] ?? ''}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (₹)', prefixText: '₹ '),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: method,
                decoration: const InputDecoration(labelText: 'Payment Method'),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'cheque', child: Text('Cheque')),
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                ],
                onChanged: (v) => setSheet(() => method = v ?? 'cash'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(labelText: 'Reference / UTR (optional)'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final amount = double.tryParse(amountCtrl.text.trim());
                          if (amount == null || amount <= 0) {
                            showSnack(context, 'Enter a valid amount', error: true);
                            return;
                          }
                          setSheet(() => saving = true);
                          try {
                            await ApiClient.adminRecordPayment(
                              structureId: structure['id'].toString(),
                              studentId: structure['student_id'].toString(),
                              amount: amount,
                              method: method,
                              reference: refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
                            );
                            if (mounted) Navigator.pop(ctx);
                            _load();
                            if (mounted) showSnack(context, 'Payment recorded ✓');
                          } on ApiError catch (e) {
                            setSheet(() => saving = false);
                            if (mounted) showSnack(context, e.message, error: true);
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.teal),
                  child: saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Record Payment', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'paid': return const Icon(Icons.check_circle_rounded, color: AppColors.teal, size: 20);
      case 'overdue': return const Icon(Icons.warning_rounded, color: AppColors.coral, size: 20);
      default: return const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.muted, size: 20);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return 'Paid';
      case 'overdue': return 'Overdue';
      default: return 'Unpaid';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return AppColors.teal;
      case 'overdue': return AppColors.coral;
      default: return AppColors.muted;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'paid': return AppColors.tealLight;
      case 'overdue': return AppColors.coralLight;
      default: return AppColors.bg;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              for (final entry in {'All': null, 'Unpaid': 'unpaid', 'Paid': 'paid', 'Overdue': 'overdue'}.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(entry.key),
                    selected: _statusFilter == entry.value,
                    onSelected: (_) {
                      setState(() => _statusFilter = entry.value);
                      _load();
                    },
                    selectedColor: AppColors.sunLight,
                    checkmarkColor: AppColors.sun,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _statusFilter == entry.value ? AppColors.sun : AppColors.muted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _structures.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('📄', style: TextStyle(fontSize: 48)),
                          SizedBox(height: 12),
                          Text('No fee structures found',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.sun,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _structures.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final s = _structures[i];
                          final id = s['id'].toString();
                          final title = s['title'] as String? ?? '';
                          final amount = (s['amount'] as num?)?.toDouble() ?? 0;
                          final status = s['status'] as String? ?? 'unpaid';
                          final studentName = s['student_name'] as String? ?? '';
                          final sectionName = s['section_name'] as String? ?? '';
                          final dueDate = (s['due_date'] as String? ?? '').split('T').first;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(title,
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                          color: _statusBg(status),
                                          borderRadius: BorderRadius.circular(8)),
                                      child: Text(_statusLabel(status),
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _statusColor(status))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (studentName.isNotEmpty)
                                      Text(studentName,
                                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                    if (studentName.isNotEmpty && sectionName.isNotEmpty)
                                      const Text(' · ', style: TextStyle(fontSize: 12, color: AppColors.muted)),
                                    if (sectionName.isNotEmpty)
                                      Text(sectionName,
                                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                                  ],
                                ),
                                if (dueDate.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text('Due: ${fmtDate(dueDate)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text('₹${amount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                                    const Spacer(),
                                    if (status != 'paid')
                                      OutlinedButton(
                                        onPressed: () => _showRecordPayment(s),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.teal,
                                          side: const BorderSide(color: AppColors.teal),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text('Record Payment',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                      ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () => _updateStatus(id, status),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.muted,
                                        side: const BorderSide(color: AppColors.border),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text('Status',
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
