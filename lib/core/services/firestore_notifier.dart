// lib/core/services/firestore_notifier.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreNotifier {
  final FirebaseFirestore _db;
  FirestoreNotifier(this._db);

  Future<void> sendToUsers({
    required Iterable<String> userIds,
    required String title,
    required String body,
    required String type, // e.g., 'classChange', 'lowAttendance'
  }) async {
    final batch = _db.batch();
    final now = FieldValue.serverTimestamp();
    for (final uid in userIds) {
      final doc = _db.collection('notifications').doc();
      batch.set(doc, {
        'userId': uid,
        'title': title,
        'body': body,
        'type': type,
        'createdAt': now,
        'seen': false,
      });
    }
    await batch.commit();
  }
}