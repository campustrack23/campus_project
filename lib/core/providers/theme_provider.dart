// lib/core/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage.dart';
import '../../main.dart';

// 1. Define the provider that the UI will watch.
final themeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ThemeModeNotifier(storage);
});

// 2. Create the Notifier class to manage the state.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final LocalStorage _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.system) {
    _loadTheme();
  }

  // Load the saved theme from local storage on startup.
  void _loadTheme() {
    final savedTheme = _storage.readString(LocalStorage.kThemeMode);
    switch (savedTheme) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
        break;
    }
  }

  // Toggle the theme and save the new preference.
  void toggleTheme(bool isDark) {
    if (isDark) {
      state = ThemeMode.dark;
      _storage.writeString(LocalStorage.kThemeMode, 'dark');
    } else {
      state = ThemeMode.light;
      _storage.writeString(LocalStorage.kThemeMode, 'light');
    }
  }
}