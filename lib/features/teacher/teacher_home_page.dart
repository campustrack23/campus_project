// lib/features/teacher/teacher_home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../common/widgets/timetable_grid.dart';
import '../../core/models/role.dart';
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

// --- OPTIMIZED PROVIDER ---
final teacherDashboardProvider = FutureProvider.autoDispose<TeacherDashboardVM>((ref) async {
  // 1. KeepAlive for 5 minutes
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), () => link.close());
  ref.onDispose(() => timer.cancel());

  final authRepo = ref.watch(authRepoProvider);
  final teacher = await authRepo.currentUser();
  if (teacher == null) throw Exception('Not logged in.');

  final ttRepo = ref.watch(timetableRepoProvider);

  // 2. Parallel Fetch
  final results = await Future.wait([
    ttRepo.forTeacher(teacher.id),
    ttRepo.allSubjects(),
    authRepo.allUsers(),
  ]);

  final entries = results[0] as List<TimetableEntry>;
  final subjects = results[1] as List<Subject>;
  final users = results[2] as List<UserAccount>;

  // 3. Processing
  final subjectsMap = {for (final s in subjects) s.id: s};
  final leadMap = {for (final s in subjects) s.id: s.teacherId};
  final teacherMap = {for (final u in users.where((x) => x.role == UserRole.teacher)) u.id: u.name};

  final now = DateTime.now();
  final todayKey = _dayStr(now.weekday);

  int toMin(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));
  DateTime todayAt(String hm) {
    final p = hm.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
  }

  final todays = entries.where((e) => e.dayOfWeek == todayKey).toList()
    ..sort((a, b) => toMin(a.startTime).compareTo(toMin(b.startTime)));

  UpcomingClass? nextClass;
  bool canMark = false;

  for (final e in todays) {
    final start = todayAt(e.startTime);
    final end = todayAt(e.endTime);
    if (!now.isBefore(start) && now.isBefore(end)) {
      nextClass = UpcomingClass(e, end.difference(now).inMinutes, isOngoing: true);
      canMark = true;
      break;
    }
    if (start.isAfter(now)) {
      nextClass = UpcomingClass(e, start.difference(now).inMinutes, isOngoing: false);
      canMark = false;
      break;
    }
  }

  return TeacherDashboardVM(
    allEntries: entries,
    nextClass: nextClass,
    todaysClasses: todays,
    canMarkNext: canMark,
    subjectsMap: subjectsMap,
    teacherNamesMap: teacherMap,
    subjectLeadMap: leadMap,
  );
});

String _dayStr(int w) => const {1:'Mon',2:'Tue',3:'Wed',4:'Thu',5:'Fri',6:'Sat',7:'Sun'}[w] ?? 'Mon';

class TeacherHomePage extends ConsumerStatefulWidget {
  const TeacherHomePage({super.key});

  @override
  ConsumerState<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends ConsumerState<TeacherHomePage> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _periodStarts = ['08:30', '09:30', '10:30', '11:30', '12:30', '13:30', '14:30', '15:30', '16:30'];
  static const _periodLabels = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];
  int _year = 4;

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(teacherDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu', icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('Teacher Dashboard'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(teacherDashboardProvider),
        ),
        data: (vm) {
          return RefreshIndicator(
            onRefresh: () => ref.refresh(teacherDashboardProvider.future),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _YearSelector(selected: _year, onSelect: (y) => setState(() => _year = y)),
                _ActionButtons(),
                if (vm.nextClass != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _NextClassCard(vm: vm),
                  ),
                _TodayList(vm: vm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                  child: Text('Weekly Timetable', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TimetableGrid(
                  days: _days, periodStarts: _periodStarts, periodLabels: _periodLabels,
                  entries: vm.allEntries.where((e) => e.section.contains(_year == 1 ? 'I-' : _year == 2 ? 'II-' : _year == 3 ? 'III-' : 'IV-')).toList(),
                  subjectCodes: vm.subjectsMap.map((k, v) => MapEntry(k, v.code)),
                  subjectLeadTeacherId: vm.subjectLeadMap,
                  teacherNames: vm.teacherNamesMap,
                  todayKey: _dayStr(DateTime.now().weekday),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NextClassCard extends StatelessWidget {
  final TeacherDashboardVM vm;
  const _NextClassCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final nc = vm.nextClass!;
    final e = nc.entry;
    final subjName = vm.subjectsMap[e.subjectId]?.name ?? e.subjectId;

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(nc.isOngoing ? 'Ongoing • Ends in ${nc.minutesToStart}m' : 'Next in ${nc.minutesToStart}m',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('$subjName\nRoom ${e.room} • ${e.section}'),
        isThreeLine: true,
        trailing: Tooltip(
          message: vm.canMarkNext ? 'Mark Attendance' : 'Too early',
          child: FilledButton.tonal(
            onPressed: vm.canMarkNext ? () => context.push('/teacher/mark/${e.id}') : null,
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }
}

class _TodayList extends StatelessWidget {
  final TeacherDashboardVM vm;
  const _TodayList({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.todaysClasses.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text('No classes today.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.all(16), child: Text("Today's Classes", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
        ...vm.todaysClasses.map((e) {
          final subj = vm.subjectsMap[e.subjectId]?.name ?? e.subjectId;
          return ListTile(
            leading: const Icon(Icons.class_),
            title: Text(subj, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${TimeFormatter.formatSlot(e.slot)} • ${e.room} • ${e.section}'),
            trailing: FilledButton.tonal(
              onPressed: () => context.push('/teacher/mark/${e.id}'),
              child: const Text('Mark'),
            ),
          );
        }),
      ],
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
          FilledButton.tonalIcon(onPressed: () => context.push('/teacher/internal-marks'), icon: const Icon(Icons.assessment), label: const Text('Marks')),
          FilledButton.tonalIcon(onPressed: () => context.push('/teacher/remarks-board'), icon: const Icon(Icons.label), label: const Text('Remarks')),
          FilledButton.tonalIcon(onPressed: () => context.push('/students/directory'), icon: const Icon(Icons.people), label: const Text('Students')),
        ],
      ),
    );
  }
}

class _YearSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;
  const _YearSelector({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [1, 2, 3, 4].map((y) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text('$y${y==1?'st':y==2?'nd':y==3?'rd':'th'} Year'),
            selected: selected == y,
            onSelected: (_) => onSelect(y),
          ),
        )).toList(),
      ),
    );
  }
}