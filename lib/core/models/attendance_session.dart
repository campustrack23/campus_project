import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceSessionStatus { open, closed }

class AttendanceSession {
  final String id; // The session ID (this is what's in the QR code)
  final String teacherId;
  final String subjectId;
  final String section;
  final String slot;
  final DateTime createdAt;
  final DateTime expiresAt; // createdAt + 10 minutes
  final AttendanceSessionStatus status;

  AttendanceSession({
    required this.id,
    required this.teacherId,
    required this.subjectId,
    required this.section,
    required this.slot,
    required this.createdAt,
    required this.expiresAt,
    this.status = AttendanceSessionStatus.open,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'teacherId': teacherId,
    'subjectId': subjectId,
    'section': section,
    'slot': slot,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'status': status.name,
  };

  factory AttendanceSession.fromMap(Map<String, dynamic> map) {
    return AttendanceSession(
      id: map['id'],
      teacherId: map['teacherId'],
      subjectId: map['subjectId'],
      section: map['section'],
      slot: map['slot'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      expiresAt: (map['expiresAt'] as Timestamp).toDate(),
      status: (map['status'] == 'closed')
          ? AttendanceSessionStatus.closed
          : AttendanceSessionStatus.open,
    );
  }
}