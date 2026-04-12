// lib/features/common/widgets/timetable_grid.dart
import 'package:flutter/material.dart';
import '../../../core/models/timetable_entry.dart';
import '../../../core/utils/time_formatter.dart';
import 'override_class_dialog.dart'; // ✅ Fixed path

class TimetableGrid extends StatelessWidget {
  final List<String> days;
  final List<String> periodStarts;
  final List<String> periodLabels;
  final List<TimetableEntry> entries;
  final Map<String, String> subjectCodes;
  final Map<String, String> subjectLeadTeacherId;
  final Map<String, String> teacherNames;
  final String? todayKey;

  // ✅ ADDED: Pass this from the Teacher's timetable page.
  // If it is null, the grid knows it's being viewed by a student.
  final String? currentTeacherId;

  const TimetableGrid({
    super.key,
    required this.days,
    required this.periodStarts,
    required this.periodLabels,
    required this.entries,
    required this.subjectCodes,
    required this.subjectLeadTeacherId,
    this.teacherNames = const {},
    this.todayKey,
    this.currentTeacherId,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<int, TimetableEntry>> grid = {
      for (final d in days) d: {}
    };

    for (final e in entries) {
      final entryTime = _normalizeTime(e.startTime);
      int pIndex = -1;

      for (int i = 0; i < periodStarts.length; i++) {
        if (_normalizeTime(periodStarts[i]) == entryTime) {
          pIndex = i;
          break;
        }
      }

      if (pIndex != -1 && grid.containsKey(e.dayOfWeek)) {
        grid[e.dayOfWeek]![pIndex] = e;
      }
    }

    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    int currentPeriodIndex = -1;

    if (todayKey != null && days.contains(todayKey)) {
      for (int i = 0; i < periodStarts.length; i++) {
        final startMins = _parseTime(periodStarts[i]);
        final endMins = startMins + 60;

        if (nowMins >= startMins && nowMins < endMins) {
          currentPeriodIndex = i;
          break;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth - 60;
        final double dynamicColWidth = availableWidth / periodStarts.length;
        final double finalColWidth =
        dynamicColWidth > 115.0 ? dynamicColWidth : 115.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              columnWidths: {
                0: const FixedColumnWidth(60),
                for (int i = 0; i < periodStarts.length; i++)
                  i + 1: FixedColumnWidth(finalColWidth),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                  ),
                  children: [
                    _buildHeaderCell(context, 'Day', ''),
                    for (int i = 0; i < periodStarts.length; i++)
                      _buildHeaderCell(
                        context,
                        periodLabels[i],
                        TimeFormatter.formatTime(periodStarts[i]),
                      ),
                  ],
                ),
                for (final day in days)
                  TableRow(
                    decoration: BoxDecoration(
                      color: day == todayKey
                          ? Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.05)
                          : null,
                    ),
                    children: [
                      _buildDayCell(context, day, isToday: day == todayKey),
                      for (int i = 0; i < periodStarts.length; i++)
                        _buildClassCell(
                          context,
                          grid[day]?[i],
                          isCurrent:
                          day == todayKey && i == currentPeriodIndex,
                          isToday: day == todayKey,
                          periodIndex: i,
                          currentPeriodIndex: currentPeriodIndex,
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _parseTime(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  String _normalizeTime(String time) {
    final parts = time.split(':');
    return '${int.parse(parts[0]).toString().padLeft(2, '0')}:${int.parse(parts[1]).toString().padLeft(2, '0')}';
  }

  Widget _buildHeaderCell(BuildContext context, String label, String subLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (subLabel.isNotEmpty)
            Text(subLabel, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, String day,
      {required bool isToday}) {
    return Container(
      height: 85,
      alignment: Alignment.center,
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(day,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isToday
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
            )),
      ),
    );
  }

  Widget _buildClassCell(
      BuildContext context,
      TimetableEntry? entry, {
        required bool isCurrent,
        required bool isToday,
        required int periodIndex,
        required int currentPeriodIndex,
      }) {
    if (entry == null) {
      return const SizedBox(height: 85);
    }

    final subjCode = subjectCodes[entry.subjectId] ?? 'SUBJ';

    // ✅ FIXED LOGIC: Allow only TODAY, current/future periods, AND if the user is a Teacher
    final isFutureOrCurrent = periodIndex >= currentPeriodIndex;
    final isTeacher = currentTeacherId != null;
    final canOverride = isToday && isFutureOrCurrent && isTeacher;

    final baseColor = isCurrent
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainer;

    final highlightColor = canOverride
        ? Theme.of(context).colorScheme.secondaryContainer
        : baseColor;

    return InkWell(
      onLongPress: canOverride
          ? () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Override Class'),
            content: Text(
                'Do you want to override "$subjCode" for today?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Yes')),
            ],
          ),
        );

        if (confirm != true) return;

        final today = DateTime.now();
        final dateString =
            "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

        showDialog(
          context: context,
          builder: (_) => OverrideClassDialog(
            entry: entry,
            subjectName: subjCode,
            dateString: dateString,
            currentTeacherId: currentTeacherId!, // ✅ PASSED THE REQUIRED ID
          ),
        );
      }
          : null, // ❌ disabled for past classes or students

      child: Container(
        height: 85,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: highlightColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: canOverride
                ? Theme.of(context).colorScheme.secondary
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subjCode,
                style:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const Spacer(),
            Text(entry.room,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.bold)),
            if (isTeacher && !canOverride && isToday)
              const Text("Locked",
                  style: TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}