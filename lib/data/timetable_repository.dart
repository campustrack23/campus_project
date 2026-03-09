// lib/data/timetable_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../core/models/timetable_entry.dart';
import '../core/models/subject.dart';

class TimetableRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  TimetableRepository();

  CollectionReference<TimetableEntry> get _entriesRef =>
      _db.collection('timetable').withConverter<TimetableEntry>(
        // FIX: Pass snap.id to fromMap
        fromFirestore: (snap, _) => TimetableEntry.fromMap(snap.id, snap.data()!),
        toFirestore: (entry, _) => entry.toMap(),
      );

  CollectionReference<Subject> get _subjectsRef =>
      _db.collection('subjects').withConverter<Subject>(
        // FIX: Pass snap.id to fromMap
        fromFirestore: (snap, _) => Subject.fromMap(snap.id, snap.data()!),
        toFirestore: (subj, _) => subj.toMap(),
      );

  // --- READ METHODS ---

  Future<Subject?> subjectById(String id) async {
    final doc = await _subjectsRef.doc(id).get();
    return doc.data();
  }

  Future<TimetableEntry?> entryById(String id) async {
    final doc = await _entriesRef.doc(id).get();
    return doc.data();
  }

  Future<List<TimetableEntry>> allEntries() async {
    final snapshot = await _entriesRef.get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<Subject>> allSubjects() async {
    final snapshot = await _subjectsRef.orderBy('code').get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<TimetableEntry>> forTeacher(String teacherId) async {
    final snapshot = await _entriesRef
        .where('teacherIds', arrayContains: teacherId)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<List<TimetableEntry>> forSection(String section) async {
    final snapshot = await _entriesRef
        .where('section', isEqualTo: section)
        .get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  // --- WRITE METHODS ---

  Future<void> addOrUpdate(TimetableEntry entry) async {
    await _entriesRef.doc(entry.id).set(entry, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _entriesRef.doc(id).delete();
  }

  Future<Subject> addOrUpdateSubject(Subject subject) async {
    await _subjectsRef.doc(subject.id).set(subject, SetOptions(merge: true));
    return subject;
  }

  Future<void> deleteSubject(String id) async {
    await _subjectsRef.doc(id).delete();
  }

  Future<TimetableEntry> newBlankEntry() async {
    final subjects = await allSubjects();
    return TimetableEntry(
      id: const Uuid().v4(),
      subjectId: subjects.isNotEmpty ? subjects.first.id : '',
      dayOfWeek: 'Mon',
      startTime: '09:30',
      endTime: '10:30',
      room: '',
      section: '',
      teacherIds: [],
    );
  }
}