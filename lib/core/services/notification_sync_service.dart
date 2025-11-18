// lib/core/services/notification_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/notification_repository.dart';
import '../models/notification.dart';
import 'notification_service.dart';
import '../../main.dart';

class NotificationSyncService {
  final Ref ref;
  final FirebaseFirestore db;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  NotificationSyncService(this.ref, this.db);

  void start(String userId) {
    stop();

    // --- FIX: Add logic to show stale notifications from cache ---
    // This runs once when the service starts (e.g., on login)
    _showStaleNotifications(userId);
    // --- End of Fix ---

    // This block listens for NEW notifications from Firestore
    _sub = db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('seen', isEqualTo: false) // 'seen' is the trigger from Firestore
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snap) async {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;

        final title = data['title']?.toString() ?? 'Notification';
        final body = data['body']?.toString() ?? '';
        final typeStr = data['type']?.toString() ?? 'classChange';

        // 1. Show the pop-up
        await ref.read(notifServiceProvider).showLocal(title, body);

        // 2. Save to local storage for the notification page
        final type = _parseType(typeStr);
        await ref.read(notifRepoProvider).queueForUser(
          userId: userId,
          title: title,
          body: body,
          type: type,
        );

        // 3. Mark as 'seen' in Firestore so it doesn't send again
        try {
          await change.doc.reference.update({'seen': true});
        } catch (_) {}
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  // --- NEW METHOD ---
  /// Shows unread notifications from the local cache, then clears them.
  /// This handles notifications that were received while the user was logged out.
  Future<void> _showStaleNotifications(String userId) async {
    final notifRepo = ref.read(notifRepoProvider);
    final notifSvc = ref.read(notifServiceProvider);

    final unread = notifRepo.unreadForUser(userId);
    if (unread.isEmpty) return;

    int shown = 0;
    for (final n in unread) {
      if (shown < 3) {
        await notifSvc.showLocal(n.title, n.body);
        shown++;
      }
    }
    if (unread.length > 3) {
      await notifSvc.showLocal('More notifications', '+${unread.length - 3} more updates');
    }

    // Mark all as read in the local cache
    await notifRepo.markAllRead(userId);
  }
  // --- End of New Method ---

  NotificationType _parseType(String s) {
    for (final t in NotificationType.values) {
      if (t.name == s) return t;
    }
    return NotificationType.classChange;
  }
}