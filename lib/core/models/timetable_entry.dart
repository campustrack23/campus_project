// lib/core/models/timetable_entry.dart
class TimetableEntry {
  final String id;
  final String subjectId;
  final String dayOfWeek; // Mon, Tue, Wed...
  final String startTime; // "08:30"
  final String endTime;   // "09:30"
  final String room;
  final String section;
  final List<String> teacherIds; // Supports multiple teachers for labs

  const TimetableEntry({
    required this.id,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.section,
    required this.teacherIds,
  });

  // Helper for UI to show "08:30 - 09:30"
  String get slot => '$startTime-$endTime';

  Map<String, dynamic> toMap() => {
    'subjectId': subjectId,
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'room': room,
    'section': section,
    'teacherIds': teacherIds,
  };

  // FIX: Accept ID separately
  factory TimetableEntry.fromMap(String id, Map<String, dynamic> map) {
    return TimetableEntry(
      id: id,
      subjectId: map['subjectId'] ?? '',
      dayOfWeek: map['dayOfWeek'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      room: map['room'] ?? '',
      section: map['section'] ?? '',
      teacherIds: (map['teacherIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}