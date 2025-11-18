// lib/core/services/local_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String kUsers = 'users';
  static const String kSubjects = 'subjects';
  static const String kTimetable = 'timetable';
  static const String kAttendance = 'attendance';
  static const String kQueries = 'queries';
  static const String kRemarks = 'remarks';
  static const String kSessionUserId = 'session_user_id';
  static const String kSeeded = 'seeded';
  static const String kOtpMap = 'otp_map';
  static const String kNotifications = 'notifications';
  static const String kLowWarned = 'low_warned';
  static const String kThemeMode = 'theme_mode';

  // --- NEW KEYS FOR OFFLINE CACHE ---
  static const String kOfflineStudentTT = 'offline_student_tt';
  static const String kOfflineTeacherTT = 'offline_teacher_tt';
  static const String kOfflineSubjects = 'offline_subjects';
  static const String kOfflineUsers = 'offline_users';
  // --- End of new keys ---

  final SharedPreferences prefs;
  LocalStorage(this.prefs);

  List<Map<String, dynamic>> readList(String key) {
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) return [];
    final list = jsonDecode(str) as List;
    return list.cast<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> items) async {
    await prefs.setString(key, jsonEncode(items));
  }

  // --- NEW: Helper for single JSON objects (like our cached data) ---
  Map<String, dynamic>? readMap(String key) {
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) return null;
    return jsonDecode(str) as Map<String, dynamic>;
  }

  Future<void> writeMap(String key, Map<String, dynamic> item) async {
    await prefs.setString(key, jsonEncode(item));
  }
  // --- End of new helper ---

  Map<String, String> readStringMap(String key) {
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) return {};
    final map = jsonDecode(str) as Map;
    return map.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  Future<void> writeStringMap(String key, Map<String, String> map) async {
    await prefs.setString(key, jsonEncode(map));
  }

  String? readString(String key) => prefs.getString(key);
  Future<void> writeString(String key, String? value) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  bool get isSeeded => prefs.getBool(kSeeded) ?? false;
  Future<void> markSeeded() async => prefs.setBool(kSeeded, true);
}