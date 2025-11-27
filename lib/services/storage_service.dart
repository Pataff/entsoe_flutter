import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class StorageService {
  static const String _settingsKey = 'app_settings';

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_settingsKey);

    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return AppSettings.fromJson(json);
      } catch (_) {
        return AppSettings();
      }
    }

    return AppSettings();
  }

  Future<bool> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(settings.toJson());
    return prefs.setString(_settingsKey, jsonString);
  }

  Future<bool> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_settingsKey);
  }
}
