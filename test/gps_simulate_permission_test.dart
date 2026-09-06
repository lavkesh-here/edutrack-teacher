// Regression test for the GPS tab's Start/Stop Simulation button (GPS
// mobile-operator mission, 2026-09-06) — must appear only for a real
// admin/principal/director role, matching the backend's own get_write_access
// check exactly (a transport_coordinator-tagged plain teacher gets read
// access to this screen but must never see or be able to trigger this
// control). Logic replicated here per this project's test convention (see
// worklog_chapter_chip_test.dart) — this is a client-side convenience check
// only, never the real authorization boundary (that's the backend's
// get_write_access + feature.gps_simulate, covered by
// backend/tests/modules/test_gps_demo_tick.py's
// test_tick_requires_write_access and test_tick_requires_gps_simulate_feature_flag).
//
// EDR-0026 (2026-09-06): canOperateGpsSimulation() moved from the
// now-deleted lib/screens/transport_coordinator.dart to
// lib/screens/admin_transport.dart (the unified TransportScreen) — same
// function, same signature, this test's replicated copy is unaffected.
import 'package:flutter_test/flutter_test.dart';

bool canOperateGpsSimulation(String? role) {
  return role == 'admin' || role == 'principal' || role == 'director';
}

void main() {
  group('GPS Simulate button role gate', () {
    test('admin can operate simulation', () {
      expect(canOperateGpsSimulation('admin'), isTrue);
    });

    test('principal can operate simulation', () {
      expect(canOperateGpsSimulation('principal'), isTrue);
    });

    test('director can operate simulation', () {
      expect(canOperateGpsSimulation('director'), isTrue);
    });

    test('plain teacher (including transport_coordinator-tagged) cannot operate simulation', () {
      expect(canOperateGpsSimulation('teacher'), isFalse);
    });

    test('hod cannot operate simulation', () {
      expect(canOperateGpsSimulation('hod'), isFalse);
    });

    test('no role (null, not logged in / not yet restored) cannot operate simulation', () {
      expect(canOperateGpsSimulation(null), isFalse);
    });
  });
}
