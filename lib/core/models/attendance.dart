// lib/core/models/attendance.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late, excused }

class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final String subjectId;
  final DateTime date;
  final String slot; // e.g. "08:30-09:30"
  final AttendanceStatus status;
  final String markedByTeacherId;
  final DateTime markedAt;

  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.subjectId,
    required this.date,
    required this.slot,
    required this.status,
    required this.markedByTeacherId,
    required this.markedAt,
  });

  Map<String, dynamic> toMap() => {
    'sessionId': sessionId,
    'studentId': studentId,
    'subjectId': subjectId,
    'date': Timestamp.fromDate(date),
    'slot': slot,
    'status': status.name, // Store enum as string
    'markedByTeacherId': markedByTeacherId,
    'markedAt': Timestamp.fromDate(markedAt),
  };

  // FIX: Accept ID separately from the map
  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic input) {
      if (input is Timestamp) return input.toDate();
      if (input is String) return DateTime.tryParse(input) ?? DateTime.now();
      return DateTime.now();
    }

    return AttendanceRecord(
      id: id,
      sessionId: map['sessionId'] ?? '',
      studentId: map['studentId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      date: parseDate(map['date']),
      slot: map['slot'] ?? '',
      status: AttendanceStatus.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => AttendanceStatus.absent,
      ),
      markedByTeacherId: map['markedByTeacherId'] ?? '',
      markedAt: parseDate(map['markedAt']),
    );
  }
}