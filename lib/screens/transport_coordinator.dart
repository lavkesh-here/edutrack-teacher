import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/bus_map.dart';

/// School-wide, read-only transport/GPS monitoring for a teacher tagged
/// 'transport_coordinator' (see AdminTeacherRolesScreen) — every route,
/// vehicle, and exception in the school, never scoped to just one route
/// the way the dispatch-teacher screen (dispatch.dart) is. No write
/// actions anywhere on this screen by design: the backend enforces this
/// (get_transport_coordinator_read_access has no write counterpart), the
/// UI simply never offers one, matching the mission's own scope for this
/// persona ("monitor", "see", "investigate" — never "create"/"mark").

class TransportCoordinatorScreen extends StatefulWidget {
  const TransportCoordinatorScreen({super.key});

  @override
  State<TransportCoordinatorScreen> createState() => _State();
}

class _State extends State<TransportCoordinatorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _vehicles = [];
  Map<String, dynamic>? _exceptions;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        ApiClient.adminListRoutes(),
        ApiClient.getTransportVehicles(),
        ApiClient.getTransportExceptions(),
      ]);
      if (mounted) {
        setState(() {
          _routes = results[0] as List<Map<String, dynamic>>;
          _vehicles = results[1] as List<Map<String, dynamic>>;
          _exceptions = results[2] as Map<String, dynamic>;
          _loading = false;
        });
      }
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load transport overview.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final missed = (_exceptions?['missed'] as List<dynamic>? ?? []);
    final pending = (_exceptions?['pending_past_threshold'] as List<dynamic>? ?? []);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.pop(context)),
        title: const Text('Transport Overview',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(49),
          child: Column(
            children: [
              Container(color: AppColors.border, height: 1),
              TabBar(
                controller: _tabCtrl,
                unselectedLabelColor: AppColors.muted,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                tabs: [
                  const Tab(text: 'Routes'),
                  const Tab(text: 'GPS'),
                  Tab(text: 'Exceptions${(missed.length + pending.length) > 0 ? ' (${missed.length + pending.length})' : ''}'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _RoutesTab(routes: _routes),
                      _GpsTab(vehicles: _vehicles),
                      _ExceptionsTab(missed: missed, pending: pending),
                    ],
                  ),
                ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.coral)),
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      );
}

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

class _RoutesTab extends StatelessWidget {
  final List<Map<String, dynamic>> routes;
  const _RoutesTab({required this.routes});

  @override
  Widget build(BuildContext context) {
    if (routes.isEmpty) return const _EmptyTab(icon: '🚌', message: 'No routes set up yet.');
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: routes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final r = routes[i];
        final studentCount = r['student_count'] ?? 0;
        final driverName = (r['driver_name'] as String?)?.trim();
        final helperName = (r['helper_name'] as String?)?.trim();
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r['name']?.toString() ?? 'Route',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
                  ),
                  if (r['dispatch_teacher_name'] != null)
                    const StatusBadge(label: 'Dispatch assigned', bg: AppColors.skyLight, fg: Color(0xFF0369A1)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  if ((r['vehicle_number'] as String?)?.isNotEmpty == true) r['vehicle_number'],
                  '$studentCount student${studentCount == 1 ? '' : 's'}',
                ].join(' · '),
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 4),
              Text(
                'Driver: ${driverName?.isNotEmpty == true ? driverName : '—'}   ·   Helper: ${helperName?.isNotEmpty == true ? helperName : '—'}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GpsTab extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles;
  const _GpsTab({required this.vehicles});

  @override
  State<_GpsTab> createState() => _GpsTabState();
}

class _GpsTabState extends State<_GpsTab> {
  String? _selectedRegNumber;

  @override
  Widget build(BuildContext context) {
    final vehicles = widget.vehicles;
    if (vehicles.isEmpty) return const _EmptyTab(icon: '📡', message: 'No vehicles added yet.');
    final hasAnyPosition = vehicles.any((v) => v['latitude'] != null && v['longitude'] != null);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // issue-4/10: the multi-bus live map -- this tab used to be a plain
        // list with no visual position at all.
        if (hasAnyPosition) ...[
          BusMap(vehicles: vehicles, selectedId: _selectedRegNumber),
          const SizedBox(height: 12),
        ],
        ...vehicles.map((v) {
        final isStale = v['is_stale'] == true;
        final hasFix = v['last_update'] != null;
        final regNumber = v['registration_number']?.toString();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
          onTap: hasFix ? () => setState(() => _selectedRegNumber = regNumber) : null,
          child: AppCard(
            child: Row(
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
          ),
          ),
        );
        }),
      ],
    );
  }
}

class _ExceptionsTab extends StatelessWidget {
  final List<dynamic> missed;
  final List<dynamic> pending;
  const _ExceptionsTab({required this.missed, required this.pending});

  @override
  Widget build(BuildContext context) {
    if (missed.isEmpty && pending.isEmpty) {
      return const _EmptyTab(icon: '✅', message: 'No missed or overdue pickups/drops today.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (missed.isNotEmpty) ...[
          const SectionHeader(title: 'MISSED'),
          ...missed.map((m) => _ExceptionRow(
                studentName: m['student_name']?.toString() ?? 'Student',
                routeName: m['route_name']?.toString(),
                label: (m['direction']?.toString() ?? '').toUpperCase(),
                badgeColor: AppColors.coral,
                badgeBg: AppColors.coralLight,
              )),
        ],
        if (pending.isNotEmpty) ...[
          const SectionHeader(title: 'PAST EXPECTED TIME'),
          ...pending.map((p) => _ExceptionRow(
                studentName: p['student_name']?.toString() ?? 'Student',
                routeName: p['route_name']?.toString(),
                label: (p['direction']?.toString() ?? '').toUpperCase(),
                badgeColor: const Color(0xFF92400E),
                badgeBg: AppColors.amberLight,
              )),
        ],
      ],
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
