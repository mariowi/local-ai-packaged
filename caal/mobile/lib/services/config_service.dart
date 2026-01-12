import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing app configuration stored in SharedPreferences.
///
/// Handles connection settings (server URL) that persist between app launches.
class ConfigService extends ChangeNotifier {
  static const _keyServerUrl = 'caal_server_url';

  SharedPreferences? _prefs;

  /// Initialize SharedPreferences. Must be called before accessing any values.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Whether the app has been configured with a valid server URL.
  bool get isConfigured => serverUrl.isNotEmpty;

  /// The CAAL server URL (e.g., "http://192.168.1.100:3000").
  String get serverUrl => _prefs?.getString(_keyServerUrl) ?? '';

  /// Save the server URL.
  Future<void> setServerUrl(String url) async {
    await _prefs?.setString(_keyServerUrl, url.trim());
    notifyListeners();
  }

  /// Clear all configuration (for testing or reset).
  Future<void> clear() async {
    await _prefs?.remove(_keyServerUrl);
    notifyListeners();
  }
}
