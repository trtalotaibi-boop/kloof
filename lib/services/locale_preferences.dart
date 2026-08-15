import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalePreferences {
  static const String _languageCodeKey = 'language_code';
  static const Set<String> _supportedLanguageCodes = {'ar', 'en'};

  static final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  static Future<Locale?> loadLocale() async {
    try {
      final languageCode = await _preferences.getString(_languageCodeKey);
      if (languageCode == null ||
          !_supportedLanguageCodes.contains(languageCode)) {
        return null;
      }
      return Locale(languageCode);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveLocale(Locale locale) async {
    final languageCode = locale.languageCode;
    if (!_supportedLanguageCodes.contains(languageCode)) {
      return;
    }

    try {
      await _preferences.setString(_languageCodeKey, languageCode);
    } catch (_) {
      // Preference persistence is best-effort. The active locale remains valid
      // for the current app session even if the local write fails.
    }
  }
}
