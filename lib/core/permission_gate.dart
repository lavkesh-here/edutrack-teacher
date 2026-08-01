import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../screens/permissions_screen.dart';

/// The only permissions this app actually asks for at runtime — keep this
/// list honest. Camera is never used (image picking always goes through the
/// OS's photo picker, which needs no runtime grant on modern Android/iOS),
/// so it's deliberately not listed here or on the Permissions screen.
enum AppPermission { location, notifications }

Permission _toPlatformPermission(AppPermission p) => switch (p) {
      AppPermission.location => Permission.locationWhenInUse,
      AppPermission.notifications => Permission.notification,
    };

String appPermissionLabel(AppPermission p) => switch (p) {
      AppPermission.location => 'Location',
      AppPermission.notifications => 'Notifications',
    };

String appPermissionRationale(AppPermission p) => switch (p) {
      AppPermission.location =>
        'Used to confirm you\'re on campus when you mark your own attendance.',
      AppPermission.notifications =>
        'Used to alert you about homework due dates, follow-ups, and school announcements.',
    };

/// Ensures [permission] is granted before a gated action runs. Shows a short
/// rationale, then triggers the native OS prompt if it's still askable. If
/// the user already said no permanently, this redirects to the in-app
/// Permissions screen (which has the "Open App Settings" escape hatch)
/// instead of leaving the user stuck with no way to fix it inside the app.
///
/// Returns true only if the permission ends up granted.
Future<bool> ensurePermission(BuildContext context, AppPermission permission) async {
  final platformPermission = _toPlatformPermission(permission);
  var status = await platformPermission.status;

  if (status.isGranted) return true;

  if (status.isPermanentlyDenied || status.isRestricted) {
    if (!context.mounted) return false;
    await _showRedirectToSettingsDialog(context, permission);
    return false;
  }

  if (!context.mounted) return false;
  final proceed = await _showRationaleDialog(context, permission);
  if (!proceed) return false;

  status = await platformPermission.request();
  return status.isGranted;
}

/// Location has a second, independent gate on top of the app-level
/// permission: the device's location *service* (GPS) can be off entirely.
/// An app can never flip that toggle for the user — the best it can do is
/// deep-link straight to the OS location-settings screen, which is what
/// this does. Once location services are on and the app permission is
/// granted, no further action is needed outside the app.
Future<bool> ensureLocationReady(BuildContext context) async {
  if (!await ensurePermission(context, AppPermission.location)) return false;

  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (serviceEnabled) return true;

  if (!context.mounted) return false;
  final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Turn on Location'),
          content: const Text(
            'Location services are off on your phone. Turn them on to continue — '
            'no further steps needed in the app after that.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Open Settings')),
          ],
        ),
      ) ??
      false;
  if (openSettings) await Geolocator.openLocationSettings();
  return false;
}

Future<bool> _showRationaleDialog(BuildContext context, AppPermission permission) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${appPermissionLabel(permission)} access needed'),
          content: Text(appPermissionRationale(permission)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continue')),
          ],
        ),
      ) ??
      false;
}

Future<void> _showRedirectToSettingsDialog(BuildContext context, AppPermission permission) async {
  final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${appPermissionLabel(permission)} is turned off'),
          content: Text(
            '${appPermissionRationale(permission)}\n\nYou previously denied this. '
            'Enable it from the Permissions page to use this feature.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Go to Permissions')),
          ],
        ),
      ) ??
      false;
  if (open && context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PermissionsScreen()));
  }
}
