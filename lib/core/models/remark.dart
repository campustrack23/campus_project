// lib/core/models/remark.dart
import 'package:uuid/uuid.dart';

class StudentRemark {
  final String id;
  final String teacherId;
  final String studentId;
  final String tag; // e.g., Good, Average, Needs Improvement, or custom
  final DateTime updatedAt;

  StudentRemark({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.tag,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'teacherId': teacherId,
    'studentId': studentId,
    'tag': tag,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory StudentRemark.fromMap(Map<String, dynamic> m) => StudentRemark(
    id: m['id'],
    teacherId: m['teacherId'],
    studentId: m['studentId'],
    tag: m['tag'],
    updatedAt: DateTime.parse(m['updatedAt']),
  );
}