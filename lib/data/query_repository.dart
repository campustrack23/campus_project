// lib/data/query_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/models/query_ticket.dart';
import '../core/models/notification.dart';
import '../core/services/firestore_notifier.dart';
import 'notification_repository.dart';

class QueryRepository {
  final NotificationRepository notifRepo;
  // --- FIX: Add FirestoreNotifier ---
  final FirestoreNotifier _firestoreNotifier;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- FIX: Update constructor ---
  QueryRepository(this.notifRepo, this._firestoreNotifier);

  CollectionReference<QueryTicket> get _queriesRef =>
      _db.collection('queries').withConverter<QueryTicket>(
        fromFirestore: (snapshot, _) => QueryTicket.fromMap(snapshot.data()!),
        toFirestore: (query, _) => query.toMap(),
      );

  Future<List<QueryTicket>> allQueries() async {
    final snapshot = await _queriesRef.orderBy('createdAt', descending: true).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

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
      createdAt: now,
      updatedAt: now,
    );

    // Set the document with a specific ID
    await _queriesRef.doc(ticket.id).set(ticket);
    return ticket;
  }

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

    // --- FIX: Send a real-time notification instead of just a local one ---
    await _firestoreNotifier.sendToUsers(
      userIds: [ticket.raisedByStudentId],
      title: 'Query update',
      body: 'Your query "${ticket.title}" is now ${status.name}.',
      type: NotificationType.queryUpdate.name,
    );
  }
}