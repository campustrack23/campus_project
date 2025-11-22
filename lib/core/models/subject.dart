// lib/core/models/subject.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Subject {
  final String id;
  final String code;
  final String name;
  final String department;
  final String semester;
  final String section;
  final String teacherId;

  const Subject({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    required this.semester,
    required this.section,
    required this.teacherId,
  });

  String get displayName => '$code - $name ($section)';

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

  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    'department': department,
    'semester': semester,
    'section': section,
    'teacherId': teacherId,
  };

  factory Subject.fromMap(String id, Map<String, dynamic>? map) {
    final m = map ?? {};
    return Subject(
      id: id,
      code: m['code'] ?? '',
      name: m['name'] ?? '',
      department: m['department'] ?? '',
      semester: m['semester'] ?? '',
      section: m['section'] ?? '',
      teacherId: m['teacherId'] ?? '',
    );
  }

  factory Subject.fromDoc(DocumentSnapshot doc) {
    return Subject.fromMap(doc.id, doc.data() as Map<String, dynamic>?);
  }
}
