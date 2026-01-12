'use client';

import { Track } from 'livekit-client';
import { AudioTrack, useTracks } from '@livekit/components-react';

/**
 * Custom audio renderer that only plays audio from agent participants.
 * This prevents hearing other human participants in multi-device setups.
 */
export function AgentAudioRenderer() {
  const tracks = useTracks(
    [Track.Source.Microphone, Track.Source.ScreenShareAudio, Track.Source.Unknown],
    {
      updateOnlyOn: [],
      onlySubscribed: true,
    }
  ).filter(
    (ref) =>
      !ref.participant.isLocal &&
      ref.publication.kind === Track.Kind.Audio &&
      ref.participant.isAgent
  );

  return (
    <div style={{ display: 'none' }}>
      {tracks.map((trackRef) => (
        <AudioTrack
          key={`${trackRef.participant.identity}-${trackRef.publication.trackSid}`}
          trackRef={trackRef}
        />
      ))}
    </div>
  );
}
