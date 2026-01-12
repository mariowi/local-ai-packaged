import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as sdk;

/// Server-side wake word detection state.
enum WakeWordState {
  /// Agent is waiting for wake word
  listening,

  /// Wake word detected, agent is processing conversation
  active,
}

/// Controller that listens for wakeword_state data packets from the backend.
///
/// This tracks server-side OpenWakeWord detection state, allowing the UI
/// to show whether the agent is waiting for wake word or actively listening.
class WakeWordStateCtrl extends ChangeNotifier {
  final sdk.Room room;
  final String serverUrl;
  late final sdk.EventsListener<sdk.RoomEvent> _listener;

  WakeWordState? _state;
  bool _isEnabled = false;
  bool _hasFetched = false;

  /// Current wake word state. Null if server-side detection is disabled.
  WakeWordState? get state => _state;

  /// Whether server-side wake word detection is enabled (from API).
  bool get isEnabled => _isEnabled;

  /// Whether we've fetched the initial state from the API.
  bool get hasFetched => _hasFetched;

  /// Whether server-side wake word detection is active (we've received state updates).
  bool get isServerWakeWordActive => _isEnabled;

  WakeWordStateCtrl({required this.room, required this.serverUrl}) {
    _listener = room.createListener();
    _listener.on<sdk.DataReceivedEvent>(_handleDataReceived);
    _listener.on<sdk.RoomConnectedEvent>(_handleRoomConnected);

    // If room is already connected, fetch immediately
    if (room.connectionState == sdk.ConnectionState.connected) {
      debugPrint('[WakeWordStateCtrl] Room already connected, fetching state');
      _fetchInitialState();
    }
  }

  void _handleRoomConnected(sdk.RoomConnectedEvent event) {
    debugPrint('[WakeWordStateCtrl] Room connected, fetching initial state');
    _fetchInitialState();
  }

  Future<void> _fetchInitialState({int retryCount = 0}) async {
    if (serverUrl.isEmpty) {
      debugPrint('[WakeWordStateCtrl] No serverUrl, skipping initial fetch');
      return;
    }

    // Already fetched successfully
    if (_hasFetched) return;

    try {
      // Extract base URL (remove /api/connection-details path if present)
      final uri = Uri.parse(serverUrl);
      final baseUrl = '${uri.scheme}://${uri.host}:8889';
      final statusUrl = '$baseUrl/wake-word/status';

      debugPrint('[WakeWordStateCtrl] Fetching initial state from: $statusUrl (attempt ${retryCount + 1})');

      final response = await http.get(
        Uri.parse(statusUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      debugPrint('[WakeWordStateCtrl] Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _hasFetched = true;
        _isEnabled = data['enabled'] == true;
        if (_isEnabled) {
          // If enabled, default to 'listening' until we get a state update
          _state = WakeWordState.listening;
          debugPrint('[WakeWordStateCtrl] Wake word enabled, set state to listening');
        } else {
          debugPrint('[WakeWordStateCtrl] Wake word disabled');
        }
        notifyListeners();
      }
    } catch (error) {
      debugPrint('[WakeWordStateCtrl] Failed to fetch initial state: $error');
      // Retry up to 3 times with exponential backoff
      if (retryCount < 3) {
        final delay = Duration(milliseconds: 500 * (retryCount + 1));
        debugPrint('[WakeWordStateCtrl] Retrying in ${delay.inMilliseconds}ms...');
        await Future.delayed(delay);
        _fetchInitialState(retryCount: retryCount + 1);
      }
    }
  }

  void _handleDataReceived(sdk.DataReceivedEvent event) {
    // Only handle wakeword_state messages
    if (event.topic != 'wakeword_state') return;

    try {
      final jsonString = utf8.decode(event.data);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      if (data['type'] == 'wakeword_state' && data['state'] != null) {
        final stateStr = data['state'] as String;
        _state = switch (stateStr) {
          'listening' => WakeWordState.listening,
          'active' => WakeWordState.active,
          _ => null,
        };
        notifyListeners();
      }
    } catch (error) {
      debugPrint('[WakeWordStateCtrl] Failed to parse wake word state: $error');
    }
  }

  /// Reset state (e.g., when disconnecting)
  void reset() {
    _state = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }
}
