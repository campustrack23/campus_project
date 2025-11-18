// lib/core/models/role.dart
enum UserRole { student, teacher, admin }

extension UserRoleX on UserRole {
  String get label => switch (this) {
    UserRole.student => 'Student',
    UserRole.teacher => 'Teacher',
    UserRole.admin => 'Admin',
  };

  String get key => name;

  static UserRole fromKey(String k) =>
      UserRole.values.firstWhere((e) => e.name == k);

  static UserRole? tryParse(String k) {
    for (final r in UserRole.values) {
      if (r.name == k) return r;
    }
    return null;
  }
}