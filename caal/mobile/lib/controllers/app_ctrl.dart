import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;
import 'package:livekit_components/livekit_components.dart' as components;
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/caal_token_source.dart';

enum AppScreenState { welcome, agent }

enum AgentScreenState { visualizer, transcription }

class AppCtrl extends ChangeNotifier {
  static const uuid = Uuid();
  static final _logger = Logger('AppCtrl');

  // Configuration
  String _serverUrl;

  String get serverUrl => _serverUrl;

  // States
  AppScreenState appScreenState = AppScreenState.welcome;
  AgentScreenState agentScreenState = AgentScreenState.visualizer;

  bool isUserCameEnabled = false;
  bool isScreenshareEnabled = false;

  final messageCtrl = TextEditingController();
  final messageFocusNode = FocusNode();

  // Session objects - can be recreated if native resources are disposed
  sdk.Room _room = sdk.Room(roomOptions: const sdk.RoomOptions(enableVisualizer: true));
  late components.RoomContext _roomContext = components.RoomContext(room: _room);
  late sdk.Session _session = _createSession();

  // Public getters for current instances
  sdk.Room get room => _room;
  components.RoomContext get roomContext => _roomContext;
  sdk.Session get session => _session;

  sdk.Session _createSession() {
    return sdk.Session.fromConfigurableTokenSource(
      createCaalTokenSource(serverUrl).cached(),
      options: sdk.SessionOptions(room: _room),
    );
  }

  /// Tracks if session objects need recreation
  bool _needsRecreation = false;

  /// Key that changes when session objects are recreated, forcing widget rebuild
  int sessionKey = 0;

  /// Mark session objects as needing recreation (called on error)
  void _markNeedsRecreation() {
    _needsRecreation = true;
  }

  /// Recreate all session objects (Room, RoomContext, Session).
  /// Called when native resources have been disposed (e.g., app swiped away).
  Future<void> _recreateSessionObjects() async {
    if (!_needsRecreation) return;

    _logger.info('Recreating session objects...');

    // Remove listener from old session
    _session.removeListener(_handleSessionChange);

    // Dispose old objects (ignore errors - they may already be disposed)
    try {
      await _session.dispose();
    } catch (e) {
      _logger.fine('Session dispose error (expected): $e');
    }
    try {
      await _room.dispose();
    } catch (e) {
      _logger.fine('Room dispose error (expected): $e');
    }
    try {
      _roomContext.dispose();
    } catch (e) {
      _logger.fine('RoomContext dispose error (expected): $e');
    }

    // Create fresh objects
    _room = sdk.Room(roomOptions: const sdk.RoomOptions(enableVisualizer: true));
    _roomContext = components.RoomContext(room: _room);
    _session = _createSession();
    _session.addListener(_handleSessionChange);

    _needsRecreation = false;
    sessionKey++; // Increment to force widget rebuild
    _logger.info('Session objects recreated (key: $sessionKey)');
    notifyListeners();
  }

  bool isSendButtonEnabled = false;
  bool isSessionStarting = false;
  bool _hasCleanedUp = false;

  AppCtrl({
    required String serverUrl,
  })  : _serverUrl = serverUrl {
    final format = DateFormat('HH:mm:ss');
    Logger.root.level = Level.FINE;
    Logger.root.onRecord.listen((record) {
      debugPrint('${format.format(record.time)}: ${record.message}');
    });

    messageCtrl.addListener(() {
      final newValue = messageCtrl.text.isNotEmpty;
      if (newValue != isSendButtonEnabled) {
        isSendButtonEnabled = newValue;
        notifyListeners();
      }
    });

    session.addListener(_handleSessionChange);
  }

  /// Update server URL config.
  /// Called when user changes settings.
  void updateConfig({
    required String serverUrl,
  }) {
    if (serverUrl == _serverUrl) {
      return;
    }

    _logger.info('Updating config - serverUrl: $serverUrl');
    _serverUrl = serverUrl;
    notifyListeners();
  }

  Future<void> _cleanUp() async {
    if (_hasCleanedUp) return;
    _hasCleanedUp = true;

    _session.removeListener(_handleSessionChange);
    await _session.dispose();
    await _room.dispose();
    _roomContext.dispose();
    messageCtrl.dispose();
    messageFocusNode.dispose();
  }

  @override
  void dispose() {
    unawaited(_cleanUp());
    super.dispose();
  }

  void sendMessage() async {
    isSendButtonEnabled = false;

    final text = messageCtrl.text;
    messageCtrl.clear();
    notifyListeners();

    if (text.isEmpty) return;
    await session.sendText(text);
  }

  void toggleUserCamera(components.MediaDeviceContext? deviceCtx) {
    isUserCameEnabled = !isUserCameEnabled;
    isUserCameEnabled ? deviceCtx?.enableCamera() : deviceCtx?.disableCamera();
    notifyListeners();
  }

  void toggleScreenShare() {
    isScreenshareEnabled = !isScreenshareEnabled;
    notifyListeners();
  }

  void toggleAgentScreenMode() {
    agentScreenState =
        agentScreenState == AgentScreenState.visualizer ? AgentScreenState.transcription : AgentScreenState.visualizer;
    notifyListeners();
  }

  void connect() async {
    if (isSessionStarting) {
      _logger.fine('Connection attempt ignored: session already starting.');
      return;
    }

    _logger.info('Starting session connection…');
    isSessionStarting = true;
    notifyListeners();

    try {
      await _session.start();
      if (_session.connectionState == sdk.ConnectionState.connected) {
        appScreenState = AppScreenState.agent;
        WakelockPlus.enable();
        notifyListeners();
      }
    } catch (error, stackTrace) {
      final errorStr = error.toString();

      // Check if this is a disposed MediaStreamTrack error
      if (errorStr.contains('disposed') || errorStr.contains('MediaStreamTrack')) {
        _logger.warning('Native resources disposed, marking for recreation...');
        _markNeedsRecreation();
        await _recreateSessionObjects();

        // Retry connection with fresh objects
        try {
          await _session.start();
          if (_session.connectionState == sdk.ConnectionState.connected) {
            appScreenState = AppScreenState.agent;
            WakelockPlus.enable();
            notifyListeners();
            return;
          }
        } catch (retryError, retryStack) {
          _logger.severe('Retry connection error: $retryError', retryError, retryStack);
        }
      } else {
        _logger.severe('Connection error: $error', error, stackTrace);
      }

      appScreenState = AppScreenState.welcome;
      notifyListeners();
    } finally {
      if (isSessionStarting) {
        isSessionStarting = false;
        notifyListeners();
      }
    }
  }

  Future<void> disconnect() async {
    await session.end();
    session.restoreMessageHistory(const []);
    WakelockPlus.disable();
    appScreenState = AppScreenState.welcome;
    agentScreenState = AgentScreenState.visualizer;
    notifyListeners();
  }

  void _handleSessionChange() {
    final sdk.ConnectionState state = _session.connectionState;
    AppScreenState? nextScreen;
    switch (state) {
      case sdk.ConnectionState.connected:
      case sdk.ConnectionState.reconnecting:
        nextScreen = AppScreenState.agent;
        break;
      case sdk.ConnectionState.disconnected:
        nextScreen = AppScreenState.welcome;
        break;
      case sdk.ConnectionState.connecting:
        nextScreen = null;
        break;
    }

    if (nextScreen != null && nextScreen != appScreenState) {
      appScreenState = nextScreen;
      notifyListeners();
    }
  }
}
