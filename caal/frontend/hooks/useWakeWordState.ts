'use client';

import { useEffect, useState } from 'react';
import { RoomEvent } from 'livekit-client';
import { useRoomContext } from '@livekit/components-react';

export type WakeWordState = 'listening' | 'active' | null;

/**
 * Hook to track server-side wake word detection state.
 * Fetches initial state from API, then listens for data packets.
 *
 * States:
 * - 'listening': Agent is waiting for wake word (blue)
 * - 'active': Wake word detected, agent is processing conversation (green)
 * - null: Wake word detection is disabled (grey)
 */
export function useWakeWordState() {
  const room = useRoomContext();
  const [state, setState] = useState<WakeWordState>(null);

  // Fetch initial state from API
  useEffect(() => {
    const fetchInitialState = async () => {
      try {
        const response = await fetch('/api/wake-word/status');
        if (response.ok) {
          const data = await response.json();
          if (data.enabled) {
            // If enabled, default to 'listening' until we get a state update
            setState('listening');
          }
        }
      } catch (error) {
        console.error('[useWakeWordState] Failed to fetch initial state:', error);
      }
    };

    fetchInitialState();
  }, []);

  // Listen for state updates via data packets
  useEffect(() => {
    if (!room) return;

    const handleDataReceived = (
      payload: Uint8Array,
      participant: unknown,
      kind: unknown,
      topic?: string
    ) => {
      // Only handle wakeword_state messages
      if (topic !== 'wakeword_state') return;

      try {
        const decoder = new TextDecoder();
        const data = JSON.parse(decoder.decode(payload));

        if (data.type === 'wakeword_state' && data.state) {
          setState(data.state as WakeWordState);
        }
      } catch (error) {
        console.error('[useWakeWordState] Failed to parse wake word state:', error);
      }
    };

    room.on(RoomEvent.DataReceived, handleDataReceived);

    return () => {
      room.off(RoomEvent.DataReceived, handleDataReceived);
    };
  }, [room]);

  return state;
}
