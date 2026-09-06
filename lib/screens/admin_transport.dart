import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../core/api.dart';
import '../core/auth.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/bus_map.dart';
import 'dispatch.dart';

/// EDR-0026 (Transport Coordinator role unification, 2026-09-06): Transport
/// Coordinator is not a distinct Responsibility -- it's identical to
/// Dispatch Coordinator (`dispatch_teacher_id` on >=1 route). This single
/// screen replaces what used to be three separately-gated screens (Bus
/// Dispatch, this admin-only screen, and the tag-gated Transport Overview):
///
/// - Routes / Assignments tabs: admin-or-above only, unchanged from before.
/// - GPS / Exceptions / Dispatch tabs: visible to admin-or-above (every
///   route, full map, Start/Stop Simulation) AND to any teacher holding
///   `dispatch_teacher_id` on >=1 route (their own route(s) only). The
///   backend does the scoping (`get_dispatch_scoped_route_ids`,
///   `backend/app/api/v1/deps.py`) -- this client never filters by route
///   itself, it renders exactly what each caller's own request returns.
/// - Neither: the existing "No Dispatch Responsibility" empty state
///   (`DispatchTab`, `dispatch.dart`), same as Bus Dispatch always showed
///   for this population -- reached through the one shared entry point now
///   instead of its own tile.
bool canOperateGpsSimulation(String? role) {
  return role == 'admin' || role == 'principal' || role == 'director';
}

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> with SingleTickerProviderStateMixin {
  TabController? _tab;
  bool _resolving = true;
  bool _isAdminOrAbove = false;

  @override
  void initState() {
    super.initState();
    _resolveAccess();
  }

  Future<void> _resolveAccess() async {
    final user = context.read<AuthProvider>().user;
    final isAdminOrAbove = user != null && canOperateGpsSimulation(user.role);
    bool hasDispatchRoute = false;
    if (!isAdminOrAbove) {
      try {
        final routes = await ApiClient.getMyDispatchRoutes();
        hasDispatchRoute = routes.isNotEmpty;
      } catch (_) {
        hasDispatchRoute = false; // falls through to the empty state, never a crash
      }
    }
    if (!mounted) return;
    setState(() {
      _isAdminOrAbove = isAdminOrAbove;
      _tab = isAdminOrAbove
          ? TabController(length: 5, vsync: this)
          : (hasDispatchRoute ? TabController(length: 3, vsync: this) : null);
      _resolving = false;
    });
  }

  @override
  void dispose() {
    _tab?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_resolving) {
      return const Scaffold(backgroundColor: AppColors.bg, body: Center(child: CircularProgressIndicator()));
    }
    if (_tab == null) {
      // Neither admin-or-above nor a dispatch assignment on any route --
      // same empty state Bus Dispatch always showed this population.
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: const Text('Transport', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
        ),
        body: const DispatchTab(),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Transport'),
        centerTitle: false,
        bottom: TabBar(
          controller: _tab,
          isScrollable: _isAdminOrAbove,
          labelColor: null,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: null,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: _isAdminOrAbove
              ? const [
                  Tab(text: 'Routes'),
                  Tab(text: 'Assignments'),
                  Tab(text: 'GPS'),
                  Tab(text: 'Exceptions'),
                  Tab(text: 'Dispatch'),
                ]
              : const [
                  Tab(text: 'GPS'),
                  Tab(text: 'Exceptions'),
                  Tab(text: 'Dispatch'),
                ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: _isAdminOrAbove
            ? const [_RoutesTab(), _AssignmentsTab(), _GpsTab(), _ExceptionsTab(), DispatchTab()]
            : const [_GpsTab(), _ExceptionsTab(), DispatchTab()],
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
  final Set<String> _expanded = {};

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
        key: const Key('add_route_fab'),
        onPressed: _showAddRouteSheet,
        backgroundColor: context.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Route', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                  color: context.primary,
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    itemCount: _routes.length,
                    itemBuilder: (_, i) {
                      final route = _routes[i];
                      final id = route['id']?.toString() ?? i.toString();
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
                                    const SizedBox(width: 4),
                                    // TR-014 Decision D: the backend's PUT
                                    // endpoint already supported this -- it
                                    // was only ever missing from this UI.
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
                                      tooltip: 'Edit route',
                                      onPressed: () => showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => _EditRouteSheet(route: route, onUpdated: _load),
                                      ),
                                    ),
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
        _assignments = results[0];
        _routes = results[1];
        _loading = false;
      });
    } on ApiError catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
      setState(() => _loading = false);
    }
  }

  Future<void> _removeAssignment(String studentId) async {
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
                ? const Center(child: CircularProgressIndicator())
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
                        color: context.primary,
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
                  key: const Key('assign_student_button'),
                  onPressed: _showAssignSheet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Assign Student'),
                  style: ElevatedButton.styleFrom(backgroundColor: context.primary),
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
              _removeAssignment(assignment['student_id']?.toString() ?? '');
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
                    TextField(key: const Key('route_name_field'), controller: _nameCtrl, decoration: const InputDecoration(hintText: 'e.g. North Route')),
                    const SizedBox(height: 14),
                    _SheetLabel('VEHICLE NUMBER'),
                    const SizedBox(height: 6),
                    TextField(controller: _vehicleCtrl, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: 'e.g. MH 01 AB 1234')),
                    const SizedBox(height: 14),
                    _SheetLabel('DRIVER NAME'),
                    const SizedBox(height: 6),
                    TextField(key: const Key('driver_name_field'), controller: _driverNameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(hintText: 'e.g. Suresh Patil')),
                    const SizedBox(height: 14),
                    _SheetLabel('DRIVER PHONE'),
                    const SizedBox(height: 6),
                    TextField(key: const Key('driver_phone_field'), controller: _driverPhoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'e.g. 9876543210')),
                    const SizedBox(height: 14),
                    _SheetLabel('CAPACITY'),
                    const SizedBox(height: 6),
                    TextField(controller: _capacityCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '0')),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        key: const Key('create_route_button'),
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

