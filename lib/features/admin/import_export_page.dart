// lib/features/admin/import_export_page.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../../main.dart';

class ImportExportPage extends ConsumerStatefulWidget {
  const ImportExportPage({super.key});

  @override
  ConsumerState<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends ConsumerState<ImportExportPage> {
  final ctrl = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Import / Export (JSON)'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _isLoading ? null : _exportAll,
                      child: const Text('Export All → Text'),
                    ),
                    FilledButton.tonal(
                      onPressed: _isLoading ? null : _copy,
                      child: const Text('Copy to Clipboard'),
                    ),
                    OutlinedButton(
                      onPressed: _isLoading ? null : _importAll,
                      child: const Text('Import from Text'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: ctrl,
                    maxLines: null,
                    expands: true,
                    style: const TextStyle(fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: 'JSON will appear here after export. Paste your JSON here to import.',
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing...', style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _exportAll() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepoProvider);
      final ttRepo = ref.read(timetableRepoProvider);
      final attRepo = ref.read(attendanceRepoProvider);
      final queryRepo = ref.read(queryRepoProvider);
      ref.read(remarkRepoProvider);

      final users = await authRepo.allUsers();
      final subjects = await ttRepo.allSubjects();
      final timetable = await ttRepo.allEntries();
      final attendance = await attRepo.allRecords();
      final queries = await queryRepo.allQueries();

      // Remarks are specific to a teacher, so exporting all isn't logical.
      // We'll export for the current admin as a sample if needed, or skip.

      final data = {
        'users': users.map((e) => e.toMap()).toList(),
        'subjects': subjects.map((e) => e.toMap()).toList(),
        'timetable': timetable.map((e) => e.toMap()).toList(),
        'attendance': attendance.map((e) => e.toMap()).toList(),
        'queries': queries.map((e) => e.toMap()).toList(),
      };
      ctrl.text = const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      ctrl.text = 'Export failed: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: ctrl.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  Future<void> _importAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Import'),
        content: const Text('This will OVERWRITE existing data in Firestore. This action cannot be undone. It will NOT create Firebase Auth users. This is for data import only.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isLoading = true);
    try {
      final map = jsonDecode(ctrl.text) as Map<String, dynamic>;
      final db = ref.read(firestoreProvider);

      // Note: This does not import users as that requires Firebase Auth.
      // This is a simple data import for other collections.

      await _importCollection(db, 'subjects', map['subjects']);
      await _importCollection(db, 'timetable', map['timetable']);
      await _importCollection(db, 'attendance', map['attendance']);
      await _importCollection(db, 'queries', map['queries']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imported successfully')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importCollection(FirebaseFirestore db, String collectionName, dynamic data) async {
    if (data is! List) return;

    // Delete all existing documents in the collection
    final existingDocs = await db.collection(collectionName).get();
    final deleteBatch = db.batch();
    for (final doc in existingDocs.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();

    // Add new documents
    final addBatch = db.batch();
    for (final item in data) {
      if (item is Map<String, dynamic> && item.containsKey('id')) {
        final docRef = db.collection(collectionName).doc(item['id']);
        addBatch.set(docRef, item);
      }
    }
    await addBatch.commit();
  }
}