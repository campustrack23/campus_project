import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/attendance.dart';
import '../core/models/attendance_session.dart';

// Simple provider definition to ensure access in consumers
final attendanceRepoProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

class AttendanceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------------------------------------------------------------------
  // COLLECTION REFERENCES
  // ---------------------------------------------------------------------------

  CollectionReference<AttendanceRecord> get _recordsRef =>
      _db.collection('attendance').withConverter<AttendanceRecord>(
        fromFirestore: (snap, _) =>
            AttendanceRecord.fromMap(snap.id, snap.data()!),
        toFirestore: (rec, _) => rec.toMap(),
      );

  CollectionReference<AttendanceSession> get sessionsRef =>
      _db.collection('attendance_sessions').withConverter<AttendanceSession>(
        fromFirestore: (snap, _) =>
            AttendanceSession.fromMap(snap.id, snap.data()!),
        toFirestore: (session, _) => session.toMap(),
      );

  // ---------------------------------------------------------------------------
  // SECURE MARKING (TRANSACTIONAL)
  // ---------------------------------------------------------------------------

  /// Marks a student as PRESENT for a given session.
  /// Validates:
  /// 1. Session exists.
  /// 2. Session is ACTIVE.
  /// 3. Student hasn't already marked.
  Future<void> markPresentSecure({
    required String sessionId,
    required String studentId,
  }) async {
    final sessionRef = sessionsRef.doc(sessionId);
    // Deterministic ID to prevent duplicate records for same student/session
    final recordId = '${sessionId}_$studentId';
    final recordRef = _recordsRef.doc(recordId);

    await _db.runTransaction((transaction) async {
      final sessionSnap = await transaction.get(sessionRef);

      if (!sessionSnap.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: 'Attendance session not found.',
        );
      }

      final session = sessionSnap.data()!;
      if (!session.isActive) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: 'Attendance session is closed.',
        );
      }

      final recordSnap = await transaction.get(recordRef);
      if (recordSnap.exists) {
        // Already marked, just return (idempotent) or throw if you want UI feedback
        // throwing allows the UI to say "Already marked"
        throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'already-exists',
            message: 'You have already marked attendance for this session.');
      }

      // Create the record
      final newRecord = AttendanceRecord(
        id: recordId,
        sessionId: sessionId,
        studentId: studentId,
        subjectId: session.subjectId,
        date: DateTime.now(), // Store actual mark time
        slot: session.slot,
        status: AttendanceStatus.present,
        markedByTeacherId: session.teacherId, // Or "SELF" if tracking source
        markedAt: DateTime.now(),
      );

      transaction.set(recordRef, newRecord);
    });
  }

  // ---------------------------------------------------------------------------
  // READ METHODS
  // ---------------------------------------------------------------------------

  Future<List<AttendanceRecord>> allRecords() async {
    final snap = await _recordsRef
        .orderBy('date', descending: true)
        .limit(500)
        .get();

    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<AttendanceRecord>> getRecordsForSession(String sessionId) async {
    final snap =
    await _recordsRef.where('sessionId', isEqualTo: sessionId).get();
    return snap.docs.map((d) => d.data()).toList();
  }

  Future<List<AttendanceRecord>> forStudent(String studentId) async {
    final snap = await _recordsRef
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .limit(200)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  // ---------------------------------------------------------------------------
  // TEACHER / ADMIN MANUAL OVERRIDES
  // ---------------------------------------------------------------------------

  Future<void> markManual({
    required String subjectId,
    required String studentId,
    required DateTime date,
    required String slot,
    required AttendanceStatus status,
    required String markedByTeacherId,
  }) async {
    // Generate a unique ID based on day/slot/student so we don't have duplicates
    // Note: 'date' should be stripped of time for the ID part if you want one-per-slot constraint
    final dateKey =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final docId = '${subjectId}_${studentId}_${dateKey}_$slot';

    final record = AttendanceRecord(
      id: docId,
      sessionId: 'MANUAL',
      studentId: studentId,
      subjectId: subjectId,
      date: date,
      slot: slot,
      status: status,
      markedByTeacherId: markedByTeacherId,
      markedAt: DateTime.now(),
    );

    await _recordsRef.doc(docId).set(record, SetOptions(merge: true));
  }
}