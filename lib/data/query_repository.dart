// lib/data/query_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/models/query_ticket.dart';
import '../core/models/notification.dart';
import '../core/services/firestore_notifier.dart';

class QueryRepository {
  final FirestoreNotifier _firestoreNotifier;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  QueryRepository(this._firestoreNotifier);

  CollectionReference<QueryTicket> get _queriesRef =>
      _db.collection('queries').withConverter<QueryTicket>(
        fromFirestore: (snapshot, _) => QueryTicket.fromMap(snapshot.data()!),
        toFirestore: (query, _) => query.toMap(),
      );

  // --- READ METHODS ---

  /// Fetch all queries (Admin view)
  Future<List<QueryTicket>> allQueries() async {
    final snapshot = await _queriesRef.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Queries raised by a specific student
  Future<List<QueryTicket>> getQueriesForStudent(String studentId) async {
    final snapshot = await _queriesRef
        .where('raisedByStudentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  /// Queries with status 'open' (optionally assign to teacher in extended versions)
  Future<List<QueryTicket>> getOpenQueries() async {
    final snapshot = await _queriesRef
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // --- WRITE METHODS ---

  /// Create a new Query Ticket
  Future<QueryTicket> raise({
    required String raisedByStudentId,
    String? subjectId,
    required String title,
    required String message,
  }) async {
    final now = DateTime.now();

    final ticket = QueryTicket(
      id: const Uuid().v4(),
      raisedByStudentId: raisedByStudentId,
      subjectId: subjectId,
      title: title,
      message: message,
      status: QueryStatus.open,
      createdAt: now,
      updatedAt: now,
    );

    await _queriesRef.doc(ticket.id).set(ticket);
    return ticket;
  }

  /// Update query status, optionally assigning a teacher, and notify student
  Future<void> updateStatus(String id, QueryStatus status, {String? assignedTo}) async {
    final docRef = _queriesRef.doc(id);
    final doc = await docRef.get();
    final ticket = doc.data();
    if (ticket == null) return;

    await docRef.update({
      'status': status.name,
      'assignedToTeacherId': assignedTo,
      'updatedAt': Timestamp.now(),
    });

    // Notify student via Firestore push notification
    await _firestoreNotifier.sendToUsers(
      userIds: [ticket.raisedByStudentId],
      title: 'Query Update',
      body: 'Your query "${ticket.title}" is now ${status.name}.',
      type: NotificationType.queryUpdate,
    );
  }

  /// Delete a query ticket by id
  Future<void> deleteQuery(String id) async {
    await _queriesRef.doc(id).delete();
  }
}
