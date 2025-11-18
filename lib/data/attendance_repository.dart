// lib/data/attendance_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/models/attendance.dart';
import '../core/models/attendance_session.dart';
import '../core/models/user.dart';
import 'auth_repository.dart';

class AttendanceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection for PERMANENT attendance records
  CollectionReference<AttendanceRecord> get _recordsRef =>
      _db.collection('attendance').withConverter<AttendanceRecord>(
        fromFirestore: (snapshot, _) => AttendanceRecord.fromMap(snapshot.data()!),
        toFirestore: (record, _) => record.toMap(),
      );

  // FIX: Renamed _sessionsRef to sessionsRef (made public)
  CollectionReference<AttendanceSession> get sessionsRef =>
      _db.collection('attendance_sessions').withConverter<AttendanceSession>(
        fromFirestore: (snapshot, _) => AttendanceSession.fromMap(snapshot.data()!),
        toFirestore: (session, _) => session.toMap(),
      );

  // FIX: Updated this to use the new public sessionsRef
  CollectionReference _attendeesRef(String sessionId) =>
      sessionsRef.doc(sessionId).collection('attendees');


  // --- NEW QR SESSION METHODS ---

  Future<AttendanceSession> createAttendanceSession({
    required String teacherId,
    required String subjectId,
    required String section,
    required String slot,
  }) async {
    final now = DateTime.now();
    final session = AttendanceSession(
      id: const Uuid().v4(),
      teacherId: teacherId,
      subjectId: subjectId,
      section: section,
      slot: slot,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
    );
    // FIX: Updated this to use the new public sessionsRef
    await sessionsRef.doc(session.id).set(session);
    return session;
  }

  Future<String> markStudentPresent({
    required String sessionId,
    required String studentId,
    required String studentName
  }) async {
    // FIX: Updated this to use the new public sessionsRef
    final sessionDoc = await sessionsRef.doc(sessionId).get();
    final session = sessionDoc.data();

    if (session == null) {
      throw Exception('Attendance session not found.');
    }
    if (session.status == AttendanceSessionStatus.closed) {
      throw Exception('Session is closed.');
    }
    if (DateTime.now().isAfter(session.expiresAt)) {
      throw Exception('Session has expired.');
    }

    // Mark the student as present in the subcollection
    await _attendeesRef(sessionId).doc(studentId).set({
      'studentId': studentId,
      'name': studentName,
      'scannedAt': FieldValue.serverTimestamp(),
    });

    // Attempt to get subject name for a clearer message
    String subjectName = 'this class';
    try {
      final subjectDoc = await _db.collection('subjects').doc(session.subjectId).get();
      if (subjectDoc.exists) {
        subjectName = subjectDoc.data()!['name'] ?? 'this class';
      }
    } catch (_) {}

    return 'Successfully marked present for $subjectName';
  }

  // Real-time stream for the teacher to see who has scanned
  Stream<List<QueryDocumentSnapshot>> listenToAttendees(String sessionId) {
    return _attendeesRef(sessionId).snapshots().map((snapshot) => snapshot.docs);
  }

  Future<List<AttendanceRecord>> finalizeAttendance(String sessionId) async {
    // FIX: Updated this to use the new public sessionsRef
    final sessionDoc = await sessionsRef.doc(sessionId).get();
    final session = sessionDoc.data();
    if (session == null) throw Exception('Session not found.');

    // 1. Close the session
    // FIX: Updated this to use the new public sessionsRef
    await sessionsRef.doc(sessionId).update({'status': 'closed'});

    // 2. Get all students who successfully scanned
    final attendeesSnapshot = await _attendeesRef(sessionId).get();
    final presentStudentIds = attendeesSnapshot.docs.map((doc) => doc.id).toSet();

    // 3. Get all students who are supposed to be in that section
    final authRepo = AuthRepository(); // A bit of a shortcut, ideally inject via provider
    final allStudentsInSection = await authRepo.studentsInSection(session.section);

    final List<AttendanceRecord> finalRecords = [];
    final now = DateTime.now();

    // 4. Loop through all students and mark them present or absent
    for (final student in allStudentsInSection) {
      final status = presentStudentIds.contains(student.id)
          ? AttendanceStatus.present
          : AttendanceStatus.absent;

      final record = await _markInternal(
        subjectId: session.subjectId,
        studentId: student.id,
        date: now,
        slot: session.slot,
        status: status,
        markedByTeacherId: session.teacherId,
      );
      finalRecords.add(record);
    }
    return finalRecords;
  }

  // --- EXISTING METHODS ---

  Future<List<AttendanceRecord>> allRecords() async {
    final snapshot = await _recordsRef.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // This is the individual 'edit' function for teachers/admins
  Future<void> mark({
    required String subjectId,
    required String studentId,
    required DateTime date,
    required String slot,
    required AttendanceStatus status,
    required String markedByTeacherId,
  }) async {
    await _markInternal(
      subjectId: subjectId,
      studentId: studentId,
      date: date,
      slot: slot,
      status: status,
      markedByTeacherId: markedByTeacherId,
    );
  }

  // Internal function to handle the upsert logic
  Future<AttendanceRecord> _markInternal({
    required String subjectId,
    required String studentId,
    required DateTime date,
    required String slot,
    required AttendanceStatus status,
    required String markedByTeacherId,
  }) async {
    // --- FIX: Use a proper timestamp range query ---
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDay = normalizedDate.add(const Duration(days: 1));

    final query = await _recordsRef
        .where('studentId', isEqualTo: studentId)
        .where('subjectId', isEqualTo: subjectId)
        .where('slot', isEqualTo: slot)
        .where('date', isGreaterThanOrEqualTo: normalizedDate) // Start of day
        .where('date', isLessThan: nextDay) // Before start of next day
        .limit(1)
        .get();
    // --- End of Fix ---

    final record = AttendanceRecord(
      id: query.docs.isNotEmpty ? query.docs.first.id : const Uuid().v4(),
      subjectId: subjectId,
      studentId: studentId,
      date: normalizedDate,
      slot: slot,
      status: status,
      markedByTeacherId: markedByTeacherId,
      markedAt: DateTime.now(),
    );

    await _recordsRef.doc(record.id).set(record, SetOptions(merge: true));
    return record;
  }


  Future<List<AttendanceRecord>> forStudent(String studentId) async {
    final snapshot = await _recordsRef.where('studentId', isEqualTo: studentId).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<AttendanceRecord>> forSubjectAndDate(String subjectId, DateTime date) async {
    // --- FIX: Use a proper timestamp range query ---
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final nextDay = normalizedDate.add(const Duration(days: 1));
    final snapshot = await _recordsRef
        .where('subjectId', isEqualTo: subjectId)
        .where('date', isGreaterThanOrEqualTo: normalizedDate)
        .where('date', isLessThan: nextDay)
        .get();
    // --- End of Fix ---
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}