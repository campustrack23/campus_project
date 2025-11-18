// lib/features/student/timetable_page.dart
// --- FIX: Corrected import typos ---
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/role.dart';
import '../common/widgets/profile_avatar_action.dart';
import '../common/widgets/app_drawer.dart';
import '../common/widgets/async_error_widget.dart';
import '../../core/models/timetable_entry.dart';
import '../../core/models/user.dart';
import '../../core/models/subject.dart';
import '../../core/utils/time_formatter.dart';
import '../../main.dart';
import '../common/widgets/timetable_grid.dart';
import '../../core/services/local_storage.dart';

final timetablePageDataProvider = FutureProvider.autoDispose((ref) async {
  final authRepo = ref.watch(authRepoProvider);
  final user = await authRepo.currentUser();
  if (user == null) throw Exception('Not logged in');

  final ttRepo = ref.watch(timetableRepoProvider);
  final section = user.section ?? _TimetablePageUtil._sectionForYear(user.year);

  final storage = ref.watch(localStorageProvider);
  try {
    // Fetch fresh data
    final entries = await ttRepo.forSection(section);
    final subjects = await ttRepo.allSubjects();
    final allUsers = await authRepo.allUsers();

    // Save to cache on success
    final cacheData = {
      'user': user.toMap(),
      'section': section,
      'entries': entries.map((e) => e.toMap()).toList(),
      'subjects': subjects.map((e) => e.toMap()).toList(),
      'allUsers': allUsers.map((e) => e.toMap()).toList(),
    };
    await storage.writeMap(LocalStorage.kOfflineStudentTT, cacheData);

    return cacheData;

  } catch (e) {
    // On error, try to load from cache
    final cachedData = storage.readMap(LocalStorage.kOfflineStudentTT);
    if (cachedData != null) {
      // Add a flag to indicate this is offline data
      cachedData['isOffline'] = true;
      return cachedData;
    } else {
      // If no cache, re-throw the original error
      rethrow;
    }
  }
});

class TimetablePage extends ConsumerWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(timetablePageDataProvider);

    return asyncData.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(
        body: AsyncErrorWidget(
          message: err.toString(),
          onRetry: () => ref.invalidate(timetablePageDataProvider),
        ),
      ),
      data: (data) {
        final user = UserAccount.fromMap(data['user'] as Map<String, dynamic>);
        final section = data['section'] as String;
        final entries = (data['entries'] as List).map((e) => TimetableEntry.fromMap(e)).toList();
        final subs = (data['subjects'] as List).map((e) => Subject.fromMap(e)).toList();
        final allUsers = (data['allUsers'] as List).map((e) => UserAccount.fromMap(e)).toList();
        final isOffline = data['isOffline'] as bool? ?? false;

        final subjectCodes = {for (final s in subs) s.id: s.code};
        final subjects = {for (final s in subs) s.id: s};
        final subjectLeadTeacherId = {for (final s in subs) s.id: s.teacherId};
        final teacherMap = {for (final u in allUsers.where((x) => x.role == UserRole.teacher)) u.id: u.name};

        final todayKey = _TimetablePageUtil._dayStr(DateTime.now().weekday);
        final todays = entries.where((e) => e.dayOfWeek == todayKey).toList()
          ..sort((a, b) => _TimetablePageUtil._toMin(a.startTime).compareTo(_TimetablePageUtil._toMin(b.startTime)));
        final nextClass = _TimetablePageUtil._findNextOrOngoing(todays);

        return Scaffold(
          appBar: AppBar(
            leading: Builder(
              builder: (ctx) => IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: Text('Timetable • $section'),
            actions: const [ProfileAvatarAction()],
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
          ),
          drawer: const AppDrawer(),
          body: ListView(
            children: [
              if (nextClass != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                            '• ${TimeFormatter.formatSlot('${nextClass.entry.startTime}-${nextClass.entry.endTime}')} '
                            '• Room ${nextClass.entry.room}',
                      ),
                    ),
                  ),
                ),
              TimetableGrid(
                days: _TimetablePageUtil.days,
                periodStarts: _TimetablePageUtil.periodStarts,
                periodLabels: _TimetablePageUtil.periodLabels,
                entries: entries,
                subjectCodes: subjectCodes,
                subjectLeadTeacherId: subjectLeadTeacherId,
                teacherNames: teacherMap,
                todayKey: todayKey,
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// Static helpers to keep the main widget clean
class _TimetablePageUtil {
  static const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const periodStarts = [
    '08:30','09:30','10:30','11:30','12:30','13:30','14:30','15:30','16:30'
  ];
  static const periodLabels = ['I','II','III','IV','V','VI','VII','VIII','IX'];

  static String _sectionForYear(int? y) => switch (y) {
    1 => 'I-HE',
    2 => 'II-HE',
    3 => 'III-HE',
    _ => 'IV-HE',
  };

  static String _dayStr(int weekday) {
    const m = {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'};
    return m[weekday] ?? 'Mon';
  }

  static int _toMin(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

  static _Upcoming? _findNextOrOngoing(List<TimetableEntry> todays) {
    if (todays.isEmpty) return null;
    final now = DateTime.now();
    DateTime at(String hhmm) {
      final p = hhmm.split(':'); return DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
    }
    for (final e in todays) {
      final s = at(e.startTime), end = at(e.endTime);
      if (!now.isBefore(s) && now.isBefore(end)) return _Upcoming(e, end.difference(now).inMinutes, isOngoing: true);
      if (s.isAfter(now)) return _Upcoming(e, s.difference(now).inMinutes, isOngoing: false);
    }
    return null;
  }
}

class _Upcoming {
  final TimetableEntry entry;
  final int minutesToStart;
  final bool isOngoing;
  _Upcoming(this.entry, this.minutesToStart, {required this.isOngoing});
}