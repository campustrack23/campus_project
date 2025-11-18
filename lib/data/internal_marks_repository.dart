// lib/data/internal_marks_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/internal_marks.dart';

class InternalMarksRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<InternalMarks> get _marksRef =>
      _db.collection('internal_marks').withConverter<InternalMarks>(
        fromFirestore: (snapshot, _) => InternalMarks.fromMap(snapshot.data()!),
        toFirestore: (marks, _) => marks.toMap(),
      );

  // --- FIX: Added a new method to get ALL marks for the admin page ---
  Future<List<InternalMarks>> getAllMarks() async {
    final snapshot = await _marksRef.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
  // --- End of Fix ---

  // Get all marks for a specific subject (for teachers)
  Future<List<InternalMarks>> getMarksForSubject(String subjectId) async {
    final snapshot = await _marksRef.where('subjectId', isEqualTo: subjectId).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Get all published marks for a specific student
  Future<List<InternalMarks>> getVisibleMarksForStudent(String studentId) async {
    final snapshot = await _marksRef
        .where('studentId', isEqualTo: studentId)
        .where('isVisibleToStudent', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Update or create a single student's marks
  Future<void> updateMarks(InternalMarks marks) async {
    final docId = '${marks.subjectId}_${marks.studentId}';
    await _marksRef.doc(docId).set(marks, SetOptions(merge: true));
  }

  // Publish or unpublish all marks for a subject
  Future<void> publishMarksForSubject(String subjectId, bool isVisible) async {
    final snapshot = await _marksRef.where('subjectId', isEqualTo: subjectId).get();
    if (snapshot.docs.isEmpty) return; // No marks to publish

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'isVisibleToStudent': isVisible});
    }
    await batch.commit();
  }
}