// lib/core/models/remark.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_parser.dart';

class StudentRemark {
  final String id;
  final String teacherId;
  final String studentId;
  final String tag;
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

  factory StudentRemark.fromMap(String id, Map<String, dynamic> m) {
    return StudentRemark(
      id: id,
      teacherId: m['teacherId'] ?? '',
      studentId: m['studentId'] ?? '',
      tag: m['tag'] ?? 'Unspecified',
      updatedAt: DateParser.parse(m['updatedAt'], fieldName: 'StudentRemark.updatedAt'),
    );
  }
}