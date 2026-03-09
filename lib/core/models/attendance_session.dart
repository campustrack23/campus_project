// lib/core/models/attendance_session.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceSession {
  final String id;
  final String teacherId;
  final String subjectId;
  final String section;
  final String slot;
  final DateTime createdAt;
  final bool isActive;

  const AttendanceSession({
    required this.id,
    required this.teacherId,
    required this.subjectId,
    required this.section,
    required this.slot,
    required this.createdAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'teacherId': teacherId,
    'subjectId': subjectId,
    'section': section,
    'slot': slot,
    'createdAt': Timestamp.fromDate(createdAt),
    'isActive': isActive,
  };

  // FIX: Accept ID separately
  factory AttendanceSession.fromMap(String id, Map<String, dynamic> map) {
    DateTime parseDate(dynamic input) {
      if (input is Timestamp) return input.toDate();
      if (input is String) return DateTime.tryParse(input) ?? DateTime.now();
      return DateTime.now();
    }

    return AttendanceSession(
      id: id,
      teacherId: map['teacherId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      section: map['section'] ?? '',
      slot: map['slot'] ?? '',
      createdAt: parseDate(map['createdAt']),
      isActive: map['isActive'] ?? true,
    );
  }
}