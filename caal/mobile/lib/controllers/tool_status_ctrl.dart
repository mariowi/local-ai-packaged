import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;

/// Represents the current tool usage status from the agent.
class ToolStatus {
  final bool toolUsed;
  final List<String> toolNames;
  final List<Map<String, dynamic>> toolParams;

  const ToolStatus({
    this.toolUsed = false,
    this.toolNames = const [],
    this.toolParams = const [],
  });

  factory ToolStatus.fromJson(Map<String, dynamic> json) {
    return ToolStatus(
      toolUsed: json['tool_used'] as bool? ?? false,
      toolNames: (json['tool_names'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      toolParams: (json['tool_params'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [],
    );
  }

  @override
  String toString() => 'ToolStatus(toolUsed: $toolUsed, toolNames: $toolNames)';
}

/// Controller that listens for tool_status data packets from the backend.
class ToolStatusCtrl extends ChangeNotifier {
  final sdk.Room room;
  late final sdk.EventsListener<sdk.RoomEvent> _listener;

  ToolStatus _status = const ToolStatus();
  ToolStatus get status => _status;

  ToolStatusCtrl({required this.room}) {
    _listener = room.createListener();
    _listener.on<sdk.DataReceivedEvent>(_handleDataReceived);
  }

  void _handleDataReceived(sdk.DataReceivedEvent event) {
    // Only handle tool_status messages
    if (event.topic != 'tool_status') return;

    try {
      final jsonString = utf8.decode(event.data);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      _status = ToolStatus.fromJson(data);
      notifyListeners();
    } catch (error) {
      debugPrint('[ToolStatusCtrl] Failed to parse tool status: $error');
    }
  }

  /// Reset status (e.g., when disconnecting)
  void reset() {
    _status = const ToolStatus();
    notifyListeners();
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }
}
