// lib/features/teacher/remarks_board_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/user.dart';
import '../../core/models/remark.dart';
import '../../core/models/role.dart';
import '../../main.dart';

// -----------------------------------------------------------------------------
// PROVIDER
// -----------------------------------------------------------------------------
final remarksBoardProvider = FutureProvider.autoDispose((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final me = await authRepo.currentUser();
  if (me == null) throw Exception('Not logged in');

  final remarkRepo = ref.watch(remarkRepoProvider);
  final remarks = await remarkRepo.forTeacher(me.id);
  final students = await authRepo.allStudents();

  return {
    'me': me,
    'remarks': remarks,
    'students': students,
  };
});

// -----------------------------------------------------------------------------
// MAIN PAGE
// -----------------------------------------------------------------------------
class RemarksBoardPage extends ConsumerStatefulWidget {
  const RemarksBoardPage({super.key});

  @override
  ConsumerState<RemarksBoardPage> createState() => _RemarksBoardPageState();
}

class _RemarksBoardPageState extends ConsumerState<RemarksBoardPage> {
  String _searchQuery = '';
  String _filterTag = 'All';

  final UserAccount _unknownUser = UserAccount(
    id: '?',
    role: UserRole.student,
    name: 'Unknown Student',
    phone: '',
    isActive: false,
    createdAt: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(remarksBoardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Remarks Board'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(remarksBoardProvider),
        ),
        data: (data) {
          final remarks = data['remarks'] as List<StudentRemark>;
          final students = data['students'] as List<UserAccount>;
          final teacherId = (data['me'] as UserAccount).id;

          // Extract unique tags for top filter
          final uniqueTags = ['All', ...remarks.map((r) => r.tag).toSet()];

          // Filter existing remarks
          final filteredRemarks = remarks.where((r) {
            if (_filterTag != 'All' && r.tag != _filterTag) return false;
            final st = students.firstWhere((s) => s.id == r.studentId, orElse: () => _unknownUser);
            if (_searchQuery.isNotEmpty) {
              return st.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  (st.collegeRollNo ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
            }
            return true;
          }).toList();

          return Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search remarks by student name...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              if (uniqueTags.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: uniqueTags.map((tag) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(tag),
                          selected: _filterTag == tag,
                          onSelected: (selected) {
                            setState(() => _filterTag = selected ? tag : 'All');
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 8),

              // Remarks List
              Expanded(
                child: filteredRemarks.isEmpty
                    ? Center(
                  child: Text(
                    remarks.isEmpty ? 'No remarks added yet.' : 'No remarks match your search.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: filteredRemarks.length,
                  itemBuilder: (context, index) {
                    final r = filteredRemarks[index];
                    final st = students.firstWhere((s) => s.id == r.studentId, orElse: () => _unknownUser);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(st.name.isNotEmpty ? st.name[0] : '?'),
                        ),
                        title: Text(st.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('CR: ${st.collegeRollNo ?? 'N/A'} • Year: ${st.year ?? '?'}'),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(r.tag, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSecondaryContainer)),
                            ),
                          ],
                        ),
                        trailing: Text(
                          DateFormat('MMM d').format(r.updatedAt),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        onTap: () => _editRemarkDialog(context, ref, teacherId, st, existingTag: r.tag),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: asyncData.maybeWhen(
        data: (data) => FloatingActionButton.extended(
          onPressed: () {
            _showModernStudentSelector(
              context,
              ref,
              data['students'] as List<UserAccount>,
              (data['me'] as UserAccount).id,
            );
          },
          icon: const Icon(Icons.add_comment),
          label: const Text('Add Remark'),
        ),
        orElse: () => null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MODERN STUDENT SELECTOR BOTTOM SHEET
  // ---------------------------------------------------------------------------
  void _showModernStudentSelector(
      BuildContext context,
      WidgetRef ref,
      List<UserAccount> allStudents,
      String teacherId,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows sheet to take up more screen height
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ModernStudentSelector(
        students: allStudents,
        onStudentSelected: (selectedStudent) {
          Navigator.pop(ctx); // Close the sheet
          _editRemarkDialog(context, ref, teacherId, selectedStudent); // Open remark input
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT/ADD REMARK DIALOG
  // ---------------------------------------------------------------------------
  Future<void> _editRemarkDialog(BuildContext context, WidgetRef ref, String teacherId, UserAccount student, {String? existingTag}) async {
    final controller = TextEditingController(text: existingTag);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${existingTag == null ? 'Add' : 'Edit'} Remark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student: ${student.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Remark / Tag',
                hintText: 'e.g. Excellent, Needs Improvement, Warned',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                try {
                  await ref.read(remarkRepoProvider).upsertRemark(
                    teacherId: teacherId,
                    studentId: student.id,
                    tag: controller.text.trim(),
                  );
                  ref.invalidate(remarksBoardProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remark saved successfully')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              }
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SEPARATE STATEFUL WIDGET FOR THE BOTTOM SHEET TO MANAGE ITS OWN FILTER STATE
// -----------------------------------------------------------------------------
class _ModernStudentSelector extends StatefulWidget {
  final List<UserAccount> students;
  final Function(UserAccount) onStudentSelected;

  const _ModernStudentSelector({
    required this.students,
    required this.onStudentSelected,
  });

  @override
  State<_ModernStudentSelector> createState() => _ModernStudentSelectorState();
}

class _ModernStudentSelectorState extends State<_ModernStudentSelector> {
  String _search = '';
  int _selectedYear = 0; // 0 = All Years
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    // 1. Filter
    var filtered = widget.students.where((s) {
      final matchSearch = s.name.toLowerCase().contains(_search.toLowerCase()) ||
          (s.collegeRollNo ?? '').toLowerCase().contains(_search.toLowerCase());
      final matchYear = _selectedYear == 0 || s.year == _selectedYear;
      return matchSearch && matchYear;
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      final cmp = a.name.compareTo(b.name);
      return _sortAscending ? cmp : -cmp;
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.85, // Takes up 85% of screen
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header & Sort Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select Student', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    TextButton.icon(
                      onPressed: () => setState(() => _sortAscending = !_sortAscending),
                      icon: Icon(_sortAscending ? Icons.arrow_downward : Icons.arrow_upward, size: 18),
                      label: Text(_sortAscending ? 'A-Z' : 'Z-A'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    hintText: 'Search by name or roll no...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 16),

              // Year Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [0, 1, 2, 3, 4].map((year) {
                    final isSelected = _selectedYear == year;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(year == 0 ? 'All Years' : 'Year $year'),
                        selected: isSelected,
                        onSelected: (val) => setState(() => _selectedYear = year),
                        showCheckmark: false,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        selectedColor: Theme.of(context).colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 24),

              // Student List
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('No students found.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final s = filtered[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(s.name.isNotEmpty ? s.name[0] : '?'),
                      ),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('CR: ${s.collegeRollNo ?? 'N/A'} • Year ${s.year ?? '?'}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.add_circle),
                        color: Theme.of(context).colorScheme.primary,
                        onPressed: () => widget.onStudentSelected(s),
                      ),
                      onTap: () => widget.onStudentSelected(s),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}