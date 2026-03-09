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

  TeacherDashboardVM({
    required this.allEntries,
    required this.nextClass,
    required this.todaysClasses,
    required this.canMarkNext,
    required this.subjectsMap,
    required this.teacherNamesMap,
    required this.subjectLeadMap,
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

  final allEntries = results[0] as List<TimetableEntry>;
  final subjects = results[1] as List<Subject>;
  final users = results[2] as List<UserAccount>;

  final subjectsMap = {for (var s in subjects) s.id: s};
  final teacherNamesMap = {for (var u in users) u.id: u.name};
  final subjectLeadMap = {for (var s in subjects) s.id: teacherNamesMap[s.teacherId] ?? 'Unknown'};

  // Determine Today's Classes
  // Logic: 1=Mon...7=Sun
  final todayNum = DateTime.now().weekday;
  final dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
  final todayStr = dayMap[todayNum] ?? 'Mon';

  final todaysClasses = allEntries.where((e) => e.dayOfWeek == todayStr).toList();
  todaysClasses.sort((a, b) => a.startTime.compareTo(b.startTime));

  UpcomingClass? next;

  return TeacherDashboardVM(
    allEntries: allEntries,
    nextClass: next,
    todaysClasses: todaysClasses,
    canMarkNext: true, // simplified
    subjectsMap: subjectsMap,
    teacherNamesMap: teacherNamesMap,
    subjectLeadMap: subjectLeadMap,
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
          onRetry: () => ref.refresh(teacherDashboardProvider),
        ),
        data: (vm) => RefreshIndicator(
          onRefresh: () async => ref.refresh(teacherDashboardProvider),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(vm: vm),
                _ActionButtons(),
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
                            // FIX: Updated path to match main.dart route
                            await context.push('/teacher/generate-qr/${entry.id}');

                            // Refresh upon return
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

  @override
  Widget build(BuildContext context) {
    final dayMap = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat'};
    final dayKey = dayMap[_selectedDay] ?? 'Mon';

    return Column(
      children: [
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
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 300,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TimetableGrid(
            days: [dayKey],
            periodStarts: const ['08:30', '09:30', '10:30', '11:30', '12:30', '13:30', '14:30', '15:30', '16:30'],
            periodLabels: const ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'],
            entries: widget.vm.allEntries,
            subjectCodes: {for (var k in widget.vm.subjectsMap.keys) k: widget.vm.subjectsMap[k]?.code ?? ''},
            subjectLeadTeacherId: {for (var k in widget.vm.subjectsMap.keys) k: widget.vm.subjectsMap[k]?.teacherId ?? ''},
            teacherNames: widget.vm.teacherNamesMap,
            todayKey: dayKey,
          ),
        ),
      ],
    );
  }
}