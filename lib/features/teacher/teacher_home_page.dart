// lib/features/teacher/teacher_home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/role.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/models/subject.dart';
import '../../core/models/user.dart';
import '../../core/utils/time_formatter.dart';
import '../../main.dart';
import '../common/widgets/timetable_grid.dart';
// --- NEW: Import for local storage ---
import '../../core/services/local_storage.dart';


final teacherDashboardProvider = FutureProvider.autoDispose((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final teacher = await authRepo.currentUser();
  if (teacher == null) throw Exception('Not logged in.');

  final ttRepo = ref.watch(timetableRepoProvider);

  // --- NEW: Offline Cache Logic ---
  final storage = ref.watch(localStorageProvider);
  try {
    // Fetch fresh data
    final allEntriesForTeacher = await ttRepo.forTeacher(teacher.id);
    final allSubjects = await ttRepo.allSubjects();
    final allUsers = await authRepo.allUsers();

    // Save to cache on success
    final cacheData = {
      'teacher': teacher.toMap(),
      'entries': allEntriesForTeacher.map((e) => e.toMap()).toList(),
      'subjects': allSubjects.map((e) => e.toMap()).toList(),
      'users': allUsers.map((e) => e.toMap()).toList(),
    };
    await storage.writeMap(LocalStorage.kOfflineTeacherTT, cacheData);

    return cacheData;

  } catch (e) {
    // On error, try to load from cache
    final cachedData = storage.readMap(LocalStorage.kOfflineTeacherTT);
    if (cachedData != null) {
      cachedData['isOffline'] = true;
      return cachedData;
    } else {
      rethrow;
    }
  }
  // --- End of Cache Logic ---
});


class TeacherHomePage extends ConsumerStatefulWidget {
  const TeacherHomePage({super.key});

