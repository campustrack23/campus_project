import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeFormatter {
  static final twelveHourFormat = DateFormat('h:mm a');

  static String formatTime(String time24h) {
    if (time24h.isEmpty || !time24h.contains(':')) return time24h;
    try {
      final time = TimeOfDay(
        hour: int.parse(time24h.split(':')[0]),
        minute: int.parse(time24h.split(':')[1]),
      );
      final tempDate = DateTime(2025, 1, 1, time.hour, time.minute);
      return twelveHourFormat.format(tempDate);
    } catch (_) {
      return time24h; // Fallback
    }
  }

  static String formatSlot(String slot24h) {
    if (slot24h.isEmpty || !slot24h.contains('-')) return slot24h;
    final parts = slot24h.split('-');
    if (parts.length != 2) return slot24h;
    return '${formatTime(parts[0])} - ${formatTime(parts[1])}';
  }
}
