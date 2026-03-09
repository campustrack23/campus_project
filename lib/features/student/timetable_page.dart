import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

// -----------------------------------------------------------------------------
// VIEW MODEL
// -----------------------------------------------------------------------------

class TimetablePageVM {
  final String section;
  final List<TimetableEntry> entries;
  final Map<String, Subject> subjectsMap;
  final Map<String, String> teacherNamesMap;
  final Upcoming? nextClass;

  TimetablePageVM({
    required this.section,
    required this.entries,
    required this.subjectsMap,
    required this.teacherNamesMap,
    required this.nextClass,
  });
}

class Upcoming {
  final TimetableEntry entry;
  final int minutesToStart;
  final bool isOngoing;

  Upcoming(
      this.entry,
      this.minutesToStart, {
        required this.isOngoing,
      });
}

// -----------------------------------------------------------------------------
// PROVIDER (OPTIMIZED + CACHED)
// -----------------------------------------------------------------------------

final studentTimetablePageProvider =
FutureProvider.autoDispose<TimetablePageVM>((ref) async {
  // Cache for 5 minutes
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), () => link.close());
  ref.onDispose(timer.cancel);

  final authRepo = ref.watch(authRepoProvider);
  final user = await authRepo.currentUser();
  if (user == null) throw Exception('Not logged in');

  final section =
      user.section ?? _TimetableUtil.sectionForYear(user.year);

  final ttRepo = ref.watch(timetableRepoProvider);

  // Fetch data in parallel
  final results = await Future.wait([
    ttRepo.forSection(section),
    ttRepo.allSubjects(),
    authRepo.allUsers(),
  ]);

  final entries = results[0] as List<TimetableEntry>;
  final subjects = results[1] as List<Subject>;
  final users = results[2] as List<UserAccount>;

  final subjectsMap = {for (final s in subjects) s.id: s};
  final teacherNamesMap = {
    for (final u in users.where((u) => u.role == UserRole.teacher))
      u.id: u.name
  };

  final todayKey = _TimetableUtil.dayStr(DateTime.now().weekday);
  final todays = entries
      .where((e) => e.dayOfWeek == todayKey)
      .toList()
    ..sort(
          (a, b) => _TimetableUtil.toMinutes(a.startTime)
          .compareTo(_TimetableUtil.toMinutes(b.startTime)),
    );

  final nextClass = _TimetableUtil.findNextOrOngoing(todays);

  return TimetablePageVM(
    section: section,
    entries: entries,
    subjectsMap: subjectsMap,
    teacherNamesMap: teacherNamesMap,
    nextClass: nextClass,
  );
});

// -----------------------------------------------------------------------------
// UI
// -----------------------------------------------------------------------------

class TimetablePage extends ConsumerWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(studentTimetablePageProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text('My Timetable'),
        actions: const [ProfileAvatarAction()],
      ),
      drawer: const AppDrawer(),
      body: asyncData.when(
        loading: () =>
        const Center(child: CircularProgressIndicator()),
        error: (err, _) => AsyncErrorWidget(
          message: err.toString(),
          onRetry: () =>
              ref.invalidate(studentTimetablePageProvider),
        ),
        data: (vm) {
          final subjectCodes =
          vm.subjectsMap.map((k, v) => MapEntry(k, v.code));
          final subjectLeadMap =
          vm.subjectsMap.map((k, v) => MapEntry(k, v.teacherId));

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(studentTimetablePageProvider),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                if (vm.nextClass != null)
                  Padding(
                    padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: _NextClassCard(vm: vm),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Text(
                    'Section ${vm.section}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),

                TimetableGrid(
                  days: _TimetableUtil.days,
                  periodStarts:
                  _TimetableUtil.periodStarts,
                  periodLabels:
                  _TimetableUtil.periodLabels,
                  entries: vm.entries,
                  subjectCodes: subjectCodes,
                  subjectLeadTeacherId: subjectLeadMap,
                  teacherNames: vm.teacherNamesMap,
                  todayKey:
                  _TimetableUtil.dayStr(DateTime.now().weekday),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// NEXT CLASS CARD
// -----------------------------------------------------------------------------

class _NextClassCard extends StatelessWidget {
  final TimetablePageVM vm;
  const _NextClassCard({required this.vm});

  @override
  Widget build(BuildContext context) {
    final nc = vm.nextClass!;
    final e = nc.entry;
    final subject =
        vm.subjectsMap[e.subjectId]?.name ?? e.subjectId;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.schedule),
        title: Text(
          nc.isOngoing
              ? 'Ongoing • ends in ${nc.minutesToStart} min'
              : 'Next class in ${nc.minutesToStart} min',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$subject\n${TimeFormatter.formatSlot(e.slot)} • Room ${e.room}',
        ),
        isThreeLine: true,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UTILITIES
// -----------------------------------------------------------------------------

class _TimetableUtil {
  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const periodStarts = [
    '08:30',
    '09:30',
    '10:30',
    '11:30',
    '12:30',
    '13:30',
    '14:30',
    '15:30',
    '16:30',
  ];
  static const periodLabels = [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
  ];

  static String sectionForYear(int? year) => switch (year) {
    1 => 'I-HE',
    2 => 'II-HE',
    3 => 'III-HE',
    _ => 'IV-HE',
  };

  static String dayStr(int weekday) {
    const map = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    return map[weekday] ?? 'Mon';
  }

  static int toMinutes(String hhmm) =>
      int.parse(hhmm.substring(0, 2)) * 60 +
          int.parse(hhmm.substring(3, 5));

  static Upcoming? findNextOrOngoing(
      List<TimetableEntry> todays) {
    if (todays.isEmpty) return null;
    final now = DateTime.now();

    DateTime at(String hhmm) {
      final p = hhmm.split(':');
      return DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(p[0]),
        int.parse(p[1]),
      );
    }

    for (final e in todays) {
      final start = at(e.startTime);
      final end = at(e.endTime);

      if (!now.isBefore(start) && now.isBefore(end)) {
        return Upcoming(
          e,
          end.difference(now).inMinutes,
          isOngoing: true,
        );
      }

      if (start.isAfter(now)) {
        return Upcoming(
          e,
          start.difference(now).inMinutes,
          isOngoing: false,
        );
      }
    }
    return null;
  }
}
