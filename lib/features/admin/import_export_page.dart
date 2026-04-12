// lib/features/admin/import_export_page.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../../core/utils/firebase_error_parser.dart';

class ImportExportPage extends ConsumerStatefulWidget {
  const ImportExportPage({super.key});

  @override
  ConsumerState<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends ConsumerState<ImportExportPage> {
  final TextEditingController ctrl = TextEditingController();
  bool _isLoading = false;

  final List<String> _collections = ['users', 'subjects', 'timetable', 'attendance'];
  String _selectedCollection = 'subjects';

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import / Export (JSON)'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Warning: This is a raw database tool. Malformed JSON will fail to import.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedCollection,
              decoration: const InputDecoration(labelText: 'Target Collection', border: OutlineInputBorder()),
              items: _collections.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _selectedCollection = v!),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Paste JSON array here...',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _isLoading ? null : _importData,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.upload),
                label: const Text('Execute Batch Import'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importData() async {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final List<dynamic> parsed = jsonDecode(text);
      final List<Map<String, dynamic>> items = parsed.cast<Map<String, dynamic>>();

      await _batchWrite(_selectedCollection, items);

      if (mounted) {
        ctrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import Successful!')));
      }
    } catch (e) {
      if (mounted) {
        // SECURITY FIX: Route error through parser to prevent leaking internal stack traces.
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(FirebaseErrorParser.getMessage(e)))
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _batchWrite(String collection, List<Map<String, dynamic>> items) async {
    final db = FirebaseFirestore.instance;
    const int batchSize = 400;

    for (var i = 0; i < items.length; i += batchSize) {
      final batch = db.batch();
      final end = (i + batchSize < items.length) ? i + batchSize : items.length;
      final chunk = items.sublist(i, end);

      for (final docData in chunk) {
        final String? id = docData['id'];
        final DocumentReference ref = id != null
            ? db.collection(collection).doc(id)
            : db.collection(collection).doc();

        batch.set(ref, docData, SetOptions(merge: true));
      }

      await batch.commit();
    }
  }
}