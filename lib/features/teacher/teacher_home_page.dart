// lib/features/teacher/teacher_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../common/widgets/timetable_grid.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../core/utils/time_formatter.dart';
import '../../main.dart';

// --- VIEW MODEL ---
class TeacherDashboardVM {
  final List<TimetableEntry> allEntries;
  final UpcomingClass? nextClass;
  final List<TimetableEntry> todaysClasses;
  final bool canMarkNext;
  final Map<String, Subject> subjectsMap;
  final Map<String, String> teacherNamesMap;
  final Map<String, String> subjectLeadMap;
  final String currentTeacherId;

  TeacherDashboardVM({
    required this.allEntries,
    required this.nextClass,
    required this.todaysClasses,
    required this.canMarkNext,
    required this.subjectsMap,
    required this.teacherNamesMap,
    required this.subjectLeadMap,
    required this.currentTeacherId,
  });
}

class UpcomingClass {
  final TimetableEntry entry;
  final int minutesToStart;
  final bool isOngoing;
  UpcomingClass(this.entry, this.minutesToStart, {required this.isOngoing});
}

// --- PROVIDER ---
final teacherDashboardProvider = FutureProvider.autoDispose<TeacherDashboardVM>((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final ttRepo = ref.watch(timetableRepoProvider);

  final user = await authRepo.currentUser();
  if (user == null) throw Exception('Not logged in');

  final results = await Future.wait([
    ttRepo.forTeacher(user.id),
    ttRepo.allSubjects(),
    authRepo.allUsers(),
  ]);

  final rawEntries = results[0] as List<TimetableEntry>;
  final subjects = results[1] as List<Subject>;
  final users = results[2] as List<UserAccount>;

  final subjectsMap = {for (var s in subjects) s.id: s};
  final teacherNamesMap = {for (var u in users) u.id: u.name};
  final subjectLeadMap = {for (var s in subjects) s.id: teacherNamesMap[s.teacherId] ?? 'Unknown'};

  // 🔴 CRITICAL FIX: Normalize days from Seeder ("1" -> "Mon")
  final normalizedEntries = rawEntries.map((e) {
    String day = e.dayOfWeek;
    const seederMap = {'1': 'Mon', '2': 'Tue', '3': 'Wed', '4': 'Thu', '5': 'Fri', '6': 'Sat'};
    final safeDay = seederMap[day] ?? day;

    final dataMap = e.toMap();
    dataMap['dayOfWeek'] = safeDay;
    return TimetableEntry.fromMap(e.id, dataMap);
  }).toList();

  // Determine Today's Classes
  final todayNum = DateTime.now().weekday;
  final dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
  final todayStr = dayMap[todayNum] ?? 'Mon';

  final todaysClasses = normalizedEntries.where((e) => e.dayOfWeek == todayStr).toList();
  todaysClasses.sort((a, b) => a.startTime.compareTo(b.startTime));

  UpcomingClass? next;

  return TeacherDashboardVM(
    allEntries: normalizedEntries,
    nextClass: next,
    todaysClasses: todaysClasses,
    canMarkNext: true,
    subjectsMap: subjectsMap,
    teacherNamesMap: teacherNamesMap,
    subjectLeadMap: subjectLeadMap,
    currentTeacherId: user.id,
  );
});

