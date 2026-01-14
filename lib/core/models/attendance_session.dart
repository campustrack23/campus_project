// lib/core/models/attendance_session.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceSessionStatus { open, closed }

extension AttendanceSessionStatusX on AttendanceSessionStatus {
  String get label => this == AttendanceSessionStatus.open ? 'Open' : 'Closed';
}

class AttendanceSession {
  /// The session ID (this is what's embedded in the QR code).
  final String id;
  final String teacherId;
  final String subjectId;
  final String section;
  final String slot;
  final DateTime createdAt;
  final DateTime expiresAt; // typically createdAt + duration (e.g. 10 minutes)
  final AttendanceSessionStatus status;

  const AttendanceSession({
    required this.id,
    required this.teacherId,
    required this.subjectId,
    required this.section,
    required this.slot,
    required this.createdAt,
    required this.expiresAt,
    this.status = AttendanceSessionStatus.open,
  });

  /// Convenience: create a new session that expires after [durationMinutes].
  /// Generates `expiresAt = createdAt + durationMinutes`.
  factory AttendanceSession.createNew({
    required String id,
    required String teacherId,
    required String subjectId,
    required String section,
    required String slot,
    DateTime? createdAt,
    int durationMinutes = 10,
  }) {
    final now = createdAt ?? DateTime.now().toUtc();
    return AttendanceSession(
      id: id,
      teacherId: teacherId,
      subjectId: subjectId,
      section: section,
      slot: slot,
      createdAt: now,
      expiresAt: now.add(Duration(minutes: durationMinutes)),
      status: AttendanceSessionStatus.open,
    );
  }

  /// Whether the session has expired (based on UTC times).
  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt.toUtc());

  /// Whether the session is currently open (not expired and status == open).
  bool get isActive => status == AttendanceSessionStatus.open && !isExpired;

  /// Create a copy with updates.
  AttendanceSession copyWith({
    String? id,
    String? teacherId,
    String? subjectId,
    String? section,
    String? slot,
    DateTime? createdAt,
    DateTime? expiresAt,
    AttendanceSessionStatus? status,
  }) {
    return AttendanceSession(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      subjectId: subjectId ?? this.subjectId,
      section: section ?? this.section,
      slot: slot ?? this.slot,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      status: status ?? this.status,
    );
  }

  /// Convert to Firestore-friendly map.
  /// Note: We don’t typically include `id` in Firestore document fields.
  Map<String, dynamic> toMap() => {
    'teacherId': teacherId,
    'subjectId': subjectId,
    'section': section,
    'slot': slot,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'status': status.name,
  };

  /// Safe parser from a plain Map (e.g., from doc.data()).
  factory AttendanceSession.fromMap(String id, Map<String, dynamic>? map) {
    final safeMap = map ?? <String, dynamic>{};

    DateTime parseTimestamp(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.now().toUtc();
    }

    final created = parseTimestamp(safeMap['createdAt']);
    final expires = parseTimestamp(safeMap['expiresAt']);

    final statusRaw = safeMap['status'] as String?;
    final status = (statusRaw != null && statusRaw == AttendanceSessionStatus.closed.name)
        ? AttendanceSessionStatus.closed
        : AttendanceSessionStatus.open;

    return AttendanceSession(
      id: id,
      teacherId: safeMap['teacherId'] ?? '',
      subjectId: safeMap['subjectId'] ?? '',
      section: safeMap['section'] ?? '',
      slot: safeMap['slot'] ?? '',
      createdAt: created,
      expiresAt: expires,
      status: status,
    );
  }

  /// Create from Firestore DocumentSnapshot safely.
  factory AttendanceSession.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return AttendanceSession.fromMap(doc.id, data);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AttendanceSession &&
        other.id == id &&
        other.teacherId == teacherId &&
        other.subjectId == subjectId &&
        other.section == section &&
        other.slot == slot &&
        other.createdAt == createdAt &&
        other.expiresAt == expiresAt &&
        other.status == status;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    teacherId.hashCode ^
    subjectId.hashCode ^
    section.hashCode ^
    slot.hashCode ^
    createdAt.hashCode ^
    expiresAt.hashCode ^
    status.hashCode;
  }
}
