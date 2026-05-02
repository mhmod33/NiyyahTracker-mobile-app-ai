import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'isDarkMode';
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;
  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      final box = Hive.box('settings');
      _isDarkMode = box.get(_key, defaultValue: false) as bool;
      notifyListeners();
    } catch (_) {}
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    try {
      final box = Hive.box('settings');
      box.put(_key, _isDarkMode);
    } catch (_) {}
    notifyListeners();
  }
}
