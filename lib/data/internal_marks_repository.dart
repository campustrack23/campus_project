// lib/data/internal_marks_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/internal_marks.dart';

class InternalMarksRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<InternalMarks> get _marksRef =>
      _db.collection('internal_marks').withConverter<InternalMarks>(
        fromFirestore: (snapshot, _) =>
            InternalMarks.fromDoc(snapshot),  // safer
        toFirestore: (marks, _) => marks.toMap(),
      );

  // ---------------- READ METHODS ----------------

  Future<List<InternalMarks>> getAllMarks() async {
    final snapshot = await _marksRef.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<InternalMarks>> getMarksForSubject(String subjectId) async {
    final snapshot =
    await _marksRef.where('subjectId', isEqualTo: subjectId).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<InternalMarks>> getVisibleMarksForStudent(
      String studentId) async {
    final snapshot = await _marksRef
        .where('studentId', isEqualTo: studentId)
        .where('isVisibleToStudent', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<InternalMarks>> getAllMarksForStudent(String studentId) async {
    final snapshot =
    await _marksRef.where('studentId', isEqualTo: studentId).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<InternalMarks>> getMarksForTeacher(String teacherId) async {
    final snapshot =
    await _marksRef.where('teacherId', isEqualTo: teacherId).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // ---------------- WRITE METHODS ----------------

  Future<void> updateMarks(InternalMarks marks) async {
    final updated = recalcTotals(marks);
    final docId = '${updated.subjectId}_${updated.studentId}'; // FIXED

    await _marksRef.doc(docId).set(
      updated,
      SetOptions(merge: true),
    );
  }

  Future<void> publishMarksForSubject(
      String subjectId, bool isVisible) async {
    final snapshot =
    await _marksRef.where('subjectId', isEqualTo: subjectId).get();
    if (snapshot.docs.isEmpty) return;

    const int batchLimit = 500;
    final docs = snapshot.docs;

    for (var i = 0; i < docs.length; i += batchLimit) {
      final batch = _db.batch();
      final end =
      (i + batchLimit < docs.length) ? i + batchLimit : docs.length;
      final chunk = docs.sublist(i, end);

      for (final doc in chunk) {
        batch.update(doc.reference, {'isVisibleToStudent': isVisible});
      }

      await batch.commit();
    }
  }

  Future<void> adminOverride(InternalMarks marks) async {
    await updateMarks(marks);
  }

  Future<void> deleteMarks(String subjectId, String studentId) async {
    final docId = '${subjectId}_$studentId';
    await _marksRef.doc(docId).delete();
  }

  // ---------------- UTILITIES ----------------

  /// FIXED: no more missing named parameter error
  InternalMarks recalcTotals(InternalMarks record) {
    return record.recalculateTotal();
  }
}
