import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

class AuthUser {
  final String teacherName;
  final String schoolName;
  final String role;
  final int teacherId;

  const AuthUser({
    required this.teacherName,
    required this.schoolName,
    required this.role,
    required this.teacherId,
  });
}

class AuthProvider extends ChangeNotifier {
  AuthUser? _user;
  bool _loading = true;

  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get loading => _loading;

  String get initials {
    if (_user == null) return '?';
    final parts = _user!.teacherName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '?';
  }

  AuthProvider() {
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
        );
      }
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final res = await ApiClient.login(email, password);
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
  }

  Future<void> logout() async {
    await ApiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('teacher_name');
    await prefs.remove('school_name');
    await prefs.remove('role');
    await prefs.remove('teacher_id');
    _user = null;
    notifyListeners();
  }
}
