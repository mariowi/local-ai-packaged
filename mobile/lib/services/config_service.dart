import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app configuration stored in SharedPreferences.
///
/// Handles connection settings (server URL, Porcupine key) that persist
/// between app launches. This replaces the need for a compile-time .env file.
class ConfigService extends ChangeNotifier {
  static const _keyServerUrl = 'caal_server_url';
  static const _keyPorcupineKey = 'porcupine_access_key';
  static const _keyWakeWordPath = 'wake_word_ppn_path';

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences. Must be called before accessing any values.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Whether the app has been configured with a valid server URL.
  bool get isConfigured => serverUrl.isNotEmpty;

  /// The CAAL server URL (e.g., "http://192.168.1.100:3000").
  String get serverUrl => _prefs?.getString(_keyServerUrl) ?? '';

  /// The Porcupine access key for wake word detection (optional).
  String get porcupineAccessKey =>
      (_prefs?.getString(_keyPorcupineKey) ?? '').replaceAll('"', '').replaceAll("'", '');

  /// Path to the custom wake word .ppn file in app storage.
  String get wakeWordPath => _prefs?.getString(_keyWakeWordPath) ?? '';

  /// Save the server URL.
  Future<void> setServerUrl(String url) async {
    await _prefs?.setString(_keyServerUrl, url.trim());
    notifyListeners();
  }

  /// Save the Porcupine access key.
  Future<void> setPorcupineAccessKey(String key) async {
    await _prefs?.setString(_keyPorcupineKey, key.trim());
    notifyListeners();
  }

  /// Save the wake word file path.
  Future<void> setWakeWordPath(String path) async {
    await _prefs?.setString(_keyWakeWordPath, path.trim());
    notifyListeners();
  }

  /// Clear all configuration (for testing or reset).
  Future<void> clear() async {
    await _prefs?.remove(_keyServerUrl);
    await _prefs?.remove(_keyPorcupineKey);
    await _prefs?.remove(_keyWakeWordPath);
    notifyListeners();
  }
}
