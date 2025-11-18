// lib/data/timetable_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/models/timetable_entry.dart';
import '../core/models/subject.dart';

class TimetableRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<TimetableEntry> get _entriesRef =>
      _db.collection('timetable').withConverter<TimetableEntry>(
        fromFirestore: (snapshot, _) => TimetableEntry.fromMap(snapshot.data()!),
        toFirestore: (entry, _) => entry.toMap(),
      );

  CollectionReference<Subject> get _subjectsRef =>
      _db.collection('subjects').withConverter<Subject>(
        fromFirestore: (snapshot, _) => Subject.fromMap(snapshot.data()!),
        toFirestore: (subject, _) => subject.toMap(),
      );

  Future<List<TimetableEntry>> allEntries() async {
    final snapshot = await _entriesRef.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Subject>> allSubjects() async {
    final snapshot = await _subjectsRef.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<Subject?> subjectById(String id) async {
    final doc = await _subjectsRef.doc(id).get();
    return doc.data();
  }

  Future<TimetableEntry?> entryById(String id) async {
    final doc = await _entriesRef.doc(id).get();
    return doc.data();
  }

  // --- FIX: Simplified logic to be more accurate ---
  Future<List<TimetableEntry>> forTeacher(String teacherId) async {
    // This single query is all that's needed.
    // It finds all timetable entries where the teacher's ID
    // is in the 'teacherIds' array.
    final entriesBySlot = await _entriesRef
        .where('teacherIds', arrayContains: teacherId)
        .get();

    return entriesBySlot.docs.map((d) => d.data()).toList();
  }
  // --- End of Fix ---

  Future<List<TimetableEntry>> forSection(String section) async {
    final snapshot = await _entriesRef.where('section', isEqualTo: section).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> addOrUpdate(TimetableEntry entry) async {
    await _entriesRef.doc(entry.id).set(entry, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _entriesRef.doc(id).delete();
  }

  // This helper can remain mostly synchronous as it's for UI prep
  Future<TimetableEntry> newBlankEntry() async {
    final subs = await allSubjects();
    return TimetableEntry(
      id: const Uuid().v4(),
      subjectId: subs.isNotEmpty ? subs.first.id : '',
      dayOfWeek: 'Mon',
      startTime: '08:30',
      endTime: '09:30',
      room: '301',
      section: 'IV-HE',
    );
  }
}