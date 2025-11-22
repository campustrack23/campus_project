// lib/core/services/local_storage.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalStorage {
  // Only keep keys that are actually used
  static const String kThemeMode = 'theme_mode';
  static const String kNotifications = 'notifications';
  static const String kSeeded = 'seeded';

  final SharedPreferences prefs;
  LocalStorage(this.prefs);

  // ===== NOTIFICATIONS (List of Maps) =====
  List<Map<String, dynamic>> readList(String key) {
    final str = prefs.getString(key);
    if (str == null || str.isEmpty) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      debugPrint('LocalStorage: Error parsing list for key $key: $e');
      return [];
    }
  }

  Future<void> writeList(String key, List<Map<String, dynamic>> items) async {
    await prefs.setString(key, jsonEncode(items));
  }

  // ===== SETTINGS (Strings/Bools) =====
  String? readString(String key) => prefs.getString(key);

  Future<void> writeString(String key, String? value) async {
    if (value == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, value);
    }
  }

  bool get isSeeded => prefs.getBool(kSeeded) ?? false;
  Future<void> markSeeded() async => await prefs.setBool(kSeeded, true);

  // ===== CLEAR SESSION =====
  Future<void> clearSession() async {
    // Only clear user-specific data, keep app settings like Seeded state
    await prefs.remove(kNotifications);
    // If you stored user ID or auth tokens manually, clear them here.
    // Note: Firebase Auth handles its own persistence.
    debugPrint('LocalStorage: Session data cleared.');
  }
}

final localStorageProvider = Provider<LocalStorage>((ref) {
  throw UnimplementedError('localStorageProvider must be overridden in main.dart');
});