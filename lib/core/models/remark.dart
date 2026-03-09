// lib/core/models/remark.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentRemark {
  final String id;
  final String teacherId;
  final String studentId;
  final String tag; // e.g., Good, Average, Needs Improvement
  final DateTime updatedAt;

  const StudentRemark({
    required this.id,
    required this.teacherId,
    required this.studentId,
    required this.tag,
    required this.updatedAt,
  });

  StudentRemark copyWith({
    String? id,
    String? teacherId,
    String? studentId,
    String? tag,
    DateTime? updatedAt,
  }) {
    return StudentRemark(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      studentId: studentId ?? this.studentId,
      tag: tag ?? this.tag,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'teacherId': teacherId,
    'studentId': studentId,
    'tag': tag,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  // FIX: Accept ID separately
  factory StudentRemark.fromMap(String id, Map<String, dynamic> m) {
    DateTime parseDate(dynamic input) {
      if (input is Timestamp) return input.toDate();
      if (input is String) return DateTime.tryParse(input) ?? DateTime.now();
      if (input is DateTime) return input;
      return DateTime.now();
    }

    return StudentRemark(
      id: id, // <--- Use passed ID
      teacherId: m['teacherId'] ?? '',
      studentId: m['studentId'] ?? '',
      tag: m['tag'] ?? 'General',
      updatedAt: parseDate(m['updatedAt']),
    );
  }
}