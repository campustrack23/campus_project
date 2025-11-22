// lib/core/models/notification.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  classChange,
  lowAttendance,
  queryUpdate,
  remarkSaved,
  general, // Fallback case
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool read;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.read = false,
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? createdAt,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }

  AppNotification copyRead(bool value) => copyWith(read: value);

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'body': body,
    'type': type.name,
    // Stored as ISO8601 string for local storage compatibility
    'createdAt': createdAt.toIso8601String(),
    'read': read,
  };

  static NotificationType _safeType(dynamic v) {
    if (v is String) {
      return NotificationType.values.firstWhere(
            (e) => e.name == v,
        orElse: () => NotificationType.general,
      );
    }
    return NotificationType.general;
  }

  factory AppNotification.fromMap(Map<String, dynamic> m) {
    DateTime parsedDate;
    final rawDate = m['createdAt'];

    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return AppNotification(
      id: m['id'] ?? '',
      userId: m['userId'] ?? '',
      title: m['title'] ?? 'No Title',
      body: m['body'] ?? '',
      type: _safeType(m['type']),
      createdAt: parsedDate,
      read: (m['read'] as bool?) ?? false,
    );
  }

  factory AppNotification.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification.fromMap({...data, 'id': doc.id});
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AppNotification &&
        other.id == id &&
        other.userId == userId &&
        other.title == title &&
        other.body == body &&
        other.type == type &&
        other.createdAt == createdAt &&
        other.read == read;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    userId.hashCode ^
    title.hashCode ^
    body.hashCode ^
    type.hashCode ^
    createdAt.hashCode ^
    read.hashCode;
  }
}
