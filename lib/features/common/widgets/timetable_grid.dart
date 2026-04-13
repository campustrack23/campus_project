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
  final String? currentTeacherId;

  // ✅ ADDED: Support for highlighting cancelled classes
  final Set<String> cancelledEntryIds;

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
    this.cancelledEntryIds = const {},
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
        final endMins = startMins + 60; // Assuming 1 hour periods

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
        final double finalColWidth = dynamicColWidth > 120.0 ? dynamicColWidth : 120.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const BouncingScrollPhysics(),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Table(
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              columnWidths: {
                0: const FixedColumnWidth(60),
                for (int i = 0; i < periodStarts.length; i++)
                  i + 1: FixedColumnWidth(finalColWidth),
              },
              children: [
                // HEADER ROW
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  children: [
                    _buildHeaderCell(context, '', ''),
                    for (int i = 0; i < periodStarts.length; i++)
                      _buildHeaderCell(
                        context,
                        periodLabels[i],
                        TimeFormatter.formatTime(periodStarts[i]),
                      ),
                  ],
                ),
                // DAY ROWS
                for (final day in days)
                  TableRow(
                    decoration: BoxDecoration(
                      color: day == todayKey
                          ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2)
                          : null,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                    children: [
                      _buildDayCell(context, day, isToday: day == todayKey),
                      for (int i = 0; i < periodStarts.length; i++)
                        _buildClassCell(
                          context,
                          grid[day]?[i],
                          isCurrent: day == todayKey && i == currentPeriodIndex,
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
          if (subLabel.isNotEmpty)
            const SizedBox(height: 4),
          if (subLabel.isNotEmpty)
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, String day, {required bool isToday}) {
    return Container(
      height: 90,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: isToday
          ? Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: RotatedBox(
          quarterTurns: 3,
          child: Text(
            day.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ),
      )
          : RotatedBox(
        quarterTurns: 3,
        child: Text(
          day.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 1.5,
          ),
        ),
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
      return const SizedBox(height: 90);
    }

    final subjCode = subjectCodes[entry.subjectId] ?? 'SUBJ';
    final isCancelled = cancelledEntryIds.contains(entry.id);

    final isFutureOrCurrent = periodIndex >= currentPeriodIndex;
    final isTeacher = currentTeacherId != null;
    final canOverride = isToday && isFutureOrCurrent && isTeacher && !isCancelled;

    // Define colors based on state
    Color cardColor;
    Color borderColor = Colors.transparent;
    Color textColor = Theme.of(context).colorScheme.onSurface;

    if (isCancelled) {
      cardColor = Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
      textColor = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    } else if (isCurrent) {
      cardColor = Theme.of(context).colorScheme.primaryContainer;
      borderColor = Theme.of(context).colorScheme.primary;
      textColor = Theme.of(context).colorScheme.onPrimaryContainer;
    } else if (canOverride) {
      cardColor = Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.5);
      borderColor = Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5);
    } else {
      cardColor = Theme.of(context).colorScheme.surfaceContainerLow;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onLongPress: canOverride
          ? () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Override Class'),
            content: Text('Do you want to override "$subjCode" for today?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes')),
            ],
          ),
        );

        if (confirm != true) return;

        final today = DateTime.now();
        final dateString = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (_) => OverrideClassDialog(
              entry: entry,
              subjectName: subjCode,
              dateString: dateString,
              currentTeacherId: currentTeacherId!,
            ),
          );
        }
      }
          : null,
      child: Container(
        height: 75,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isCancelled
              ? Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1.5, style: BorderStyle.solid)
              : Border.all(color: borderColor, width: 1.5),
          boxShadow: isCancelled ? [] : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    subjCode,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: textColor,
                      decoration: isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isCancelled ? 'Cancelled' : entry.room,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isCancelled ? Colors.red.withValues(alpha: 0.7) : textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                if (isTeacher && !canOverride && isToday && !isCancelled)
                  const Icon(Icons.lock_outline, size: 12, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }
}