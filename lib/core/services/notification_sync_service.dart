// lib/core/services/notification_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // for debugPrint

import '../../data/notification_repository.dart';
import '../models/notification.dart';
import 'notification_service.dart';

class NotificationSyncService {
  final Ref ref;
  final FirebaseFirestore db;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  NotificationSyncService(this.ref, this.db);

  void start(String userId) {
    stop(); // Ensure no duplicate listeners
    debugPrint('NotificationSync: Starting sync for user $userId');

    final notifRepo = ref.read(notifRepoProvider);
    final notifService = ref.read(notifServiceProvider);

    _sub = db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false) // match AppNotification model field
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) async {
      if (snap.docChanges.isEmpty) return;

      debugPrint('NotificationSync: Received ${snap.docChanges.length} updates');

      // Spam prevention: aggregate notifications when too many arrive
      if (snap.docChanges.length > 3) {
        await notifService.showLocal(
          'New Notifications',
          'You have ${snap.docChanges.length} new updates.',
        );
      }

      int shownCount = 0;

      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data();
        if (data == null) continue;

        final docId = change.doc.id;
        final title = data['title']?.toString() ?? 'Notification';
        final body = data['body']?.toString() ?? '';
        final typeStr = data['type']?.toString() ?? 'general';
        final type = _parseType(typeStr);

        final createdAt = (data['createdAt'] is Timestamp)
            ? (data['createdAt'] as Timestamp).toDate()
            : DateTime.now();

        final notification = AppNotification(
          id: docId,
          userId: userId,
          title: title,
          body: body,
          type: type,
          createdAt: createdAt,
          read: false,
        );

        // Save notification to local repository
        await notifRepo.save(notification);

        // Show local popup only for small batches and limit display
        if (snap.docChanges.length <= 3 && shownCount < 3) {
          await notifService.showLocal(title, body);
          shownCount++;
        }

        // Mark notification as read in Firestore to avoid re-syncing
        try {
          await change.doc.reference.update({'read': true});
        } catch (e) {
          debugPrint('NotificationSync: Failed to mark read: $e');
        }
      }
    }, onError: (e) {
      debugPrint('NotificationSync: Error in stream: $e');
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    debugPrint('NotificationSync: Service stopped');
  }

  NotificationType _parseType(String s) {
    for (final t in NotificationType.values) {
      if (t.name == s) return t;
    }
    return NotificationType.general;
  }
}
