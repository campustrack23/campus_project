// lib/core/models/timetable_override.dart

class TimetableOverride {
  final String id;
  final String section;
  final String date; // 'YYYY-MM-DD'
  final String originalEntryId; // links back to the TimetableEntry being overridden
  final bool isCancelled;
  final String? newStartTime;
  final String? newEndTime;
  final String? newRoom;
  final String? reason;
  final String createdByTeacherId;
  final DateTime createdAt;

  const TimetableOverride({
    required this.id,
    required this.section,
    required this.date,
    required this.originalEntryId,
    required this.isCancelled,
    this.newStartTime,
    this.newEndTime,
    this.newRoom,
    this.reason,
    required this.createdByTeacherId,
    required this.createdAt,
  });

  /// Firestore → model
  factory TimetableOverride.fromMap(String id, Map<String, dynamic> map) {
    return TimetableOverride(
      id: id,
      section: map['section'] as String,
      date: map['date'] as String,
      originalEntryId: map['originalEntryId'] as String,
      isCancelled: map['isCancelled'] as bool,
      newStartTime: map['newStartTime'] as String?,
      newEndTime: map['newEndTime'] as String?,
      newRoom: map['newRoom'] as String?,
      reason: map['reason'] as String?,
      createdByTeacherId: map['createdByTeacherId'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  /// model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'section': section,
      'date': date,
      'originalEntryId': originalEntryId,
      'isCancelled': isCancelled,
      if (newStartTime != null) 'newStartTime': newStartTime,
      if (newEndTime != null) 'newEndTime': newEndTime,
      if (newRoom != null) 'newRoom': newRoom,
      if (reason != null) 'reason': reason,
      'createdByTeacherId': createdByTeacherId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Convenience: is this a reschedule (not a cancellation)?
  bool get isRescheduled =>
      !isCancelled && (newStartTime != null || newRoom != null);

  TimetableOverride copyWith({
    String? section,
    String? date,
    String? originalEntryId,
    bool? isCancelled,
    String? newStartTime,
    String? newEndTime,
    String? newRoom,
    String? reason,
    String? createdByTeacherId,
    DateTime? createdAt,
  }) {
    return TimetableOverride(
      id: id,
      section: section ?? this.section,
      date: date ?? this.date,
      originalEntryId: originalEntryId ?? this.originalEntryId,
      isCancelled: isCancelled ?? this.isCancelled,
      newStartTime: newStartTime ?? this.newStartTime,
      newEndTime: newEndTime ?? this.newEndTime,
      newRoom: newRoom ?? this.newRoom,
      reason: reason ?? this.reason,
      createdByTeacherId: createdByTeacherId ?? this.createdByTeacherId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}