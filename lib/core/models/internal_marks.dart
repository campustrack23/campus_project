// lib/core/models/internal_marks.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class InternalMarks {
  final String id; // doc ID: subjectId_studentId
  final String subjectId;
  final String studentId;
  final String teacherId;

  final double assignmentMarks; // Max 12
  final double testMarks;       // Max 12
  final double attendanceMarks; // Max 6
  final double totalMarks;      // Max 30

  final bool isVisibleToStudent;
  final DateTime updatedAt;

  const InternalMarks({
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

  /// Helper to create a new, empty record
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
    String? teacherId,
    double? assignmentMarks,
    double? testMarks,
    double? attendanceMarks,
    // totalMarks is usually auto-calculated, so omitted from copyWith
    bool? isVisibleToStudent,
    DateTime? updatedAt,
  }) {
    return InternalMarks(
      id: id,
      subjectId: subjectId,
      studentId: studentId,
      teacherId: teacherId ?? this.teacherId,
      assignmentMarks: assignmentMarks ?? this.assignmentMarks,
      testMarks: testMarks ?? this.testMarks,
      attendanceMarks: attendanceMarks ?? this.attendanceMarks,
      totalMarks: (assignmentMarks ?? this.assignmentMarks) +
          (testMarks ?? this.testMarks) +
          (attendanceMarks ?? this.attendanceMarks),
      isVisibleToStudent: isVisibleToStudent ?? this.isVisibleToStudent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Recalculate total marks explicitly, useful after batch updates
  InternalMarks recalculateTotal() {
    final newTotal = assignmentMarks + testMarks + attendanceMarks;
    return InternalMarks(
      id: id,
      subjectId: subjectId,
      studentId: studentId,
      teacherId: teacherId,
      assignmentMarks: assignmentMarks,
      testMarks: testMarks,
      attendanceMarks: attendanceMarks,
      totalMarks: newTotal,
      isVisibleToStudent: isVisibleToStudent,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
      id: map['id'] ?? '',
      subjectId: map['subjectId'] ?? '',
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      assignmentMarks: (map['assignmentMarks'] as num?)?.toDouble() ?? 0.0,
      testMarks: (map['testMarks'] as num?)?.toDouble() ?? 0.0,
      attendanceMarks: (map['attendanceMarks'] as num?)?.toDouble() ?? 0.0,
      totalMarks: (map['totalMarks'] as num?)?.toDouble() ??
          ((map['assignmentMarks'] as num?)?.toDouble() ?? 0.0) +
              ((map['testMarks'] as num?)?.toDouble() ?? 0.0) +
              ((map['attendanceMarks'] as num?)?.toDouble() ?? 0.0),
      isVisibleToStudent: map['isVisibleToStudent'] as bool? ?? false,
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  factory InternalMarks.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return InternalMarks.fromMap({...data, 'id': doc.id});
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is InternalMarks &&
        other.id == id &&
        other.subjectId == subjectId &&
        other.studentId == studentId &&
        other.teacherId == teacherId &&
        other.assignmentMarks == assignmentMarks &&
        other.testMarks == testMarks &&
        other.attendanceMarks == attendanceMarks &&
        other.totalMarks == totalMarks &&
        other.isVisibleToStudent == isVisibleToStudent &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    subjectId.hashCode ^
    studentId.hashCode ^
    teacherId.hashCode ^
    assignmentMarks.hashCode ^
    testMarks.hashCode ^
    attendanceMarks.hashCode ^
    totalMarks.hashCode ^
    isVisibleToStudent.hashCode ^
    updatedAt.hashCode;
  }
}
