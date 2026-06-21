import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/auth.dart';
import 'core/api.dart';
import 'core/theme.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/force_change_password.dart';
import 'screens/notifications_screen.dart';
import 'screens/leave.dart';

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Firebase not configured yet — app runs normally
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const EduTrackApp(),
    ),
  );
}

class EduTrackApp extends StatelessWidget {
  const EduTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduTrack Teacher',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (_) => const _Root(),
        '/force-change-password': (_) => const ForceChangePasswordScreen(),
      },
      home: const _Root(),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFcm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkAppLock();
    }
  }

  Future<void> _checkAppLock() async {
    if (_pausedAt == null || !mounted) return;
    final elapsed = DateTime.now().difference(_pausedAt!);
    _pausedAt = null;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    if (elapsed.inSeconds >= 60 && await auth.isBiometricEnabled) {
      auth.lockApp();
    }
  }

  Future<void> _setupFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token != null) await _registerToken(token);
      messaging.onTokenRefresh.listen(_registerToken);

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initial = await messaging.getInitialMessage();
      if (initial != null) _handleNotificationTap(initial);
    } catch (_) {
      // Firebase not configured; skip silently
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      final deviceId = '${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch ~/ 86400000}';
      await ApiClient.registerPushToken(token, deviceId);
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    if (!mounted || title.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: AppColors.sun,
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type'] as String? ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = Navigator.of(context);
      // Only navigate if user is logged in (HomeScreen is showing)
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) return;
      switch (type) {
        case 'leave_approved':
        case 'leave_rejected':
          nav.push(MaterialPageRoute(builder: (_) => const LeaveScreen()));
        default:
          nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFF8F3),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎓', style: TextStyle(fontSize: 48)),
              SizedBox(height: 16),
              CircularProgressIndicator(color: Color(0xFFF97316)),
            ],
          ),
        ),
      );
    }

    if (auth.isLoggedIn && auth.user != null) {
      try {
        FirebaseCrashlytics.instance.setUserIdentifier('teacher_${auth.user!.teacherId}');
        FirebaseCrashlytics.instance.setCustomKey('role', auth.user!.role);
        FirebaseCrashlytics.instance.setCustomKey('school', auth.user!.schoolName);
      } catch (_) {}
    }

    if (!auth.isLoggedIn) return const LoginScreen();
    if (auth.isLocked) return const _BiometricLockScreen();
    return const HomeScreen();
  }
}

// ── Biometric lock screen ─────────────────────────────────────────────────────

class _BiometricLockScreen extends StatefulWidget {
  const _BiometricLockScreen();

  @override
  State<_BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<_BiometricLockScreen> {
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    final auth = context.read<AuthProvider>();
    final err = await auth.unlockApp();
    if (!mounted) return;
    setState(() { _loading = false; _error = err; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F3),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(child: Text('🎓', style: TextStyle(fontSize: 38))),
                ),
                const SizedBox(height: 24),
                const Text(
                  'EduTrack is locked',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1C1917)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use your fingerprint or face to continue',
                  style: TextStyle(fontSize: 14, color: Color(0xFF78716C)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDA4AF)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFBE123C), fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _unlock,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.fingerprint_rounded, size: 22),
                    label: Text(_loading ? 'Verifying…' : 'Unlock'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF97316),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
