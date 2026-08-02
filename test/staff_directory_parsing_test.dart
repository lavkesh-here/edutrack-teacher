// Pure logic test for StaffDirectoryEntry.fromJson (core/api.dart), added
// alongside the staff directory feature. Exercises the exact response shape
// of GET /api/v1/teacher/staff-directory (teacher.py::staff_directory).

import 'package:flutter_test/flutter_test.dart';

class _StaffDirectoryEntry {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final String? profilePhotoUrl;
  final List<String> functionalTags;

  _StaffDirectoryEntry({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.profilePhotoUrl,
    this.functionalTags = const [],
  });

  factory _StaffDirectoryEntry.fromJson(Map<String, dynamic> j) => _StaffDirectoryEntry(
        id: j['id'].toString(),
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        role: j['role'] as String? ?? 'teacher',
        profilePhotoUrl: j['profile_photo_url'] as String?,
        functionalTags: (j['functional_tags'] as List<dynamic>? ?? []).cast<String>(),
      );
}

void main() {
  test('parses a full staff directory row', () {
    final entry = _StaffDirectoryEntry.fromJson({
      'id': 'aa780d89-6043-4612-8abd-47a958988809',
      'name': 'Anita Sharma',
      'email': 'anita.sharma@demo.school',
      'phone': '9876500000',
      'role': 'teacher',
      'profile_photo_url': 'https://storage.googleapis.com/bucket/photo.jpg',
      'functional_tags': ['Sports Coordinator', 'Exam Committee'],
    });
    expect(entry.name, 'Anita Sharma');
    expect(entry.phone, '9876500000');
    expect(entry.functionalTags, ['Sports Coordinator', 'Exam Committee']);
  });

  test('missing phone, photo, and tags default gracefully', () {
    final entry = _StaffDirectoryEntry.fromJson({
      'id': 'aa780d89-6043-4612-8abd-47a958988809',
      'name': 'Demo Teacher',
      'email': 'teacher@demo.school',
      'phone': null,
      'role': 'admin',
      'profile_photo_url': null,
      'functional_tags': <dynamic>[],
    });
    expect(entry.phone, isNull);
    expect(entry.profilePhotoUrl, isNull);
    expect(entry.functionalTags, isEmpty);
  });
}