  @override
  ConsumerState<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends ConsumerState<TeacherHomePage> {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _periodStarts = [
    '08:30', '09:30', '10:30', '11:30', '12:30', '13:30', '14:30', '15:30', '16:30'
  ];
  static const _periodLabels = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'];

  int _year = 4;

  List<String> _sectionsForYear(int y) => switch (y) {
    1 => ['I-HE'],
    2 => ['II-HE'],
    3 => ['III-HE'],
    _ => ['IV-HE'],
  };

  Future<void> _refresh() async => ref.invalidate(teacherDashboardProvider);

  int _toMin(String hhmm) => int.parse(hhmm.substring(0,2)) * 60 + int.parse(hhmm.substring(3,5));

  DateTime _todayAt(String hhmm) {
    final now = DateTime.now();
    final p = hhmm.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
  }

  @override
  Widget build(BuildContext context) {
    final asyncData = ref.watch(teacherDashboardProvider);

    return asyncData.when(
      loading: () => Scaffold(appBar: AppBar(title: const Text('Teacher Dashboard')), body: const Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
        body: AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(teacherDashboardProvider),
        ),
      ),
      data: (data) {
        // --- NEW: Parse data from maps ---
        final allEntriesForTeacher = (data['entries'] as List).map((e) => TimetableEntry.fromMap(e)).toList();
        final allSubjects = (data['subjects'] as List).map((e) => Subject.fromMap(e)).toList();
        final allUsers = (data['users'] as List).map((e) => UserAccount.fromMap(e)).toList();
        final isOffline = data['isOffline'] as bool? ?? false;
        // --- End of Parse ---

        final sections = _sectionsForYear(_year);
        final entriesAll = allEntriesForTeacher.where((e) => sections.contains(e.section)).toList();

        final subjects = {for (final s in allSubjects) s.id: s};
        final subjectCodes = {for (final s in allSubjects) s.id: s.code};
        final subjectLeadTeacherId = {for (final s in allSubjects) s.id: s.teacherId};

        final teacherMap = { for (final u in allUsers.where((x) => x.role == UserRole.teacher)) u.id: u.name };

        final now = DateTime.now();
        final todayKey = _dayStr(now.weekday);
        final todays = entriesAll.where((e) => e.dayOfWeek == todayKey).toList()
          ..sort((a, b) => _toMin(a.startTime).compareTo(_toMin(b.startTime)));
        final nextClass = _findNextOrOngoing(todays, now);

        bool canMarkNextClass = false;
        if (nextClass != null) {
          final classStartTime = _todayAt(nextClass.entry.startTime);
          canMarkNextClass = now.isAfter(classStartTime);
        }

        return Scaffold(
          appBar: AppBar(
            leading: Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Text('Teacher Dashboard'),
            actions: const [ProfileAvatarAction()],
            // --- NEW: Show offline banner ---
            bottom: isOffline
                ? PreferredSize(
              preferredSize: const Size.fromHeight(24.0),
              child: Container(
                color: Colors.amber,
                width: double.infinity,
                padding: const EdgeInsets.all(2.0),
                child: const Text(
                  'Offline Mode (data may be old)',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black, fontSize: 12),
                ),
              ),
            )
                : null,
            // --- End of Banner ---
          ),
          drawer: const AppDrawer(),
          body: RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      _yearChip(1), const SizedBox(width: 6),
                      _yearChip(2), const SizedBox(width: 6),
                      _yearChip(3), const SizedBox(width: 6),
                      _yearChip(4),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/teacher/internal-marks'),
                        icon: const Icon(Icons.assessment),
                        label: const Text('Internal Marks'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/teacher/remarks'),
                        icon: const Icon(Icons.label_important_outline),
                        label: const Text('Remarks Board'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => context.push('/students/directory'),
                        icon: const Icon(Icons.people_alt),
                        label: const Text('Students Directory'),
                      ),
                    ],
                  ),
                ),
                if (nextClass != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Card(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(
                          nextClass.isOngoing
                              ? 'Ongoing • ends in ${nextClass.minutesToStart} min'
                              : 'Next class in ${nextClass.minutesToStart} min',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${subjects[nextClass.entry.subjectId]?.name ?? nextClass.entry.subjectId} '
                              '• ${TimeFormatter.formatSlot(nextClass.entry.slot)} '
                              '• Room ${nextClass.entry.room} • ${nextClass.entry.section}',
                        ),
                        trailing: Tooltip(
                          message: canMarkNextClass ? 'Mark Attendance' : 'Class has not started yet',
                          child: FilledButton.tonal(
                            onPressed: canMarkNextClass
                                ? () => context.push('/teacher/mark?entryId=${Uri.encodeComponent(nextClass.entry.id)}')
                                : null,
                            child: const Text('Open'),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
                  child: Text("Today's Classes",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                if (todays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text('No classes scheduled today. See Weekly Timetable below.'),
                  )
                else
                  ...todays.map((e) {
                    final leadId = subjectLeadTeacherId[e.subjectId];
                    final ids = (e.teacherIds.isNotEmpty) ? e.teacherIds : (leadId != null && leadId.isNotEmpty ? [leadId] : <String>[]);
                    final tNames = ids.map((t) => teacherMap[t] ?? 'Teacher').join(' + ');
                    final teacherText = tNames.isEmpty ? '' : ' • $tNames';

                    final classStartTime = _todayAt(e.startTime);
                    final canMark = now.isAfter(classStartTime);

                    return ListTile(
                      leading: const Icon(Icons.class_),
                      title: Text(subjects[e.subjectId]?.name ?? e.subjectId,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${e.dayOfWeek} • ${TimeFormatter.formatSlot(e.slot)} • ${e.room} • ${e.section}$teacherText'),
                      trailing: Tooltip(
                        message: canMark ? 'Mark Attendance' : 'Class has not started yet',
                        child: FilledButton.tonal(
                          onPressed: canMark
                              ? () => context.push('/teacher/mark?entryId=${Uri.encodeComponent(e.id)}')
                              : null,
                          child: const Text('Mark'),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                  child: Text('Weekly Timetable',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                TimetableGrid(
                  days: _days,
                  periodStarts: _periodStarts,
                  periodLabels: _periodLabels,
                  entries: entriesAll,
                  subjectCodes: subjectCodes,
                  subjectLeadTeacherId: subjectLeadTeacherId,
                  teacherNames: teacherMap,
                  todayKey: todayKey,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
// ... (Rest of the file is unchanged) ...
  String _dayStr(int weekday) {
    const m = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return m[weekday]!;
  }

  _Upcoming? _findNextOrOngoing(List<TimetableEntry> todays, DateTime now) {
    if (todays.isEmpty) return null;
    for (final e in todays) {
      final start = _todayAt(e.startTime);
      final end = _todayAt(e.endTime);
      if (!now.isBefore(start) && now.isBefore(end)) {
        return _Upcoming(e, end.difference(now).inMinutes, isOngoing: true);
      }
      if (start.isAfter(now)) {
        return _Upcoming(e, start.difference(now).inMinutes, isOngoing: false);
      }
    }
    return null;
  }

  Widget _yearChip(int y) => ChoiceChip(
    label: Text('$y${y == 1 ? 'st' : y == 2 ? 'nd' : y == 3 ? 'rd' : 'th'} Year'),
    selected: _year == y,
    onSelected: (_) => setState(() => _year = y),
  );
}

class _Upcoming {
  final TimetableEntry entry;
  final int minutesToStart;
  final bool isOngoing;
  _Upcoming(this.entry, this.minutesToStart, {required this.isOngoing});
}