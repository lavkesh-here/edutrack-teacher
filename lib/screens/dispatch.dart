import 'package:flutter/material.dart';
import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// EDR-0020: a teacher assigned bus-dispatch responsibility for a route
/// (school off-time duty, not a role) opens this from the More tab, picks
/// their route if they have more than one, then works through the same
/// dispatch workflow the Admin Transport dashboard offers — scoped by the
/// backend to only the route(s) they're actually assigned to.

class DispatchListScreen extends StatefulWidget {
  const DispatchListScreen({super.key});

  @override
  State<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends State<DispatchListScreen> {
  List<Map<String, dynamic>> _routes = [];
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
      final routes = await ApiClient.getMyDispatchRoutes();
      if (mounted) setState(() { _routes = routes; _loading = false; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load your dispatch routes.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Bus Dispatch',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _load)
                : _routes.isEmpty
                    ? const _NoResponsibility()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _routes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _RouteCard(
                          route: _routes[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DispatchDetailScreen(route: _routes[i])),
                          ),
                        ),
                      ),
      ),
    );
  }
}

class _NoResponsibility extends StatelessWidget {
  const _NoResponsibility();

  @override
  Widget build(BuildContext context) => ListView(
        children: const [
          SizedBox(height: 80),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text('🚌', style: TextStyle(fontSize: 56)),
                  SizedBox(height: 16),
                  Text('No Dispatch Responsibility',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
                  SizedBox(height: 8),
                  Text(
                    "You're not currently assigned to operate any bus route's dispatch. "
                    'An admin assigns this per route when needed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.coral)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ],
      );
}

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final VoidCallback onTap;
  const _RouteCard({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final studentCount = route['student_count'] ?? 0;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: context.primaryLight, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: const Text('🚌', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(route['name']?.toString() ?? 'Route',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(
                  [
                    if ((route['vehicle_number'] as String?)?.isNotEmpty == true) route['vehicle_number'],
                    '$studentCount student${studentCount == 1 ? '' : 's'}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

// ── Detail screen ────────────────────────────────────────────────────────────

class DispatchDetailScreen extends StatefulWidget {
  final Map<String, dynamic> route;
  const DispatchDetailScreen({super.key, required this.route});

  @override
  State<DispatchDetailScreen> createState() => _DispatchDetailScreenState();
}

class _DispatchDetailScreenState extends State<DispatchDetailScreen> {
  String _direction = 'pickup'; // 'pickup' | 'drop'
  Map<String, dynamic>? _status; // dispatch-status response (both directions + gps + staff)
  List<Map<String, dynamic>> _students = [];
  final Map<String, String> _pendingBoarding = {}; // student_id -> chosen status this session
  final Map<String, String> _pendingReasons = {}; // student_id -> correction reason, only when required
  bool _loadingStatus = true;
  bool _loadingStudents = true;
  bool _saving = false;
  String? _error;

  String get _routeId => widget.route['id'].toString();

  @override
  void initState() {
    super.initState();
    _loadStatus();
    _loadStudents();
  }

  Future<void> _loadStatus() async {
    setState(() => _loadingStatus = true);
    try {
      final data = await ApiClient.getDispatchStatus(_routeId);
      if (mounted) setState(() { _status = data; _loadingStatus = false; _error = null; });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loadingStatus = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load dispatch status.'; _loadingStatus = false; });
    }
  }

  Future<void> _loadStudents() async {
    setState(() => _loadingStudents = true);
    try {
      final data = await ApiClient.getDispatchRouteStudents(_routeId, direction: _direction);
      if (mounted) setState(() { _students = data; _loadingStudents = false; _pendingBoarding.clear(); _pendingReasons.clear(); });
    } on ApiError catch (e) {
      if (mounted) setState(() { _error = e.message; _loadingStudents = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load the student roster.'; _loadingStudents = false; });
    }
  }

  void _switchDirection(String d) {
    if (d == _direction) return;
    setState(() => _direction = d);
    _loadStudents();
  }

  /// Mirrors the backend's own validate_transition() (app/services/
  /// transport_events.py): a status change away from an already-recorded,
  /// non-pending status requires a correction_reason -- except re-confirming
  /// the same status, or the missed->completed "picked up after all" case.
  /// Without this check, tapping a different status for an already-recorded
  /// student silently failed on save with no way to explain why (this was
  /// the "Saved with 1 issue - check the roster" bug: the mobile UI had no
  /// path to supply a reason at all, so every real correction failed).
  bool _statusChangeNeedsReason(String serverStatus, String newStatus) {
    if (serverStatus == 'pending') return false;
    if (serverStatus == newStatus) return false;
    if (serverStatus == 'missed' && newStatus == 'completed') return false;
    return true;
  }

  Future<void> _setBoardingStatus(String studentId, String serverStatus, String newStatus) async {
    if (!_statusChangeNeedsReason(serverStatus, newStatus)) {
      setState(() {
        _pendingBoarding[studentId] = newStatus;
        _pendingReasons.remove(studentId);
      });
      return;
    }
    final reason = await _promptForCorrectionReason(context, from: serverStatus, to: newStatus);
    if (reason == null) return; // cancelled -- leave the student's status untouched
    setState(() {
      _pendingBoarding[studentId] = newStatus;
      _pendingReasons[studentId] = reason;
    });
  }

  Future<String?> _promptForCorrectionReason(BuildContext context, {required String from, required String to}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reason for correction'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This student is already marked "$from" -- changing it to "$to" needs a short reason.',
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 200,
              decoration: const InputDecoration(hintText: 'e.g. marked by mistake, parent confirmed pickup'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _markStaffAttendance(String transportStaffId, String status) async {
    try {
      await ApiClient.recordDispatchStaffAttendance(_routeId, transportStaffId: transportStaffId, status: status);
      await _loadStatus();
    } on ApiError catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Could not save attendance.', isError: true);
    }
  }

  Future<void> _recordTripEvent(String eventType) async {
    try {
      await ApiClient.recordDispatchTripEvent(_routeId, direction: _direction, eventType: eventType);
      await _loadStatus();
      if (mounted) _showSnack('Trip marked $eventType.');
    } on ApiError catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Could not update trip status.', isError: true);
    }
  }

  Future<void> _saveBoardingAttendance() async {
    if (_pendingBoarding.isEmpty) return;
    setState(() => _saving = true);
    try {
      final result = await ApiClient.recordDispatchRouteEventsBatch(
        _routeId, direction: _direction, statusByStudentId: _pendingBoarding,
        reasonByStudentId: _pendingReasons,
      );
      final results = (result['results'] as List<dynamic>? ?? []);
      final failed = results.where((r) => (r as Map)['ok'] != true).length;
      if (mounted) {
        _showSnack(
          failed == 0
              ? 'Attendance saved for ${results.length} student${results.length == 1 ? '' : 's'}.'
              : 'Saved with $failed issue${failed == 1 ? '' : 's'} — check the roster.',
          isError: failed > 0,
        );
      }
      await _loadStudents();
    } on ApiError catch (e) {
      _showSnack(e.message, isError: true);
    } catch (_) {
      _showSnack('Could not save attendance.', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? AppColors.coral : AppColors.teal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => Navigator.pop(context)),
        title: Text(widget.route['name']?.toString() ?? 'Dispatch',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.wait([_loadStatus(), _loadStudents()]),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _DirectionToggle(direction: _direction, onChanged: _switchDirection),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(_error!, style: const TextStyle(color: AppColors.coral, fontSize: 13)),
              ),
            _loadingStatus
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                : _StatusSection(
                    status: _status,
                    direction: _direction,
                    route: widget.route,
                    onMarkStaff: _markStaffAttendance,
                    onTripEvent: _recordTripEvent,
                  ),
            const SectionHeader(title: 'STUDENTS'),
            _loadingStudents
                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                : _students.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('No students are assigned to this route.', style: TextStyle(color: AppColors.muted)),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: _students.map((s) {
                            final studentId = s['student_id'].toString();
                            final serverStatus = s['status']?.toString() ?? 'pending';
                            final chosen = _pendingBoarding[studentId] ?? serverStatus;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _StudentRow(
                                student: s,
                                current: chosen,
                                onSet: (status) => _setBoardingStatus(studentId, serverStatus, status),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
            if (_pendingBoarding.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _saveBoardingAttendance,
                    child: _saving
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Save Attendance (${_pendingBoarding.length})'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DirectionToggle extends StatelessWidget {
  final String direction;
  final ValueChanged<String> onChanged;
  const _DirectionToggle({required this.direction, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(child: _ToggleTab(label: '🌅 Pickup', selected: direction == 'pickup', onTap: () => onChanged('pickup'))),
            Expanded(child: _ToggleTab(label: '🌆 Drop', selected: direction == 'drop', onTap: () => onChanged('drop'))),
          ],
        ),
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : null,
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? AppColors.text : AppColors.muted)),
        ),
      );
}

class _StatusSection extends StatelessWidget {
  final Map<String, dynamic>? status;
  final String direction;
  final Map<String, dynamic> route;
  final void Function(String transportStaffId, String status) onMarkStaff;
  final void Function(String eventType) onTripEvent;

  const _StatusSection({
    required this.status, required this.direction, required this.route,
    required this.onMarkStaff, required this.onTripEvent,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    final tripLog = (status!['trip_log'] as Map<String, dynamic>?) ?? {};
    final currentTrip = tripLog[direction] as Map<String, dynamic>?;
    final gps = status!['gps'] as Map<String, dynamic>?;
    final staffAttendance = (status!['staff_attendance'] as Map<String, dynamic>?) ?? {};

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (gps != null) _GpsCard(gps: gps),
          if (gps != null) const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('TRIP STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.6)),
                    const Spacer(),
                    _tripBadge(currentTrip?['event_type']?.toString()),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => onTripEvent('dispatched'), child: const Text('Dispatch'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(onPressed: () => onTripEvent('completed'), child: const Text('Complete'))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.coral, side: const BorderSide(color: AppColors.coral)),
                      onPressed: () => onTripEvent('cancelled'), child: const Text('Cancel'),
                    )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DRIVER & HELPER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.muted, letterSpacing: 0.6)),
                const SizedBox(height: 12),
                if (route['driver_id'] != null)
                  _StaffRow(
                    label: '🚗 Driver', name: route['driver_name']?.toString() ?? 'Driver',
                    status: staffAttendance['driver']?.toString(),
                    onMark: (s) => onMarkStaff(route['driver_id'].toString(), s),
                  )
                else
                  const Text('No driver linked to this route.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                if (route['helper_id'] != null) ...[
                  const SizedBox(height: 10),
                  _StaffRow(
                    label: '🧑‍🤝‍🧑 Helper', name: route['helper_name']?.toString() ?? 'Helper',
                    status: staffAttendance['helper']?.toString(),
                    onMark: (s) => onMarkStaff(route['helper_id'].toString(), s),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripBadge(String? eventType) {
    switch (eventType) {
      case 'dispatched':
        return const StatusBadge(label: 'Dispatched', bg: AppColors.skyLight, fg: Color(0xFF0369A1));
      case 'completed':
        return const StatusBadge(label: 'Completed', bg: AppColors.greenLight, fg: Color(0xFF15803D));
      case 'cancelled':
        return const StatusBadge(label: 'Cancelled', bg: AppColors.coralLight, fg: Color(0xFFBE123C));
      default:
        return const StatusBadge(label: 'Not Started', bg: Color(0xFFF3F4F6), fg: Color(0xFF6B7280));
    }
  }
}

class _StaffRow extends StatelessWidget {
  final String label;
  final String name;
  final String? status;
  final ValueChanged<String> onMark;
  const _StaffRow({required this.label, required this.name, required this.status, required this.onMark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
            ],
          ),
        ),
        _MiniToggle(label: 'Present', selected: status == 'present', color: AppColors.green, onTap: () => onMark('present')),
        const SizedBox(width: 6),
        _MiniToggle(label: 'Absent', selected: status == 'absent', color: AppColors.coral, onTap: () => onMark('absent')),
      ],
    );
  }
}

class _MiniToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _MiniToggle({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8),
            border: selected ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? color : AppColors.muted)),
        ),
      );
}

class _GpsCard extends StatelessWidget {
  final Map<String, dynamic> gps;
  const _GpsCard({required this.gps});

  @override
  Widget build(BuildContext context) {
    final isStale = gps['is_stale'] == true;
    final hasFix = gps['last_update'] != null;
    final speed = gps['speed_kmh'];
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: !hasFix ? const Color(0xFFF3F4F6) : (isStale ? AppColors.amberLight : AppColors.greenLight),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(!hasFix ? '📡' : (isStale ? '⏱️' : '🟢'), style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gps['registration_number']?.toString() ?? 'Vehicle',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text(
                  !hasFix
                      ? 'No GPS signal yet'
                      : isStale
                          ? 'Last seen a while ago — signal may be stale'
                          : 'Live · ${speed ?? 0} km/h',
                  style: TextStyle(fontSize: 12, color: !hasFix ? AppColors.muted : (isStale ? const Color(0xFF92400E) : AppColors.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final Map<String, dynamic> student;
  final String current;
  final ValueChanged<String> onSet;
  const _StudentRow({required this.student, required this.current, required this.onSet});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['student_name']?.toString() ?? 'Student',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.text)),
                if ((student['stop_name'] as String?)?.isNotEmpty == true)
                  Text(student['stop_name'].toString(), style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          _MiniToggle(label: 'Present', selected: current == 'completed', color: AppColors.green, onTap: () => onSet('completed')),
          const SizedBox(width: 6),
          _MiniToggle(label: 'Absent', selected: current == 'missed', color: AppColors.coral, onTap: () => onSet('missed')),
        ],
      ),
    );
  }
}
