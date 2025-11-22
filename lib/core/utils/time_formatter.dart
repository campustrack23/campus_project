// lib/core/utils/time_formatter.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TimeFormatter {
  // Force 'en_US' locale to always show AM/PM, independent of device locale/settings
  static final DateFormat twelveHourFormat = DateFormat('h:mm a', 'en_US');
  static final DateFormat twentyFourHourFormat = DateFormat('HH:mm');

  // Format single 24h time string ("08:30") → "8:30 AM"
  static String formatTime(String time24h) {
    final cleanTime = time24h.trim();
    if (cleanTime.isEmpty || !cleanTime.contains(':')) return time24h;

    try {
      final parts = cleanTime.split(':');
      if (parts.length < 2) return time24h;

      final time = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );

      final dateTemp = DateTime(2024, 1, 1, time.hour, time.minute);
      return twelveHourFormat.format(dateTemp);
    } catch (_) {
      return time24h;
    }
  }

  // Format slot "08:30-09:30" → "8:30 AM - 9:30 AM"
  static String formatSlot(String slot24h) {
    if (slot24h.isEmpty || !slot24h.contains('-')) return slot24h;

    final parts = slot24h.split('-');
    if (parts.length != 2) return slot24h;

    return '${formatTime(parts[0])} - ${formatTime(parts[1])}';
  }

  // Convert 12h to 24h ("8:30 PM" → "20:30")
  static String to24h(String time12h) {
    try {
      final dt = twelveHourFormat.parse(time12h);
      return twentyFourHourFormat.format(dt);
    } catch (_) {
      return time12h;
    }
  }

  // Normalize 24h time input like "8:5" → "08:05"
  static String normalize24(String time) {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return time;

      final hour = int.parse(parts[0]).clamp(0, 23);
      final minute = int.parse(parts[1]).clamp(0, 59);

      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return time;
    }
  }

  // Validate 24h time format string "HH:mm"
  static bool isValid24h(String time) {
    if (!time.contains(':')) return false;

    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
    } catch (_) {
      return false;
    }
  }
}
