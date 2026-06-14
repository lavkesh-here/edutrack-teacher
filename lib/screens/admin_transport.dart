import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class AdminTransportScreen extends StatefulWidget {
  const AdminTransportScreen({super.key});

  @override
  State<AdminTransportScreen> createState() => _AdminTransportScreenState();
}

class _AdminTransportScreenState extends State<AdminTransportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Transport'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.sun,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.sun,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Routes'),
            Tab(text: 'Assignments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _RoutesTab(),
          _AssignmentsTab(),
        ],
      ),
    );
  }
}

// ── Routes Tab ────────────────────────────────────────────────────────────────

class _RoutesTab extends StatefulWidget {
  const _RoutesTab();

  @override
  State<_RoutesTab> createState() => _RoutesTabState();
}

class _RoutesTabState extends State<_RoutesTab> {
  List<Map<String, dynamic>> _routes = [];
  bool _loading = true;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiClient.adminListRoutes();
      setState(() {
        _routes = data;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      setState(() => _loading = false);
    }
  }

  void _showAddRouteSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddRouteSheet(onCreated: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddRouteSheet,
        backgroundColor: AppColors.sky,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Route', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
          : _routes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🚌', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 12),
                      const Text(
                        'No routes yet',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Add a route using the button below',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.sun,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _routes.length,
                    itemBuilder: (_, i) {
                      final route = _routes[i];
                      final id = route['id'] as int? ?? i;
                      final isExpanded = _expanded.contains(id);
                      final stops = route['stops'] as List<dynamic>? ?? [];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => setState(() {
                                if (isExpanded) {
                                  _expanded.remove(id);
                                } else {
                                  _expanded.add(id);
                                }
                              }),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: AppColors.skyLight,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: Text('🚌', style: TextStyle(fontSize: 20)),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            route['name'] as String? ?? '',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.text,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _routeSub(route),
                                            style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        _Chip(
                                          '${route['student_count'] ?? 0} students',
                                          AppColors.tealLight,
                                          AppColors.teal,
                                        ),
                                        const SizedBox(height: 4),
                                        _Chip(
                                          '${stops.length} stops',
                                          AppColors.violetLight,
                                          AppColors.violet,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      isExpanded ? Icons.expand_less : Icons.expand_more,
                                      color: AppColors.muted,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isExpanded && stops.isNotEmpty) ...[
                              const Divider(height: 1, color: AppColors.border),
                              ...stops.asMap().entries.map((e) {
                                final stop = e.value as Map<String, dynamic>;
                                final isLast = e.key == stops.length - 1;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    border: isLast
                                        ? null
                                        : const Border(bottom: BorderSide(color: AppColors.border)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.sky,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          stop['name'] as String? ?? '',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text,
                                          ),
                                        ),
                                      ),
                                      if (stop['pickup_time'] != null)
                                        Text(
                                          stop['pickup_time'] as String,
                                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  String _routeSub(Map<String, dynamic> r) {
    final parts = <String>[];
    final veh = r['vehicle_number'] as String?;
    final driver = r['driver_name'] as String?;
    if (veh != null && veh.isNotEmpty) parts.add(veh);
    if (driver != null && driver.isNotEmpty) parts.add(driver);
    return parts.isEmpty ? 'No vehicle info' : parts.join(' · ');
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _Chip(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
        ),
      );
}

// ── Assignments Tab ───────────────────────────────────────────────────────────

class _AssignmentsTab extends StatefulWidget {
  const _AssignmentsTab();

  @override
  State<_AssignmentsTab> createState() => _AssignmentsTabState();
}

class _AssignmentsTabState extends State<_AssignmentsTab> {
  List<Map<String, dynamic>> _assignments = [];
  List<Map<String, dynamic>> _routes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.adminListTransportAssignments(),
        ApiClient.adminListRoutes(),
      ]);
      setState(() {
        _assignments = results[0] as List<Map<String, dynamic>>;
        _routes = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      setState(() => _loading = false);
    }
  }

  Future<void> _removeAssignment(int studentId) async {
    try {
      await ApiClient.adminRemoveTransportAssignment(studentId);
      if (mounted) {
        showSnack(context, 'Assignment removed');
        _load();
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  void _showAssignSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignStudentSheet(
        routes: _routes,
        onAssigned: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.sun))
                : _assignments.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🗺️', style: TextStyle(fontSize: 44)),
                            SizedBox(height: 12),
                            Text(
                              'No assignments yet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.sun,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _assignments.length,
                          itemBuilder: (_, i) {
                            final a = _assignments[i];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                border: Border(bottom: BorderSide(color: AppColors.border)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a['student_name'] as String? ?? '',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          a['class_label'] as String? ?? '',
                                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Text('🚌 ', style: TextStyle(fontSize: 12)),
                                            Text(
                                              a['route_name'] as String? ?? '',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.sky,
                                              ),
                                            ),
                                            if (a['stop_name'] != null) ...[
                                              const Text(' · ', style: TextStyle(color: AppColors.muted)),
                                              Text(
                                                a['stop_name'] as String,
                                                style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.coral, size: 20),
                                    onPressed: () => _showDeleteConfirm(a),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _showAssignSheet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Assign Student'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.sky),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Assignment?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Remove transport assignment for ${assignment['student_name'] ?? 'this student'}?',
          style: const TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeAssignment(assignment['student_id'] as int? ?? 0);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Add Route Bottom Sheet ────────────────────────────────────────────────────

class _AddRouteSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _AddRouteSheet({required this.onCreated});

  @override
  State<_AddRouteSheet> createState() => _AddRouteSheetState();
}

class _AddRouteSheetState extends State<_AddRouteSheet> {
  final _nameCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _driverNameCtrl = TextEditingController();
  final _driverPhoneCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController(text: '0');
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vehicleCtrl.dispose();
    _driverNameCtrl.dispose();
    _driverPhoneCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Route name is required', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.adminCreateRoute(
        name: name,
        vehicleNumber: _vehicleCtrl.text.trim().isEmpty ? null : _vehicleCtrl.text.trim(),
        driverName: _driverNameCtrl.text.trim().isEmpty ? null : _driverNameCtrl.text.trim(),
        driverPhone: _driverPhoneCtrl.text.trim().isEmpty ? null : _driverPhoneCtrl.text.trim(),
        capacity: int.tryParse(_capacityCtrl.text.trim()) ?? 0,
      );
      if (mounted) {
        showSnack(context, 'Route created');
        Navigator.pop(context);
        widget.onCreated();
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(20)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Add Route',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('✕', style: TextStyle(fontSize: 22, color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetLabel('ROUTE NAME *'),
                    const SizedBox(height: 6),
                    TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'e.g. North Route')),
                    const SizedBox(height: 14),
                    _SheetLabel('VEHICLE NUMBER'),
                    const SizedBox(height: 6),
                    TextField(controller: _vehicleCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'e.g. MH 01 AB 1234')),
                    const SizedBox(height: 14),
                    _SheetLabel('DRIVER NAME'),
                    const SizedBox(height: 6),
                    TextField(controller: _driverNameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Suresh Patil')),
                    const SizedBox(height: 14),
                    _SheetLabel('DRIVER PHONE'),
                    const SizedBox(height: 6),
                    TextField(controller: _driverPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'e.g. 9876543210')),
                    const SizedBox(height: 14),
                    _SheetLabel('CAPACITY'),
                    const SizedBox(height: 6),
                    TextField(controller: _capacityCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '0')),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Create Route'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetLabel extends StatelessWidget {
  final String text;
  const _SheetLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.5),
      );
}

// ── Assign Student Bottom Sheet ───────────────────────────────────────────────

class _AssignStudentSheet extends StatefulWidget {
  final List<Map<String, dynamic>> routes;
  final VoidCallback onAssigned;

  const _AssignStudentSheet({required this.routes, required this.onAssigned});

  @override
  State<_AssignStudentSheet> createState() => _AssignStudentSheetState();
}

class _AssignStudentSheetState extends State<_AssignStudentSheet> {
  final _searchCtrl = TextEditingController();
  List<StudentSearchResult> _results = [];
  StudentSearchResult? _selected;
  int? _selectedRouteId;
  bool _searching = false;
  bool _saving = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) return;
    setState(() => _searching = true);
    try {
      final data = await ApiClient.searchStudents(q.trim());
      setState(() { _results = data; _searching = false; });
    } catch (_) {
      setState(() => _searching = false);
    }
  }

