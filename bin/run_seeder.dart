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
    print('Starting database seed based on new timetable images...');
  }
  try {
    await seeder.seed();
    if (kDebugMode) {
      print('✅ Seeding complete!');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ An error occurred during seeding:');
    }
    if (kDebugMode) {
      print(e);
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
        passwordHash: '',
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
          print('User ${user.email} already exists in Auth. Fetching profile...');
        }
        final snapshot = await _db.collection('users').where('email', isEqualTo: user.email).limit(1).get();
        if (snapshot.docs.isNotEmpty) {
          final existingUser = UserAccount.fromMap(snapshot.docs.first.data());
          if (existingUser.role == UserRole.teacher && user.qualifications.isNotEmpty) {
            await _db.collection('users').doc(existingUser.id).set(
              {'qualifications': user.qualifications},
              SetOptions(merge: true),
            );
            return existingUser.copyWith(qualifications: user.qualifications);
          }
          return existingUser;
        } else {
          throw Exception('User exists in Auth but not in Firestore.');
        }
      }
      if (kDebugMode) {
        print('Error creating user ${user.email}: $e');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating user ${user.email}: $e');
      }
      rethrow;
    }
  }

  Future<void> seed() async {
    final now = DateTime.now();
    const id = Uuid();

    if (kDebugMode) {
      print('Seeding users (Admin, Teachers, Students)...');
    }
    await _createUser(UserAccount(
      id: 'temp_admin', role: UserRole.admin, name: 'Admin', email: 'admin@college.edu',
      phone: '0000000000', passwordHash: '', createdAt: now,
    ), 'Admin@123');

    final tSS = await _createUser(_teacher(now, 'Prof. Sangeeta Srivastava', 'ss@college.edu', '9999901101', ['M.Tech', 'Ph.D.']), 'Teach@123');
    final tSA = await _createUser(_teacher(now, 'Dr. Sunita Arya', 'sa@college.edu', '9999901102', ['Ph.D. in Electronics']), 'Teach@123');
    final tSN = await _createUser(_teacher(now, 'Prof. Swati Nagpal', 'sn@college.edu', '9999901103', ['M.Tech']), 'Teach@123');
    final tAJ = await _createUser(_teacher(now, 'Prof. Amit Jain', 'aj@college.edu', '9999901104', ['M.Sc. Physics', 'M.Tech']), 'Teach@123');
    final tSK = await _createUser(_teacher(now, 'Dr. Sanjeev Kumar', 'sk@college.edu', '9999901105', ['Ph.D.']), 'Teach@123');
    final tRST = await _createUser(_teacher(now, 'Dr. Raghbendra S. Tomar', 'rst@college.edu', '9999901106', ['Ph.D.']), 'Teach@123');
    final tHM = await _createUser(_teacher(now, 'Mr. Harshmani', 'hmy@college.edu', '9999901107', ['M.Tech']), 'Teach@123');
    final tVK = await _createUser(_teacher(now, 'Mr. Vinay Kumar', 'vk@college.edu', '9999901108', ['M.Tech (VLSI)']), 'Teach@123');
    final tSY = await _createUser(_teacher(now, 'Ms. Sheetal Yadav', 'sy@college.edu', '9999901109', ['M.Tech']), 'Teach@123');
    final tSHS = await _createUser(_teacher(now, 'Dr. Shivani Sital', 'shs@college.edu', '9999901110', ['Ph.D.']), 'Teach@123');
    final tShikha = await _createUser(_teacher(now, 'Dr. Shikha', 'shikha@college.edu', '9999901001', ['Ph.D. (Guest)']), 'Teach@123');

    await _createUser(_stu(now, 'Akshay Kumar', 'akshay@student.edu', '6302', '22055558010', '9000000002', 4, 'IV-HE'), 'Stud@123');
    await _createUser(_stu(now, 'Amit Kumar', 'amit@student.edu', '6304', '22055558009', '9000000004', 4, 'IV-HE'), 'Stud@123');
    await _createUser(_stu(now, 'Chandan Kumar Singh', 'chandan@student.edu', '6307', '22055558002', '9000000005', 4, 'IV-HE'), 'Stud@123');
    await _createUser(_stu(now, 'Salman Khan', 'salman@student.edu', '6318', '22055558012', '9000000009', 4, 'IV-HE'), 'Stud@123');
    await _createUser(_stu(now, 'Shruti', 'shruti@student.edu', '6321', '22055558008', '9000000010', 4, 'IV-HE'), 'Stud@123');
    await _createUser(_stu(now, 'Yash Gulati', 'yash@student.edu', '6323', '22055558003', '9000000011', 4, 'IV-HE'), 'Stud@123');
    await _createUser(_stu(now, 'Aditya Singh', 'aditya@student.edu', '6327', '22055558018', '9000000012', 4, 'IV-HE'), 'Stud@123');
    await _createUser(_stu(now, 'Sankalan Saha', 'sankalan@student.edu', '6333', '22055558020', '9000000013', 4, 'IV-HE'), 'Stud@123');
    await _createUser(_stu(now, 'Mohit Chauhan', 'mohit@student.edu', '6341', '22055558021', '9000000014', 4, 'IV-HE'), 'Stud@123');

    if (kDebugMode) {
      print('Users seeded. Clearing and seeding subjects and timetable...');
    }

    await _clearCollection('subjects');
    await _clearCollection('timetable');
    await _clearCollection('internal_marks');

    // --- Define Subjects ---

    // --- FIX: Create separate GE/AEC/VAC/SEC subjects for each year ---
    final y1 = _YearKit(section: 'I-HE', id: id, owner: this, semester: 'FIRST SEMESTER');
    final subjPFP     = y1.subj('PFP', 'Programming Fundamental using Python', tSHS);
    final subjPFPLab  = y1.subj('PFP LAB', 'PFP Lab', tSHS);
    final subjCTN     = y1.subj('CTN', 'Circuit Theory and Network Analysis', tSS);
    final subjCTNLab  = y1.subj('CTN LAB', 'CTN Lab', tSS);
    final subjSD      = y1.subj('SD', 'Semiconductor Devices', tSN);
    final subjSDLab   = y1.subj('SD LAB', 'SD Lab', tSN);
    final subjaecY1  = y1.subj('AEC-Y1', 'Ability Enhancement Course', tShikha);
    final subjgeY1   = y1.subj('GE-Y1', 'Generic Elective', tShikha);
    final subjgelabY1= y1.subj('GE Lab-Y1', 'GE Lab/Tutorial', tShikha);
    final subjvacY1  = y1.subj('VAC-Y1', 'Value Addition Course', tShikha);
    final subjsecY1  = y1.subj('SEC-Y1', 'Skill Enhancement Course', tShikha);

    final y2 = _YearKit(section: 'II-HE', id: id, owner: this, semester: 'THIRD SEMESTER');
    final subjEM      = y2.subj('EM', 'Engineering Mathematics', tSK);
    final subjAE2     = y2.subj('AE-II', 'Analog Electronics-II', tAJ);
    final subjAE2Lab  = y2.subj('AE-II LAB', 'AE-II Lab', tAJ);
    final subjSS      = y2.subj('S&S', 'Signals and Systems', tRST);
    final subjSSLab   = y2.subj('S&S LAB', 'S&S Lab', tRST);
    final subjAIML    = y2.subj('GE/AIML(DSE)', 'AI and Machine Learning', tHM);
    final subjaecY2  = y2.subj('AEC-Y2', 'Ability Enhancement Course', tShikha);
    final subjgelabY2= y2.subj('GE Lab-Y2', 'GE Lab/Tutorial', tShikha);
    final subjvacY2  = y2.subj('VAC-Y2', 'Value Addition Course', tShikha);
    final subjsecY2  = y2.subj('SEC-Y2', 'Skill Enhancement Course', tShikha);

    final y3 = _YearKit(section: 'III-HE', id: id, owner: this, semester: 'FIFTH SEMESTER');
    final subjEMT     = y3.subj('EMT', 'Electromagnetics', tSA);
    final subjCN      = y3.subj('CN', 'Computer Networks', tVK);
    final subjES      = y3.subj('ES', 'Embedded System', tSY);
    final subjCNLab   = y3.subj('CN LAB', 'CN Lab', tVK);
    final subjESLab   = y3.subj('ES LAB', 'ES Lab', tSY);
    final subjEMTLab  = y3.subj('EMT LAB', 'EMT Lab', tSA);
    final subjVLSI    = y3.subj('VLSI', 'Basic VLSI Design', tSK);
    final subjVLSILab = y3.subj('VLSI LAB', 'VLSI Lab', tSK);
    final subjgeY3   = y3.subj('GE-Y3', 'Generic Elective', tShikha);
    final subjsecY3  = y3.subj('SEC-Y3', 'Skill Enhancement Course', tShikha);

    final y4 = _YearKit(section: 'IV-HE', id: id, owner: this, semester: 'SEVENTH SEMESTER');
    final subjCMOS    = y4.subj('CMOS', 'CMOS Digital VLSI Design', tShikha);
    final subjAML     = y4.subj('AML', 'Advanced Machine Learning', tSHS);
    final subjAES     = y4.subj('AES', 'Advanced Embedded System Design', tSY);
    final subjCS      = y4.subj('CS', 'Control Systems', tRST);
    final subjCMOSLab = y4.subj('CMOS LAB', 'CMOS Lab', tShikha);
    final subjAMLLab  = y4.subj('AML LAB', 'AML Lab', tSHS);
    final subjCSLab   = y4.subj('CS LAB', 'CS Lab', tRST);
    final subjAESLab  = y4.subj('AES LAB', 'AES Lab', tSY);
    // --- End of Fix ---

    final subjectsAll = [
      ...y1.subjects, ...y2.subjects, ...y3.subjects, ...y4.subjects
    ];
    final subjectsBatch = _db.batch();
    for (final s in subjectsAll) {
      subjectsBatch.set(_db.collection('subjects').doc(s.id), s.toMap());
    }
    await subjectsBatch.commit();
    if (kDebugMode) {
      print('Seeded ${subjectsAll.length} subjects.');
    }

    final List<TimetableEntry> tt = [];
    void addBlock(String section, String day, int fromP, int toP, Subject subj, String room, List<String> teachers) {
      for (int p = fromP; p <= toP; p++) {
        tt.add(TimetableEntry(
          id: id.v4(), subjectId: subj.id, dayOfWeek: day, startTime: _start(p),
          endTime: _end(p), room: room, section: section, teacherIds: teachers,
        ));
      }
    }

    // --- FIX: Use year-specific GE/AEC/VAC/SEC subjects ---
    addBlock('I-HE', 'Mon', 0, 1, subjPFP, '301', [tSHS.id]);
    addBlock('I-HE', 'Mon', 2, 2, subjPFPLab, 'NEL', [tSHS.id, tSN.id]);
    addBlock('I-HE', 'Mon', 3, 3, subjSD, '301', [tSN.id]);
    addBlock('I-HE', 'Mon', 5, 8, subjvacY1, 'NR', [tShikha.id]);
    addBlock('I-HE', 'Tue', 0, 0, subjCTN, '301', [tSS.id]);
    addBlock('I-HE', 'Tue', 1, 1, subjaecY1, 'NR', [tShikha.id]);
    addBlock('I-HE', 'Tue', 2, 2, subjCTN, '301', [tSS.id]);
    addBlock('I-HE', 'Tue', 3, 3, subjCTN, '301', [tSS.id]);
    addBlock('I-HE', 'Wed', 0, 1, subjPFP, 'NR', [tSHS.id]);
    addBlock('I-HE', 'Wed', 2, 2, subjSDLab, 'NEL', [tSN.id, tSS.id]);
    addBlock('I-HE', 'Wed', 4, 8, subjgeY1, 'NR', [tShikha.id]);
    addBlock('I-HE', 'Thu', 0, 1, subjSD, 'NR', [tSN.id]);
    addBlock('I-HE', 'Thu', 2, 3, subjCTN, 'NR', [tSS.id]);
    addBlock('I-HE', 'Thu', 4, 7, subjgelabY1, 'NR', [tShikha.id]);
    addBlock('I-HE', 'Fri', 0, 0, subjaecY1, 'NR', [tShikha.id]);
    addBlock('I-HE', 'Fri', 2, 3, subjCTNLab, 'NEL', [tSS.id, tAJ.id]);
    addBlock('I-HE', 'Fri', 5, 8, subjsecY1, 'NR', [tShikha.id]);

    addBlock('II-HE', 'Mon', 2, 2, subjEM, '301', [tSK.id]);
    addBlock('II-HE', 'Mon', 3, 4, subjAE2Lab, 'NR', [tAJ.id, tSA.id]);
    addBlock('II-HE', 'Mon', 5, 5, subjEM, 'NR', [tSK.id]);
    addBlock('II-HE', 'Mon', 6, 8, subjvacY2, 'NR', [tShikha.id]);
    addBlock('II-HE', 'Tue', 0, 1, subjSS, 'NEL', [tRST.id]);
    addBlock('II-HE', 'Tue', 2, 3, subjAE2, 'NEL', [tAJ.id, tSA.id]);
    addBlock('II-HE', 'Tue', 4, 4, subjaecY2, 'NR', [tShikha.id]);
    addBlock('II-HE', 'Tue', 6, 8, subjvacY2, 'NR', [tShikha.id]);
    addBlock('II-HE', 'Wed', 0, 1, subjSS, '301', [tRST.id]);
    addBlock('II-HE', 'Wed', 2, 3, subjAE2, '301', [tAJ.id]);
    addBlock('II-HE', 'Wed', 4, 4, subjAIML, 'NR', [tHM.id]);
    addBlock('II-HE', 'Wed', 6, 8, subjaecY2, 'NR', [tShikha.id]);
    addBlock('II-HE', 'Thu', 0, 1, subjAE2, '301', [tAJ.id]);
    addBlock('II-HE', 'Thu', 3, 3, subjgelabY2, 'NR', [tShikha.id]);
    addBlock('II-HE', 'Thu', 4, 5, subjAIML, 'NR', [tHM.id]);
    addBlock('II-HE', 'Thu', 6, 6, subjaecY2, 'NR', [tShikha.id]);
    addBlock('II-HE', 'Fri', 0, 0, subjsecY2, 'NR', [tShikha.id]);
    addBlock('II-HE', 'Fri', 2, 3, subjSSLab, 'NR', [tRST.id, tSA.id]);
    addBlock('II-HE', 'Fri', 4, 5, subjAIML, 'NR', [tHM.id]);
    addBlock('II-HE', 'Fri', 6, 8, subjsecY2, 'NR', [tShikha.id]);

    addBlock('III-HE', 'Mon', 0, 3, subjgeY3, 'NR', [tShikha.id]);
    addBlock('III-HE', 'Mon', 4, 7, subjsecY3, 'NR', [tShikha.id]);
    addBlock('III-HE', 'Tue', 0, 0, subjEMT, '301', [tSA.id]);
    addBlock('III-HE', 'Tue', 1, 2, subjCN, 'NR', [tVK.id]);
    addBlock('III-HE', 'Tue', 3, 3, subjES, 'NR', [tSY.id]);
    addBlock('III-HE', 'Tue', 4, 5, subjCNLab, 'NR', [tVK.id, tSN.id]);
    addBlock('III-HE', 'Tue', 6, 7, subjgeY3, 'NR', [tShikha.id]);
    addBlock('III-HE', 'Wed', 0, 1, subjEMT, '301', [tSA.id]);
    addBlock('III-HE', 'Wed', 2, 3, subjESLab, 'NEL', [tSY.id, tAJ.id]);
    addBlock('III-HE', 'Wed', 4, 5, subjVLSILab, '301', [tSK.id, tSS.id]);
    addBlock('III-HE', 'Wed', 6, 6, subjVLSI, 'NEL', [tSK.id]);
    addBlock('III-HE', 'Wed', 7, 7, subjVLSI, '301', [tSK.id]);
    addBlock('III-HE', 'Thu', 0, 1, subjEMTLab, 'NEL', [tSA.id, tHM.id]);
    addBlock('III-HE', 'Thu', 2, 3, subjVLSI, '301', [tSK.id]);
    addBlock('III-HE', 'Thu', 4, 5, subjVLSILab, 'NEL', [tSK.id, tSS.id]);
    addBlock('III-HE', 'Thu', 6, 7, subjVLSI, '301', [tSK.id]);
    addBlock('III-HE', 'Fri', 0, 1, subjCN, 'NR', [tVK.id]);
    addBlock('III-HE', 'Fri', 4, 5, subjES, '301', [tSY.id]);
    addBlock('III-HE', 'Fri', 6, 6, subjVLSI, '301', [tSK.id]);

    addBlock('IV-HE', 'Wed', 0, 1, subjCMOSLab, 'NEL', [tShikha.id, tSN.id]);
    addBlock('IV-HE', 'Wed', 2, 3, subjAML, 'NR', [tSHS.id]);
    addBlock('IV-HE', 'Wed', 4, 4, subjCSLab, 'NEL', [tRST.id]);
    addBlock('IV-HE', 'Wed', 5, 5, subjAES, 'NR', [tSY.id]);
    addBlock('IV-HE', 'Wed', 6, 6, subjAES, 'NR', [tSY.id]);
    addBlock('IV-HE', 'Thu', 0, 1, subjAMLLab, 'NEL', [tSHS.id]);
    addBlock('IV-HE', 'Thu', 2, 3, subjCMOS, '301', [tSHS.id, tSA.id]);
    addBlock('IV-HE', 'Thu', 4, 4, subjAES, 'NR', [tSY.id]);
    addBlock('IV-HE', 'Thu', 5, 7, subjAESLab, 'NEL', [tSY.id, tAJ.id]);
    addBlock('IV-HE', 'Fri', 0, 1, subjCMOS, '301', [tShikha.id]);
    addBlock('IV-HE', 'Fri', 2, 3, subjAES, '301', [tSY.id]);
    addBlock('IV-HE', 'Fri', 5, 7, subjCS, '301', [tRST.id]);
    addBlock('IV-HE', 'Sat', 0, 0, subjCMOS, '301', [tShikha.id]);
    addBlock('IV-HE', 'Sat', 2, 2, subjCS, '301', [tHM.id]);
    addBlock('IV-HE', 'Sat', 3, 3, subjCS, '301', [tRST.id]);
    // --- End of Fix ---

    final ttBatch = _db.batch();
    for (final t in tt) {
      ttBatch.set(_db.collection('timetable').doc(t.id), t.toMap());
    }
    await ttBatch.commit();
    if (kDebugMode) {
      print('Seeded ${tt.length} timetable entries.');
    }
  }

  UserAccount _teacher(DateTime now, String name, String email, String phone, [List<String> qualifications = const []]) => UserAccount(
    id: 'temp', role: UserRole.teacher, name: name, email: email, phone: phone, passwordHash: '', createdAt: now,
    qualifications: qualifications,
  );

  UserAccount _stu(DateTime now, String name, String email, String cr, String er, String phone, int year, String section) => UserAccount(
    id: 'temp', role: UserRole.student, name: name, email: email, phone: phone, collegeRollNo: cr,
    examRollNo: er, section: section, year: year, passwordHash: '', createdAt: now,
  );

  Future<void> _clearCollection(String name) async {
    final snapshot = await _db.collection(name).limit(500).get();
    if (snapshot.docs.isEmpty) {
      if (kDebugMode) {
        print('Collection "$name" is already empty.');
      }
      return;
    }
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (kDebugMode) {
      print('Cleared ${snapshot.docs.length} documents from "$name".');
    }
  }
}

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