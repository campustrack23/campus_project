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

// -----------------------------------------------------------------------------
// VIEW MODEL
// -----------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// PROVIDER
// -----------------------------------------------------------------------------
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

  // Normalize days from Seeder ("1" -> "Mon")
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

// -----------------------------------------------------------------------------
// MAIN PAGE
// -----------------------------------------------------------------------------
class TeacherHomePage extends ConsumerWidget {
  const TeacherHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(teacherDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Workspace', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [ProfileAvatarAction()],
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
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
            child: Center(
              // 🔴 WEB FIX: Constrains the width so it doesn't stretch on large monitors
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(vm: vm),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: _ActionButtons(),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Today\'s Classes',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (vm.todaysClasses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.event_available_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No classes scheduled today!',
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text('Enjoy your free time.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: vm.todaysClasses.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (ctx, i) {
                          final entry = vm.todaysClasses[i];
                          final subj = vm.subjectsMap[entry.subjectId];
                          return _ModernClassCard(entry: entry, subject: subj, ref: ref);
                        },
                      ),
                    const SizedBox(height: 36),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Weekly Timetable',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _TimetablePreview(vm: vm),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HEADER
// -----------------------------------------------------------------------------
class _Header extends StatelessWidget {
  final TeacherDashboardVM vm;
  const _Header({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, Professor 👋',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${vm.todaysClasses.length} Classes Today',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Ready for the day?',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ACTION BUTTONS
// -----------------------------------------------------------------------------
class _ActionButtons extends StatelessWidget {
  const _ActionButtons();

  @override
  Widget build(BuildContext context) {
    final actions = [
      (title: 'Marks', icon: Icons.assessment_rounded, path: '/teacher/internal-marks', color: Colors.indigo),
      (title: 'Remarks', icon: Icons.rate_review_rounded, path: '/teacher/remarks-board', color: Colors.teal),
      (title: 'Students', icon: Icons.people_alt_rounded, path: '/students/directory', color: Colors.purple),
    ];

    // 🔴 WEB FIX: Uses GridView with fixed extents so cards NEVER stretch vertically or horizontally
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250, // Max width per card
        mainAxisExtent: 140,     // Fixed height per card
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (ctx, i) => _ModernActionCard(
        title: actions[i].title,
        icon: actions[i].icon,
        path: actions[i].path,
        themeColor: actions[i].color,
      ),
    );
  }
}

class _ModernActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String path;
  final MaterialColor themeColor;

  const _ModernActionCard({
    required this.title,
    required this.icon,
    required this.path,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 🔴 BORDER FIX: Solid, highly visible borders in light/dark mode
    final borderColor = isDark ? Colors.white30 : Colors.black26;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(path),
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? themeColor.shade900.withValues(alpha: 0.5) : themeColor.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDark ? themeColor.shade200 : themeColor.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TODAY's CLASS CARD
// -----------------------------------------------------------------------------
class _ModernClassCard extends StatelessWidget {
  final TimetableEntry entry;
  final Subject? subject;
  final WidgetRef ref;

  const _ModernClassCard({required this.entry, required this.subject, required this.ref});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timeStr = TimeFormatter.formatTime(entry.startTime).split(' ');

    // 🔴 BORDER FIX: Solid, highly visible borders in light/dark mode
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white30 : Colors.black26;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left Time Block
          Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timeStr[0],
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  timeStr.length > 1 ? timeStr[1] : '',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // Right Content Block
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subject?.name ?? 'Unknown Subject',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.class_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Sec: ${entry.section}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.room_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Room ${entry.room}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await context.push('/teacher/generate-qr/${entry.id}');
                        ref.invalidate(teacherDashboardProvider);
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('Take Attendance'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TIMETABLE PREVIEW
// -----------------------------------------------------------------------------
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white30 : Colors.black26;

    // Filter entries based on the selected year chip
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
        // --- YEAR FILTERS ---
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
                child: FilterChip(
                  label: Text(dayMap[d]!),
                  selected: isSel,
                  showCheckmark: false,
                  onSelected: (v) => setState(() => _selectedDay = d),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSel ? Theme.of(context).colorScheme.primary : borderColor,
                      width: 1.5,
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: isSel ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                  ),
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
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Center(
            child: Text(
              _selectedYear == null
                  ? 'No classes scheduled.'
                  : 'No classes for Year $_selectedYear.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
            ),
          ),
        )
            : TimetableGrid(
          days: [dayKey],
          periodStarts: const ['09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00', '16:00', '17:00'],
          periodLabels: const ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX'],
          entries: filteredEntries,
          subjectCodes: {for (var k in widget.vm.subjectsMap.keys) k: widget.vm.subjectsMap[k]?.code ?? ''},
          subjectLeadTeacherId: {for (var k in widget.vm.subjectsMap.keys) k: widget.vm.subjectsMap[k]?.teacherId ?? ''},
          teacherNames: widget.vm.teacherNamesMap,
          todayKey: dayKey,
          currentTeacherId: widget.vm.currentTeacherId,
          cancelledEntryIds: const {},
        ),
      ],
    );
  }

  Widget _buildYearChip(String label, int? yearValue) {
    final isSelected = _selectedYear == yearValue;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.white30 : Colors.black26;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      onSelected: (bool selected) {
        setState(() {
          _selectedYear = selected ? yearValue : null;
        });
      },
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Theme.of(context).colorScheme.secondary : borderColor,
          width: 1.5,
        ),
      ),
      labelStyle: TextStyle(
        color: isSelected ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}