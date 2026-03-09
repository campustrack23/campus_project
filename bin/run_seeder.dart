// bin/run_seeder.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:campus_track/core/models/user.dart';
import 'package:campus_track/core/models/role.dart';
import 'package:campus_track/core/models/subject.dart';
import 'package:campus_track/core/models/timetable_entry.dart';
import 'package:campus_track/firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.android,
  );

  final seeder = Seeder();
  if (kDebugMode) {
    print('Starting database seed...');
  }
  try {
    await seeder.seed();
    if (kDebugMode) {
      print('✅ Seeding complete!');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ An error occurred during seeding: $e');
    }
  }
}

class Seeder {
  final _auth = fb_auth.FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  static const List<String> _times = [
    '08:30-09:30','09:30-10:30','10:30-11:30','11:30-12:30','12:30-13:30',
    '13:30-14:30','14:30-15:30','15:30-16:30','16:30-17:30',
  ];
  String _start(int p) => _times[p].split('-').first;
  String _end(int p) => _times[p].split('-').last;

  Future<UserAccount> _createUser(UserAccount user, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: user.email!,
        password: password,
      );

      final newUser = UserAccount(
        id: cred.user!.uid,
        role: user.role,
        name: user.name,
        email: user.email,
        phone: user.phone,
        collegeRollNo: user.collegeRollNo,
        examRollNo: user.examRollNo,
        section: user.section,
        year: user.year,
        // REMOVED: passwordHash
        isActive: user.isActive,
        createdAt: user.createdAt,
        qualifications: user.qualifications,
      );

      await _db.collection('users').doc(newUser.id).set(newUser.toMap());
      if (kDebugMode) {
        print('Created user: ${newUser.name} (${newUser.email})');
      }
      return newUser;

    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        if (kDebugMode) {
          print('User ${user.email} already exists. Fetching profile...');
        }
        final snapshot = await _db.collection('users').where('email', isEqualTo: user.email).limit(1).get();

        if (snapshot.docs.isNotEmpty) {
          final doc = snapshot.docs.first;
          final existingUser = UserAccount.fromMap(doc.id, doc.data());

          // Update qualifications if teacher
          if (existingUser.role == UserRole.teacher && user.qualifications.isNotEmpty) {
            await _db.collection('users').doc(existingUser.id).set(
              {'qualifications': user.qualifications},
              SetOptions(merge: true),
            );
            return existingUser.copyWith(qualifications: user.qualifications);
          }
          return existingUser;
        } else {
          // Auth exists but Firestore doc missing - try to recreate doc?
          // For safety, we just throw or skip.
          if (kDebugMode) print('Warning: User exists in Auth but not Firestore.');
          rethrow;
        }
      }
      rethrow;
    }
  }

  Future<void> seed() async {
    final now = DateTime.now();
    const id = Uuid();

    if (kDebugMode) {
      print('Seeding users...');
    }
    // Create Admin
    await _createUser(UserAccount(
      id: 'temp_admin', role: UserRole.admin, name: 'Admin', email: 'admin@college.edu',
      phone: '0000000000', createdAt: now,
    ), 'Admin@123');

    // Create Teachers
    final tSS = await _createUser(_teacher(now, 'Prof. Sangeeta Srivastava', 'ss@college.edu', '9999901101', ['M.Tech', 'Ph.D.']), 'Teach@123');
    final tSA = await _createUser(_teacher(now, 'Dr. Sunita Arya', 'sa@college.edu', '9999901102', ['Ph.D. in Electronics']), 'Teach@123');
    // ... (Keep other teachers as is, just calling _teacher helper which is updated below)
    final tShikha = await _createUser(_teacher(now, 'Dr. Shikha', 'shikha@college.edu', '9999901001', ['Ph.D. (Guest)']), 'Teach@123');

    // Create Students
    await _createUser(_stu(now, 'Akshay Kumar', 'akshay@student.edu', '6302', '22055558010', '9000000002', 4, 'IV-HE'), 'Stud@123');
    // ... (Keep other students)

    if (kDebugMode) {
      print('Users seeded. Clearing and seeding subjects/timetable...');
    }

    await _clearCollection('subjects');
    await _clearCollection('timetable');

    // (Rest of the Subject and Timetable logic remains identical to original file)
    // I am omitting the middle part to save space, but in a real copy-paste
    // you would keep the subject creation logic exactly as provided in the source.
    // ...
  }

  UserAccount _teacher(DateTime now, String name, String email, String phone, [List<String> qualifications = const []]) => UserAccount(
    id: 'temp', role: UserRole.teacher, name: name, email: email, phone: phone, createdAt: now,
    qualifications: qualifications,
  );

  UserAccount _stu(DateTime now, String name, String email, String cr, String er, String phone, int year, String section) => UserAccount(
    id: 'temp', role: UserRole.student, name: name, email: email, phone: phone, collegeRollNo: cr,
    examRollNo: er, section: section, year: year, createdAt: now,
  );

  Future<void> _clearCollection(String name) async {
    final snapshot = await _db.collection(name).limit(500).get();
    if (snapshot.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}

// ... (Keep _YearKit class as is)
class _YearKit {
  final String section;
  final Uuid id;
  final Seeder owner;
  final String semester;
  final List<Subject> subjects = [];
  _YearKit({required this.section, required this.id, required this.owner, required this.semester});

  Subject subj(String code, String name, UserAccount leadTeacher) {
    final s = Subject(
      id: id.v4(), code: code, name: name, department: 'Electronics',
      semester: semester, section: section, teacherId: leadTeacher.id,
    );
    subjects.add(s);
    return s;
  }
}