// ── Edit Route Bottom Sheet (TR-014 Decision D) ───────────────────────────────

class _EditRouteSheet extends StatefulWidget {
  final Map<String, dynamic> route;
  final VoidCallback onUpdated;
  const _EditRouteSheet({required this.route, required this.onUpdated});

  @override
  State<_EditRouteSheet> createState() => _EditRouteSheetState();
}

class _EditRouteSheetState extends State<_EditRouteSheet> {
  late final _nameCtrl = TextEditingController(text: widget.route['name'] as String? ?? '');
  late final _vehicleCtrl = TextEditingController(text: widget.route['vehicle_number'] as String? ?? '');
  late final _driverNameCtrl = TextEditingController(text: widget.route['driver_name'] as String? ?? '');
  late final _driverPhoneCtrl = TextEditingController(text: widget.route['driver_phone'] as String? ?? '');
  late final _capacityCtrl = TextEditingController(text: (widget.route['capacity'] ?? 0).toString());
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
      await ApiClient.adminUpdateRoute(
        widget.route['id'].toString(),
        name: name,
        vehicleNumber: _vehicleCtrl.text.trim(),
        driverName: _driverNameCtrl.text.trim(),
        driverPhone: _driverPhoneCtrl.text.trim(),
        capacity: int.tryParse(_capacityCtrl.text.trim()) ?? 0,
      );
      if (mounted) {
        showSnack(context, 'Route updated');
        Navigator.pop(context);
        widget.onUpdated();
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
                    const Text('Edit Route',
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
                    TextField(key: const Key('edit_route_name_field'), controller: _nameCtrl, decoration: const InputDecoration(hintText: 'e.g. North Route')),
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
                    const SizedBox(height: 8),
                    const Text(
                      'Note: clearing vehicle/driver fields back to blank isn\'t supported yet — only overwriting with a new value.',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        key: const Key('save_route_button'),
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Save Changes'),
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
  String? _selectedRouteId;
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
                      key: const Key('transport_student_search_field'),
                      controller: _searchCtrl,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        hintText: 'Type student name and press search...',
                        suffixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : IconButton(
                                icon: Icon(Icons.search, color: context.primary),
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
                    DropdownButtonFormField<String>(
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
                        return DropdownMenuItem<String>(
                          value: r['id']?.toString(),
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
                        key: const Key('assign_route_button'),
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

// ── GPS Tab (EDR-0026: moved from the now-deleted transport_coordinator.dart)
// ────────────────────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  final String icon;
  final String message;
  const _EmptyTab({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Text(icon, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text(message, style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      );
}

class _GpsTab extends StatefulWidget {
  const _GpsTab();

  @override
  State<_GpsTab> createState() => _GpsTabState();
}

class _GpsTabState extends State<_GpsTab> {
  List<Map<String, dynamic>> _vehicles = [];
  bool _loading = true;
  String? _error;
  String? _selectedRegNumber;

  // TR-014 Decision C: auto-poll, so a coordinator watching this tab sees
  // ticks driven by someone else (Admin Web, or another device's Start
  // Simulation) without needing to pull-to-refresh manually -- this tab
  // previously only ever loaded once, on open.
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 10);

  // TR-014 Decision C: the selected vehicle's road-snapped route polyline,
  // fetched once per selection (not re-fetched on every poll -- a route's
  // shape doesn't change tick to tick, only the vehicle's position on it does).
  final Map<String, List<LatLng>> _routePathCache = {};

  // GPS mobile-operator mission (2026-09-06): live-tick state, scoped to
  // this tab's own State so it survives tab switches within this screen but
  // is torn down (dispose below) the moment this screen itself is left --
  // the tick endpoint is deliberately stateless server-side (its own
  // docstring: "no server-side simulation process to track, kill, or leak"),
  // so the client interval below is the ONLY thing driving movement.
  final Set<String> _simulatingIds = {};
  final Map<String, Timer> _timers = {};
  final Map<String, Map<String, dynamic>> _liveOverrides = {};
  static const _tickInterval = Duration(seconds: 3); // matches Admin Web's real SIM_TICK_MS

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _loadSilently());
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getTransportVehicles();
      if (mounted) setState(() { _vehicles = data; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load GPS data.'; _loading = false; });
    }
  }

  // Background refresh -- never flips _loading (which would flash a
  // full-tab spinner every 10s), and never surfaces a transient network
  // error to the user the way the initial _load() does.
  Future<void> _loadSilently() async {
    try {
      final data = await ApiClient.getTransportVehicles();
      if (mounted) setState(() => _vehicles = data);
    } catch (_) {
      // Silent -- the next poll tries again; the initial _load()'s own
      // error state already covers "can't load at all".
    }
  }

  String? get _selectedVehicleId {
    if (_selectedRegNumber == null) return null;
    for (final v in _vehicles) {
      if (v['registration_number']?.toString() == _selectedRegNumber) return v['id']?.toString();
    }
    return null;
  }

  Future<void> _loadRoutePathFor(String vehicleId) async {
    if (_routePathCache.containsKey(vehicleId)) return;
    try {
      final points = await ApiClient.getVehicleRoutePath(vehicleId);
      if (mounted) setState(() => _routePathCache[vehicleId] = points);
    } catch (_) {
      // No path drawn is a harmless degradation -- the marker itself still works.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    super.dispose();
  }

  void _startSimulation(String vehicleId) {
    if (_timers.containsKey(vehicleId)) return; // never a duplicate timer for the same vehicle
    setState(() => _simulatingIds.add(vehicleId));
    _tick(vehicleId, sessionStart: true);
    _timers[vehicleId] = Timer.periodic(_tickInterval, (_) => _tick(vehicleId));
  }

  void _stopSimulation(String vehicleId) {
    _timers.remove(vehicleId)?.cancel();
    if (mounted) setState(() => _simulatingIds.remove(vehicleId));
  }

  Future<void> _tick(String vehicleId, {bool sessionStart = false}) async {
    try {
      final step = await ApiClient.simulateVehicleTick(vehicleId, sessionStart: sessionStart);
      if (!mounted) return;
      setState(() {
        _liveOverrides[vehicleId] = {
          'latitude': step['latitude'],
          'longitude': step['longitude'],
          'speed_kmh': step['speed_kmh'],
          'ignition_on': step['ignition_on'],
          'is_stale': false,
          'last_update': step['fix_time'],
        };
      });
    } catch (_) {
      // Role/flag disabled mid-session, network failure, etc. — never keep
      // polling silently after a failure; stop and let the user retry.
      _stopSimulation(vehicleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulation unavailable — stopping')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.coral)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final user = context.watch<AuthProvider>().user;
    final isAdminOrAbove = user != null && canOperateGpsSimulation(user.role);

    // Merge live-tick overrides over the polled/loaded vehicle list — never a
    // separate client-side simulation model, just a display-layer overlay of
    // the same backend state this same endpoint already wrote.
    final vehicles = _vehicles.map((v) {
      final override = _liveOverrides[v['id']?.toString()];
      return override == null ? v : {...v, ...override};
    }).toList();

    if (vehicles.isEmpty) return const _EmptyTab(icon: '📡', message: 'No vehicles added yet.');
    final hasAnyPosition = vehicles.any((v) => v['latitude'] != null && v['longitude'] != null);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasAnyPosition) ...[
          BusMap(
            vehicles: vehicles, selectedId: _selectedRegNumber,
            routePath: _selectedVehicleId == null ? null : _routePathCache[_selectedVehicleId],
          ),
          const SizedBox(height: 12),
        ],
        ...vehicles.map((v) {
        final isStale = v['is_stale'] == true;
        final hasFix = v['last_update'] != null;
        final regNumber = v['registration_number']?.toString();
        final vehicleId = v['id']?.toString();
        final isSimulating = vehicleId != null && _simulatingIds.contains(vehicleId);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
          onTap: hasFix ? () {
            setState(() => _selectedRegNumber = regNumber);
            if (vehicleId != null) _loadRoutePathFor(vehicleId);
          } : null,
          child: AppCard(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: !hasFix ? const Color(0xFFF3F4F6) : (isStale ? AppColors.amberLight : AppColors.greenLight),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(!hasFix ? '📡' : (isStale ? '⏱️' : '🟢'), style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v['registration_number']?.toString() ?? 'Vehicle',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                      Text(
                        v['route_name'] != null
                            ? '${v['route_name']} · ${!hasFix ? 'no GPS signal yet' : (isStale ? 'signal stale' : '${v['speed_kmh'] ?? 0} km/h')}'
                            : (!hasFix ? 'No route linked · no GPS signal yet' : (isStale ? 'No route linked · signal stale' : 'No route linked · ${v['speed_kmh'] ?? 0} km/h')),
                        style: TextStyle(fontSize: 12, color: !hasFix ? AppColors.muted : (isStale ? const Color(0xFF92400E) : AppColors.muted)),
                      ),
                    ],
                  ),
                ),
              ],
              ),
              if (isAdminOrAbove && vehicleId != null) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => isSimulating ? _stopSimulation(vehicleId) : _startSimulation(vehicleId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isSimulating ? AppColors.coral : AppColors.teal,
                      side: BorderSide(color: isSimulating ? AppColors.coral : AppColors.teal),
                    ),
                    child: Text(isSimulating ? '⏹ Stop Simulation' : '▶ Start Simulation',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ],
            ),
          ),
          ),
        );
        }),
      ],
      ),
    );
  }
}

