// lib/core/services/firestore_notifier.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification.dart'; // Import to use the Enum

class FirestoreNotifier {
  final FirebaseFirestore _db;
  FirestoreNotifier(this._db);

  /// Sends a notification to a list of users.
  /// Automatically handles Firestore's 500-operation batch limit.
  Future<void> sendToUsers({
    required Iterable<String> userIds,
    required String title,
    required String body,
    required NotificationType type, // Use Enum for safety
  }) async {
    if (userIds.isEmpty) return;

    const int batchLimit = 500;
    final List<String> allUsers = userIds.toList();

    for (var i = 0; i < allUsers.length; i += batchLimit) {
      final batch = _db.batch();
      final end = (i + batchLimit < allUsers.length) ? i + batchLimit : allUsers.length;
      final chunk = allUsers.sublist(i, end);

      final now = FieldValue.serverTimestamp();

      for (final uid in chunk) {
        final docRef = _db.collection('notifications').doc();

        batch.set(docRef, {
          'id': docRef.id, // Store ID for easier local access
          'userId': uid,
          'title': title,
          'body': body,
          'type': type.name,
          'createdAt': now,
          'read': false, // Use 'read' to match model naming
        });
      }

      await batch.commit();
    }
  }

  /// Sends a notification to a single user for convenience.
  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
  }) async {
    await sendToUsers(
      userIds: [userId],
      title: title,
      body: body,
      type: type,
    );
  }
}
