import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/auth.dart';
import 'core/api.dart';
import 'core/branding.dart';
import 'core/device_context.dart';
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
  await DeviceContext.init();

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
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BrandingProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const EduTrackApp(),
    ),
  );
}

class EduTrackApp extends StatelessWidget {
  const EduTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    final branding = context.watch<BrandingProvider>();
    return MaterialApp(
      title: 'EduTrack Teacher',
      theme: buildTheme(branding.primaryColor),
      debugShowCheckedModeBanner: false,
      // Clamp system font scale to 1.2× max — prevents layout overflow on large
      // accessibility font settings while still allowing mild scaling.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(
              minScaleFactor: 1.0,
              maxScaleFactor: 1.2,
            ),
          ),
          child: child!,
        );
      },
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
  Timer? _inactivityTimer;
  AuthProvider? _authRef;
  bool _wasLoggedIn = false;
  static const _inactivityDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupFcm();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _authRef = context.read<AuthProvider>();
      _authRef!.addListener(_handleAuthChange);
      _handleAuthChange();
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _authRef?.removeListener(_handleAuthChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handleAuthChange() {
    if (!mounted || _authRef == null) return;
    final isLoggedIn = _authRef!.isLoggedIn;
    if (isLoggedIn && !_wasLoggedIn) {
      context.read<BrandingProvider>().load();
    } else if (!isLoggedIn && _wasLoggedIn) {
      context.read<BrandingProvider>().reset();
    }
    _wasLoggedIn = isLoggedIn;
    if (isLoggedIn && !_authRef!.isLocked) {
      _resetInactivityTimer();
    } else {
      _inactivityTimer?.cancel();
    }
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(_inactivityDuration, _onInactivity);
  }

  Future<void> _onInactivity() async {
    if (!mounted || _authRef == null) return;
    if (_authRef!.isLoggedIn && !_authRef!.isLocked && await _authRef!.isBiometricEnabled) {
      _authRef!.lockApp();
    }
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
    } else {
      // No lock screen to trigger the post-unlock refresh — do it directly
      // so a resume still counts as activity for the session's expiry.
      auth.refreshSession();
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
      final prefs = await SharedPreferences.getInstance();
      var deviceId = prefs.getString('push_device_id');
      if (deviceId == null) {
        deviceId = '${Platform.operatingSystem}_${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('push_device_id', deviceId);
      }
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
        backgroundColor: Theme.of(context).colorScheme.primary,
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
      return Scaffold(
        backgroundColor: const Color(0xFFFFF8F3),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎓', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
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

    final home = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInactivityTimer(),
      child: const HomeScreen(),
    );

    if (!auth.isLocked) return home;

    return Stack(
      children: [
        IgnorePointer(child: home),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(color: Colors.black.withOpacity(0.35)),
        ),
        const _BiometricLockScreen(),
      ],
    );
  }
}

// ── Biometric lock screen ─────────────────────────────────────────────────────

class _BiometricLockScreen extends StatefulWidget {
  const _BiometricLockScreen();

  @override
  State<_BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<_BiometricLockScreen> {
  String? _bioError;
  bool _bioLoading = false;

  // Password fallback state
  bool _showPassword = false;
  bool _obscure = true;
  bool _passLoading = false;
  String? _passError;
  int _failedAttempts = 0;
  bool _accountLocked = false;
  final _passCtrl = TextEditingController();

  static const _maxAttempts = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _triggerBiometric());
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _triggerBiometric() async {
    if (!mounted) return;
    setState(() { _bioLoading = true; _bioError = null; });
    final auth = context.read<AuthProvider>();
    final err = await auth.unlockApp();
    if (!mounted) return;
    if (err != null) {
      setState(() { _bioLoading = false; _bioError = err; });
    } else {
      setState(() => _bioLoading = false);
    }
  }

  Future<void> _submitPassword() async {
    if (_passCtrl.text.trim().isEmpty) return;
    setState(() { _passLoading = true; _passError = null; });
    final auth = context.read<AuthProvider>();
    final email = await auth.getStoredEmail() ?? '';
    try {
      final res = await ApiClient.login(email, _passCtrl.text.trim());
      await ApiClient.setToken(res.token);
      if (!mounted) return;
      auth.lockApp(); // triggers isLocked = false via unlockApp bypass
      // Directly unlock: set isLocked false then notify
      auth.forceUnlock();
    } on ApiError catch (e) {
      if (!mounted) return;
      final newCount = _failedAttempts + 1;
      if (newCount >= _maxAttempts) {
        // Lock the account on the backend
        try { await ApiClient.lockMyAccount(); } catch (_) {}
        setState(() { _passLoading = false; _accountLocked = true; _failedAttempts = newCount; });
      } else {
        setState(() {
          _passLoading = false;
          _failedAttempts = newCount;
          _passError = e.message.contains('locked')
              ? e.message
              : 'Incorrect password. ${_maxAttempts - newCount} attempt${_maxAttempts - newCount == 1 ? '' : 's'} remaining.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _passLoading = false; _passError = 'Something went wrong. Try again.'; });
    }
  }

  Future<void> _cancelToLogout() async {
    final auth = context.read<AuthProvider>();
    await auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(child: Text('🎓', style: TextStyle(fontSize: 38))),
                ),
                const SizedBox(height: 24),

                if (_accountLocked) ...[
                  // ── Account locked state ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDA4AF)),
                    ),
                    child: Column(
                      children: const [
                        Text('🔒', style: TextStyle(fontSize: 32)),
                        SizedBox(height: 10),
                        Text(
                          'Account Locked',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFBE123C)),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Too many incorrect attempts. Contact your admin to unlock your account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Color(0xFFBE123C), height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ] else if (_showPassword) ...[
                  // ── Password entry mode ───────────────────────────────
                  const Text(
                    'Enter your password',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1C1917)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_maxAttempts - _failedAttempts} attempt${_maxAttempts - _failedAttempts == 1 ? '' : 's'} remaining',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF78716C)),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    autofocus: true,
                    onSubmitted: (_) => _passLoading ? null : _submitPassword(),
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_passError != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDA4AF)),
                      ),
                      child: Text(
                        _passError!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFBE123C), fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _passLoading ? null : _submitPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _passLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Text('Login', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _passLoading ? null : _cancelToLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF78716C),
                        side: const BorderSide(color: Color(0xFFE7E5E4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Cancel (Logout)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ] else ...[
                  // ── Biometric unlock mode ─────────────────────────────
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
                  if (_bioError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFDA4AF)),
                      ),
                      child: Text(
                        _bioError!,
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
                      onPressed: _bioLoading ? null : _triggerBiometric,
                      icon: _bioLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : const Icon(Icons.fingerprint_rounded, size: 22),
                      label: Text(_bioLoading ? 'Verifying…' : 'Unlock'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => setState(() { _showPassword = true; _passCtrl.clear(); _passError = null; }),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF78716C),
                        side: const BorderSide(color: Color(0xFFE7E5E4)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Use Password Instead', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


