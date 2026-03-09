// lib/core/models/role.dart

enum UserRole {
  student,
  teacher,
  admin,
}

extension UserRoleX on UserRole {
  /// Human-readable label for UI
  String get label {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Faculty';
      case UserRole.admin:
        return 'Administrator';
    }
  }

  // ---------------------------------------------------------------------------
  // Convenience Getters
  // ---------------------------------------------------------------------------

  bool get isStudent => this == UserRole.student;
  bool get isTeacher => this == UserRole.teacher;
  bool get isAdmin => this == UserRole.admin;

  // ---------------------------------------------------------------------------
  // Serialization Helpers
  // ---------------------------------------------------------------------------

  /// String key used for storage (Firestore, JSON, etc.)
  String get key => name;

  /// Safe parser → defaults to `student`
  static UserRole fromString(String? value) {
    if (value == null) return UserRole.student;
    return UserRole.values.firstWhere(
          (e) => e.name == value,
      orElse: () => UserRole.student,
    );
  }

  /// Nullable parser → returns null if invalid
  static UserRole? tryParse(String? value) {
    if (value == null) return null;
    try {
      return UserRole.values.byName(value);
    } catch (_) {
      return null;
    }
  }
}
