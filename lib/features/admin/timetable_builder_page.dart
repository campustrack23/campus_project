// lib/features/admin/timetable_builder_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/notification.dart';
import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
// --- FIX: Import the new error widget ---
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
  ConsumerState<TimetableBuilderPage> createState() => _TimetableBuilderPageState();
}

class _TimetableBuilderPageState extends ConsumerState<TimetableBuilderPage> {
  int _year = 4;

  List<String> _sectionsForYear(int y) => switch (y) {
    1 => ['I-HE'],
    2 => ['II-HE'],
    3 => ['III-HE'],
    _ => ['IV-HE'],
  };

  static const dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  int _dayIdx(String d) => dayOrder.indexOf(d);
  int _toMin(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(timetableBuilderProvider);

    return Scaffold(
        appBar: AppBar(
          leading: Builder(
            builder: (ctx) => IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          title: const Text('Timetable Builder'),
          actions: [
            const ProfileAvatarAction(),
            IconButton(onPressed: () => ref.invalidate(timetableBuilderProvider), icon: const Icon(Icons.refresh)),
            IconButton(onPressed: () => _openEditor(context), icon: const Icon(Icons.add)),
          ],
        ),
        drawer: const AppDrawer(),
        body: asyncData.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          // --- FIX: Use the new error widget ---
          error: (err, stack) => AsyncErrorWidget(
            message: err.toString(),
            onRetry: () => ref.invalidate(timetableBuilderProvider),
          ),
          // --- End of Fix ---
          data: (data) {
            final allEntries = data['entries'] as List<TimetableEntry>;
            final allSubjects = data['subjects'] as List<Subject>;

            final sections = _sectionsForYear(_year);
            final entries = allEntries
                .where((e) => sections.contains(e.section))
                .toList()
              ..sort((a, b) {
                final d = _dayIdx(a.dayOfWeek).compareTo(_dayIdx(b.dayOfWeek));
                return d != 0 ? d : _toMin(a.startTime).compareTo(_toMin(b.startTime));
              });

            final subjectsMap = {for (final s in allSubjects) s.id: s};

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _yearChip(1),
                      const SizedBox(width: 6),
                      _yearChip(2),
                      const SizedBox(width: 6),
                      _yearChip(3),
                      const SizedBox(width: 6),
                      _yearChip(4),
                    ],
                  ),
                ),
                Expanded(
                  child: entries.isEmpty
                      ? const Center(child: Text('No entries yet. Add one with +'))
                      : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      final subj = subjectsMap[e.subjectId];
                      return ListTile(
                        leading: const Icon(Icons.class_),
                        title: Text(subj?.name ?? e.subjectId),
                        subtitle: Text('${e.dayOfWeek}  ${e.startTime}-${e.endTime} • Room ${e.room} • ${e.section}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _handleDelete(e, subj),
                        ),
                        onTap: () => _openEditor(context, existing: e),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        )
    );
  }

  Future<void> _handleDelete(TimetableEntry e, Subject? subj) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
          '${subj?.name ?? e.subjectId}\n${e.dayOfWeek} ${e.startTime}-${e.endTime} • ${e.section}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;

    await ref.read(timetableRepoProvider).delete(e.id);

    final recipients = (await ref.read(authRepoProvider).allStudents())
        .where((s) => (s.section ?? '').toUpperCase() == e.section.toUpperCase())
        .map((s) => s.id);

    // This uses Firestore Notifier to send a real-time notification
    await ref.read(firestoreNotifierProvider).sendToUsers(
      userIds: recipients,
      title: 'Class Cancelled: ${subj?.name ?? e.subjectId}',
      body: '${e.dayOfWeek} ${e.startTime}-${e.endTime} • Room ${e.room} • ${e.section}',
      type: NotificationType.classChange.name,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notice sent to ${e.section}')));
    ref.invalidate(timetableBuilderProvider);
  }

  Widget _yearChip(int y) => ChoiceChip(
    label: Text('$y${y == 1 ? 'st' : y == 2 ? 'nd' : y == 3 ? 'rd' : 'th'} Year'),
    selected: _year == y,
    onSelected: (selected) {
      if (selected) setState(() => _year = y);
    },
  );

