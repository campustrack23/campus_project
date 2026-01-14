// lib/core/models/attendance.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent, late, excused }

extension AttendanceStatusX on AttendanceStatus {
  String get label {
    switch (this) {
      case AttendanceStatus.present:
        return "Present";
      case AttendanceStatus.absent:
        return "Absent";
      case AttendanceStatus.late:
        return "Late";
      case AttendanceStatus.excused:
        return "Excused";
    }
  }

  static AttendanceStatus fromName(String? val) {
    return AttendanceStatus.values.firstWhere(
          (e) => e.name == val,
      orElse: () => AttendanceStatus.absent,
    );
  }
}

class AttendanceRecord {
  final String id;
  final String subjectId;
  final String studentId;
  final DateTime date;
  final String slot; // "09:00-10:00"
  final AttendanceStatus status;
  final String markedByTeacherId;
  final DateTime markedAt;

  const AttendanceRecord({
    required this.id,
    required this.subjectId,
    required this.studentId,
    required this.date,
    required this.slot,
    required this.status,
    required this.markedByTeacherId,
    required this.markedAt,
  });

  AttendanceRecord copyWith({
    String? id,
    String? subjectId,
    String? studentId,
    DateTime? date,
    String? slot,
    AttendanceStatus? status,
    String? markedByTeacherId,
    DateTime? markedAt,
  }) {
    return AttendanceRecord(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      studentId: studentId ?? this.studentId,
      date: date ?? this.date,
      slot: slot ?? this.slot,
      status: status ?? this.status,
      markedByTeacherId: markedByTeacherId ?? this.markedByTeacherId,
      markedAt: markedAt ?? this.markedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      // ID is not included by default in Firestore document fields
      'subjectId': subjectId,
      'studentId': studentId,
      'date': Timestamp.fromDate(date),
      'slot': slot,
      'status': status.name,
      'markedByTeacherId': markedByTeacherId,
      'markedAt': Timestamp.fromDate(markedAt),
    };
  }

  // Firestore .data() does not include 'id', so allow id as param for flexibility
  factory AttendanceRecord.fromMap(String id, Map<String, dynamic> map) {
    return AttendanceRecord(
      id: id,
      subjectId: map['subjectId'] ?? '',
      studentId: map['studentId'] ?? '',
      date: (map['date'] is Timestamp)
          ? (map['date'] as Timestamp).toDate()
          : DateTime.now(),
      slot: map['slot'] ?? '',
      status: AttendanceStatusX.fromName(map['status']),
      markedByTeacherId: map['markedByTeacherId'] ?? '',
      markedAt: (map['markedAt'] is Timestamp)
          ? (map['markedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  factory AttendanceRecord.fromDoc(DocumentSnapshot doc) {
    return AttendanceRecord.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AttendanceRecord &&
        other.id == id &&
        other.subjectId == subjectId &&
        other.studentId == studentId &&
        other.date == date &&
        other.slot == slot &&
        other.status == status &&
        other.markedByTeacherId == markedByTeacherId &&
        other.markedAt == markedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    subjectId.hashCode ^
    studentId.hashCode ^
    date.hashCode ^
    slot.hashCode ^
    status.hashCode ^
    markedByTeacherId.hashCode ^
    markedAt.hashCode;
  }
}
