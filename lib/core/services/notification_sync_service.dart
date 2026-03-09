// lib/core/services/notification_sync_service.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

// FIXED: Hide the provider from this file to avoid conflict with main.dart
import '../../main.dart';

class NotificationSyncService {
  final Ref ref;
  final FirebaseFirestore db;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // Flag to prevent showing notifications for existing unread messages on app launch
  bool _isFirstLoad = true;

  NotificationSyncService(this.ref, this.db);

  void start(String userId) {
    stop(); // Ensure no duplicate listeners
    debugPrint('NotificationSync: Starting sync for user $userId');

    final notifService = ref.read(notifServiceProvider);

    _sub = db
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20) // Limit to save bandwidth
        .snapshots()
        .listen((snap) async {

      // SKIP the first snapshot.
      // The first snapshot contains all existing unread messages.
      // We don't want to buzz the phone for messages that were already there.
      if (_isFirstLoad) {
        _isFirstLoad = false;
        return;
      }

      if (snap.docChanges.isEmpty) return;

      debugPrint('NotificationSync: Received ${snap.docChanges.length} updates');

      // Spam prevention: if many come at once (e.g. batch update), show one summary
      if (snap.docChanges.length > 3) {
        await notifService.showLocal(
          'New Notifications',
          'You have ${snap.docChanges.length} new updates.',
        );
        return;
      }

      for (final change in snap.docChanges) {
        // We only care about NEW additions to the unread list
        if (change.type != DocumentChangeType.added) continue;

        final data = change.doc.data();
        if (data == null) continue;

        final title = data['title']?.toString() ?? 'Notification';
        final body = data['body']?.toString() ?? '';

        // Trigger the local push notification (Heads-up display)
        await notifService.showLocal(title, body);

        // NOTE: We do NOT save to a local repo because the UI reads directly from Firestore.
        // We also do NOT mark as read here, allowing the UI to show the "Unread" badge.
      }
    }, onError: (e) {
      debugPrint('NotificationSync: Error in stream: $e');
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    debugPrint('NotificationSync: Stopped');
  }
}