  Future<void> _openEditor(BuildContext context, {TimetableEntry? existing}) async {
    // We must read the provider *before* the async gap
    final provider = ref.read(timetableBuilderProvider);
    final repo = ref.read(timetableRepoProvider);

    // Check if data is already loaded
    if (provider.value == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data not loaded yet. Try refreshing.')));
      return;
    }
    final data = provider.value!;
    final allSubjects = data['subjects'] as List<Subject>;
    final allUsers = data['users'] as List<UserAccount>;

    if (allSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No subjects found. Add subjects first.')));
      return;
    }

    // --- FIX: Get all unique sections from the subjects list ---
    final allSections = allSubjects.map((s) => s.section).toSet().toList()..sort();
    // --- End of Fix ---

    TimetableEntry entryData = existing ?? await repo.newBlankEntry();

    final teachers = allUsers.where((u) => u.role == UserRole.teacher).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final selectedTeacherIds = <String>{...entryData.teacherIds};

    final form = GlobalKey<FormState>();
    String subjectId = entryData.subjectId.isNotEmpty && allSubjects.any((s) => s.id == entryData.subjectId)
        ? entryData.subjectId
        : allSubjects.first.id;
    String day = entryData.dayOfWeek;
    final startCtrl = TextEditingController(text: entryData.startTime);
    final endCtrl = TextEditingController(text: entryData.endTime);
    final roomCtrl = TextEditingController(text: entryData.room);

    // --- FIX: Use state variable for section dropdown ---
    String section = entryData.section;
    if (existing == null) {
      final defaultSec = _sectionsForYear(_year).first;
      section = allSections.contains(defaultSec) ? defaultSec : allSections.first;
    }
    // --- End of Fix ---

    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    bool validTime(String v) => RegExp(r'^\d{2}:\d{2}$').hasMatch(v);
    int toMinLocal(String v) => int.parse(v.substring(0, 2)) * 60 + int.parse(v.substring(3, 5));

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return AlertDialog(
            title: Text(existing == null ? 'Add Entry' : 'Edit Entry'),
            content: Form(
              key: form,
              child: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: subjectId,
                        isExpanded: true,
                        menuMaxHeight: 360,
                        items: allSubjects
                            .map((s) => DropdownMenuItem<String>(
                          value: s.id,
                          child: Text('${s.code} — ${s.name}', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setModalState(() => subjectId = v ?? allSubjects.first.id),
                        decoration: const InputDecoration(labelText: 'Subject'),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: day,
                        items: days.map((d) => DropdownMenuItem<String>(value: d, child: Text(d))).toList(),
                        onChanged: (v) => setModalState(() => day = v ?? 'Mon'),
                        decoration: const InputDecoration(labelText: 'Day of week'),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start time (HH:mm)'), validator: (v) => (v == null || !validTime(v)) ? 'Use HH:mm' : null),
                      const SizedBox(height: 8),
                      TextFormField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End time (HH:mm)'), validator: (v) {
                        if (v == null || !validTime(v)) return 'Use HH:mm';
                        if (validTime(startCtrl.text) && toMinLocal(v) <= toMinLocal(startCtrl.text)) return 'End must be after start';
                        return null;
                      }),
                      const SizedBox(height: 8),
                      TextFormField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room'), validator: (v) => v!.isEmpty ? 'Required' : null),
                      const SizedBox(height: 8),
                      // --- FIX: Change TextFormField to DropdownButtonFormField ---
                      DropdownButtonFormField<String>(
                        initialValue: section,
                        items: allSections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (v) => setModalState(() => section = v ?? allSections.first),
                        decoration: const InputDecoration(labelText: 'Section'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                      // --- End of Fix ---
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Teachers (max 2)', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 180),
                        child: SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: teachers.map((t) {
                              final selected = selectedTeacherIds.contains(t.id);
                              return FilterChip(
                                label: Text(t.name, overflow: TextOverflow.ellipsis),
                                selected: selected,
                                onSelected: (v) => setModalState(() {
                                  if (v) { if (selectedTeacherIds.length < 2) selectedTeacherIds.add(t.id); }
                                  else { selectedTeacherIds.remove(t.id); }
                                }),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      if (selectedTeacherIds.length >= 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text('Max 2 teachers selected', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  if (!form.currentState!.validate()) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (ok == true) {
      final newEntry = TimetableEntry(
        id: entryData.id,
        subjectId: subjectId,
        dayOfWeek: day,
        startTime: startCtrl.text.trim(),
        endTime: endCtrl.text.trim(),
        room: roomCtrl.text.trim(),
        // --- FIX: Use dropdown value ---
        section: section,
        teacherIds: selectedTeacherIds.toList(),
      );
      await repo.addOrUpdate(newEntry);

      final subj = allSubjects.firstWhere((s) => s.id == newEntry.subjectId, orElse: () => Subject(id: newEntry.subjectId, code: 'N/A', name: 'Unknown', department: '', semester: '', section: '', teacherId: ''));
      final recipients = (await ref.read(authRepoProvider).allStudents())
          .where((s) => (s.section ?? '').toUpperCase() == newEntry.section.toUpperCase())
          .map((s) => s.id);

      await ref.read(firestoreNotifierProvider).sendToUsers(
        userIds: recipients,
        title: 'Class Updated: ${subj.name}',
        body: '${newEntry.dayOfWeek} ${newEntry.startTime}-${newEntry.endTime} • Room ${newEntry.room}',
        type: NotificationType.classChange.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notice sent to ${newEntry.section}')));
        ref.invalidate(timetableBuilderProvider);
      }
    }
  }
}
