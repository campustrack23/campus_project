// lib/core/utils/date_parser.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class DateParser {
  /// Safely parses dynamic Firestore date fields into a DateTime object.
  /// Provides a fallback to current time to prevent fatal app crashes on malformed data,
  /// while logging the error in debug mode for developer visibility.
  static DateTime parse(dynamic input, {String? fieldName}) {
    if (input == null) {
      if (kDebugMode) print('⚠️ DateParser: Null input for field ${fieldName ?? 'unknown'}');
      return DateTime.now();
    }

    try {
      if (input is Timestamp) return input.toDate();
      if (input is DateTime) return input;
      if (input is String) return DateTime.parse(input);
      if (input is int) return DateTime.fromMillisecondsSinceEpoch(input);
    } catch (e) {
      if (kDebugMode) print('⚠️ DateParser: Failed to parse date for field ${fieldName ?? 'unknown'} - Input: $input');
    }

    return DateTime.now();
  }
}