import 'dart:math' as math;
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
  // TR-016: tapping a bus marker directly on the map selects it, same as tapping
  // its card in the list below -- null (FullscreenBusMap's own default) means
  // the map manages selection locally instead of deferring to a parent.
  final void Function(String registrationNumber)? onVehicleTap;
  const BusMap({
    super.key, required this.vehicles, this.selectedId, this.routePath,
    this.height = 220, this.fullscreenEnabled = true, this.onVehicleTap,
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

  // TR-017: explicit, user-initiated recenter -- unlike _tryLocateSelf (silent,
  // never prompts), this is a deliberate button press so prompting for
  // permission here is appropriate.
  Future<void> _recenterOnMe() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    final granted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    final serviceEnabled = granted && await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!granted || !serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location unavailable -- check permission and GPS')),
      );
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      if (!mounted) return;
      setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
      _controller.move(_myLocation!, 13);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your location')),
        );
      }
    }
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
                    markers: [
                      ...positioned.map((v) {
                      final key = _keyOf(v);
                      final rawPos = LatLng((v['latitude'] as num).toDouble(), (v['longitude'] as num).toDouble());
                      final displayed = _displayedPosition(key, rawPos);
                      final isStale = v['is_stale'] == true;
                      final ignitionOn = v['ignition_on'] as bool?;
                      final regNumber = v['registration_number']?.toString();
                      final isSelected = widget.selectedId != null && regNumber == widget.selectedId;
                      final color = ignitionOn == false ? AppColors.muted : (isSelected ? AppColors.violet : AppColors.teal);
                      final heading = (v['heading_deg'] as num?)?.toDouble();
                      final size = isSelected ? 34.0 : 26.0;
                      return Marker(
                        point: displayed,
                        width: size, height: size,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: regNumber == null ? null : () => widget.onVehicleTap?.call(regNumber),
                          child: Opacity(
                            opacity: isStale ? 0.55 : 1,
                            child: BusGlyph(color: color, headingDeg: heading, size: size),
                          ),
                        ),
                      );
                    }),
                      if (_myLocation != null)
                        Marker(
                          point: _myLocation!,
                          width: 18, height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.sky,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                            ),
                          ),
                        ),
                    ],
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
        Positioned(
          right: 8, top: widget.fullscreenEnabled ? 44 : 8,
          child: GestureDetector(
            onTap: _recenterOnMe,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]),
              child: const Icon(Icons.my_location, size: 20, color: AppColors.text),
            ),
          ),
        ),
      ],
    );
  }
}

/// Live-verified feedback (2026-09-06): "use a proper bus image, like a car
/// image on Google Maps" -- replaces the old plain circle-with-a-generic-
/// icon marker with a small drawn bus silhouette (body + windshield +
/// headlights) that rotates to face the vehicle's actual heading, the same
/// way Google Maps' own car marker turns to face the direction of travel.
/// Still a vector drawing (CustomPainter), not a bitmap asset -- no new
/// asset pipeline/licensing question, same reasoning as the rest of this
/// file's deliberately-lightweight map layer. `headingDeg` is null for a
/// vehicle with no recent fix; the glyph then stays upright (north) rather
/// than guessing a direction with no data behind it.
class BusGlyph extends StatelessWidget {
  final Color color;
  final double? headingDeg;
  final double size;
  const BusGlyph({super.key, required this.color, required this.headingDeg, required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: (headingDeg ?? 0) * math.pi / 180,
      child: CustomPaint(
        size: Size(size, size),
        painter: _BusGlyphPainter(color: color),
      ),
    );
  }
}

class _BusGlyphPainter extends CustomPainter {
  final Color color;
  const _BusGlyphPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.06, w * 0.56, h * 0.88),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(body, Paint()..color = Colors.black26..style = PaintingStyle.fill);
    canvas.drawRRect(
      body.shift(const Offset(0, -1)),
      Paint()..color = color..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      body.shift(const Offset(0, -1)),
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = w * 0.045,
    );
    // Windshield -- the "front" of the bus, at the top (north) before rotation.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.30, h * 0.12, w * 0.40, h * 0.16),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = Colors.white.withOpacity(0.85),
    );
    // Two headlights at the front corners.
    final headlightPaint = Paint()..color = const Color(0xFFFFE58A);
    canvas.drawCircle(Offset(w * 0.30, h * 0.10), w * 0.045, headlightPaint);
    canvas.drawCircle(Offset(w * 0.70, h * 0.10), w * 0.045, headlightPaint);
  }

  @override
  bool shouldRepaint(covariant _BusGlyphPainter old) => old.color != color;
}

/// TR-014 Decision C: fullscreen view, reusing BusMap itself (fullscreenEnabled:
/// false to avoid a recursive fullscreen button) rather than duplicating the
/// map-rendering logic.
///
/// TR-016: stateful so a marker tap here can select/zoom locally -- this view
/// has no parent tab to report a selection back to, unlike the inline BusMap.
class FullscreenBusMap extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles;
  final String? selectedId;
  final List<LatLng>? routePath;
  const FullscreenBusMap({super.key, required this.vehicles, this.selectedId, this.routePath});

  @override
  State<FullscreenBusMap> createState() => _FullscreenBusMapState();
}

class _FullscreenBusMapState extends State<FullscreenBusMap> {
  late String? _selectedId = widget.selectedId;

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
          vehicles: widget.vehicles, selectedId: _selectedId,
          // A different vehicle selected in here has no fetched route path of
          // its own to show -- avoid drawing the original selection's path
          // against a now-different bus.
          routePath: _selectedId == widget.selectedId ? widget.routePath : null,
          height: MediaQuery.of(context).size.height, fullscreenEnabled: false,
          onVehicleTap: (reg) => setState(() => _selectedId = reg),
        ),
      ),
    );
  }
}
