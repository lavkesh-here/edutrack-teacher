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
/// updates (previously snapped once on selection, then never again); nothing
/// selected centers on the coordinator's own location when available,
/// falling back to today's average-of-all-vehicles center otherwise -- never
/// a hard failure or a permission prompt just to view the map.
class BusMap extends StatefulWidget {
  final List<Map<String, dynamic>> vehicles; // each with latitude/longitude/registration_number/route_name/is_stale/ignition_on
  final String? selectedId; // registration_number of the selected vehicle, if any
  final double height;
  const BusMap({super.key, required this.vehicles, this.selectedId, this.height = 220});

  @override
  State<BusMap> createState() => _BusMapState();
}

class _BusMapState extends State<BusMap> {
  final MapController _controller = MapController();
  LatLng? _myLocation;

  List<Map<String, dynamic>> get _positioned =>
      widget.vehicles.where((v) => v['latitude'] != null && v['longitude'] != null).toList();

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
  }

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

  Map<String, dynamic>? _selectedFrom(List<Map<String, dynamic>> vehicles, String? id) {
    if (id == null) return null;
    for (final v in vehicles) {
      if (v['registration_number']?.toString() == id && v['latitude'] != null && v['longitude'] != null) return v;
    }
    return null;
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
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
            MarkerLayer(
              markers: positioned.map((v) {
                final isStale = v['is_stale'] == true;
                final ignitionOn = v['ignition_on'] as bool?;
                final isSelected = widget.selectedId != null && v['registration_number']?.toString() == widget.selectedId;
                final color = ignitionOn == false ? AppColors.muted : (isSelected ? AppColors.violet : AppColors.teal);
                return Marker(
                  point: LatLng((v['latitude'] as num).toDouble(), (v['longitude'] as num).toDouble()),
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
    );
  }
}
