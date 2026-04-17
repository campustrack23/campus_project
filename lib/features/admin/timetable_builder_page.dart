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

// -----------------------------------------------------------------------------
// PROVIDER
// -----------------------------------------------------------------------------
final timetableBuilderProvider = FutureProvider.autoDispose((ref) async {
  final ttRepo = ref.watch(timetableRepoProvider);
  final authRepo = ref.watch(authRepoProvider);

  final results = await Future.wait([
    ttRepo.allEntries(),
    ttRepo.allSubjects(),
    authRepo.allUsers(),
  ]);

  return {
    'entries': results[0] as List<TimetableEntry>,
    'subjects': results[1] as List<Subject>,
    'users': results[2] as List<UserAccount>,
  };
});

// -----------------------------------------------------------------------------
// MAIN PAGE
// -----------------------------------------------------------------------------
class TimetableBuilderPage extends ConsumerStatefulWidget {
  const TimetableBuilderPage({super.key});

  @override
  ConsumerState<TimetableBuilderPage> createState() => _TimetableBuilderPageState();
}

class _TimetableBuilderPageState extends ConsumerState<TimetableBuilderPage> {
  int _selectedYear = 4;
  String _selectedDay = 'Mon';

  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  String _getSectionPrefix(int year) {
    return switch (year) {
      1 => 'I-',
      2 => 'II-',
      3 => 'III-',
      _ => 'IV-',
    };
  }

