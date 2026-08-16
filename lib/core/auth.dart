import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'cache.dart';
import 'features.dart';

const _secure = FlutterSecureStorage();
const _kBioEnabled = 'bio_enabled';

class AuthUser {
  final String teacherName;
  final String schoolName;
  final String role;
  final String teacherId;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final List<String> tags;
  final List<String> disabledFeatures;

  const AuthUser({
    required this.teacherName,
    required this.schoolName,
    required this.role,
    required this.teacherId,
    this.email,
    this.phone,
    this.photoUrl,
    this.tags = const [],
    this.disabledFeatures = const [],
  });

  bool hasTag(String tag) => tags.contains(tag);

  /// True if an admin has hidden this core-teaching section for this
  /// teacher (see backend ALLOWED_DISABLABLE_FEATURES). Admins/principals/
  /// directors are never restricted this way -- the setting only applies to
  /// plain teacher-role staff.
  bool isFeatureDisabled(String feature) =>
      role == 'teacher' && disabledFeatures.contains(feature);
}

class AuthProvider extends ChangeNotifier {
  AuthUser? _user;
  bool _loading = true;
  bool _isLocked = false;
  FeatureFlags _features = FeatureFlags.defaults();

  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;
  bool get isLocked => _isLocked;
  FeatureFlags get features => _features;

  // ── Biometric ──────────────────────────────────────────────────────────────
  final _localAuth = LocalAuthentication();

  Future<bool> get isBiometricAvailable async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) { return false; }
  }

  Future<bool> get isBiometricEnabled async =>
      (await SharedPreferences.getInstance()).getBool(_kBioEnabled) ?? false;

  Future<void> enableBiometric() async {
    (await SharedPreferences.getInstance()).setBool(_kBioEnabled, true);
  }

  Future<void> disableBiometric() async {
    (await SharedPreferences.getInstance()).setBool(_kBioEnabled, false);
    // Clean up any legacy stored credentials
    await _secure.delete(key: 'bio_email');
    await _secure.delete(key: 'bio_password');
  }

  /// Prompts biometric and locks/unlocks the app. Returns null on success, error string on failure.
  Future<String?> unlockApp() async {
    try {
      final authed = await _localAuth.authenticate(
        localizedReason: 'Unlock EduTrack',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (!authed) return 'Authentication cancelled.';
      _isLocked = false;
      notifyListeners();
      refreshSession();
      return null;
    } catch (e) {
      return 'Biometric error: $e';
    }
  }

  /// Exchanges the current token for a fresh 7-day one. Fire-and-forget: a
  /// failure here just means the next real API call 401s and logs out the
  /// normal way (ApiClient.onUnauthorized), so nothing extra to handle.
  /// Called on unlock and on cold-start restore — an actively-used session
  /// should never hit the hard expiry wall; only a genuinely idle-for-7-days
  /// one should force a re-login.
  Future<void> refreshSession() async {
    if (_user == null) return;
    try {
      final token = await ApiClient.refreshToken();
      await ApiClient.setToken(token);
    } catch (_) {}
  }

  /// Prompts biometric for confirmation (enrollment / toggle). Returns true if authenticated.
  Future<bool> authenticateBiometric(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }

  void lockApp() {
    _isLocked = true;
    notifyListeners();
  }

  void forceUnlock() {
    _isLocked = false;
    notifyListeners();
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
      final id = prefs.getString('teacher_id') ?? '';
      if (name.isNotEmpty) {
        final tagsStr = prefs.getString('teacher_tags') ?? '';
        final tags = tagsStr.isEmpty ? <String>[] : tagsStr.split(',');
        final disabledStr = prefs.getString('teacher_disabled_features') ?? '';
        final disabled = disabledStr.isEmpty ? <String>[] : disabledStr.split(',');
        _user = AuthUser(
          teacherName: name,
          schoolName: school,
          role: role,
          teacherId: id,
          email: prefs.getString('teacher_email'),
          phone: prefs.getString('teacher_phone'),
          photoUrl: prefs.getString('teacher_photo_url'),
          tags: tags,
          disabledFeatures: disabled,
        );
      }
    }
    if (_user != null && (prefs.getBool(_kBioEnabled) ?? false)) {
      _isLocked = true;
    }
    _loading = false;
    notifyListeners();
    if (_user != null) {
      _loadFeatureFlags();
      refreshSession();
    }
  }

  Future<String?> getStoredEmail() async =>
      (await SharedPreferences.getInstance()).getString('teacher_email');

  /// Returns true if user must change password (first login)
  Future<bool> login(String email, String password, {String? schoolCode}) async {
    final res = await ApiClient.login(email, password, schoolCode: schoolCode);
    await ApiClient.setToken(res.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_name', res.teacherName);
    await prefs.setString('school_name', res.schoolName);
    await prefs.setString('role', res.role);
    await prefs.setString('teacher_id', res.teacherId);
    await prefs.setString('teacher_email', email);
    final tags = res.functionalTags;
    await prefs.setString('teacher_tags', tags.join(','));
    final disabledFeatures = res.disabledFeatures;
    await prefs.setString('teacher_disabled_features', disabledFeatures.join(','));
    _user = AuthUser(
      teacherName: res.teacherName,
      schoolName: res.schoolName,
      role: res.role,
      teacherId: res.teacherId,
      tags: tags,
      disabledFeatures: disabledFeatures,
    );
    // Load feature flags after login (non-blocking)
    _loadFeatureFlags();
    notifyListeners();
    return res.mustChangePassword;
  }

  Future<void> _loadFeatureFlags() async {
    try {
      final cached = await FeatureFlags.fromCache();
      if (cached != null) {
        _features = cached;
        notifyListeners();
      }
      final fresh = await ApiClient.getFeatureConfig();
      _features = FeatureFlags.fromJson(fresh);
      await _features.saveToCache();
      notifyListeners();
    } catch (_) {}
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
      tags: _user!.tags,
      disabledFeatures: _user!.disabledFeatures,
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
      tags: _user!.tags,
      disabledFeatures: _user!.disabledFeatures,
    );
    notifyListeners();
  }

  Future<void> logout() async {
    _isLocked = false;
    final prefs = await SharedPreferences.getInstance();
    try {
      final deviceId = prefs.getString('push_device_id');
      if (deviceId != null) {
        await ApiClient.deregisterPushToken(deviceId);
        await prefs.remove('push_device_id');
      }
    } catch (_) {}
    await ApiClient.setToken(null);
    await prefs.remove('teacher_name');
    await prefs.remove('school_name');
    await prefs.remove('role');
    await prefs.remove('teacher_id');
    await prefs.remove('teacher_email');
    await prefs.remove('teacher_phone');
    await prefs.remove('teacher_photo_url');
    await prefs.remove('teacher_tags');
    await prefs.remove('teacher_disabled_features');
    _user = null;
    _features = FeatureFlags.defaults();
    await CacheService.clearAll();
    notifyListeners();
  }
}
