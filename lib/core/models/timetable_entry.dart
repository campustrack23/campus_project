class TimetableEntry {
  final String id;
  final String subjectId;
  final String dayOfWeek; // Mon..Sun
  final String startTime; // "08:30"
  final String endTime;   // "09:30"
  final String room;      // NEL/NR/301
  final String section;   // IV-HE
  final List<String> teacherIds; // multiple teachers per slot

  TimetableEntry({
    required this.id,
    required this.subjectId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.room,
    required this.section,
    this.teacherIds = const [],
  });

  // **NEW**: slot getter
  String get slot => '$startTime-$endTime';

  Map<String, dynamic> toMap() => {
    'id': id,
    'subjectId': subjectId,
    'dayOfWeek': dayOfWeek,
    'startTime': startTime,
    'endTime': endTime,
    'room': room,
    'section': section,
    'teacherIds': teacherIds,
  };

  factory TimetableEntry.fromMap(Map<String, dynamic> map) => TimetableEntry(
    id: map['id'],
    subjectId: map['subjectId'],
    dayOfWeek: map['dayOfWeek'],
    startTime: map['startTime'],
    endTime: map['endTime'],
    room: map['room'],
    section: map['section'],
    teacherIds: (map['teacherIds'] as List?)?.cast<String>() ?? const [],
  );
}
