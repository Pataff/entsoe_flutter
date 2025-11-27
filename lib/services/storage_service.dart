import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import 'entsoe_service.dart';

class StorageService {
  static const String _settingsKey = 'app_settings';
  static const String _historicalCacheKey = 'historical_price_cache';

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

  /// Carica la cache dei prezzi storici
  Future<HistoricalPriceCache?> loadHistoricalCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_historicalCacheKey);

    if (jsonString != null) {
      try {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        return HistoricalPriceCache.fromJson(json);
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  /// Salva la cache dei prezzi storici
  Future<bool> saveHistoricalCache(HistoricalPriceCache cache) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(cache.toJson());
    return prefs.setString(_historicalCacheKey, jsonString);
  }

  /// Cancella la cache dei prezzi storici
  Future<bool> clearHistoricalCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(_historicalCacheKey);
  }
}
