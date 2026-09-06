import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';

/// issue-4/10 (transport coordinator's GPS tab): a multi-bus live map, same
/// OpenStreetMap choice as the admin web GPS map and the parent app's
/// single-bus map -- no vendor API key needed anywhere in this project.
///
/// Brought to parity with the admin web map fix (same session): a real bus
/// icon instead of an emoji; ignition-off greys the marker independently of
/// the existing staleness signal (opacity), same two-signal split as web,
/// TR-008/TR-009; the selected bus is followed continuously as its position
/// updates (previously snapped once on selection, then never again), and
/// already auto-zooms to 15 on selection (TR-013) -- nothing selected
/// centers on the coordinator's own location when available, falling back
/// to today's average-of-all-vehicles center otherwise -- never a hard
/// failure or a permission prompt just to view the map.
///
/// TR-014 Decision C (2026-09-06): two more additions, both purely visual --
/// (1) each marker glides smoothly between consecutive position updates
/// instead of snapping instantly (a hand-rolled per-vehicle tween, since
/// flutter_map's MarkerLayer positions markers from a fixed `point` with no
/// built-in animation, and adding a new marker-animation package was judged
/// unnecessary for this); (2) an optional route polyline for the selected
/// vehicle, fed by the new /vehicles/{id}/route-path endpoint -- drawn only
/// for the selected bus (not all of them at once) to avoid cluttering a
/// multi-bus view.
class BusMap extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles; // each with latitude/longitude/registration_number/route_name/is_stale/ignition_on
  final String? selectedId; // registration_number of the selected vehicle, if any
  final List<LatLng>? routePath; // the selected vehicle's road-snapped path, if loaded
  final double height;
  final bool fullscreenEnabled;
  const BusMap({
    super.key, required this.vehicles, this.selectedId, this.routePath,
    this.height = 220, this.fullscreenEnabled = true,
  });

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> with SingleTickerProviderStateMixin {
  final MapController _controller = MapController();
  LatLng? _myLocation;

  // Glide animation state: for each vehicle key, the last two known
  // positions and one shared clock driving every vehicle's tween at once --
  // simplest correct approach for a handful of buses, no per-vehicle
  // AnimationController churn.
  late final AnimationController _glide = AnimationController(vsync: this, duration: const Duration(seconds: 3));
  final Map<String, LatLng> _glideFrom = {};
  final Map<String, LatLng> _glideTo = {};

  List<Map<String, dynamic>> get _positioned =>
      widget.vehicles.where((v) => v['latitude'] != null && v['longitude'] != null).toList();

  String _keyOf(Map<String, dynamic> v) => (v['id'] ?? v['registration_number']).toString();

  Map<String, dynamic>? _selected(List<Map<String, dynamic>> positioned) {
    if (widget.selectedId == null) return null;
    for (final v in positioned) {
      if (v['registration_number']?.toString() == widget.selectedId) return v;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedId == null) _tryLocateSelf();
    for (final v in _positioned) {
      final p = LatLng((v['latitude'] as num).toDouble(), (v['longitude'] as num).toDouble());
      _glideFrom[_keyOf(v)] = p;
      _glideTo[_keyOf(v)] = p;
    }
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  LatLng _lerp(LatLng a, LatLng b, double t) =>
      LatLng(a.latitude + (b.latitude - a.latitude) * t, a.longitude + (b.longitude - a.longitude) * t);

  // Silent, best-effort only -- never prompts for permission just to pick a
  // default map center. If it's already granted, use it; otherwise leave
  // _myLocation null and the average-of-all-vehicles center (below) covers
  // it, same graceful-degradation principle as the web fix.
  Future<void> _tryLocateSelf() async {
    final permission = await Geolocator.checkPermission();
    final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    if (!granted) return;
    if (!await Geolocator.isLocationServiceEnabled()) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (mounted && widget.selectedId == null) {
        setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
        _controller.move(_myLocation!, 13);
      }
    } catch (_) {
      // No GPS fix, timeout, etc. -- stay on the average-of-all-vehicles center.
    }
  }

  @override
  void didUpdateWidget(covariant BusMap old) {
    super.didUpdateWidget(old);

    // Start a fresh glide for every vehicle whose position actually moved.
    bool anyMoved = false;
    for (final v in _positioned) {
      final key = _keyOf(v);
      final newPos = LatLng((v['latitude'] as num).toDouble(), (v['longitude'] as num).toDouble());
      final currentTarget = _glideTo[key];
      if (currentTarget == null) {
        _glideFrom[key] = newPos;
        _glideTo[key] = newPos;
      } else if (currentTarget != newPos) {
        // Animate from wherever the glide currently is (not necessarily the
        // old target, if a tick arrived mid-animation) so a fast tick cadence
        // never looks like it snaps back before gliding again.
        _glideFrom[key] = _displayedPosition(key, currentTarget);
        _glideTo[key] = newPos;
        anyMoved = true;
      }
    }
    if (anyMoved) {
      _glide
        ..reset()
        ..forward();
    }

    final positioned = _positioned;
    final selected = _selected(positioned);
    final oldSelected = widget.selectedId == old.selectedId
        ? _selectedFrom(old.vehicles, old.selectedId)
        : null;

    if (widget.selectedId != null && selected != null) {
      final samePosition = oldSelected != null &&
          oldSelected['latitude'] == selected['latitude'] &&
          oldSelected['longitude'] == selected['longitude'];
      // Follow: re-center both on first selection AND on every subsequent
      // position update for the same selected bus -- previously this only
      // fired once, on selectedId changing, so a coordinator watching one
      // live bus never actually saw the map track it as new data arrived.
      if (widget.selectedId != old.selectedId || !samePosition) {
        _controller.move(
          LatLng((selected['latitude'] as num).toDouble(), (selected['longitude'] as num).toDouble()),
          15,
        );
      }
    } else if (widget.selectedId == null && old.selectedId != null) {
      // Just deselected -- prefer the coordinator's own location if already
      // resolved, otherwise fall back to fitting all vehicles.
      if (_myLocation != null) {
        _controller.move(_myLocation!, 13);
      } else {
        _tryLocateSelf();
      }
    }
  }

  LatLng _displayedPosition(String key, LatLng fallback) {
    final from = _glideFrom[key];
    final to = _glideTo[key];
    if (from == null || to == null) return fallback;
    final eased = Curves.easeInOut.transform(_glide.value);
    return _lerp(from, to, eased);
  }

  Map<String, dynamic>? _selectedFrom(List<Map<String, dynamic>> vehicles, String? id) {
    if (id == null) return null;
    for (final v in vehicles) {
      if (v['registration_number']?.toString() == id && v['latitude'] != null && v['longitude'] != null) return v;
    }
    return null;
  }

  void _openFullscreen() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenBusMap(
      vehicles: widget.vehicles, selectedId: widget.selectedId, routePath: widget.routePath,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final positioned = _positioned;
    if (positioned.isEmpty) {
      return Container(
        height: widget.height,
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.center,
        child: const Text('No vehicle has reported a position yet', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      );
    }

    final points = positioned
        .map((v) => LatLng((v['latitude'] as num).toDouble(), (v['longitude'] as num).toDouble()))
        .toList();
    // Nothing selected and no resolved self-location yet: average of every
    // vehicle is still the right first-paint default (matches prior
    // behavior) -- _tryLocateSelf() upgrades this the moment it resolves.
    final center = widget.selectedId == null && _myLocation != null
        ? _myLocation!
        : points.length == 1
            ? points.first
            : LatLng(
                points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
                points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length,
              );

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: widget.height,
            child: AnimatedBuilder(
              animation: _glide,
              builder: (context, _) => FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: points.length == 1 ? 15 : 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.edutrack.teacher',
                  ),
                  if (widget.routePath != null && widget.routePath!.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(points: widget.routePath!, strokeWidth: 4, color: AppColors.violet.withOpacity(0.6)),
                    ]),
                  MarkerLayer(
                    markers: positioned.map((v) {
                      final key = _keyOf(v);
                      final rawPos = LatLng((v['latitude'] as num).toDouble(), (v['longitude'] as num).toDouble());
                      final displayed = _displayedPosition(key, rawPos);
                      final isStale = v['is_stale'] == true;
                      final ignitionOn = v['ignition_on'] as bool?;
                      final isSelected = widget.selectedId != null && v['registration_number']?.toString() == widget.selectedId;
                      final color = ignitionOn == false ? AppColors.muted : (isSelected ? AppColors.violet : AppColors.teal);
                      return Marker(
                        point: displayed,
                        width: isSelected ? 44 : 34,
                        height: isSelected ? 44 : 34,
                        child: Opacity(
                          opacity: isStale ? 0.55 : 1,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.directions_bus, color: Colors.white, size: isSelected ? 22 : 16),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  RichAttributionWidget(
                    attributions: [TextSourceAttribution('OpenStreetMap contributors', onTap: () {})],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.fullscreenEnabled)
          Positioned(
            right: 8, top: 8,
            child: GestureDetector(
              onTap: _openFullscreen,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: const Icon(Icons.fullscreen, size: 20, color: AppColors.text),
              ),
            ),
          ),
      ],
    );
  }
}

/// TR-014 Decision C: fullscreen view, reusing BusMap itself (fullscreenEnabled:
/// false to avoid a recursive fullscreen button) rather than duplicating the
/// map-rendering logic.
class FullscreenBusMap extends StatelessWidget {
  final List<Map<String, dynamic>> vehicles;
  final String? selectedId;
  final List<LatLng>? routePath;
  const FullscreenBusMap({super.key, required this.vehicles, this.selectedId, this.routePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Live Map', style: TextStyle(color: Colors.white)),
      ),
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: BusMap(
          vehicles: vehicles, selectedId: selectedId, routePath: routePath,
          height: MediaQuery.of(context).size.height, fullscreenEnabled: false,
        ),
      ),
    );
  }
}
