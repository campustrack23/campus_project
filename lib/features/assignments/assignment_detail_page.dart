// lib/features/assignments/assignment_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/services/api_service.dart';
import '../../core/models/role.dart';
import '../../main.dart';

class AssignmentDetailPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> assignment;

  const AssignmentDetailPage({super.key, required this.assignment});

  @override
  ConsumerState<AssignmentDetailPage> createState() => _AssignmentDetailPageState();
}

class _AssignmentDetailPageState extends ConsumerState<AssignmentDetailPage> {
  final _submissionCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isStudent = user?.role == UserRole.student;
    final dueDate = widget.assignment['dueDate'] != null
        ? DateFormat('MMM d, yyyy - h:mm a').format(DateTime.parse(widget.assignment['dueDate']))
        : 'No due date';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignment'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Text(
              widget.assignment['subjectName'] ?? 'General Subject',
              style: TextStyle(color: Colors.indigo[700], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.assignment['title'] ?? 'Untitled Assignment',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Due $dueDate', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500)),
            const Divider(height: 32),

            // --- INSTRUCTIONS ---
            const Text('Instructions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              widget.assignment['description'] ?? 'No instructions provided.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 32),

            // --- MY WORK SECTION (TEAMS STYLE) ---
            if (isStudent) ...[
              const Text('My work', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _submissionCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Paste Google Drive Link or Text here...',
                          border: InputBorder.none,
                          icon: Icon(Icons.link),
                        ),
                        maxLines: null,
                      ),
                      const Divider(),
                      TextButton.icon(
                        onPressed: () {
                          // TODO: Implement File Picker package here in the future
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('File upload requires file_picker package. Use link for now.')),
                          );
                        },
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Attach File (Flask Upload)'),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: _isSubmitting ? null : _turnInAssignment,
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Turn in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _turnInAssignment() async {
    if (_submissionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please attach work before turning in.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final id = widget.assignment['id']?.toString() ?? widget.assignment['_id']?.toString() ?? '';
      await ref.read(apiServiceProvider).submitAssignment(id, {'submission': _submissionCtrl.text});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment Turned In!')));
        Navigator.pop(context); // Go back to list
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}