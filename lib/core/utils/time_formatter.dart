// lib/core/utils/time_formatter.dart
import 'package:intl/intl.dart';

class TimeFormatter {
  // Force AM/PM regardless of device locale
  static final DateFormat _twelveHour =
  DateFormat('h:mm a', 'en_US');
  static final DateFormat _twentyFourHour =
  DateFormat('HH:mm');

  /// "08:30" → "8:30 AM"
  static String formatTime(String time24) {
    final clean = time24.trim();
    if (clean.isEmpty || !clean.contains(':')) return time24;

    try {
      final parts = clean.split(':');
      if (parts.length != 2) return time24;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final temp = DateTime(2024, 1, 1, hour, minute);
      return _twelveHour.format(temp);
    } catch (_) {
      return time24;
    }
  }

  /// DateTime → "9:30 AM"
  static String formatDateTime(DateTime dt) {
    try {
      return _twelveHour.format(dt);
    } catch (_) {
      return dt.toString();
    }
  }

  /// "08:30-09:30" → "8:30 AM - 9:30 AM"
  static String formatSlot(String slot24h) {
    if (!slot24h.contains('-')) return slot24h;

    final parts = slot24h.split('-');
    if (parts.length != 2) return slot24h;

    return '${formatTime(parts[0])} - ${formatTime(parts[1])}';
  }

  /// "8:5" → "08:05"
  static String normalize24(String time) {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return time;

      final h = int.parse(parts[0]).clamp(0, 23);
      final m = int.parse(parts[1]).clamp(0, 59);

      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    } catch (_) {
      return time;
    }
  }

  /// "8:30 PM" → "20:30"
  static String to24h(String time12h) {
    try {
      final dt = _twelveHour.parse(time12h);
      return _twentyFourHour.format(dt);
    } catch (_) {
      return time12h;
    }
  }

  /// "09:30" → minutes from midnight (570)
  static int toMin(String time24) {
    try {
      final parts = time24.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (_) {
      return 0;
    }
  }

  /// Validate "HH:mm"
  static bool isValid24h(String time) {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return false;

      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);

      return h >= 0 && h <= 23 && m >= 0 && m <= 59;
    } catch (_) {
      return false;
    }
  }
}