class _ExceptionsTab extends StatefulWidget {
  const _ExceptionsTab();

  @override
  State<_ExceptionsTab> createState() => _ExceptionsTabState();
}

class _ExceptionsTabState extends State<_ExceptionsTab> {
  List<dynamic> _missed = [];
  List<dynamic> _pending = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiClient.getTransportExceptions();
      if (mounted) {
        setState(() {
          _missed = data['missed'] as List<dynamic>? ?? [];
          _pending = data['pending_past_threshold'] as List<dynamic>? ?? [];
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load exceptions.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.coral)),
              const SizedBox(height: 12),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_missed.isEmpty && _pending.isEmpty) {
      return const _EmptyTab(icon: '✅', message: 'No missed or overdue pickups/drops today.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_missed.isNotEmpty) ...[
            const SectionHeader(title: 'MISSED'),
            ..._missed.map((m) => _ExceptionRow(
                  studentName: m['student_name']?.toString() ?? 'Student',
                  routeName: m['route_name']?.toString(),
                  label: (m['direction']?.toString() ?? '').toUpperCase(),
                  badgeColor: AppColors.coral,
                  badgeBg: AppColors.coralLight,
                )),
          ],
          if (_pending.isNotEmpty) ...[
            const SectionHeader(title: 'PAST EXPECTED TIME'),
            ..._pending.map((p) => _ExceptionRow(
                  studentName: p['student_name']?.toString() ?? 'Student',
                  routeName: p['route_name']?.toString(),
                  label: (p['direction']?.toString() ?? '').toUpperCase(),
                  badgeColor: const Color(0xFF92400E),
                  badgeBg: AppColors.amberLight,
                )),
          ],
        ],
      ),
    );
  }
}

class _ExceptionRow extends StatelessWidget {
  final String studentName;
  final String? routeName;
  final String label;
  final Color badgeColor;
  final Color badgeBg;
  const _ExceptionRow({required this.studentName, required this.routeName, required this.label, required this.badgeColor, required this.badgeBg});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                    if (routeName != null) Text(routeName!, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
              if (label.isNotEmpty) StatusBadge(label: label, bg: badgeBg, fg: badgeColor),
            ],
          ),
        ),
      );
}