  // ✅ NEW: Strict filtering logic to ONLY get subjects for the selected year
  List<Subject> _getSubjectsForSelectedYear(List<Subject> allSubjects) {
    return allSubjects.where((s) {
      final sem = s.semester.toString();
      final sec = s.section.toString();
      if (_selectedYear == 1 && (sem == '1' || sem == '2' || sec.startsWith('I-'))) return true;
      if (_selectedYear == 2 && (sem == '3' || sem == '4' || sec.startsWith('II-'))) return true;
      if (_selectedYear == 3 && (sem == '5' || sem == '6' || sec.startsWith('III-'))) return true;
      if (_selectedYear == 4 && (sem == '7' || sem == '8' || sec.startsWith('IV-'))) return true;
      return false;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(timetableBuilderProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Builder', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: const [ProfileAvatarAction()],
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(message: err.toString(), onRetry: () => ref.invalidate(timetableBuilderProvider)),
        data: (data) {
          final allEntries = data['entries'] as List<TimetableEntry>;
          final allSubjects = data['subjects'] as List<Subject>;
          final users = data['users'] as List<UserAccount>;
          final teachers = users.where((u) => u.role == UserRole.teacher).toList();

          // 1. Filter Entries for the list
          final sectionPrefix = _getSectionPrefix(_selectedYear);
          final filteredEntries = allEntries
              .where((e) => e.section.startsWith(sectionPrefix) && e.dayOfWeek == _selectedDay)
              .toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));

          // 2. Filter Subjects for the dropdowns
          final validSubjectsForYear = _getSubjectsForSelectedYear(allSubjects);

          return Column(
            children: [
              // --- PREMIUM FILTER HEADER ---
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4))),
                ),
                child: Column(
                  children: [
                    // YEAR SELECTOR
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('1st Year')),
                          ButtonSegment(value: 2, label: Text('2nd Year')),
                          ButtonSegment(value: 3, label: Text('3rd Year')),
                          ButtonSegment(value: 4, label: Text('4th Year')),
                        ],
                        selected: {_selectedYear},
                        onSelectionChanged: (Set<int> newSelection) {
                          setState(() => _selectedYear = newSelection.first);
                        },
                        style: SegmentedButton.styleFrom(
                          backgroundColor: colorScheme.surface,
                          selectedBackgroundColor: colorScheme.primaryContainer,
                          selectedForegroundColor: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),

                    // DAY SELECTOR
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: days.map((d) {
                          final isSel = d == _selectedDay;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8, bottom: 16),
                            child: FilterChip(
                              label: Text(d),
                              selected: isSel,
                              showCheckmark: false,
                              onSelected: (v) => setState(() => _selectedDay = d),
                              backgroundColor: colorScheme.surface,
                              selectedColor: colorScheme.primary,
                              labelStyle: TextStyle(
                                color: isSel ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // --- TIMELINE LIST ---
              Expanded(
                child: filteredEntries.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredEntries.length,
                  itemBuilder: (context, index) {
                    final entry = filteredEntries[index];
                    final subj = allSubjects.firstWhere(
                          (s) => s.id == entry.subjectId,
                      orElse: () => const Subject(id: '', code: '?', name: 'Unknown', department: '', semester: '', section: '', teacherId: ''),
                    );
                    return _buildTimelineCard(entry, subj, validSubjectsForYear, teachers);
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final data = await ref.read(timetableBuilderProvider.future);
          final validSubjects = _getSubjectsForSelectedYear(data['subjects'] as List<Subject>);
          final teachers = (data['users'] as List<UserAccount>).where((u) => u.role == UserRole.teacher).toList();

          if (context.mounted) {
            _showEditDialog(null, validSubjects, teachers);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TIMELINE CARD WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildTimelineCard(TimetableEntry entry, Subject subj, List<Subject> validSubjects, List<UserAccount> teachers) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Time Block
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const SizedBox(height: 12),
                Text(
                  entry.startTime,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorScheme.primary),
                ),
                Text(
                  entry.endTime,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Right Content Card
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            subj.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              icon: Icon(Icons.edit_outlined, size: 20, color: colorScheme.secondary),
                              onPressed: () => _showEditDialog(entry, validSubjects, teachers),
                            ),
                            IconButton(
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(4),
                              icon: Icon(Icons.delete_outline, size: 20, color: colorScheme.error),
                              onPressed: () => _confirmDelete(entry.id),
                            ),
                          ],
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: colorScheme.secondaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
                          child: Text('Sec: ${entry.section}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: colorScheme.tertiaryContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            children: [
                              Icon(Icons.room, size: 12, color: colorScheme.tertiary),
                              const SizedBox(width: 4),
                              Text(entry.room, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.tertiary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (entry.teacherIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Divider(height: 1, color: isDark ? Colors.white12 : Colors.black12),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${entry.teacherIds.length} Teacher(s) Assigned',
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      )
                    ]
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.event_busy_rounded, size: 64, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text('No classes scheduled', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'There are no Year $_selectedYear classes on $_selectedDay.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ADD / EDIT DIALOG
  // ---------------------------------------------------------------------------
  Future<void> _showEditDialog(TimetableEntry? entry, List<Subject> validSubjects, List<UserAccount> teachers) async {
    final isNew = entry == null;
    final id = entry?.id ?? const Uuid().v4();

    // If editing, and the subject isn't in our filtered list, we must add it temporarily so it doesn't crash the dropdown
    String? subjectId = entry?.subjectId;
    if (subjectId != null && !validSubjects.any((s) => s.id == subjectId)) {
      subjectId = null; // Force them to pick a valid one for this year
    } else if (subjectId == null && validSubjects.isNotEmpty) {
      subjectId = validSubjects.first.id;
    }

    String day = entry?.dayOfWeek ?? _selectedDay;
    String section = entry?.section ?? '${_getSectionPrefix(_selectedYear)}HE';

    final startCtrl = TextEditingController(text: entry?.startTime ?? '09:00');
    final endCtrl = TextEditingController(text: entry?.endTime ?? '10:00');
    final roomCtrl = TextEditingController(text: entry?.room ?? 'Room ');

    final Set<String> selectedTeacherIds = (entry?.teacherIds ?? []).toSet();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              width: 500, // Enterprise wide dialog
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNew ? 'Schedule New Class' : 'Edit Class Schedule',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 24),

                    if (validSubjects.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Text('⚠️ No subjects found for this Year. Please create subjects first.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: subjectId,
                        decoration: InputDecoration(
                          labelText: 'Select Subject (Year $_selectedYear Only)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.menu_book),
                        ),
                        items: validSubjects.map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text('${s.name} (${s.code})', overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) => setState(() => subjectId = v!),
                      ),

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: day,
                            items: days.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                            onChanged: (v) => setState(() => day = v!),
                            decoration: InputDecoration(
                              labelText: 'Day',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              prefixIcon: const Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: section,
                            decoration: InputDecoration(
                              labelText: 'Section Code',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (v) => section = v,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                                controller: startCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Start (HH:MM)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  prefixIcon: const Icon(Icons.access_time),
                                )
                            )
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: TextFormField(
                                controller: endCtrl,
                                decoration: InputDecoration(
                                  labelText: 'End (HH:MM)',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                )
                            )
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: roomCtrl,
                        decoration: InputDecoration(
                          labelText: 'Room Number',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.room),
                        )
                    ),
                    const SizedBox(height: 24),

                    const Text('Assigned Teachers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: teachers.map((t) {
                          final isSel = selectedTeacherIds.contains(t.id);
                          return FilterChip(
                            label: Text(t.name),
                            selected: isSel,
                            showCheckmark: false,
                            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                            selectedColor: Theme.of(context).colorScheme.primaryContainer,
                            labelStyle: TextStyle(color: isSel ? Theme.of(context).colorScheme.onPrimaryContainer : null, fontWeight: isSel ? FontWeight.bold : null),
                            onSelected: (sel) {
                              setState(() {
                                if (sel) {
                                  selectedTeacherIds.add(t.id);
                                } else {
                                  selectedTeacherIds.remove(t.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        const SizedBox(width: 12),
                        FilledButton(
                          onPressed: () async {
                            if (subjectId == null || subjectId!.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a valid subject.')));
                              return;
                            }

                            final newEntry = TimetableEntry(
                              id: id,
                              subjectId: subjectId!,
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
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text('Save Class'),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DELETE CONFIRMATION
  // ---------------------------------------------------------------------------
  Future<void> _confirmDelete(String entryId) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Class?'),
          content: const Text('Are you sure you want to remove this class from the timetable? This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        )
    );

    if (confirm == true) {
      await ref.read(timetableRepoProvider).delete(entryId);
      ref.invalidate(timetableBuilderProvider);
    }
  }
}