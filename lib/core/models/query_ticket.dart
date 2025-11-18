// lib/core/models/query_ticket.dart
enum QueryStatus { open, inProgress, resolved, rejected }

class QueryTicket {
  final String id;
  final String raisedByStudentId;
  final String? subjectId;
  final String title;
  final String message;
  final List<String> attachments;
  final QueryStatus status;
  final String? assignedToTeacherId;
  final DateTime createdAt;
  final DateTime updatedAt;

  QueryTicket({
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'raisedByStudentId': raisedByStudentId,
    'subjectId': subjectId,
    'title': title,
    'message': message,
    'attachments': attachments,
    'status': status.name,
    'assignedToTeacherId': assignedToTeacherId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
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

  factory QueryTicket.fromMap(Map<String, dynamic> map) => QueryTicket(
    id: map['id'] as String,
    raisedByStudentId: map['raisedByStudentId'] as String,
    subjectId: map['subjectId'] as String?,
    title: map['title'] as String,
    message: map['message'] as String,
    attachments: (map['attachments'] as List?)
        ?.map((e) => e.toString())
        .toList() ??
        const [],
    status: _statusFrom(map['status']),
    assignedToTeacherId: map['assignedToTeacherId'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
    updatedAt: DateTime.parse(map['updatedAt'] as String),
  );
}