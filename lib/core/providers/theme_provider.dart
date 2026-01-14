// lib/core/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage.dart';

/// ThemeMode state notifier provider
final themeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final storage = ref.watch(localStorageProvider);
  return ThemeModeNotifier(storage);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final LocalStorage _storage;

  ThemeModeNotifier(this._storage) : super(ThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() {
    final savedTheme = _storage.readString(LocalStorage.kThemeMode);
    if (savedTheme == null) {
      state = ThemeMode.system;
      return;
    }

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

  /// Set theme explicitly and persist choice
  void setTheme(ThemeMode mode) {
    state = mode;

    final valueToSave = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

    _storage.writeString(LocalStorage.kThemeMode, valueToSave);
  }

  /// Convenience getter for UI usage
  bool get isDarkMode => state == ThemeMode.dark;
}
