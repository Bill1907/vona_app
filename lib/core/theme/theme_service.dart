import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'isDarkMode';
  final SharedPreferences _prefs;

  ThemeService(this._prefs);

  bool get isDarkMode => _prefs.getBool(_themeKey) ?? true;

  Future<void> toggleTheme() async {
    await _prefs.setBool(_themeKey, !isDarkMode);
    notifyListeners();
  }

  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;
}
