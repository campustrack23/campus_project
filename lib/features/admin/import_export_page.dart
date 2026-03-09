// lib/features/admin/import_export_page.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';

class ImportExportPage extends ConsumerStatefulWidget {
  const ImportExportPage({super.key});

  @override
  ConsumerState<ImportExportPage> createState() => _ImportExportPageState();
}

class _ImportExportPageState extends ConsumerState<ImportExportPage> {
  final TextEditingController ctrl = TextEditingController();
  bool _isLoading = false;

  // Available collections to import into
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
              'Paste JSON data below to import.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 10),

            // Collection Selector
            DropdownButtonFormField<String>(
              value: _selectedCollection,
              decoration: const InputDecoration(labelText: 'Target Collection'),
              items: _collections.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedCollection = v);
              },
            ),
            const SizedBox(height: 10),

            Expanded(
              child: TextField(
                controller: ctrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: const InputDecoration(
                  hintText: '[{"id": "...", "name": "..."}]',
                  border: OutlineInputBorder(),
                  filled: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: _exportData,
                    icon: const Icon(Icons.download),
                    label: const Text('Export Current'),
                  ),
                  FilledButton.icon(
                    onPressed: () => _importData(_selectedCollection),
                    icon: const Icon(Icons.upload),
                    label: const Text('Import JSON'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData() async {
    setState(() => _isLoading = true);
    try {
      final snap = await FirebaseFirestore.instance.collection(_selectedCollection).limit(1000).get();
      final data = snap.docs.map((d) {
        final map = d.data();
        // Convert timestamps to string for JSON compatibility
        final converted = map.map((k, v) {
          if (v is Timestamp) return MapEntry(k, v.toDate().toIso8601String());
          return MapEntry(k, v);
        });
        return converted;
      }).toList();

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      ctrl.text = jsonStr;

      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${data.length} items')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importData(String collection) async {
    if (ctrl.text.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Import to "$collection"?'),
        content: const Text('This will overwrite existing documents with matching IDs. Ensure JSON is valid.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      // 1. VALIDATE JSON
      final dynamic decoded = jsonDecode(ctrl.text);
      if (decoded is! List) {
        throw const FormatException('Root must be a JSON List [...]');
      }

      final List<Map<String, dynamic>> items = [];
      for(var i=0; i<decoded.length; i++) {
        final item = decoded[i];
        if (item is! Map) throw FormatException('Item at index $i is not a JSON Object');
        items.add(Map<String, dynamic>.from(item));
      }

      // 2. BATCH WRITE
      await _batchWrite(collection, items);

      if(mounted) {
        ctrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import Successful!')));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
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
        // Ensure we have an ID
        final String? id = docData['id'];
        final DocumentReference ref = id != null
            ? db.collection(collection).doc(id)
            : db.collection(collection).doc(); // Auto-id if missing

        // Sanitize Timestamps (convert ISO strings back to Timestamp if needed)
        // This is basic; deep conversion would be recursive.
        final sanitized = docData.map((k, v) {
          // If string looks like date, try parse?
          // For simplicity, we assume generic import. Models handle parsing.
          return MapEntry(k, v);
        });

        batch.set(ref, sanitized, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }
}