class TeacherHomePage extends ConsumerWidget {
  const TeacherHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(teacherDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty Dashboard'),
        actions: const [ProfileAvatarAction()],
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(teacherDashboardProvider),
        ),
        data: (vm) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(teacherDashboardProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(vm: vm),
                const _ActionButtons(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text('Today\'s Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                if (vm.todaysClasses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('No classes today!', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vm.todaysClasses.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final entry = vm.todaysClasses[i];
                      final subj = vm.subjectsMap[entry.subjectId];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            TimeFormatter.formatTime(entry.startTime).split(' ')[0],
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(subj?.name ?? 'Unknown Subject', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${entry.room} • ${entry.section}'),
                        trailing: FilledButton.icon(
                          onPressed: () async {
                            await context.push('/teacher/generate-qr/${entry.id}');
                            ref.invalidate(teacherDashboardProvider);
                          },
                          icon: const Icon(Icons.qr_code, size: 18),
                          label: const Text('Take'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Weekly Timetable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 8),
                _TimetablePreview(vm: vm),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TeacherDashboardVM vm;
  const _Header({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good day, Professor!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(
            'You have ${vm.todaysClasses.length} classes today.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
              onPressed: () => context.push('/teacher/internal-marks'),
              icon: const Icon(Icons.assessment),
              label: const Text('Marks')
          ),
          FilledButton.tonalIcon(
              onPressed: () => context.push('/teacher/remarks-board'),
              icon: const Icon(Icons.label),
              label: const Text('Remarks')
          ),
          FilledButton.tonalIcon(
              onPressed: () => context.push('/students/directory'),
              icon: const Icon(Icons.people),
              label: const Text('Students')
          ),
        ],
      ),
    );
  }
}

class _TimetablePreview extends StatefulWidget {
  final TeacherDashboardVM vm;
  const _TimetablePreview({required this.vm});

  @override
  State<_TimetablePreview> createState() => _TimetablePreviewState();
}

class _TimetablePreviewState extends State<_TimetablePreview> {
  int _selectedDay = DateTime.now().weekday; // 1=Mon
  int? _selectedYear; // null = All years

  @override
  Widget build(BuildContext context) {
    final dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat'};
    final dayKey = dayMap[_selectedDay] ?? 'Mon';

    // 🔴 FILTER LOGIC: Filter entries based on the selected year chip
    final filteredEntries = widget.vm.allEntries.where((e) {
      if (_selectedYear == null) return true;
      if (_selectedYear == 1 && e.section.startsWith('I-')) return true;
      if (_selectedYear == 2 && e.section.startsWith('II-')) return true;
      if (_selectedYear == 3 && e.section.startsWith('III-')) return true;
      if (_selectedYear == 4 && e.section.startsWith('IV-')) return true;
      return false;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 🔴 YEAR FILTERS ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildYearChip('All', null),
              const SizedBox(width: 8),
              _buildYearChip('1st Yr', 1),
              const SizedBox(width: 8),
              _buildYearChip('2nd Yr', 2),
              const SizedBox(width: 8),
              _buildYearChip('3rd Yr', 3),
              const SizedBox(width: 8),
              _buildYearChip('4th Yr', 4),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // --- DAY FILTERS ---
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [1, 2, 3, 4, 5, 6].map((d) {
              final isSel = d == _selectedDay;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(dayMap[d]!),
                  selected: isSel,
                  onSelected: (v) => setState(() => _selectedDay = d),
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // --- TIMETABLE GRID ---
        filteredEntries.isEmpty
            ? Container(
          height: 150,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: Text(
              _selectedYear == null
                  ? 'No classes scheduled.'
                  : 'No classes for Year $_selectedYear.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        )
            : TimetableGrid(
          days: [dayKey],
          periodStarts: const ['09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00'],
          periodLabels: const ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'],
          entries: filteredEntries, // Pass the filtered list here!
          subjectCodes: {for (var k in widget.vm.subjectsMap.keys) k: widget.vm.subjectsMap[k]?.code ?? ''},
          subjectLeadTeacherId: {for (var k in widget.vm.subjectsMap.keys) k: widget.vm.subjectsMap[k]?.teacherId ?? ''},
          teacherNames: widget.vm.teacherNamesMap,
          todayKey: dayKey,
          currentTeacherId: widget.vm.currentTeacherId,
          cancelledEntryIds: const {}, // Empty set for teachers as overrides are handled differently
        ),
      ],
    );
  }

  Widget _buildYearChip(String label, int? yearValue) {
    final isSelected = _selectedYear == yearValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _selectedYear = selected ? yearValue : null;
        });
      },
      selectedColor: Theme.of(context).colorScheme.primaryContainer,
    );
  }
}