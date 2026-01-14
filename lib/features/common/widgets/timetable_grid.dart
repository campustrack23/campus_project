// lib/features/common/widgets/timetable_grid.dart
import 'package:flutter/material.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/models/timetable_entry.dart';

class TimetableGrid extends StatelessWidget {
  final List<String> days;
  final List<String> periodStarts;
  final List<String> periodLabels;
  final List<TimetableEntry> entries;
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
    // 1. Organize entries by Day -> Period Index
    final Map<String, Map<int, TimetableEntry>> grid = {for (final d in days) d: {}};

    for (final e in entries) {
      // FIX: Normalize time to handle "8:30" vs "08:30" mismatch
      final entryTime = _normalizeTime(e.startTime);
      int pIndex = -1;

      for (int i = 0; i < periodStarts.length; i++) {
        if (_normalizeTime(periodStarts[i]) == entryTime) {
          pIndex = i;
          break;
        }
      }

      if (pIndex != -1) {
        grid[e.dayOfWeek]![pIndex] = e;
      }
    }

    // 2. Calculate Current Period (for highlighting)
    final now = DateTime.now();
    final nowMins = now.hour * 60 + now.minute;
    int currentPeriodIndex = -1;

    if (days.contains(todayKey)) {
      for (int i = 0; i < periodStarts.length; i++) {
        final startMins = _parseTime(periodStarts[i]);
        final endMins = startMins + 60; // Assuming 1 hour slots
        if (nowMins >= startMins && nowMins < endMins) {
          currentPeriodIndex = i;
          break;
        }
      }
    }

    // 3. Build UI
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const FixedColumnWidth(60), // Day Column
            for (int i = 0; i < periodStarts.length; i++)
              i + 1: const FixedColumnWidth(115), // Class Columns
          },
          border: TableBorder(
            verticalInside: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              width: 1,
            ),
            horizontalInside: BorderSide.none,
          ),
          children: [
            // --- HEADER ROW ---
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
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

            // --- DATA ROWS ---
            for (final day in days)
              TableRow(
                decoration: BoxDecoration(
                  color: day == todayKey
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.04)
                      : null,
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.5))),
                ),
                children: [
                  _buildDayCell(context, day, isToday: day == todayKey),
                  for (int i = 0; i < periodStarts.length; i++)
                    _buildClassCell(
                      context,
                      grid[day]?[i],
                      isCurrent: (day == todayKey && i == currentPeriodIndex),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  int _parseTime(String hhmm) {
    try {
      final p = hhmm.split(':');
      return int.parse(p[0]) * 60 + int.parse(p[1]);
    } catch (_) {
      return 0;
    }
  }

  String _normalizeTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    return '${int.parse(parts[0]).toString().padLeft(2, '0')}:${int.parse(parts[1]).toString().padLeft(2, '0')}';
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeaderCell(BuildContext context, String label, String subLabel) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (subLabel.isNotEmpty)
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, String day, {required bool isToday}) {
    final color = isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      height: 85,
      alignment: Alignment.center,
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          day.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
            letterSpacing: 1.2,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildClassCell(BuildContext context, TimetableEntry? entry, {required bool isCurrent}) {
    if (entry == null) {
      return Container(
        height: 85,
        alignment: Alignment.center,
        child: Text(
          '-',
          style: TextStyle(
            color: Theme.of(context).dividerColor,
            fontSize: 20,
            fontWeight: FontWeight.w300,
          ),
        ),
      );
    }

    final subjCode = subjectCodes[entry.subjectId] ?? 'SUBJ';
    String teacherDisplay = '';
    if (entry.teacherIds.isNotEmpty) {
      final first = teacherNames[entry.teacherIds.first] ?? '';
      teacherDisplay = first.length > 10 ? '${first.substring(0, 8)}..' : first;
      if (entry.teacherIds.length > 1) teacherDisplay += ' +';
    } else {
      final leadId = subjectLeadTeacherId[entry.subjectId];
      if (leadId != null) {
        final name = teacherNames[leadId] ?? '';
        teacherDisplay = name.isNotEmpty ? name.split(' ').first : '';
      }
    }

    final bgColor = isCurrent
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainer;

    final borderColor = isCurrent
        ? Theme.of(context).colorScheme.primary
        : Colors.transparent;

    return Container(
      height: 85,
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: isCurrent ? [
            BoxShadow(color: borderColor.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))
          ] : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              subjCode,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                entry.room,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            if (teacherDisplay.isNotEmpty)
              Row(
                children: [
                  Icon(Icons.person, size: 10, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      teacherDisplay,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.secondary),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}