  Future<void> _submit() async {
    if (_selected == null) {
      showSnack(context, 'Select a student', error: true);
      return;
    }
    if (_selectedRouteId == null) {
      showSnack(context, 'Select a route', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiClient.adminAssignTransport(
        studentId: _selected!.id,
        routeId: _selectedRouteId!,
      );
      if (mounted) {
        showSnack(context, 'Student assigned to route');
        Navigator.pop(context);
        widget.onAssigned();
      }
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Assignment failed: ${e.toString()}', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(20)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('Assign Student',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.text)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('✕', style: TextStyle(fontSize: 22, color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SheetLabel('SEARCH STUDENT'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _searchCtrl,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        hintText: 'Type student name and press search...',
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.sun)),
                              )
                            : IconButton(
                                icon: const Icon(Icons.search, color: AppColors.sun),
                                onPressed: () => _search(_searchCtrl.text),
                              ),
                      ),
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.teal.withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Text('✓ ', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w800)),
                            Expanded(
                              child: Text(
                                '${_selected!.name}${_selected!.classLabel != null ? " · ${_selected!.classLabel}" : ""}',
                                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.teal),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _selected = null),
                              child: const Icon(Icons.close, size: 16, color: AppColors.teal),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_results.isNotEmpty && _selected == null) ...[
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: _results.take(5).map((s) {
                            return GestureDetector(
                              onTap: () => setState(() {
                                _selected = s;
                                _results = [];
                                _searchCtrl.text = s.name;
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: AppColors.border)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.name,
                                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
                                      ),
                                    ),
                                    Text(
                                      s.classLabel ?? '',
                                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _SheetLabel('SELECT ROUTE'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: _selectedRouteId,
                      hint: const Text('Choose a route'),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: widget.routes.map((r) {
                        return DropdownMenuItem<int>(
                          value: r['id'] as int?,
                          child: Text(r['name'] as String? ?? ''),
                        );
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedRouteId = v),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Confirm Assignment'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
