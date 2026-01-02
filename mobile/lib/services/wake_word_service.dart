import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';

/// Service that listens for the wake word and triggers a callback when detected.
/// Used to unmute the microphone when user says the wake word.
class WakeWordService extends ChangeNotifier {
  PorcupineManager? _porcupineManager;
  final VoidCallback onWakeWordDetected;
  final String serverUrl;
  final String porcupineAccessKey;
  final String? customWakeWordPath;
  bool _isEnabled = false;
  bool _isReady = false;

  /// Callback to unmute the microphone - set by the control bar
  VoidCallback? onUnmuteMic;

  bool get isEnabled => _isEnabled;
  bool get isReady => _isReady;

  WakeWordService({
    required this.onWakeWordDetected,
    required this.serverUrl,
    required this.porcupineAccessKey,
    this.customWakeWordPath,
  });

  /// Calls the backend /api/wake endpoint to trigger a greeting.
  Future<void> _callWakeApi() async {
    if (serverUrl.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$serverUrl/api/wake'),
        headers: {'Content-Type': 'application/json'},
        body: '{"room_name": "voice_assistant_room"}',
      );
      if (response.statusCode == 200) {
        debugPrint('[WakeWordService] Wake API called successfully');
      } else {
        debugPrint('[WakeWordService] Wake API error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[WakeWordService] Wake API failed: $e');
    }
  }

  /// Enable wake word mode and start listening.
  Future<bool> enable() async {
    if (_isEnabled) return true;

    if (porcupineAccessKey.isEmpty) {
      debugPrint('[WakeWordService] Porcupine access key not set, wake word disabled');
      return false;
    }

    try {
      // Use custom path if set, otherwise fall back to bundled asset
      final wakeWordPath = (customWakeWordPath?.isNotEmpty == true)
          ? customWakeWordPath!
          : 'assets/wakeword.ppn';

      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        porcupineAccessKey,
        [wakeWordPath],
        _onWakeWordCallback,
        errorCallback: _onError,
      );
      await _porcupineManager?.start();
      _isEnabled = true;
      _isReady = true;
      debugPrint('[WakeWordService] Enabled and listening for wake word');
      notifyListeners();
      return true;
    } on PorcupineException catch (e) {
      debugPrint('[WakeWordService] Failed to initialize: ${e.message}');
      return false;
    }
  }

  /// Disable wake word mode and stop listening.
  Future<void> disable() async {
    if (!_isEnabled) return;

    await _porcupineManager?.stop();
    await _porcupineManager?.delete();
    _porcupineManager = null;
    _isEnabled = false;
    _isReady = false;
    debugPrint('[WakeWordService] Disabled');
    notifyListeners();
  }

  /// Toggle wake word mode on/off.
  Future<bool> toggle() async {
    if (_isEnabled) {
      await disable();
      return false;
    } else {
      return await enable();
    }
  }

  /// Clean up resources.
  @override
  Future<void> dispose() async {
    await disable();
    super.dispose();
  }

  void _onWakeWordCallback(int keywordIndex) async {
    debugPrint('[WakeWordService] Wake word detected!');
    // Call the wake API to trigger greeting, then unmute
    await _callWakeApi();
    onUnmuteMic?.call();
    onWakeWordDetected();
  }

  void _onError(PorcupineException e) {
    debugPrint('[WakeWordService] Error: ${e.message}');
  }
}
