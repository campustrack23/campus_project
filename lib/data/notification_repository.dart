// lib/data/notification_repository.dart
import 'package:uuid/uuid.dart';
import '../core/models/notification.dart';
import '../core/services/local_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationRepository {
  final LocalStorage store;

  NotificationRepository(this.store);

  List<AppNotification> _all() {
    final list = store.readList(LocalStorage.kNotifications);
    final notifications = list.map(AppNotification.fromMap).toList();
    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  Future<void> _saveAll(List<AppNotification> list) async {
    if (list.length > 100) {
      list = list.sublist(list.length - 100);
    }
    await store.writeList(
      LocalStorage.kNotifications,
      list.map((e) => e.toMap()).toList(),
    );
  }

  Future<void> save(AppNotification notification) async {
    final list = _all();
    final index = list.indexWhere((n) => n.id == notification.id);

    if (index != -1) {
      list[index] = notification;
    } else {
      list.add(notification);
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveAll(list);
  }

  Future<void> createLocalAlert({
    required String userId,
    required String title,
    required String body,
    required NotificationType type,
  }) async {
    final list = _all();
    list.add(AppNotification(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      body: body,
      type: type,
      createdAt: DateTime.now(),
      read: false,
    ));
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveAll(list);
  }

  List<AppNotification> unreadForUser(String userId) =>
      _all().where((n) => n.userId == userId && !n.read).toList();

  int unreadCount(String userId) => unreadForUser(userId).length;

  List<AppNotification> forUser(String userId) =>
      _all().where((n) => n.userId == userId).toList();

  Future<void> markAllRead(String userId) async {
    final list = _all();
    bool changed = false;
    for (int i = 0; i < list.length; i++) {
      if (list[i].userId == userId && !list[i].read) {
        list[i] = list[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _saveAll(list);
    }
  }

  Future<void> markRead(String notificationId) async {
    final list = _all();
    final idx = list.indexWhere((n) => n.id == notificationId);
    if (idx != -1 && !list[idx].read) {
      list[idx] = list[idx].copyWith(read: true);
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _saveAll(list);
    }
  }

  Future<void> clearForUser(String userId) async {
    final list = _all()..removeWhere((n) => n.userId == userId);
    await _saveAll(list);
  }

  Future<void> delete(String notificationId) async {
    final list = _all()..removeWhere((n) => n.id == notificationId);
    await _saveAll(list);
  }
}

/// RIVERPOD PROVIDER
final notifRepoProvider = Provider<NotificationRepository>((ref) {
  final store = ref.watch(localStorageProvider);
  return NotificationRepository(store);
});
