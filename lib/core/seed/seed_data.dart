// lib/core/seed/seed_data.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../models/subject.dart';
import '../models/timetable_entry.dart';

class Seeder {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Checks if data exists, and if not, seeds it.
  Future<void> seedIfNeeded() async {
    // Check if users collection is empty
    final userSnapshot = await _db.collection('users').limit(1).get();
    if (userSnapshot.docs.isNotEmpty) {
      // Already seeded
      return;
    }

    final now = DateTime.now();
    const id = Uuid();

    // 1. Create Users

    // Admin
    final admin = UserAccount(
      id: 'admin_id',
      role: UserRole.admin,
      name: 'Admin User',
      email: 'admin@college.edu',
      phone: '9999999999',
      createdAt: now,
    );

    // Teachers
    final t1 = _teacher(id, now, 'Dr. Sangeeta', 'sangeeta@college.edu', '9876543210');
    final t2 = _teacher(id, now, 'Prof. Sharma', 'sharma@college.edu', '9876543211');
    final t3 = _teacher(id, now, 'Dr. Smith', 'smith@college.edu', '9876543212');

    // Students
    final s1 = _stu(id, now, 'Aarav', 'aarav@student.edu', '101', '202301', '9000000001', 4, 'IV-HE');
    final s2 = _stu(id, now, 'Vivaan', 'vivaan@student.edu', '102', '202302', '9000000002', 4, 'IV-HE');

    final allUsers = [admin, t1, t2, t3, s1, s2];

    // 2. Create Subjects
    final yearKit = _YearKit(section: 'IV-HE', id: id);

    // Define subjects
    final sub1 = yearKit.subj('CS401', 'Advanced Flutter', t1);
    final sub2 = yearKit.subj('CS402', 'Cloud Computing', t2);
    final sub3 = yearKit.subj('CS403', 'System Design', t3);
    final sub4 = yearKit.subj('CS404', 'Ethics', t1);

    // 3. Create Timetable (Sample for Mon/Tue)
    // Monday
    yearKit.addEntry(sub1, 'Mon', 0, 'Room 101');
    yearKit.addEntry(sub2, 'Mon', 1, 'Room 102');
    yearKit.addEntry(sub3, 'Mon', 2, 'Lab A'); // Lab
    yearKit.addEntry(sub4, 'Mon', 3, 'Room 101');

    // Tuesday
    yearKit.addEntry(sub2, 'Tue', 0, 'Room 102');
    yearKit.addEntry(sub1, 'Tue', 1, 'Room 101');

    // BATCH WRITE
    final batch = _db.batch();

    for (final u in allUsers) {
      batch.set(_db.collection('users').doc(u.id), u.toMap());
    }
    for (final s in yearKit.subjects) {
      batch.set(_db.collection('subjects').doc(s.id), s.toMap());
    }
    for (final t in yearKit.entries) {
      batch.set(_db.collection('timetable').doc(t.id), t.toMap());
    }

    // Commit everything
    await batch.commit();
  }

  // Helpers
  UserAccount _teacher(Uuid id, DateTime now, String name, String email, String phone) => UserAccount(
    id: id.v4(),
    role: UserRole.teacher,
    name: name,
    email: email,
    phone: phone,
    createdAt: now,
  );

  // FIXED: Added 'email' parameter to signature
  UserAccount _stu(Uuid id, DateTime now, String name, String email, String cr, String er, String phone, int year, String section) => UserAccount(
    id: id.v4(),
    role: UserRole.student,
    name: name,
    email: email,
    phone: phone,
    collegeRollNo: cr,
    examRollNo: er,
    section: section,
    year: year,
    createdAt: now,
  );
}

class _YearKit {
  final String section;
  final Uuid id;
  final List<Subject> subjects = [];
  final List<TimetableEntry> entries = [];

  _YearKit({required this.section, required this.id});

  Subject subj(String code, String name, UserAccount leadTeacher) {
    final s = Subject(
      id: id.v4(),
      code: code,
      name: name,
      department: 'CSE',
      semester: '8',
      section: section,
      teacherId: leadTeacher.id,
    );
    subjects.add(s);
    return s;
  }

  void addEntry(Subject subject, String day, int periodIndex, String room) {
    const times = [
      '08:30-09:30','09:30-10:30','10:30-11:30','11:30-12:30','12:30-13:30',
      '13:30-14:30','14:30-15:30','15:30-16:30','16:30-17:30',
    ];

    if (periodIndex < 0 || periodIndex >= times.length) return;

    final slot = times[periodIndex];
    final start = slot.split('-').first;
    final end = slot.split('-').last;

    entries.add(TimetableEntry(
      id: id.v4(),
      subjectId: subject.id,
      dayOfWeek: day,
      startTime: start,
      endTime: end,
      room: room,
      section: section,
      teacherIds: [subject.teacherId],
    ));
  }
}