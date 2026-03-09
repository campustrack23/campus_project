// lib/features/admin/timetable_builder_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/models/role.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../main.dart';

final timetableBuilderProvider = FutureProvider.autoDispose((ref) async {
  final ttRepo = ref.watch(timetableRepoProvider);
  final authRepo = ref.watch(authRepoProvider);

  final entries = await ttRepo.allEntries();
  final subjects = await ttRepo.allSubjects();
  final users = await authRepo.allUsers();

  return {
    'entries': entries,
    'subjects': subjects,
    'users': users,
  };
});

class TimetableBuilderPage extends ConsumerStatefulWidget {
  const TimetableBuilderPage({super.key});

  @override
  ConsumerState<TimetableBuilderPage> createState() =>
      _TimetableBuilderPageState();
}

class _TimetableBuilderPageState extends ConsumerState<TimetableBuilderPage> {
  int _year = 4;
  String _day = 'Mon';

  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(timetableBuilderProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Builder'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.refresh(timetableBuilderProvider)
        ),
        data: (data) {
          final allEntries = data['entries'] as List<TimetableEntry>;
          final subjects = data['subjects'] as List<Subject>;
          final users = data['users'] as List<UserAccount>;
          final teachers = users.where((u) => u.role == UserRole.teacher).toList();

          // Filter by Year (Rough mapping)
          final sectionPrefix = _getSectionPrefix(_year);
          final filtered = allEntries
              .where((e) => e.section.startsWith(sectionPrefix) && e.dayOfWeek == _day)
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          return Column(
            children: [
              // --- Controls ---
              Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButton<int>(
                        value: _year,
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('1st Year')),
                          DropdownMenuItem(value: 2, child: Text('2nd Year')),
                          DropdownMenuItem(value: 3, child: Text('3rd Year')),
                          DropdownMenuItem(value: 4, child: Text('4th Year')),
                        ],
                        onChanged: (v) => setState(() => _year = v!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _day,
                        isExpanded: true,
                        items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                        onChanged: (v) => setState(() => _day = v!),
                      ),
                    ),
                  ],
                ),
              ),

              // --- List ---
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final subj = subjects.firstWhere(
                          (s) => s.id == entry.subjectId,
                      orElse: () => const Subject(id: '', code: '?', name: 'Unknown', department: '', semester: '', section: '', teacherId: ''),
                    );

                    return Card(
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.startTime,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        title: Text(subj.name),
                        subtitle: Text('${entry.room} • ${entry.section}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditDialog(entry, subjects, teachers),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await ref.read(timetableRepoProvider).delete(entry.id);
                                ref.invalidate(timetableBuilderProvider);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(null, [], []), // Will handle null inside
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getSectionPrefix(int year) {
    return switch (year) {
      1 => 'I-', 2 => 'II-', 3 => 'III-', _ => 'IV-',
    };
  }

  Future<void> _showEditDialog(TimetableEntry? entry, List<Subject> subjects, List<UserAccount> teachers) async {
    // If subjects/teachers empty (clicked FAB before load), refetch or guard
    if (subjects.isEmpty) {
      final data = await ref.read(timetableBuilderProvider.future);
      subjects = data['subjects'] as List<Subject>;
      final users = data['users'] as List<UserAccount>;
      teachers = users.where((u) => u.role == UserRole.teacher).toList();
    }

    // Default or existing
    final isNew = entry == null;
    final id = entry?.id ?? const Uuid().v4();
    String subjectId = entry?.subjectId ?? (subjects.isNotEmpty ? subjects.first.id : '');
    String day = entry?.dayOfWeek ?? _day;
    String section = entry?.section ?? '${_getSectionPrefix(_year)}HE';

    final startCtrl = TextEditingController(text: entry?.startTime ?? '09:30');
    final endCtrl = TextEditingController(text: entry?.endTime ?? '10:30');
    final roomCtrl = TextEditingController(text: entry?.room ?? '301');

    final Set<String> selectedTeacherIds = (entry?.teacherIds ?? []).toSet();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isNew ? 'Add Class' : 'Edit Class'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: subjects.any((s) => s.id == subjectId) ? subjectId : null,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    items: subjects.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => subjectId = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: day,
                          items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                          onChanged: (v) => setState(() => day = v!),
                          decoration: const InputDecoration(labelText: 'Day'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: section,
                          decoration: const InputDecoration(labelText: 'Section'),
                          onChanged: (v) => section = v,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: TextFormField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start (HH:MM)'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End (HH:MM)'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room No')),
                  const SizedBox(height: 16),
                  const Text('Assigned Teachers', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: teachers.map((t) {
                      final isSel = selectedTeacherIds.contains(t.id);
                      return FilterChip(
                        label: Text(t.name),
                        selected: isSel,
                        onSelected: (sel) {
                          setState(() {
                            if (sel) selectedTeacherIds.add(t.id);
                            else selectedTeacherIds.remove(t.id);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () async {
                  if (subjectId.isEmpty) return;

                  final newEntry = TimetableEntry(
                    id: id,
                    subjectId: subjectId,
                    dayOfWeek: day,
                    startTime: startCtrl.text.trim(),
                    endTime: endCtrl.text.trim(),
                    room: roomCtrl.text.trim(),
                    section: section,
                    teacherIds: selectedTeacherIds.toList(),
                  );

                  await ref.read(timetableRepoProvider).addOrUpdate(newEntry);
                  ref.invalidate(timetableBuilderProvider);

                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}