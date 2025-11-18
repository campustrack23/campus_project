// lib/core/models/internal_marks.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InternalMarks {
  final String id; // doc ID, combination of subjectId_studentId
  final String subjectId;
  final String studentId;
  final String teacherId;

  final double assignmentMarks; // out of 12
  final double testMarks;       // out of 12
  final double attendanceMarks; // out of 6 (auto-calculated)
  final double totalMarks;      // out of 30

  final bool isVisibleToStudent;
  final DateTime updatedAt;

  InternalMarks({
    required this.id,
    required this.subjectId,
    required this.studentId,
    required this.teacherId,
    this.assignmentMarks = 0.0,
    this.testMarks = 0.0,
    this.attendanceMarks = 0.0,
    this.totalMarks = 0.0,
    this.isVisibleToStudent = false,
    required this.updatedAt,
  });

  // Helper to create a new, empty record
  factory InternalMarks.empty({
    required String subjectId,
    required String studentId,
    required String teacherId,
  }) {
    return InternalMarks(
      id: '${subjectId}_$studentId',
      subjectId: subjectId,
      studentId: studentId,
      teacherId: teacherId,
      updatedAt: DateTime.now(),
    );
  }

  InternalMarks copyWith({
    double? assignmentMarks,
    double? testMarks,
    double? attendanceMarks,
    double? totalMarks,
    bool? isVisibleToStudent,
    DateTime? updatedAt,
    // --- FIX: Added missing teacherId parameter ---
    String? teacherId,
  }) {
    return InternalMarks(
      id: id,
      subjectId: subjectId,
      studentId: studentId,
      // --- FIX: Use new teacherId if provided, otherwise keep old one ---
      teacherId: teacherId ?? this.teacherId,
      assignmentMarks: assignmentMarks ?? this.assignmentMarks,
      testMarks: testMarks ?? this.testMarks,
      attendanceMarks: attendanceMarks ?? this.attendanceMarks,
      totalMarks: totalMarks ?? this.totalMarks,
      isVisibleToStudent: isVisibleToStudent ?? this.isVisibleToStudent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
  // --- End of Fix ---

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subjectId': subjectId,
      'studentId': studentId,
      'teacherId': teacherId,
      'assignmentMarks': assignmentMarks,
      'testMarks': testMarks,
      'attendanceMarks': attendanceMarks,
      'totalMarks': totalMarks,
      'isVisibleToStudent': isVisibleToStudent,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory InternalMarks.fromMap(Map<String, dynamic> map) {
    return InternalMarks(
      id: map['id'] as String,
      subjectId: map['subjectId'] as String,
      studentId: map['studentId'] as String,
      teacherId: map['teacherId'] as String,
      assignmentMarks: (map['assignmentMarks'] as num?)?.toDouble() ?? 0.0,
      testMarks: (map['testMarks'] as num?)?.toDouble() ?? 0.0,
      attendanceMarks: (map['attendanceMarks'] as num?)?.toDouble() ?? 0.0,
      totalMarks: (map['totalMarks'] as num?)?.toDouble() ?? 0.0,
      isVisibleToStudent: map['isVisibleToStudent'] as bool? ?? false,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }
}