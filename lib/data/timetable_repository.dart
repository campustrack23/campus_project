// lib/data/timetable_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/models/timetable_entry.dart';
import '../core/models/timetable_override.dart';
import '../core/models/subject.dart';

class TimetableRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  TimetableRepository();

  // ─── Typed collection references ────────────────────────────────────────────

  CollectionReference<TimetableEntry> get _entriesRef =>
      _db.collection('timetable').withConverter<TimetableEntry>(
        fromFirestore: (snap, _) => TimetableEntry.fromMap(snap.id, snap.data()!),
        toFirestore: (entry, _) => entry.toMap(),
      );

  CollectionReference<Subject> get _subjectsRef =>
      _db.collection('subjects').withConverter<Subject>(
        fromFirestore: (snap, _) => Subject.fromMap(snap.id, snap.data()!),
        toFirestore: (subj, _) => subj.toMap(),
      );

  // NOTE: timetable_overrides uses a raw ref — TimetableOverride.fromMap/toMap
  // handle the conversion manually, keeping override logic self-contained.
  CollectionReference<Map<String, dynamic>> get _overridesRef =>
      _db.collection('timetable_overrides');

  // ─── Subjects ────────────────────────────────────────────────────────────────

  Future<Subject?> subjectById(String id) async {
    final doc = await _subjectsRef.doc(id).get();
    return doc.data();
  }

  Future<List<Subject>> allSubjects() async {
    final snapshot = await _subjectsRef.orderBy('code').get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Future<Subject> addOrUpdateSubject(Subject subject) async {
    await _subjectsRef.doc(subject.id).set(subject, SetOptions(merge: true));
    return subject;
  }

  Future<void> deleteSubject(String id) async {
    await _subjectsRef.doc(id).delete();
  }

  // ─── Timetable Entries ───────────────────────────────────────────────────────

  Future<TimetableEntry?> entryById(String id) async {
    final doc = await _entriesRef.doc(id).get();
    return doc.data();
  }

  Future<List<TimetableEntry>> allEntries() async {
    final snapshot = await _entriesRef.get();
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

  Future<void> addOrUpdate(TimetableEntry entry) async {
    await _entriesRef.doc(entry.id).set(entry, SetOptions(merge: true));
  }

  Future<void> delete(String id) async {
    await _entriesRef.doc(id).delete();
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

  // ─── Overrides ───────────────────────────────────────────────────────────────

  /// Fetch all overrides for [section] on a given [date] ('YYYY-MM-DD').
  /// Returns an empty list on error rather than throwing, so the UI can
  /// fall back to the normal timetable gracefully.
  Future<List<TimetableOverride>> getOverridesForDate(
      String section,
      String date,
      ) async {
    try {
      final snap = await _overridesRef
          .where('section', isEqualTo: section)
          .where('date', isEqualTo: date)
          .get();

      return snap.docs
          .map((doc) => TimetableOverride.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('TimetableRepository.getOverridesForDate error: $e');
      return [];
    }
  }

  /// Teacher cancels or reschedules a class.
  ///
  /// Saves the override document, then writes a push-notification record
  /// targeted at [overrideData.section] so students are informed automatically.
  ///
  /// Throws an [Exception] on failure so the calling layer can surface a
  /// meaningful error in the UI.
  Future<void> createOverride(
      TimetableOverride overrideData,
      String subjectName,
      ) async {
    try {
      // 1. Persist the override.
      await _overridesRef
          .doc(overrideData.id)
          .set(overrideData.toMap());

      // 2. Build a human-readable notification for the affected section.
      final title = overrideData.isCancelled
          ? 'Class Cancelled: $subjectName'
          : 'Class Rescheduled: $subjectName';

      final body = overrideData.isCancelled
          ? 'Today\'s class has been cancelled. '
          'Reason: ${overrideData.reason ?? "Urgent work"}'
          : 'Class moved to ${overrideData.newStartTime} '
          'in Room ${overrideData.newRoom}';

      // 3. Write to notifications collection.
      //    A background Cloud Function (or your FCM layer) should watch
      //    this collection and fan-out to the actual device tokens for
      //    the targetSection.
      await _db.collection('notifications').add({
        'title': title,
        'message': body,
        'targetSection': overrideData.section,
        'createdAt': DateTime.now().toIso8601String(),
        'type': 'timetable_override',
        // Carry the override id so the notification can deep-link back.
        'overrideId': overrideData.id,
      });
    } catch (e) {
      throw Exception('Failed to create class override: $e');
    }
  }

  /// Delete a previously created override (e.g. teacher reverting a change).
  Future<void> deleteOverride(String id) async {
    await _overridesRef.doc(id).delete();
  }
}