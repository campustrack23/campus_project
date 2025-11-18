// lib/data/remark_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/models/remark.dart';

class RemarkRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<StudentRemark> get _remarksRef =>
      _db.collection('remarks').withConverter<StudentRemark>(
        fromFirestore: (snapshot, _) => StudentRemark.fromMap(snapshot.data()!),
        toFirestore: (remark, _) => remark.toMap(),
      );

  // An efficient upsert by using a predictable document ID.
  String _docId(String teacherId, String studentId) => '${teacherId}_$studentId';

  Future<StudentRemark?> getRemark(String teacherId, String studentId) async {
    final doc = await _remarksRef.doc(_docId(teacherId, studentId)).get();
    return doc.data();
  }

  Future<void> upsertRemark({
    required String teacherId,
    required String studentId,
    required String tag,
  }) async {
    final docId = _docId(teacherId, studentId);
    final item = StudentRemark(
      id: docId, // Use the predictable ID
      teacherId: teacherId,
      studentId: studentId,
      tag: tag,
      updatedAt: DateTime.now(),
    );
    await _remarksRef.doc(docId).set(item, SetOptions(merge: true));
  }

  Future<List<StudentRemark>> forTeacher(String teacherId) async {
    final snapshot = await _remarksRef.where('teacherId', isEqualTo: teacherId).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }
}