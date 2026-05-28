import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

const String _themeBoxKey = 'settings';
const String _themePrefKey = 'theme_mode';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final Box _box;

  ThemeNotifier(this._box) : super(_loadTheme(_box));

  static ThemeMode _loadTheme(Box box) {
    final int? themeIndex = box.get(_themePrefKey);
    if (themeIndex != null) {
      return ThemeMode.values[themeIndex];
    }
    return ThemeMode.dark; // Default to dark as per spec
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    _box.put(_themePrefKey, mode.index);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  // Wait for Hive to be initialized before accessing this provider
  final box = Hive.box('settings');
  return ThemeNotifier(box);
});
