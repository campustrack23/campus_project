// lib/core/services/firestore_notifier.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification.dart';
import 'notification_service.dart';

class FirestoreNotifier {
  final FirebaseFirestore _db;
  final NotificationService _localService;

  FirestoreNotifier({
    FirebaseFirestore? firestore,
    required NotificationService localService,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _localService = localService;

  // ---------------------------------------------------------------------------
  // SECURE SEND TO MULTIPLE USERS
  // ---------------------------------------------------------------------------
  Future<void> sendToUsers({
    required Iterable<String> userIds,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? data,
  }) async {
    if (userIds.isEmpty) return;

    // SECURITY FIX: Prevent client-side manipulation of the notifications collection.
    // Instead of bypassing security rules to write N documents to other users' paths, 
    // we write a single intent to 'notification_requests'. A Firebase Cloud Function 
    // MUST process this queue to securely distribute the notifications.
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    await _db.collection('notification_requests').add({
      'targetUserIds': userIds.toList(),
      'title': title,
      'body': body,
      'type': type.name,
      'data': data,
      'requestedBy': currentUserId ?? 'system',
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  // ---------------------------------------------------------------------------
  // SEND TO SINGLE USER
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
  // LOCAL NOTIFICATION HELPER
  // ---------------------------------------------------------------------------
  Future<void> sendLocalOnly({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localService.showLocal(title, body, payload: payload);
  }
}