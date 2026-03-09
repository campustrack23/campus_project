import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notification.dart';
import 'notification_service.dart';

class FirestoreNotifier {
  final FirebaseFirestore _db;
  final NotificationService _localService;

  /// Constructor accepts both Firestore & NotificationService
  FirestoreNotifier({
    FirebaseFirestore? firestore,
    required NotificationService localService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _localService = localService;

  // ---------------------------------------------------------------------------
  // SEND TO MULTIPLE USERS (AUTO HANDLES 500 BATCH LIMIT)
  // ---------------------------------------------------------------------------

  Future<void> sendToUsers({
    required Iterable<String> userIds,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    if (userIds.isEmpty) return;

    const int batchLimit = 500;
    final List<String> allUsers = userIds.toList();

    for (var i = 0; i < allUsers.length; i += batchLimit) {
      final batch = _db.batch();
      final end =
      (i + batchLimit < allUsers.length) ? i + batchLimit : allUsers.length;
      final chunk = allUsers.sublist(i, end);

      final now = DateTime.now();

      for (final uid in chunk) {
        final docRef = _db.collection('notifications').doc();

        final notification = AppNotification(
          id: docRef.id,
          userId: uid,
          title: title,
          body: body,
          type: type,
          read: false,
          createdAt: now,
          data: data,
        );

        batch.set(docRef, notification.toMap());
      }

      await batch.commit();
    }
  }

  // ---------------------------------------------------------------------------
  // SEND TO SINGLE USER (CONVENIENCE)
  // ---------------------------------------------------------------------------

  Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    await sendToUsers(
      userIds: [userId],
      title: title,
      body: body,
      type: type,
      data: data,
    );
  }

  // ---------------------------------------------------------------------------
  // OPTIONAL: LOCAL NOTIFICATION HELPER
  // ---------------------------------------------------------------------------

  Future<void> sendLocalOnly({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localService.showLocal(
      title,
      body,
      payload: payload,
    );
  }
}
