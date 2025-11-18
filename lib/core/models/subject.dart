class Subject {
  final String id;
  final String code;
  final String name;
  final String department;
  final String semester;
  final String section; // e.g., "A"
  final String teacherId;

  Subject({
    required this.id,
    required this.code,
    required this.name,
    required this.department,
    required this.semester,
    required this.section,
    required this.teacherId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'department': department,
        'semester': semester,
        'section': section,
        'teacherId': teacherId,
      };

  factory Subject.fromMap(Map<String, dynamic> map) => Subject(
        id: map['id'],
        code: map['code'],
        name: map['name'],
        department: map['department'],
        semester: map['semester'],
        section: map['section'],
        teacherId: map['teacherId'],
      );
}
