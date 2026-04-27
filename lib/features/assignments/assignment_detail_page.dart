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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ FIX: Support both camelCase and snake_case formatting
    final rawDueDate = widget.assignment['dueDate'] ?? widget.assignment['due_date'];
    final dueDate = rawDueDate != null
        ? DateFormat('EEEE, MMM d, yyyy • h:mm a').format(DateTime.parse(rawDueDate))
        : 'No due date';

    final displaySubject = widget.assignment['subjectName'] ?? widget.assignment['subject_name'] ?? 'General Subject';
    final displayTitle = widget.assignment['title'] ?? 'Untitled Assignment';
    final displayDesc = widget.assignment['description'] ?? 'No instructions provided by the instructor.';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PREMIUM HEADER ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      displaySubject.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    displayTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.2),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: Colors.white.withValues(alpha: 0.8), size: 16),
                      const SizedBox(width: 8),
                      Text('Due: $dueDate', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            // --- INSTRUCTIONS ---
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instructions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colorScheme.primary, letterSpacing: 1.0)),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
                    ),
                    child: Text(
                      displayDesc,
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- MY WORK SECTION (TEAMS STYLE) ---
                  if (isStudent) ...[
                    Text('Submit Your Work', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colorScheme.primary, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _submissionCtrl,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Paste Google Drive Link or Text here...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(20),
                              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                          Divider(height: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('File upload requires backend file storage. Please paste a link for now.')),
                                    );
                                  },
                                  icon: const Icon(Icons.attach_file_rounded),
                                  label: const Text('Attach File'),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: _isSubmitting ? null : _turnInAssignment,
                        icon: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.send_rounded),
                        label: Text(_isSubmitting ? 'Turning In...' : 'Turn In Assignment', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _turnInAssignment() async {
    if (_submissionCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please attach work or paste a link before turning in.'), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final id = widget.assignment['id']?.toString() ?? widget.assignment['_id']?.toString() ?? '';
      await ref.read(apiServiceProvider).submitAssignment(id, {'submission': _submissionCtrl.text});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assignment Turned In Successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context); // Go back to list
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}