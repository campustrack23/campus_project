// lib/core/models/timetable_entry.dart
import 'package:flutter/foundation.dart'; // For listEquals

class TimetableEntry {
  final String id;
  final String subjectId;
  final String dayOfWeek; // Mon, Tue, Wed...
  final String startTime; // "08:30"
  final String endTime;   // "09:30"
  final String room;      // NEL/NR/301
  final String section;   // IV-HE
  final List<String> teacherIds; // Multiple teachers allowed

  const TimetableEntry({
    required this.id,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.section,
    this.teacherIds = const [],
  });

  // Getter for easy slot display "08:30-09:30"
  String get slot => '$startTime-$endTime';

  // CopyWith for easier updates (e.g., swapping teachers)
  TimetableEntry copyWith({
    String? id,
    String? subjectId,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? room,
    String? section,
    List<String>? teacherIds,
  }) {
    return TimetableEntry(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      room: room ?? this.room,
      section: section ?? this.section,
      teacherIds: teacherIds ?? this.teacherIds,
    );
  }

  Map<String, dynamic> toMap() => {
    'subjectId': subjectId,
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'room': room,
    'section': section,
    'teacherIds': teacherIds,
  };

  factory TimetableEntry.fromMap(String id, Map<String, dynamic>? map) {
    final m = map ?? {};
    return TimetableEntry(
      id: id,
      subjectId: m['subjectId'] ?? '',
      dayOfWeek: m['dayOfWeek'] ?? '',
      startTime: m['startTime'] ?? '',
      endTime: m['endTime'] ?? '',
      room: m['room'] ?? '',
      section: m['section'] ?? '',
      teacherIds: (m['teacherIds'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
    );
  }

  factory TimetableEntry.fromDoc(doc) => TimetableEntry.fromMap(doc.id, doc.data() as Map<String, dynamic>?);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TimetableEntry &&
        other.id == id &&
        other.subjectId == subjectId &&
        other.dayOfWeek == dayOfWeek &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.room == room &&
        other.section == section &&
        listEquals(other.teacherIds, teacherIds);
  }

  @override
  int get hashCode {
    return id.hashCode ^
    subjectId.hashCode ^
    dayOfWeek.hashCode ^
    startTime.hashCode ^
    endTime.hashCode ^
    room.hashCode ^
    section.hashCode ^
    Object.hashAll(teacherIds);
  }
}
