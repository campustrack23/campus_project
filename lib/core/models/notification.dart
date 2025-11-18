// lib/core/models/notification.dart
import 'package:uuid/uuid.dart';

enum NotificationType {
  classChange,
  lowAttendance,
  queryUpdate,
  remarkSaved,
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyRead(bool value) => AppNotification(
    id: id,
    userId: userId,
    title: title,
    body: body,
    type: type,
    createdAt: createdAt,
    read: value,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  static NotificationType _safeType(dynamic v) {
    if (v is String) {
      for (final t in NotificationType.values) {
        if (t.name == v) return t;
      }
    }
    return NotificationType.classChange;
  }

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'],
    userId: m['userId'],
    title: m['title'],
    body: m['body'],
    type: _safeType(m['type']),
    createdAt: DateTime.parse(m['createdAt']),
    read: (m['read'] as bool?) ?? false,
  );
}