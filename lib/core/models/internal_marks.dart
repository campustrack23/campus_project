// lib/core/models/internal_marks.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/date_parser.dart';

class InternalMarks {
  final String id;
  final String subjectId;
  final String studentId;
  final String teacherId;
  final double assignmentMarks; // Max 12
  final double testMarks;       // Max 12
  final double attendanceMarks; // Max 6
  final double totalMarks;      // Max 30
  final bool isFrozen;
  final bool isVisibleToStudent;
  final DateTime updatedAt;

  const InternalMarks({
    required this.id,
    required this.subjectId,
    required this.studentId,
    required this.teacherId,
    required this.assignmentMarks,
    required this.testMarks,
    required this.attendanceMarks,
    required this.totalMarks,
    this.isFrozen = false,
    this.isVisibleToStudent = false,
    required this.updatedAt,
  });

  factory InternalMarks.empty({
    required String subjectId,
    required String studentId,
    required String teacherId,
  }) {
    return InternalMarks(
      id: '',
      subjectId: subjectId,
      studentId: studentId,
      teacherId: teacherId,
      assignmentMarks: 0,
      testMarks: 0,
      attendanceMarks: 0,
      totalMarks: 0,
      isFrozen: false,
      isVisibleToStudent: false,
      updatedAt: DateTime.now(),
    );
  }

  InternalMarks copyWith({
    String? id,
    String? subjectId,
    String? studentId,
    String? teacherId,
    double? assignmentMarks,
    double? testMarks,
    double? attendanceMarks,
    double? totalMarks,
    bool? isFrozen,
    bool? isVisibleToStudent,
    DateTime? updatedAt,
  }) {
    return InternalMarks(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      studentId: studentId ?? this.studentId,
      teacherId: teacherId ?? this.teacherId,
      assignmentMarks: assignmentMarks ?? this.assignmentMarks,
      testMarks: testMarks ?? this.testMarks,
      attendanceMarks: attendanceMarks ?? this.attendanceMarks,
      totalMarks: totalMarks ?? this.totalMarks,
      isFrozen: isFrozen ?? this.isFrozen,
      isVisibleToStudent: isVisibleToStudent ?? this.isVisibleToStudent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'subjectId': subjectId,
    'studentId': studentId,
    'teacherId': teacherId,
    'assignmentMarks': assignmentMarks,
    'testMarks': testMarks,
    'attendanceMarks': attendanceMarks,
    'totalMarks': totalMarks,
    'isFrozen': isFrozen,
    'isVisibleToStudent': isVisibleToStudent,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory InternalMarks.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data() ?? {};
    return InternalMarks(
      id: doc.id,
      subjectId: map['subjectId'] ?? '',
      studentId: map['studentId'] ?? '',
      teacherId: map['teacherId'] ?? '',
      assignmentMarks: (map['assignmentMarks'] as num?)?.toDouble() ?? 0.0,
      testMarks: (map['testMarks'] as num?)?.toDouble() ?? 0.0,
      attendanceMarks: (map['attendanceMarks'] as num?)?.toDouble() ?? 0.0,
      totalMarks: (map['totalMarks'] as num?)?.toDouble() ?? 0.0,
      isFrozen: map['isFrozen'] ?? false,
      isVisibleToStudent: map['isVisibleToStudent'] ?? false,
      updatedAt: DateParser.parse(map['updatedAt'], fieldName: 'InternalMarks.updatedAt'),
    );
  }
}