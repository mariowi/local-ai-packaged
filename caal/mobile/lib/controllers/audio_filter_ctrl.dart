import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as sdk;

/// Controller that filters audio subscriptions to only include agent participants.
/// This prevents hearing other human participants in multi-device setups.
class AudioFilterCtrl extends ChangeNotifier {
  final sdk.Room room;
  sdk.EventsListener<sdk.RoomEvent>? _listener;

  AudioFilterCtrl({required this.room}) {
    _listener = room.createListener();
    _listener!.on<sdk.TrackSubscribedEvent>(_handleTrackSubscribed);
    _listener!.on<sdk.RoomConnectedEvent>(_handleRoomConnected);

    if (room.connectionState == sdk.ConnectionState.connected) {
      _filterExistingTracks();
    }
  }

  void _handleRoomConnected(sdk.RoomConnectedEvent event) {
    _filterExistingTracks();
  }

  void _filterExistingTracks() {
    for (final participant in room.remoteParticipants.values) {
      if (participant.kind == sdk.ParticipantKind.AGENT) continue;

      for (final pub in participant.audioTrackPublications) {
        if (pub.track != null) {
          unawaited((pub.track as sdk.RemoteAudioTrack).stop());
        }
        unawaited(pub.disable());
        if (pub.subscribed) {
          unawaited(pub.unsubscribe());
        }
      }
    }
  }

  void _handleTrackSubscribed(sdk.TrackSubscribedEvent event) {
    final participant = event.participant;
    final track = event.track;

    if (track.kind != sdk.TrackType.AUDIO) return;
    if (participant.kind == sdk.ParticipantKind.AGENT) return;

    unawaited((track as sdk.RemoteAudioTrack).stop());
    unawaited(event.publication.disable());
    unawaited(event.publication.unsubscribe());
  }

  @override
  void dispose() {
    _listener?.dispose();
    _listener = null;
    super.dispose();
  }
}
