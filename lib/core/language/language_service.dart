import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';

class LanguageService extends ChangeNotifier with WidgetsBindingObserver {
  final SharedPreferences _prefs;
  static const String _localeKey = 'app_locale';

  Locale _locale;
  bool _useSystemLocale = true;
  static const String _useSystemLocaleKey = 'use_system_locale';

  /// Creates a LanguageService with default or saved locale.
  LanguageService(this._prefs, Locale systemLocale) : _locale = systemLocale {
    // Load saved preferences
    _loadSavedLocale();

    // Register observer for locale changes
    WidgetsBinding.instance.addObserver(this);
  }

  /// Get current locale
  Locale get locale =>
      _useSystemLocale ? PlatformDispatcher.instance.locale : _locale;

  /// Check if we're using system locale
  bool get isUsingSystemLocale => _useSystemLocale;

  /// Set to use system locale
  void useSystemLocale() {
    _useSystemLocale = true;
    _prefs.setBool(_useSystemLocaleKey, true);
    notifyListeners();
  }

  /// Set a specific locale
  void setLocale(Locale newLocale) {
    _locale = newLocale;
    _useSystemLocale = false;

    // Save to preferences
    _prefs.setString(
        _localeKey, '${newLocale.languageCode}_${newLocale.countryCode ?? ""}');
    _prefs.setBool(_useSystemLocaleKey, false);

    notifyListeners();
  }

  /// Load saved locale from preferences
  void _loadSavedLocale() {
    _useSystemLocale = _prefs.getBool(_useSystemLocaleKey) ?? true;

    final String? savedLocale = _prefs.getString(_localeKey);
    if (!_useSystemLocale && savedLocale != null) {
      final parts = savedLocale.split('_');
      if (parts.length > 1 && parts[1].isNotEmpty) {
        _locale = Locale(parts[0], parts[1]);
      } else {
        _locale = Locale(parts[0]);
      }
    }
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    // If the system locale changes and we're using system locale, notify listeners
    if (_useSystemLocale) {
      notifyListeners();
    }
    super.didChangeLocales(locales);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Get list of supported locales
  static List<Locale> get supportedLocales => [
        const Locale('en', 'US'), // English
        const Locale('ko', 'KR'), // Korean
        // Add more supported locales as needed
      ];

  /// Get a locale display name for UI
  static String getDisplayName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'ko':
        return '한국어';
      default:
        return locale.languageCode;
    }
  }
}
