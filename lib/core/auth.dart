import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

const _secure = FlutterSecureStorage();
const _kBioEmail = 'bio_email';
const _kBioPass  = 'bio_password';
const _kBioEnabled = 'bio_enabled';

class AuthUser {
  final String teacherName;
  final String schoolName;
  final String role;
  final int teacherId;
  final String? email;
  final String? phone;
  final String? photoUrl;

  const AuthUser({
    required this.teacherName,
    required this.schoolName,
    required this.role,
    required this.teacherId,
    this.email,
    this.phone,
    this.photoUrl,
  });
}

class AuthProvider extends ChangeNotifier {
  AuthUser? _user;
  bool _loading = true;

  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;

  // ── Biometric ──────────────────────────────────────────────────────────────
  final _localAuth = LocalAuthentication();

  Future<bool> get isBiometricAvailable async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) { return false; }
  }

  Future<bool> get isBiometricEnabled async =>
      (await SharedPreferences.getInstance()).getBool(_kBioEnabled) ?? false;

  Future<void> enableBiometric(String email, String password) async {
    await _secure.write(key: _kBioEmail, value: email);
    await _secure.write(key: _kBioPass,  value: password);
    (await SharedPreferences.getInstance()).setBool(_kBioEnabled, true);
  }

  Future<void> disableBiometric() async {
    await _secure.delete(key: _kBioEmail);
    await _secure.delete(key: _kBioPass);
    (await SharedPreferences.getInstance()).setBool(_kBioEnabled, false);
  }

  /// Authenticates with biometric and re-logs in with stored credentials.
  /// Returns null on success, error message on failure.
  Future<String?> biometricLogin() async {
    try {
      final authed = await _localAuth.authenticate(
        localizedReason: 'Unlock EduTrack',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (!authed) return 'Biometric authentication cancelled.';

      final email    = await _secure.read(key: _kBioEmail);
      final password = await _secure.read(key: _kBioPass);
      if (email == null || password == null) return 'Stored credentials missing.';

      await login(email, password);
      return null;
    } catch (e) {
      return 'Biometric error: $e';
    }
  }

  String get initials {
    if (_user == null) return '?';
    final parts = _user!.teacherName.trim().split(' ');
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  AuthProvider() {
    // Wire global 401 handler so any expired token auto-logs out
    ApiClient.onUnauthorized = () async => logout();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await ApiClient.getToken();
    if (token != null) {
      final name = prefs.getString('teacher_name') ?? '';
      final school = prefs.getString('school_name') ?? '';
      final role = prefs.getString('role') ?? 'teacher';
      final id = prefs.getInt('teacher_id') ?? 0;
      if (name.isNotEmpty) {
        _user = AuthUser(
          teacherName: name,
          schoolName: school,
          role: role,
          teacherId: id,
          email: prefs.getString('teacher_email'),
          phone: prefs.getString('teacher_phone'),
          photoUrl: prefs.getString('teacher_photo_url'),
        );
      }
    }
    _loading = false;
    notifyListeners();
  }

  /// Returns true if user must change password (first login)
  Future<bool> login(String email, String password, {String? schoolCode}) async {
    final res = await ApiClient.login(email, password, schoolCode: schoolCode);
    await ApiClient.setToken(res.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_name', res.teacherName);
    await prefs.setString('school_name', res.schoolName);
    await prefs.setString('role', res.role);
    await prefs.setInt('teacher_id', res.teacherId);
    _user = AuthUser(
      teacherName: res.teacherName,
      schoolName: res.schoolName,
      role: res.role,
      teacherId: res.teacherId,
    );
    notifyListeners();
    return res.mustChangePassword;
  }

  Future<void> updateProfile({String? name, String? phone, String? email}) async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (name != null) await prefs.setString('teacher_name', name);
    if (phone != null) await prefs.setString('teacher_phone', phone);
    if (email != null) await prefs.setString('teacher_email', email);
    _user = AuthUser(
      teacherName: name ?? _user!.teacherName,
      schoolName: _user!.schoolName,
      role: _user!.role,
      teacherId: _user!.teacherId,
      email: email ?? _user!.email,
      phone: phone ?? _user!.phone,
      photoUrl: _user!.photoUrl,
    );
    notifyListeners();
  }

  Future<void> updatePhotoUrl(String url) async {
    if (_user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_photo_url', url);
    _user = AuthUser(
      teacherName: _user!.teacherName,
      schoolName: _user!.schoolName,
      role: _user!.role,
      teacherId: _user!.teacherId,
      email: _user!.email,
      phone: _user!.phone,
      photoUrl: url,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('teacher_name');
    await prefs.remove('school_name');
    await prefs.remove('role');
    await prefs.remove('teacher_id');
    await prefs.remove('teacher_email');
    await prefs.remove('teacher_phone');
    await prefs.remove('teacher_photo_url');
    _user = null;
    notifyListeners();
  }
}
