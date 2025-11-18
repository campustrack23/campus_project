// lib/data/notification_repository.dart
import 'package:uuid/uuid.dart';
import '../core/models/notification.dart'; // **CHANGED**: Importing the model from its new file
import '../core/services/local_storage.dart';


class NotificationRepository {
  final LocalStorage store;
  NotificationRepository(this.store);

  List<AppNotification> _all() =>
      store.readList(LocalStorage.kNotifications).map(AppNotification.fromMap).toList();

  Future<void> _saveAll(List<AppNotification> list) async =>
      store.writeList(LocalStorage.kNotifications, list.map((e) => e.toMap()).toList());

  Future<void> queueForUser({
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
    await _saveAll(list);
  }

  Future<void> queueForUsers({
    required Iterable<String> userIds,
    required String title,
    required String body,
    required NotificationType type,
  }) async {
    final list = _all();
    final now = DateTime.now();
    for (final uid in userIds) {
      list.add(AppNotification(
        id: const Uuid().v4(),
        userId: uid,
        title: title,
        body: body,
        type: type,
        createdAt: now,
        read: false,
      ));
    }
    await _saveAll(list);
  }

  List<AppNotification> unreadForUser(String userId) =>
      _all().where((n) => n.userId == userId && !n.read).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int unreadCount(String userId) => unreadForUser(userId).length;

  List<AppNotification> forUser(String userId) =>
      _all().where((n) => n.userId == userId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> markAllRead(String userId) async {
    final list = _all();
    for (int i = 0; i < list.length; i++) {
      if (list[i].userId == userId) list[i] = list[i].copyRead(true);
    }
    await _saveAll(list);
  }

  Future<void> markRead(String notificationId) async {
    final list = _all();
    final idx = list.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      list[idx] = list[idx].copyRead(true);
      await _saveAll(list);
    }
  }

  Future<void> clearForUser(String userId) async {
    final list = _all()..removeWhere((n) => n.userId == userId);
    await _saveAll(list);
  }
}