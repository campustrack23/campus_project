// lib/core/models/attendance.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late, excused }

class AttendanceRecord {
  final String id;
  final String subjectId;
  final String studentId;
  final DateTime date;
  final String slot; // "09:00-10:00"
  final AttendanceStatus status;
  final String markedByTeacherId;
  final DateTime markedAt;

  AttendanceRecord({
    required this.id,
    required this.subjectId,
    required this.studentId,
    required this.date,
    required this.slot,
    required this.status,
    required this.markedByTeacherId,
    required this.markedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'subjectId': subjectId,
    'studentId': studentId,
    // --- FIX: Save as a Firestore Timestamp object ---
    'date': Timestamp.fromDate(date),
    'slot': slot,
    'status': status.name,
    'markedByTeacherId': markedByTeacherId,
    'markedAt': Timestamp.fromDate(markedAt),
  };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) =>
      AttendanceRecord(
        id: map['id'],
        subjectId: map['subjectId'],
        studentId: map['studentId'],
        // --- FIX: Read from a Firestore Timestamp object ---
        date: (map['date'] as Timestamp).toDate(),
        slot: map['slot'],
        status: AttendanceStatus.values.byName(map['status']),
        markedByTeacherId: map['markedByTeacherId'],
        markedAt: (map['markedAt'] as Timestamp).toDate(),
      );
}