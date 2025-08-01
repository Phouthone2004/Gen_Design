// services/settings_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../data/settings_model.dart';

class SettingsService {
  static const _key = 'app_settings';
  static final SettingsService instance = SettingsService._init();
  
  SettingsService._init();

  Future<void> saveSettings(SettingsModel settings) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = settings.toJson();
    await prefs.setString(_key, jsonString);
  }

  Future<SettingsModel> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString != null) {
      try {
        return SettingsModel.fromJson(jsonString);
      } catch (e) {
        // If decoding fails, return default settings
        return SettingsModel();
      }
    }
    // If no settings are saved, return default settings
    return SettingsModel();
  }
}
