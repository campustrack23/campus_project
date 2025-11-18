// lib/features/common/widgets/timetable_grid.dart
import 'package:flutter/material.dart';
import '../../../core/utils/time_formatter.dart';

class TimetableGrid extends StatelessWidget {
  final List<String> days;
  final List<String> periodStarts;
  final List<String> periodLabels;
  final List<dynamic> entries; // Use dynamic for TimetableEntry
  final Map<String, String> subjectCodes;
  final Map<String, String> subjectLeadTeacherId;
  final Map<String, String> teacherNames;
  final String todayKey;

  const TimetableGrid({
    super.key,
    required this.days,
    required this.periodStarts,
    required this.periodLabels,
    required this.entries,
    required this.subjectCodes,
    required this.subjectLeadTeacherId,
    required this.teacherNames,
    required this.todayKey,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<int, List<String>>> grid = {for (final d in days) d: {}};

    for (final e in entries) {
      final p = periodStarts.indexOf(e.startTime);
      if (p == -1) continue;
      final leadId = subjectLeadTeacherId[e.subjectId];
      final ids = (e.teacherIds.isNotEmpty)
          ? e.teacherIds
          : (leadId != null && leadId.isNotEmpty ? [leadId] : <String>[]);
      final tNames = ids.map((t) => teacherNames[t] ?? 'Teacher').join(' + ');
      final teacherText = tNames.isEmpty ? '' : ' ($tNames)';
      final code = subjectCodes[e.subjectId] ?? 'SUBJ';
      final line = '$code • ${e.room}$teacherText';
      (grid[e.dayOfWeek]![p] ??= <String>[]).add(line);
    }

    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    int currentPeriod = -1;
    if (days.contains(todayKey)) {
      for (int i = 0; i < periodStarts.length; i++) {
        final startMins = int.parse(periodStarts[i].substring(0, 2)) * 60 + int.parse(periodStarts[i].substring(3, 5));
        final endMins = startMins + 60;
        if (nowMins >= startMins && nowMins < endMins) {
          currentPeriod = i;
          break;
        }
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const FixedColumnWidth(120),
            for (int i = 0; i < periodStarts.length; i++) i + 1: const FixedColumnWidth(160),
          },
          border: TableBorder.symmetric(
            inside: BorderSide(color: Theme.of(context).dividerColor),
            outside: BorderSide.none,
          ),
          children: [
            TableRow(
              decoration: BoxDecoration(color: Theme.of(context).dividerColor.withAlpha(20)),
              children: [
                _cellHeader('DAYS / PERIODS'),
                for (int i = 0; i < periodStarts.length; i++)
                  _cellHeader('${periodLabels[i]}\n${TimeFormatter.formatTime(periodStarts[i])}'),
              ],
            ),
            for (final d in days)
              TableRow(
                decoration: d == todayKey ? BoxDecoration(color: Theme.of(context).colorScheme.primary.withAlpha(13)) : null,
                children: [
                  _cellDay(d, isToday: d == todayKey),
                  for (int p = 0; p < periodStarts.length; p++)
                    _cellBody(
                      (grid[d]![p] ?? const <String>[]).join('\n'),
                      isCurrent: d == todayKey && p == currentPeriod,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cellHeader(String t) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
  );

  Widget _cellDay(String t, {bool isToday = false}) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(t, style: TextStyle(fontWeight: isToday ? FontWeight.w900 : FontWeight.w700)),
  );

  Widget _cellBody(String t, {bool isCurrent = false}) => Container(
    padding: const EdgeInsets.all(8),
    decoration: isCurrent
        ? BoxDecoration(
      border: Border.all(color: Colors.blueAccent, width: 2),
      borderRadius: BorderRadius.circular(4),
      color: Colors.blue.withAlpha(26),
    )
        : null,
    alignment: Alignment.center,
    child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  );
}