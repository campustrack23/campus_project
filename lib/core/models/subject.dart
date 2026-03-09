// lib/core/models/subject.dart
class Subject {
  final String id;
  final String code;
  final String name;
  final String department;
  final String semester;
  final String section;
  final String teacherId; // The lead faculty

  const Subject({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    required this.semester,
    required this.section,
    required this.teacherId,
  });

  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    'department': department,
    'semester': semester,
    'section': section,
    'teacherId': teacherId,
  };

  // FIX: Accept ID separately
  factory Subject.fromMap(String id, Map<String, dynamic> map) {
    return Subject(
      id: id,
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      department: map['department'] ?? '',
      semester: map['semester'] ?? '',
      section: map['section'] ?? '',
      teacherId: map['teacherId'] ?? '',
    );
  }

  Subject copyWith({
    String? id,
    String? code,
    String? name,
    String? department,
    String? semester,
    String? section,
    String? teacherId,
  }) {
    return Subject(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      section: section ?? this.section,
      teacherId: teacherId ?? this.teacherId,
    );
  }
}