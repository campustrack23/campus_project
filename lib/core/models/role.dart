// lib/core/models/role.dart

enum UserRole { student, teacher, admin }

extension UserRoleX on UserRole {
  /// Returns a human-readable label for UI display
  String get label => switch (this) {
    UserRole.student => 'Student',
    UserRole.teacher => 'Teacher',
    UserRole.admin => 'Admin',
  };

  // ===== CONVENIENCE GETTERS =====
  bool get isStudent => this == UserRole.student;
  bool get isTeacher => this == UserRole.teacher;
  bool get isAdmin => this == UserRole.admin;

  // ===== SERIALIZATION =====
  String get key => name;

  /// A safe parser that defaults to [student] if input is invalid or null.
  static UserRole fromKey(String? k) {
    if (k == null) return UserRole.student;
    return UserRole.values.firstWhere(
          (e) => e.name == k,
      orElse: () => UserRole.student,
    );
  }

  /// Returns null if the string doesn't match any UserRole
  static UserRole? tryParse(String? k) {
    if (k == null) return null;
    try {
      return UserRole.values.byName(k);
    } catch (_) {
      return null;
    }
  }
}
