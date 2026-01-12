'use client';

import { useEffect, useState } from 'react';
import { RoomEvent } from 'livekit-client';
import { useRoomContext } from '@livekit/components-react';

export interface ToolStatus {
  toolUsed: boolean;
  toolNames: string[];
  toolParams: Record<string, unknown>[];
}

/**
 * Hook to track tool usage status from the agent.
 * Listens for data packets with topic "tool_status" from the backend.
 */
export function useToolStatus() {
  const room = useRoomContext();
  const [toolStatus, setToolStatus] = useState<ToolStatus | null>(null);

  useEffect(() => {
    if (!room) return;

    const handleDataReceived = (
      payload: Uint8Array,
      participant: unknown,
      kind: unknown,
      topic?: string
    ) => {
      // Only handle tool_status messages
      if (topic !== 'tool_status') return;

      try {
        const decoder = new TextDecoder();
        const data = JSON.parse(decoder.decode(payload));

        setToolStatus({
          toolUsed: data.tool_used ?? false,
          toolNames: data.tool_names ?? [],
          toolParams: data.tool_params ?? [],
        });
      } catch (error) {
        console.error('[useToolStatus] Failed to parse tool status:', error);
      }
    };

    room.on(RoomEvent.DataReceived, handleDataReceived);

    return () => {
      room.off(RoomEvent.DataReceived, handleDataReceived);
    };
  }, [room]);

  return toolStatus;
}
