// lib/data/remark_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/remark.dart';
import '../core/models/notification.dart'; // For NotificationType enum
import '../core/services/firestore_notifier.dart';

class RemarkRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreNotifier _notifier;

  // Inject FirestoreNotifier for push notifications
  RemarkRepository(this._notifier);

  CollectionReference<StudentRemark> get _remarksRef =>
      _db.collection('remarks').withConverter<StudentRemark>(
        fromFirestore: (snapshot, _) => StudentRemark.fromMap(snapshot.data()!),
        toFirestore: (remark, _) => remark.toMap(),
      );

  // Predictable document ID to ensure unique remark per teacher/student pair
  String _docId(String teacherId, String studentId) => '${teacherId}_$studentId';

  // --- READ METHODS ---

  /// Get remark for specific teacher-student pair
  Future<StudentRemark?> getRemark(String teacherId, String studentId) async {
    final doc = await _remarksRef.doc(_docId(teacherId, studentId)).get();
    return doc.data();
  }

  /// Get all remarks given by a teacher
  Future<List<StudentRemark>> forTeacher(String teacherId) async {
    final snapshot = await _remarksRef.where('teacherId', isEqualTo: teacherId).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Get all remarks received by a student, sorted newest first
  Future<List<StudentRemark>> forStudent(String studentId) async {
    final snapshot = await _remarksRef
        .where('studentId', isEqualTo: studentId)
        .orderBy('updatedAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // --- WRITE METHODS ---

  /// Upsert a remark and notify the student
  Future<void> upsertRemark({
    required String teacherId,
    required String studentId,
    required String tag,
  }) async {
    final docId = _docId(teacherId, studentId);
    final now = DateTime.now();

    final remark = StudentRemark(
      id: docId,
      teacherId: teacherId,
      studentId: studentId,
      tag: tag,
      updatedAt: now,
    );

    await _remarksRef.doc(docId).set(remark, SetOptions(merge: true));

    // Notify student about new/updated remark
    await _notifier.sendToUsers(
      userIds: [studentId],
      title: 'New Remark',
      body: 'A teacher has added a remark: "$tag"',
      type: NotificationType.remarkSaved,
    );
  }

  /// Delete a remark by teacher-student pair
  Future<void> deleteRemark(String teacherId, String studentId) async {
    await _remarksRef.doc(_docId(teacherId, studentId)).delete();
  }
}
