// lib/data/attendance_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/models/attendance.dart';
import '../core/models/attendance_session.dart';
import '../core/models/user.dart';

class AttendanceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<AttendanceRecord> get _recordsRef =>
      _db.collection('attendance').withConverter<AttendanceRecord>(
        fromFirestore: (snap, _) =>
            AttendanceRecord.fromMap(snap.id, snap.data()!),
        toFirestore: (rec, _) => rec.toMap(),
      );

  CollectionReference<AttendanceSession> get sessionsRef =>
      _db.collection('attendance_sessions').withConverter<AttendanceSession>(
        fromFirestore: (snap, _) =>
            AttendanceSession.fromMap(snap.id, snap.data()),
        toFirestore: (session, _) => session.toMap(),
      );

  CollectionReference _attendeesRef(String sessionId) =>
      sessionsRef.doc(sessionId).collection('attendees');

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> listenToAttendees(
      String sessionId) {
    return _attendeesRef(sessionId)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => d as QueryDocumentSnapshot<Map<String, dynamic>>)
        .toList());
  }

  Future<List<AttendanceRecord>> allRecords() async {
    final snapshot = await _recordsRef.orderBy('date', descending: true).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ---------------- Create Session ----------------
  Future<AttendanceSession> createAttendanceSession({
    required String teacherId,
    required String subjectId,
    required String section,
    required String slot,
  }) async {
    // Check for existing active session to prevent duplicates
    final existing = await sessionsRef
        .where('teacherId', isEqualTo: teacherId)
        .where('subjectId', isEqualTo: subjectId)
        .where('section', isEqualTo: section)
        .where('status', isEqualTo: 'open')
        .get();

    for (var doc in existing.docs) {
      if (!doc.data().isExpired) {
        return doc.data();
      }
    }

    // Use UTC for server consistency
    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();

    final session = AttendanceSession(
      id: id,
      teacherId: teacherId,
      subjectId: subjectId,
      section: section,
      slot: slot,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
      status: AttendanceSessionStatus.open,
    );

    await sessionsRef.doc(id).set(session);
    return session;
  }

  // ---------------- Mark Present (Transaction) ----------------
  Future<String> markStudentPresent({
    required String sessionId,
    required String studentId,
    required String studentName,
  }) async {
    return _db.runTransaction((transaction) async {
      final sessionDocRef = sessionsRef.doc(sessionId);
      final attendeeDocRef = _attendeesRef(sessionId).doc(studentId);

      final sessionSnap = await transaction.get(sessionDocRef);
      if (!sessionSnap.exists) throw Exception('Session does not exist.');

      final session = sessionSnap.data()!;
      if (!session.isActive) throw Exception('Session closed or expired.');

      final attendeeSnap = await transaction.get(attendeeDocRef);
      if (attendeeSnap.exists) return 'Already marked present.';

      transaction.set(attendeeDocRef, {
        'studentId': studentId,
        'name': studentName,
        'scannedAt': FieldValue.serverTimestamp(),
      });

      return 'Marked Present';
    });
  }

  // ---------------- Finalize Attendance (TIMEZONE FIX) ----------------
  Future<List<AttendanceRecord>> finalizeAttendance({
    required String sessionId,
    required List<UserAccount> studentsInSection,
  }) async {
    final sessionDoc = await sessionsRef.doc(sessionId).get();
    final session = sessionDoc.data();
    if (session == null) throw Exception('Session not found.');

    final attendeeSnapshot = await _attendeesRef(sessionId).get();
    final presentStudentIds = attendeeSnapshot.docs.map((doc) => doc.id).toSet();

    final batch = _db.batch();
    final List<AttendanceRecord> createdRecords = [];

    // FIX: Use SESSION date (converted to Local), not "Current Moment"
    // This ensures if a class happens at 11:55 PM and is finalized at 12:05 AM,
    // it counts for the correct day.
    final sessionDateLocal = session.createdAt.toLocal();
    final dateOnly = DateTime(sessionDateLocal.year, sessionDateLocal.month, sessionDateLocal.day);

    for (final student in studentsInSection) {
      final isPresent = presentStudentIds.contains(student.id);
      final status = isPresent ? AttendanceStatus.present : AttendanceStatus.absent;

      final docId = _generateRecordId(session.subjectId, student.id, dateOnly, session.slot);
      final docRef = _recordsRef.doc(docId);

      final record = AttendanceRecord(
        id: docId,
        subjectId: session.subjectId,
        studentId: student.id,
        date: dateOnly,
        slot: session.slot,
        status: status,
        markedByTeacherId: session.teacherId,
        markedAt: DateTime.now(),
      );

      batch.set(docRef, record, SetOptions(merge: true));
      createdRecords.add(record);
    }

    batch.update(sessionsRef.doc(sessionId), {'status': 'closed'});
    await batch.commit();

    return createdRecords;
  }

  // ---------------- Manual Marking ----------------
  Future<void> mark({
    required String subjectId,
    required String studentId,
    required DateTime date,
    required String slot,
    required AttendanceStatus status,
    required String markedByTeacherId,
  }) async {
    // Ensure date passed in is already Local Midnight, but safeguard here:
    final localDate = date.toLocal();
    final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);

    final docId = _generateRecordId(subjectId, studentId, dateOnly, slot);

    final record = AttendanceRecord(
      id: docId,
      subjectId: subjectId,
      studentId: studentId,
      date: dateOnly,
      slot: slot,
      status: status,
      markedByTeacherId: markedByTeacherId,
      markedAt: DateTime.now(),
    );

    await _recordsRef.doc(docId).set(record, SetOptions(merge: true));
  }

  // ---------------- Queries ----------------
  Future<List<AttendanceRecord>> forStudent(String studentId) async {
    final snapshot = await _recordsRef
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<AttendanceRecord>> forSubjectAndDate(String subjectId, DateTime date) async {
    // Normalize input date to Local Midnight
    final d = date.toLocal();
    final normalizedDate = DateTime(d.year, d.month, d.day);

    // Fetch by subject first
    final snapshot = await _recordsRef.where('subjectId', isEqualTo: subjectId).get();

    // Filter by date in memory to avoid complex Firestore indexes
    // and ensure timezone matching matches the "dateOnly" logic above
    return snapshot.docs
        .map((doc) => doc.data())
        .where((r) =>
    r.date.year == normalizedDate.year &&
        r.date.month == normalizedDate.month &&
        r.date.day == normalizedDate.day)
        .toList();
  }

  String _generateRecordId(String subject, String student, DateTime date, String slot) {
    final dateStr = DateFormat('yyyyMMdd').format(date);
    final cleanSlot = slot.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    return '${subject}_${student}_${dateStr}_$cleanSlot';
  }
}