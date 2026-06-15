import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/auth.dart';
import 'core/theme.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/force_change_password.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase: init + Crashlytics error capture
  // Requires google-services.json (Android) / GoogleService-Info.plist (iOS)
  // Download from Firebase Console → Project Settings → Your Apps
  try {
    await Firebase.initializeApp();
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (_) {
    // Firebase not configured yet — Crashlytics unavailable, app runs normally
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

class _Root extends StatelessWidget {
  const _Root();

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

    // Set Crashlytics user context when logged in
    if (auth.isLoggedIn && auth.user != null) {
      try {
        FirebaseCrashlytics.instance.setUserIdentifier('teacher_${auth.user!.teacherId}');
        FirebaseCrashlytics.instance.setCustomKey('role', auth.user!.role);
        FirebaseCrashlytics.instance.setCustomKey('school', auth.user!.schoolName);
      } catch (_) {}
    }

    return auth.isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
