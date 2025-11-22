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
  final TextEditingController ctrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

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
                      border: OutlineInputBorder(),
                      filled: true,
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

  // ===== EXPORT ALL DATA TO TEXTAREA =====
  Future<void> _exportAll() async {
    setState(() => _isLoading = true);
    ctrl.clear();
    try {
      final authRepo = ref.read(authRepoProvider);
      final ttRepo = ref.read(timetableRepoProvider);
      final attRepo = ref.read(attendanceRepoProvider);
      final queryRepo = ref.read(queryRepoProvider);

      final users = await authRepo.allUsers();
      final subjects = await ttRepo.allSubjects();
      final timetable = await ttRepo.allEntries();
      final attendance = await attRepo.allRecords();
      final queries = await queryRepo.allQueries();

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

  // ===== COPY TO CLIPBOARD =====
  Future<void> _copy() async {
    if (ctrl.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: ctrl.text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  // ===== IMPORT ALL DATA FROM TEXTAREA =====
  Future<void> _importAll() async {
    if (ctrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Text area is empty')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Import'),
        content: const Text(
          'WARNING: This will DELETE all existing data in the collections and replace it with this JSON.\n\n'
              'Note: This restores user profiles, but does NOT create Firebase Auth accounts (passwords).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('OVERWRITE DATA'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _isLoading = true);
    try {
      final map = jsonDecode(ctrl.text) as Map<String, dynamic>;
      final db = ref.read(firestoreProvider);

      // Import all supported collections.
      await _importCollection(db, 'users', map['users']);
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

  /// Imports a Firestore collection with batching and deletes all old documents first.
  Future<void> _importCollection(FirebaseFirestore db, String collectionName, dynamic data) async {
    if (data is! List) return;

    // 1. DELETE ALL EXISTING DOCUMENTS (in batches)
    final existingDocs = await db.collection(collectionName).get();
    if (existingDocs.docs.isNotEmpty) {
      const batchSize = 400; // Firestore limit = 500
      for (var i = 0; i < existingDocs.docs.length; i += batchSize) {
        final batch = db.batch();
        final end = (i + batchSize < existingDocs.docs.length) ? i + batchSize : existingDocs.docs.length;
        final chunk = existingDocs.docs.sublist(i, end);
        for (final doc in chunk) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    // 2. ADD NEW DOCUMENTS (in batches)
    if (data.isNotEmpty) {
      const batchSize = 400;
      for (var i = 0; i < data.length; i += batchSize) {
        final batch = db.batch();
        final end = (i + batchSize < data.length) ? i + batchSize : data.length;
        final chunk = data.sublist(i, end);

        // Add each item if it has 'id'
        for (final item in chunk) {
          if (item is Map<String, dynamic> && item.containsKey('id')) {
            final docRef = db.collection(collectionName).doc(item['id']);
            batch.set(docRef, item);
          }
        }
        await batch.commit();
      }
    }
  }
}
