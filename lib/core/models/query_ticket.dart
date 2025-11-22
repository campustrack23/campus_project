// lib/core/models/query_ticket.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum QueryStatus { open, inProgress, resolved, rejected }

extension QueryStatusX on QueryStatus {
  String get label {
    switch (this) {
      case QueryStatus.open:
        return "Open";
      case QueryStatus.inProgress:
        return "In Progress";
      case QueryStatus.resolved:
        return "Resolved";
      case QueryStatus.rejected:
        return "Rejected";
    }
  }
}

class QueryTicket {
  final String id;
  final String raisedByStudentId;
  final String? subjectId; // Nullable if general query
  final String title;
  final String message;
  final List<String> attachments;
  final QueryStatus status;
  final String? assignedToTeacherId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QueryTicket({
    required this.id,
    required this.raisedByStudentId,
    this.subjectId,
    required this.title,
    required this.message,
    this.attachments = const [],
    this.status = QueryStatus.open,
    this.assignedToTeacherId,
    required this.createdAt,
    required this.updatedAt,
  });

  QueryTicket copyWith({
    String? id,
    String? raisedByStudentId,
    String? subjectId,
    String? title,
    String? message,
    List<String>? attachments,
    QueryStatus? status,
    String? assignedToTeacherId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QueryTicket(
      id: id ?? this.id,
      raisedByStudentId: raisedByStudentId ?? this.raisedByStudentId,
      subjectId: subjectId ?? this.subjectId,
      title: title ?? this.title,
      message: message ?? this.message,
      attachments: attachments ?? this.attachments,
      status: status ?? this.status,
      assignedToTeacherId: assignedToTeacherId ?? this.assignedToTeacherId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'raisedByStudentId': raisedByStudentId,
    'subjectId': subjectId,
    'title': title,
    'message': message,
    'attachments': attachments,
    'status': status.name,
    'assignedToTeacherId': assignedToTeacherId,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  static QueryStatus _statusFrom(dynamic s) {
    if (s is String) {
      return QueryStatus.values.firstWhere(
            (e) => e.name == s,
        orElse: () => QueryStatus.open,
      );
    }
    return QueryStatus.open;
  }

  factory QueryTicket.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic input) {
      if (input is Timestamp) return input.toDate();
      if (input is String) return DateTime.tryParse(input) ?? DateTime.now();
      if (input is DateTime) return input;
      return DateTime.now();
    }

    return QueryTicket(
      id: map['id'] as String? ?? '',
      raisedByStudentId: map['raisedByStudentId'] as String? ?? '',
      subjectId: map['subjectId'] as String?,
      title: map['title'] as String? ?? 'No Title',
      message: map['message'] as String? ?? '',
      attachments: (map['attachments'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const [],
      status: _statusFrom(map['status']),
      assignedToTeacherId: map['assignedToTeacherId'] as String?,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  factory QueryTicket.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return QueryTicket.fromMap({...data, 'id': doc.id});
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QueryTicket &&
        other.id == id &&
        other.raisedByStudentId == raisedByStudentId &&
        other.subjectId == subjectId &&
        other.title == title &&
        other.message == message &&
        other.attachments.length == attachments.length && // simple list check
        other.status == status &&
        other.assignedToTeacherId == assignedToTeacherId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
    raisedByStudentId.hashCode ^
    subjectId.hashCode ^
    title.hashCode ^
    message.hashCode ^
    attachments.hashCode ^
    status.hashCode ^
    assignedToTeacherId.hashCode ^
    createdAt.hashCode ^
    updatedAt.hashCode;
  }
}
