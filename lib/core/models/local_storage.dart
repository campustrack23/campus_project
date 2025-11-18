
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const String kUsers = 'users';
  static const String kSubjects = 'subjects';
  static const String kTimetable = 'timetable';
  static const String kAttendance = 'attendance';
  static const String kQueries = 'queries';
  static const String kSessionUserId = 'session_user_id';
  static const String kSeeded = 'seeded';
  static const String kOtpMap = 'otp_map';

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

  static String? get kLowWarned => null;
  Future<void> markSeeded() async => prefs.setBool(kSeeded, true);
}
